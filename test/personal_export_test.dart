import 'dart:async';
import 'dart:convert';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/personal_export_service.dart';
import 'package:bookself_app/ui/screens/personal_export_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/test_fonts.dart';

void main() {
  setUpAll(useBundledTestFonts);
  test(
    'exporta somente fontes pessoais, omite tokens e preserva opcionais/datas',
    () async {
      final paths = <String>[];
      final service = PersonalExportService(
        currentUid: () => 'a',
        reader: (path, field, owner) async {
          paths.add(path);
          expect(owner, 'a');
          if (path == 'users/a') {
            return {
              'a': {
                'uid': 'a',
                'name': 'Pessoa',
                'inviteCode': 'segredo',
                'partnerUid': 'b',
              },
            };
          }
          if (path == 'books') {
            return {
              'book': {
                'userId': 'a',
                'finishedDate': null,
                'addedAt': Timestamp(100, 123),
              },
            };
          }
          return {};
        },
      );
      final result = jsonDecode(await service.export('a')) as Map;
      expect(result['atomicSnapshot'], false);
      expect(paths, [
        'users/a',
        'books',
        'bible_progress',
        'libraries/a/catalog',
        'libraries/a/entries',
        'libraries/a/listens',
        'libraries/a/series_visibility',
      ]);
      expect(result['collections']['users/a']['a'], {
        'uid': 'a',
        'name': 'Pessoa',
      });
      expect(result['collections']['books']['book']['finishedDate'], isNull);
      expect(
        result['collections']['books']['book']['addedAt']['type'],
        'timestamp',
      );
    },
  );
  test(
    'exporta configuração, episódios mesmo sem documento pai e ocultação somente próprios',
    () async {
      final paths = <String>[];
      final service = PersonalExportService(
        currentUid: () => 'a',
        reader: (path, _, _) async {
          paths.add(path);
          return switch (path) {
            'libraries/a/entries' => {
              'series': {'ownerId': 'a', 'mediaType': 'series'},
            },
            'libraries/a/series/series' => {},
            'libraries/a/series/series/episodes' => {
              'one': {
                'watched': true,
                'revision': 3,
                'updatedAt': Timestamp(100, 123),
              },
            },
            'libraries/a/series_visibility' => {
              'series': {'visible': false, 'revision': 2},
            },
            _ => {},
          };
        },
      );
      final result = jsonDecode(await service.export('a'))['collections'];
      expect(result['libraries/a/series/series'], isEmpty);
      expect(
        result['libraries/a/series/series/episodes']['one']['watched'],
        true,
      );
      expect(
        result['libraries/a/series/series/episodes']['one']['updatedAt']['nanoseconds'],
        123,
      );
      expect(
        result['libraries/a/series_visibility']['series']['visible'],
        false,
      );
      expect(
        paths.any((p) => p.contains('/b/') || p.startsWith('shared_')),
        false,
      );
    },
  );
  test(
    'falha em episódios, troca de conta e limite somado recusam cópia inteira',
    () async {
      for (final mode in ['failure', 'account', 'limit', 'path']) {
        var uid = 'a';
        final service = PersonalExportService(
          currentUid: () => uid,
          reader: (path, _, _) async {
            if (path.endsWith('/entries')) {
              return {
                mode == 'path' ? '../b' : 'series': {
                  'ownerId': 'a',
                  'mediaType': 'series',
                },
              };
            }
            if (path.endsWith('/episodes')) {
              if (mode == 'failure') throw StateError('falha');
              if (mode == 'account') uid = 'b';
              if (mode == 'limit') {
                return {
                  for (var i = 0; i < PersonalExportService.maxDocuments; i++)
                    '$i': {'watched': false},
                };
              }
            }
            return {};
          },
        );
        await expectLater(
          service.export('a'),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
      }
    },
  );
  test(
    'troca de sessão durante leitura descarta tudo e não consulta próxima fonte',
    () async {
      var uid = 'a';
      var reads = 0;
      final service = PersonalExportService(
        currentUid: () => uid,
        reader: (_, _, _) async {
          reads++;
          uid = 'b';
          return {};
        },
      );
      await expectLater(service.export('a'), throwsStateError);
      expect(reads, 1);
    },
  );
  test('dono divergente, falha e limite não produzem cópia parcial', () async {
    for (final mode in ['owner', 'network', 'size']) {
      final service = PersonalExportService(
        currentUid: () => 'a',
        reader: (path, _, _) async {
          if (mode == 'network') throw StateError('detalhe privado');
          if (mode == 'size') {
            return {
              for (var i = 0; i <= PersonalExportService.maxDocuments; i++)
                '$i': {},
            };
          }
          return path == 'books'
              ? {
                  'foreign': {'userId': 'b'},
                }
              : {};
        },
      );
      await expectLater(service.export('a'), throwsStateError);
    }
  });
  testWidgets('não copia automaticamente e retira cópia após troca de conta', (
    tester,
  ) async {
    final auth = JointAuth();
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: PersonalExportScreen(
            service: PersonalExportService(
              currentUid: () => auth.uid,
              reader: (_, _, _) async => {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gerar cópia pessoal'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    await tester.ensureVisible(find.text('Copiar JSON pessoal'));
    await tester.tap(find.text('Copiar JSON pessoal'));
    await tester.pumpAndSettle();
    expect(jsonDecode(copied.single)['ownerId'], 'a');
    auth.change();
    await tester.pumpAndSettle();
    expect(find.text('Copiar JSON pessoal'), findsNothing);
    auth.dispose();
  });
  testWidgets('falha traduzida permite retry; retorno tardio não expõe dados', (
    tester,
  ) async {
    final auth = JointAuth();
    var fail = true;
    final gate = Completer<Map<String, Map<String, dynamic>>>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: PersonalExportScreen(
            service: PersonalExportService(
              currentUid: () => auth.uid,
              reader: (_, _, _) async {
                if (fail) throw StateError('segredo');
                return gate.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gerar cópia pessoal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira a conexão'), findsOneWidget);
    expect(find.textContaining('segredo'), findsNothing);
    fail = false;
    await tester.tap(find.text('Gerar cópia pessoal'));
    await tester.pump();
    auth.change();
    gate.complete({});
    await tester.pumpAndSettle();
    expect(find.text('Copiar JSON pessoal'), findsNothing);
    expect(tester.takeException(), isNull);
    auth.dispose();
  });
}
