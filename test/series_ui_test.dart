import 'dart:async';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/data/models/series_record.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/services/series_progress_service.dart';
import 'package:bookself_app/ui/screens/series_add_screen.dart';
import 'package:bookself_app/ui/screens/series_details_screen.dart';
import 'package:bookself_app/ui/screens/series_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class EmptySeriesLibrary extends SeriesLibraryService {
  @override
  Future<LibraryPage<SeriesRecord>> page(
    String owner, {
    LibraryCursor? after,
  }) async => LibraryPage([], null);
  @override
  Future<int> count(String owner) async => 0;
}

void main() {
  setUpAll(useBundledTestFonts);
  late ProfileFirestoreFake db;
  late SeriesLibraryService service;
  late JointAuth auth;
  setUp(() {
    db = ProfileFirestoreFake();
    auth = JointAuth();
    service = SeriesLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
      progress: SeriesProgressService(firestore: db),
    );
  });
  Future<void> show(WidgetTester tester, Widget screen) async {
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
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'biblioteca vazia orienta episódios e oferece acesso direto a filmes',
    (tester) async {
      var movies = 0;
      await show(
        tester,
        SeriesLibraryScreen(
          service: EmptySeriesLibrary(),
          onBooks: () {},
          onMovies: () => movies++,
        ),
      );
      await tap(tester, 'Filmes');
      expect(movies, 1);
      await tester.scrollUntilVisible(
        find.text('Nenhuma série salva'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Cadastre uma série para acompanhar seus episódios.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cadastro manual sem API em tela pequena exige título e confirma escrita',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, SeriesAddScreen(owner: 'a', service: service));
      await tap(tester, 'Salvar série');
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Título da série'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Informe o título.'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Título da série'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da série'),
        'Série fictícia',
      );
      db.commitGate = Completer<void>();
      await tester.scrollUntilVisible(
        find.text('Salvar série'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Salvar série'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar série'));
      await tester.pump();
      expect(find.text('Salvando série…'), findsOneWidget);
      db.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(
        db.documents.values.where(
          (v) => v['mediaType'] == 'series' && v.containsKey('state'),
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('adiciona episódio, marca, pausa, retoma e desmarca sem cortes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = await service.save(
      service.prepare(
        'a',
        MediaMetadata(MediaType.series, {'title': 'Série fictícia'}),
      ),
    );
    await show(tester, SeriesDetailsScreen(series: row, service: service));
    await tap(tester, 'Adicionar episódio');
    await tap(tester, 'Temporada 1 · Episódio 1');
    expect(
      (await service.read('a', row.entry.id)).progress.episodes.single.watched,
      isTrue,
    );
    await tap(tester, 'Lista de episódios completa');
    expect(find.text('Em dia'), findsOneWidget);
    await tap(tester, 'Produção encerrada');
    expect(find.text('Concluída'), findsOneWidget);
    await tap(tester, 'Pausar série');
    expect(find.text('Pausada'), findsOneWidget);
    await tap(tester, 'Pausar série');
    await tap(tester, 'Temporada 1 · Episódio 1');
    expect(find.text('Em andamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
