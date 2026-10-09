import 'dart:async';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/movie_record.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/movie_library_service.dart';
import 'package:bookself_app/ui/screens/movie_add_screen.dart';
import 'package:bookself_app/ui/screens/movie_couple_screen.dart';
import 'package:bookself_app/ui/screens/movie_details_screen.dart';
import 'package:bookself_app/ui/screens/movie_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class MovieJointService extends CoupleWorkspaceService {
  final gate = Completer<void>();
  final selections = <CoupleSelection>[];
  @override
  String newId() => 'selection';
  @override
  Stream<List<CoupleRecord>> records(
    String relation,
    String collection, {
    String? listId,
  }) => Stream.value([
    CoupleRecord('list', {'title': 'Nossa lista'}),
  ]);
  @override
  Future<void> addItem(
    String uid,
    String relation,
    String listId,
    String id,
    CoupleSelection selection,
  ) {
    selections.add(selection);
    return gate.future;
  }
}

class PagedMovies extends MovieLibraryService {
  PagedMovies(MediaLibraryRepository repository, this.movies)
    : super(repository: repository);
  final List<MovieRecord> movies;
  @override
  Future<LibraryPage<MovieRecord>> page(
    String owner, {
    LibraryCursor? after,
  }) async => LibraryPage(movies.where((m) => m.entry.ownerId == owner), null);
  @override
  Future<int> count(String owner) async =>
      movies.where((m) => m.entry.ownerId == owner).length;
}

void main() {
  setUpAll(useBundledTestFonts);
  late ProfileFirestoreFake db;
  late MovieLibraryService service;
  late JointAuth auth;
  setUp(() {
    db = ProfileFirestoreFake();
    service = MovieLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
    auth = JointAuth();
  });
  Future<MovieRecord> movie({String title = 'Filme fictício'}) => service.save(
    service.prepare('a', MediaMetadata(MediaType.movie, {'title': title})),
  );
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    bool large = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(find.text(label), 160);
    }
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('filme é anunciado como botão e abre detalhes pelo teclado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final original = await movie();
    final paged = PagedMovies(FirestoreMediaLibraryRepository(firestore: db), [
      original,
    ]);
    await show(tester, MovieLibraryScreen(service: paged, onBooks: () {}));
    await tester.ensureVisible(find.text(original.title));
    await tester.pumpAndSettle();
    final card = find.bySemanticsLabel(
      RegExp('Filme fictício.*', dotAll: true),
    );
    expect(
      tester.getSemantics(card).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    var duplicateButtons = 0;
    void inspect(SemanticsNode node) {
      node.visitChildren((child) {
        if (!child.isMergedIntoParent &&
            child.getSemanticsData().flagsCollection.isButton) {
          duplicateButtons++;
        }
        inspect(child);
        return true;
      });
    }

    inspect(tester.getSemantics(card));
    expect(duplicateButtons, 0, reason: 'O cartão deve expor uma única ação.');
    // Percorre a ordem real de Tab, sem chamar o callback de abertura.
    var focused = false;
    for (var i = 0; i < 20; i++) {
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
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do filme'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('lista anuncia seleção e gravação com tela pequena e texto 2×', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shared = MovieJointService();
    await show(
      tester,
      MovieCoupleScreen(
        movie: await movie(),
        relation: 'relation',
        experience: false,
        service: shared,
      ),
      large: true,
    );
    await tap(tester, 'Nossa lista');
    final list = find.bySemanticsLabel('Nossa lista');
    final data = tester.getSemantics(list).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tap(tester, 'Adicionar à lista');
    await tester.ensureVisible(
      find.text('Adicionando filme à lista do casal. Aguarde.'),
    );
    await tester.pump();
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              'Adicionando filme à lista do casal. Aguarde.',
            ),
          )
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    auth.change();
    shared.gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'manual valida título e aguarda commit; falha permite retry do mesmo ID',
    (tester) async {
      await show(tester, MovieAddScreen(owner: 'a', service: service));
      await tap(tester, 'Salvar filme');
      expect(find.text('Informe o título.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Filme manual');
      db.commitGate = Completer<void>();
      await tap(tester, 'Salvar filme');
      expect(find.text('Salvando filme…'), findsOneWidget);
      expect(db.documents, isEmpty);
      final generated = db.generatedIds;
      db.commitGate!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tentar salvar novamente'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Tentar salvar novamente'), findsOneWidget);
      db.commitGate = Completer<void>();
      await tap(tester, 'Tentar salvar novamente');
      // O catálogo preparado conserva sua identidade. O repositório pode
      // reservar outro ID de entrada se a transação anterior não confirmou.
      expect(db.generatedIds, generated + 1);
      db.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(
        db.documents.keys.where((p) => p.contains('/entries/')),
        hasLength(1),
      );
      expect(
        db.documents.keys.where((p) => p.contains('/catalog/')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'troca de conta durante escrita não anuncia sucesso nem acessa contexto antigo',
    (tester) async {
      await show(tester, MovieAddScreen(owner: 'a', service: service));
      await tester.enterText(find.byType(TextFormField).first, 'Filme manual');
      db.commitGate = Completer<void>();
      await tap(tester, 'Salvar filme');
      auth.change();
      await tester.pump();
      expect(find.text('Sua conta mudou'), findsOneWidget);
      db.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sua conta mudou'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'detalhes tratam conflito e exigem releitura antes de nova escrita',
    (tester) async {
      final original = await movie();
      await service.update(original, watched: true, date: '2020-01-01');
      await show(tester, MovieDetailsScreen(movie: original, service: service));
      await tap(tester, 'Marcar como assistido');
      await tester.pumpAndSettle();
      expect(find.text('Recarregar filme'), findsOneWidget);
      await tap(tester, 'Recarregar filme');
      await tester.pumpAndSettle();
      expect(find.text('Assistido'), findsOneWidget);
      await tap(tester, 'Quero assistir');
      await tester.pumpAndSettle();
      expect((await service.read('a', original.entry.id)).watchedOn, isNull);
    },
  );
  testWidgets(
    'seleção requer consentimento e aguarda escrita sem copiar estado pessoal',
    (tester) async {
      final shared = MovieJointService();
      final original = await movie();
      await show(
        tester,
        MovieCoupleScreen(
          movie: original,
          relation: 'relation',
          experience: false,
          service: shared,
        ),
      );
      await tap(tester, 'Nossa lista');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Adicionar à lista'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tap(tester, 'Adicionar à lista');
      expect(find.text('Confirmando…'), findsOneWidget);
      expect(shared.selections.single.source, 'library');
      expect(shared.selections.single.toMap().containsKey('state'), isFalse);
      auth.change();
      await tester.pump();
      shared.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('O vínculo mudou'), findsOneWidget);
      expect((await service.read('a', original.entry.id)).watched, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'biblioteca filtra e limpa dados na troca de conta com texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = await movie(
        title: 'Filme fictício com título bastante longo para a tela pequena',
      );
      final watched = await service.update(
        original,
        watched: true,
        date: '2020-01-01',
      );
      final paged = PagedMovies(
        FirestoreMediaLibraryRepository(firestore: db),
        [watched],
      );
      await show(
        tester,
        MovieLibraryScreen(service: paged, onBooks: () {}),
        large: true,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum filme corresponde aos filtros'), findsOneWidget);
      auth.change();
      await tester.pumpAndSettle();
      expect(find.text(original.title), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
