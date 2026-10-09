import 'dart:async';
import 'package:bookself_app/services/music_listen_service.dart';
import 'package:bookself_app/ui/screens/music_listen_screen.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/ui/screens/music_add_screen.dart';
import 'package:bookself_app/ui/screens/music_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class RetryListen extends MusicListenService {
  final gate = Completer<void>();
  final ids = <String>[];
  @override
  String newId(String owner) => 'stable-listen';
  @override
  Future<void> save(String owner, String entry, String id, String date) async {
    ids.add(id);
    if (ids.length == 1) throw StateError('Falha simulada');
    await gate.future;
  }
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets(
    'escuta exige data, retry conserva intenção e retorno após troca é ignorado',
    (tester) async {
      final auth = JointAuth();
      final db = ProfileFirestoreFake();
      final library = MusicLibraryService(
        repository: FirestoreMediaLibraryRepository(firestore: db),
      );
      final music = await library.save(
        library.prepare(
          'a',
          MediaMetadata(MediaType.track, {
            'title': 'Faixa',
            'artists': ['Artista'],
          }),
        ),
      );
      final service = RetryListen();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: MusicListenScreen(music: music, service: service),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar escuta'),
            )
            .onPressed,
        null,
      );
      await tester.tap(find.text('Escolher data da escuta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar escuta'));
      await tester.pumpAndSettle();
      expect(service.ids, ['stable-listen']);
      expect(find.textContaining('conserva esta escuta'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(service.ids, ['stable-listen', 'stable-listen']);
      expect(find.text('Confirmando escuta…'), findsOneWidget);
      auth.change();
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sua conta mudou'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
  testWidgets('manual exige artistas e mostra versão em 320 px/texto 2×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = JointAuth();
    final db = ProfileFirestoreFake();
    final service = MusicLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MusicAddScreen(
            owner: 'a',
            service: service,
            type: MediaType.track,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('indisponível'), findsOneWidget);
    final save = find.text('Salvar música');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Informe os artistas.'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Informe os artistas.'), findsOneWidget);
    expect(db.writes, 0);
    expect(
      find.widgetWithText(TextFormField, 'Versão (opcional)'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
    final record = await service.save(
      service.prepare(
        'a',
        MediaMetadata(MediaType.track, {
          'title': 'Obra',
          'artists': ['Artista'],
          'version': 'Ao vivo',
          'albumTitle': 'Álbum',
        }),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: MusicDetailsScreen(music: record, service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Versão/edição: Ao vivo'), findsOneWidget);
    expect(find.text('Álbum: Álbum'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
