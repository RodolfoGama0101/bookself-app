import 'dart:async';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/series_record.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/services/series_progress_service.dart';
import 'package:bookself_app/services/series_sharing_service.dart';
import 'package:bookself_app/ui/screens/series_comparison_screen.dart';
import 'package:bookself_app/ui/screens/series_couple_screen.dart';
import 'package:bookself_app/ui/screens/series_add_screen.dart';
import 'package:bookself_app/ui/screens/series_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'movie_ui_test.dart' show MovieJointService;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class SharingFake extends SeriesSharingService {
  final selections = StreamController<List<SharedSeries>>.broadcast();
  final progress = StreamController<List<SeriesEpisode>>.broadcast();
  @override
  Stream<List<SharedSeries>> series(String owner) => selections.stream;
  @override
  Stream<List<SeriesEpisode>> episodes(String owner, String entry) =>
      progress.stream;
}

void main() {
  setUpAll(useBundledTestFonts);
  late ProfileFirestoreFake db;
  late SeriesLibraryService service;
  setUp(() {
    db = ProfileFirestoreFake();
    service = SeriesLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
      progress: SeriesProgressService(firestore: db),
    );
  });
  Future<SeriesRecord> create() => service.save(
    service.prepare(
      'a',
      MediaMetadata(MediaType.series, {'title': 'Série fictícia'}),
    ),
  );
  for (final route in ['comparison', 'couple', 'details', 'add']) {
    testWidgets(
      'retorno por botão continua disponível após troca de conta: $route',
      (tester) async {
        final row = await create(), auth = JointAuth(), sharing = SharingFake();
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => switch (route) {
                          'comparison' => SeriesComparisonScreen(
                            series: row,
                            partner: 'b',
                            relation: 'relation',
                            service: sharing,
                          ),
                          'couple' => SeriesCoupleScreen(
                            series: row,
                            relation: 'relation',
                            experience: true,
                          ),
                          'details' => SeriesDetailsScreen(
                            series: row,
                            service: service,
                          ),
                          _ => SeriesAddScreen(owner: 'a', service: service),
                        },
                      ),
                    ),
                    child: const Text('Abrir série'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir série'));
        await tester.pump();
        auth.change();
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Abrir série'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        await sharing.selections.close();
        await sharing.progress.close();
      },
    );
  }
  testWidgets(
    'comparação expõe seleção única e permite escolher série por Tab e Enter em tela pequena',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final row = await create(), auth = JointAuth(), sharing = SharingFake();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: SeriesComparisonScreen(
              series: row,
              partner: 'b',
              relation: 'relation',
              service: sharing,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(StreamBuilder<List<SharedSeries>>),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      sharing.selections.add([
        SharedSeries('series', 'Série compartilhada', 'manual-reference'),
      ]);
      await tester.pumpAndSettle();
      final card = find.widgetWithText(ListTile, 'Série compartilhada');
      await tester.scrollUntilVisible(
        card,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      var focused = false;
      for (var i = 0; i < 15; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (tester
                .getSemantics(card)
                .getSemanticsData()
                .flagsCollection
                .isFocused
                .toBoolOrNull() ==
            true) {
          focused = true;
          break;
        }
      }
      expect(focused, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        tester
            .getSemantics(card)
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        true,
      );
      sharing.progress.addError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Progresso indisponível.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .getSemantics(find.textContaining('Progresso indisponível.'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
      auth.dispose();
      await sharing.selections.close();
      await sharing.progress.close();
    },
  );
  test(
    'ocultação sobrevive ao retry de inclusão e marcação mantém projeção mínima',
    () async {
      final prepared = service.prepare(
        'a',
        MediaMetadata(MediaType.series, {'title': 'Série fictícia'}),
      );
      final row = await service.save(prepared);
      expect(await service.sharing.visible('a', row.entry.id), isTrue);
      await service.sharing.setVisible(row, false);
      await service.save(prepared);
      expect(await service.sharing.visible('a', row.entry.id), isFalse);
      final e = SeriesEpisode(id: 'one', season: 1, number: 1, available: true);
      await service.progress.saveEpisode('a', row.entry.id, e, watched: true);
      final projection =
          db.documents['shared_series/a/entries/${row.entry.id}/episodes/one']!;
      expect(projection.keys.toSet(), {
        'schemaVersion',
        'season',
        'number',
        'watched',
        'revision',
        'updatedAt',
      });
      expect(projection['watched'], isTrue);
      expect(
        db.documents.containsKey('shared_series/a/entries/${row.entry.id}'),
        isFalse,
      );
    },
  );
  testWidgets(
    'comparação retira progresso em erro, ocultação e troca de vínculo',
    (tester) async {
      final row = await create(), sharing = SharingFake(), auth = JointAuth();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: SeriesComparisonScreen(
              series: row,
              partner: 'b',
              relation: 'relation',
              service: sharing,
            ),
          ),
        ),
      );
      await tester.pump();
      sharing.selections.add([
        SharedSeries(
          'partner-series',
          'Série compartilhada',
          'manual-reference',
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Série compartilhada'));
      await tester.pump();
      sharing.progress.add([
        SeriesEpisode(
          id: 'one',
          season: 1,
          number: 3,
          available: true,
          watched: true,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Temporada 1 · Episódio 3'), findsOneWidget);
      sharing.progress.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Temporada 1 · Episódio 3'), findsNothing);
      sharing.selections.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhuma série compartilhada pelo parceiro.'),
        findsOneWidget,
      );
      auth.change();
      await tester.pumpAndSettle();
      expect(find.text('O vínculo mudou'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await sharing.selections.close();
      await sharing.progress.close();
    },
  );
  testWidgets(
    'seleção de episódio exige consentimento e descarta sucesso de conta antiga',
    (tester) async {
      final row = await create(),
          auth = JointAuth(),
          joint = MovieJointService();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: SeriesCoupleScreen(
              series: row,
              episode: SeriesEpisode(
                id: 'one',
                season: 2,
                number: 4,
                available: true,
              ),
              relation: 'relation',
              experience: false,
              service: joint,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nossa lista'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Adicionar à lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à lista'));
      await tester.pump();
      expect(joint.selections.single.episode, {
        'id': 'one',
        'season': 2,
        'number': 4,
      });
      expect(joint.selections.single.toMap().containsKey('watched'), isFalse);
      auth.change();
      joint.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('O vínculo mudou'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
