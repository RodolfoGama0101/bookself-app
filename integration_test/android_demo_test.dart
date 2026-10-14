import 'dart:math';

import 'package:bookself_app/main.dart' as app;
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/services/firebase_environment.dart';
import 'package:bookself_app/services/movie_library_service.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/ui/screens/main_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Este teste cria somente dados novos; não limpa outras sessões demo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'QA-03: bibliotecas e casal no Firebase Android demo',
    (tester) async {
      const environment = FirebaseEnvironment.fromDefines;
      if (!environment.useEmulators ||
          !const bool.fromEnvironment('RUN_ANDROID_DEMO_TESTS')) {
        fail('Exige opt-in RUN_ANDROID_DEMO_TESTS e USE_FIREBASE_EMULATORS.');
      }
      environment.validate();
      app.main();
      await waitFor(
        tester,
        () => find.byType(MaterialApp).evaluate().isNotEmpty,
      );
      await waitFor(
        tester,
        () =>
            find.byType(MainNavigation).evaluate().isNotEmpty ||
            find.text('Entrar').evaluate().isNotEmpty,
      );
      final auth = FirebaseEnvironment.auth;
      final db = FirebaseEnvironment.firestore;
      expect(auth.app.options.projectId, FirebaseEnvironment.demoProjectId);
      expect(db.app.options.projectId, FirebaseEnvironment.demoProjectId);
      expect(db.settings.sslEnabled, isFalse);
      expect(
        db.settings.host,
        '${environment.host}:${environment.firestorePort}',
      );
      if (auth.currentUser != null) await auth.signOut();
      await waitFor(tester, () => find.text('Entrar').evaluate().isNotEmpty);

      final nonce = DateTime.now().microsecondsSinceEpoch;
      final email = 'android-$nonce@example.test';
      final password = List.generate(
        24,
        (_) => Random.secure().nextInt(36).toRadixString(36),
      ).join();
      await tapText(tester, 'Não tem conta? Cadastre-se');
      await fill(tester, 'Seu Nome', 'Jornada Android');
      await fill(tester, 'E-mail', email);
      await fill(tester, 'Senha', password);
      await tapText(tester, 'Criar Conta');
      await waitFor(
        tester,
        () => find.byType(MainNavigation).evaluate().isNotEmpty,
      );
      final owner = auth.currentUser!.uid;
      final profile = await db
          .collection('users')
          .doc(owner)
          .get(const GetOptions(source: Source.server));
      expect(profile.data()?['name'], 'Jornada Android');
      tester.printToConsole('QA-03: cadastro e perfil confirmados.');

      // Livro manual: criação e status confirmados pelo servidor nativo.
      await tapText(tester, 'Adicionar livro');
      await tapText(tester, 'Cadastrar manualmente');
      await fill(tester, 'Título do Livro', 'Livro Android');
      await fill(tester, 'Autor(es)', 'Autoria fictícia');
      await tapText(tester, 'Cadastrar');
      await waitFor(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      await back(tester);
      await destination(tester, 'Biblioteca');
      await tester.tap(find.byType(Tab).at(2));
      await tester.pump(const Duration(milliseconds: 500));
      await tapText(tester, 'Livro Android');
      await tapText(tester, 'Lendo');
      await waitFor(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      final books = await db
          .collection('books')
          .where('userId', isEqualTo: owner)
          .get(const GetOptions(source: Source.server));
      expect(books.docs.single.data()['status'], 'Lendo');
      tester.printToConsole('QA-03: livro e leitura confirmados.');
      await back(tester);

      // Filme sem pôster/API: altera status e relê pela biblioteca real.
      await tapText(tester, 'Filmes');
      await tapText(tester, 'Adicionar filme');
      await fill(tester, 'Título do filme', 'Filme Android');
      await tapText(tester, 'Salvar filme');
      await tapText(tester, 'Filme Android');
      await tapText(tester, 'Marcar como assistido');
      await waitFor(tester, () => find.text('Assistido').evaluate().isNotEmpty);
      final movies = MovieLibraryService();
      final moviePage = await movies.page(owner);
      expect(moviePage.items.single.watched, isTrue);
      tester.printToConsole('QA-03: filme assistido confirmado.');
      await back(tester);

      // Faixa: favoritos independem do registro da escuta.
      await tapText(tester, 'Música');
      await tapText(tester, 'Adicionar seleção');
      await fill(tester, 'Título', 'Faixa Android');
      await fill(
        tester,
        'Artistas (separe com ponto e vírgula)',
        'Artista fictício',
      );
      await tapText(tester, 'Salvar música');
      await tapText(tester, 'Faixa Android');
      await tapText(tester, 'Favoritar');
      await waitFor(
        tester,
        () => find.text('Remover dos favoritos').evaluate().isNotEmpty,
      );
      final music = MusicLibraryService();
      final tracks = await music.page(owner, type: MediaType.track);
      expect(tracks.items.single.entry.favorite, isTrue);
      await tapText(tester, 'Registrar escuta pessoal');
      await tapText(tester, 'Escolher data da escuta');
      await tapText(tester, 'Confirmar');
      await tapText(tester, 'Salvar escuta');
      await waitFor(
        tester,
        () => find.text('Atualizar minhas escutas').evaluate().isNotEmpty,
      );
      await show(tester, find.textContaining('Escuta em '));
      expect(find.textContaining('Escuta em '), findsOneWidget);
      tester.printToConsole('QA-03: favorito e escuta confirmados.');
      await back(tester);

      // Série: episódio disponível, marcação e pausa preservam o visto.
      await tapText(tester, 'Séries');
      await tapText(tester, 'Adicionar série');
      await fill(tester, 'Título da série', 'Série Android');
      await tapText(tester, 'Salvar série');
      await tapText(tester, 'Série Android');
      await tapText(tester, 'Adicionar episódio');
      await tapText(tester, 'Temporada 1 · Episódio 1');
      await tapText(tester, 'Pausar série');
      final series = SeriesLibraryService();
      await waitFor(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      final seriesPage = await series.page(owner);
      expect(seriesPage.items.single.progress.episodes.single.watched, isTrue);
      expect(seriesPage.items.single.progress.paused, isTrue);
      tester.printToConsole('QA-03: episódio e pausa confirmados.');
      await back(tester);

      // Bíblia mantém escrita pessoal independente das novas bibliotecas.
      await tapText(tester, 'Acompanhar Bíblia');
      await tapText(tester, 'Gênesis');
      await show(tester, find.byKey(const ValueKey('bible-chapter-1')));
      await tester.tap(find.byKey(const ValueKey('bible-chapter-1')));
      await waitFor(
        tester,
        () => find
            .text('Capítulo 1 de Gênesis marcado como lido.')
            .evaluate()
            .isNotEmpty,
      );
      final bible = await db
          .collection('bible_progress')
          .where('userId', isEqualTo: owner)
          .get(const GetOptions(source: Source.server));
      expect(bible.docs.single.data()['readChapters'], contains(1));
      tester.printToConsole('QA-03: capítulo bíblico confirmado.');

      await back(tester);
      await destination(tester, 'Nós');
      tester.printToConsole('QA-03: iniciando convite.');
      await tapText(tester, 'Convites do casal');
      await tapText(tester, 'Li e concordo com esse compartilhamento.');
      await tapText(tester, 'Criar convite');
      await waitFor(
        tester,
        () => find.byType(SelectableText).evaluate().isNotEmpty,
      );
      final code = tester
          .widget<SelectableText>(find.byType(SelectableText).first)
          .data!;
      tester.printToConsole('QA-03: convite criado.');
      await back(tester);
      await signOut(tester);

      // Segunda conta também nasce pela interface, sem seed administrativo.
      final partnerEmail = 'partner-$nonce@example.test';
      await tapText(tester, 'Não tem conta? Cadastre-se');
      await fill(tester, 'Seu Nome', 'Parceiro Android');
      await fill(tester, 'E-mail', partnerEmail);
      await fill(tester, 'Senha', password);
      await tapText(tester, 'Criar Conta');
      await waitFor(
        tester,
        () => find.byType(MainNavigation).evaluate().isNotEmpty,
      );
      final partner = auth.currentUser!.uid;
      final sharedBooks = db
          .collection('shared_books')
          .where('userId', isEqualTo: owner);
      await denied(
        () => sharedBooks.get(const GetOptions(source: Source.server)),
      );
      await destination(tester, 'Nós');
      await tapText(tester, 'Convites do casal');
      await fill(tester, 'Código de convite', code);
      await tapText(tester, 'Consultar convite');
      await waitFor(
        tester,
        () => find.text('Jornada Android').evaluate().isNotEmpty,
      );
      await tapText(tester, 'Li e concordo com esse compartilhamento.');
      await tapText(tester, 'Aceitar convite');
      await waitFor(
        tester,
        () => find
            .text(
              'Você já possui um vínculo ativo. Para encerrá-lo, volte ao Perfil.',
            )
            .evaluate()
            .isNotEmpty,
      );
      final linked = await db
          .collection('users')
          .doc(partner)
          .get(const GetOptions(source: Source.server));
      expect(linked.data()?['partnerUid'], owner);
      final relation = linked.data()!['relationshipId'] as String;
      expect(
        (await sharedBooks.get(
          const GetOptions(source: Source.server),
        )).docs.single.data()['status'],
        'Lendo',
      );
      await denied(
        () => db
            .collection('users')
            .doc(owner)
            .get(const GetOptions(source: Source.server)),
      );
      tester.printToConsole(
        'QA-03: convite consentido e isolamento de perfil confirmados.',
      );
      await back(tester);

      // Álbum pessoal e seleção compartilhada não registram escutas por efeito colateral.
      await destination(tester, 'Biblioteca');
      await tapText(tester, 'Música');
      await tapText(tester, 'Álbuns');
      await tapText(tester, 'Adicionar seleção');
      await fill(tester, 'Título', 'Álbum Android');
      await fill(
        tester,
        'Artistas (separe com ponto e vírgula)',
        'Artista fictício',
      );
      await tapText(tester, 'Salvar música');
      await tapText(tester, 'Álbum Android');
      await tapText(tester, 'Favoritar');
      await waitFor(
        tester,
        () => find.text('Remover dos favoritos').evaluate().isNotEmpty,
      );
      final albums = await music.page(partner, type: MediaType.album);
      expect(albums.items.single.entry.favorite, isTrue);
      await back(tester);
      await destination(tester, 'Nós');
      await tapText(tester, 'Listas e experiências');
      await tapText(tester, 'Nova lista');
      await fill(tester, 'Nome da lista', 'Lista Android');
      await tapText(tester, 'Criar');
      await tapText(tester, 'Lista Android');
      await tapText(tester, 'Adicionar seleção à lista');
      await tapText(tester, 'Livro');
      await tapText(tester, 'Álbum');
      await fill(tester, 'Título', 'Álbum Android');
      await fill(
        tester,
        'Autor ou artista (opcional para livros, filmes e séries)',
        'Artista fictício',
      );
      await tapText(tester, 'Compartilhar seleção');
      await tapText(tester, 'Propor experiência');
      await tapText(tester, 'Livro');
      await tapText(tester, 'Filme');
      await fill(tester, 'Título', 'Sessão Android');
      await tapText(tester, 'Escolher data da experiência');
      await tapText(tester, 'Confirmar');
      await tapText(tester, 'Compartilhar seleção');
      await show(tester, find.text('Sessão Android'));
      await back(tester);
      await signOut(tester);

      await signIn(tester, email, password);
      await destination(tester, 'Nós');
      await tapText(tester, 'Listas e experiências');
      await tapText(tester, 'Lista Android');
      await show(tester, find.text('Álbum Android'));
      await tapText(tester, 'Confirmar versão');
      await show(tester, find.text('Confirmada pelos dois'));
      final experiences = db
          .collection('couple_relationships')
          .doc(relation)
          .collection('experiences');
      final confirmed = (await experiences.get(
        const GetOptions(source: Source.server),
      )).docs.single;
      expect(CoupleRecord(confirmed.id, confirmed.data()).confirmed, isTrue);
      await denied(() => music.page(partner, type: MediaType.album));
      tester.printToConsole(
        'QA-03: lista, álbum e dupla confirmação sem acesso aos favoritos alheios.',
      );
      await back(tester);
      await destination(tester, 'Perfil');
      await tapText(tester, 'Desvincular Casal');
      await tapText(tester, 'Desvincular');
      await waitFor(
        tester,
        () => find.text('Desvincular Casal').evaluate().isEmpty,
      );
      expect((await movies.page(owner)).items.single.watched, isTrue);
      expect(
        (await series.page(
          owner,
        )).items.single.progress.episodes.single.watched,
        isTrue,
      );
      expect(
        (await music.page(
          owner,
          type: MediaType.track,
        )).items.single.entry.favorite,
        isTrue,
      );
      await signOut(tester);
      await signIn(tester, partnerEmail, password);
      await denied(
        () => sharedBooks.get(const GetOptions(source: Source.server)),
      );
      expect(
        (await music.page(
          partner,
          type: MediaType.album,
        )).items.single.entry.favorite,
        isTrue,
      );
      expect(
        (await experiences.get(
          const GetOptions(source: Source.server),
        )).docs.length,
        1,
      );
      tester.printToConsole(
        'QA-03: término revogou consulta e preservou bibliotecas e histórico.',
      );

      movies.close();
      music.close();
      series.close();
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(condition(), isTrue, reason: 'Estado esperado não apareceu em 30 s.');
}

Future<void> show(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 15; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    if (finder.evaluate().isNotEmpty) {
      final nested = find.byType(NestedScrollView).hitTestable();
      if (nested.evaluate().isNotEmpty) {
        await tester.drag(nested.first, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 300));
        continue;
      }
      await tester.ensureVisible(finder.first);
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.hitTestable().evaluate().isNotEmpty) return;
    }
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        )
        .hitTestable();
    if (scroll.evaluate().isEmpty) break;
    await tester.drag(scroll.last, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    finder.hitTestable(),
    findsWidgets,
    reason: 'Controle inacessível na tela.',
  );
}

Future<void> tapText(WidgetTester tester, String label) async {
  tester.printToConsole('QA-03: ação $label');
  await settle(tester);
  final finder = find.text(label);
  await show(tester, finder);
  await tester.tap(finder.hitTestable().first);
  await settle(tester);
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await show(tester, field);
  await tester.enterText(field.first, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> destination(WidgetTester tester, String label) async {
  await settle(tester);
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> back(WidgetTester tester) async {
  tester.printToConsole('QA-03: retornando à tela anterior.');
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  expect(
    navigator.canPop(),
    isTrue,
    reason: 'O teste não deve fechar a rota raiz.',
  );
  navigator.pop();
  await settle(tester);
  tester.printToConsole('QA-03: retorno concluído.');
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> signOut(WidgetTester tester) async {
  await destination(tester, 'Perfil');
  await tapText(tester, 'Sair da Conta');
  await waitFor(tester, () => find.text('Entrar').evaluate().isNotEmpty);
}

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await fill(tester, 'E-mail', email);
  await fill(tester, 'Senha', password);
  await tapText(tester, 'Entrar');
  await waitFor(
    tester,
    () => find.byType(MainNavigation).evaluate().isNotEmpty,
  );
}

Future<void> denied(Future<Object?> Function() read) async {
  await expectLater(
    read(),
    throwsA(
      isA<FirebaseException>().having(
        (error) => error.code,
        'categoria',
        'permission-denied',
      ),
    ),
  );
}
