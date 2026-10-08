import 'dart:async';

import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/theme_service.dart';
import 'package:bookself_app/ui/screens/bible_screen.dart';
import 'package:bookself_app/ui/screens/main_navigation.dart';
import 'package:bookself_app/ui/screens/bookshelf_screen.dart';
import 'package:bookself_app/ui/widgets/content_state.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class _Auth extends ChangeNotifier implements AuthService {
  String owner = 'owner';
  String? partner;
  @override
  bool get isLoading => false;
  @override
  UserModel get currentUserModel => UserModel(
    uid: owner,
    name: 'Pessoa fictícia',
    email: '$owner@example.test',
    createdAt: DateTime(2020),
    partnerUid: partner,
    relationshipId: partner == null ? null : 'relation',
  );
  @override
  PartnerProfile? get partnerUserModel => null;
  void change({String? ownerId, String? partnerId}) {
    owner = ownerId ?? owner;
    partner = partnerId;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BookModel _book(String owner, String title) => BookModel(
  id: '$owner-book',
  userId: owner,
  title: title,
  authors: [],
  coverUrl: '',
  status: 'Quero Ler',
  publishedDate: '',
  addedAt: DateTime(2020),
);

class _Books extends BookService {
  final updates = StreamController<List<BookModel>>.broadcast();
  final shared = StreamController<List<BookModel>>.broadcast();
  int reads = 0;
  bool failOnce = false;
  @override
  Stream<List<BookModel>> streamUserBooks(String uid) {
    reads++;
    if (failOnce) {
      failOnce = false;
      return Stream.error(StateError('PRIVATE_FIXTURE'));
    }
    return (() async* {
      yield [_book(uid, 'Livro de $uid')];
      yield* updates.stream;
    })();
  }

  @override
  Stream<List<BookModel>> streamSharedBooks(String uid) => (() async* {
    yield [_book(uid, 'Livro compartilhado')];
    yield* shared.stream;
  })();
  @override
  Stream<List<BookModel>> streamCoupleFeed(String uid, String? partnerId) =>
      Stream.value([]);
  Future<void> close() async {
    await updates.close();
    await shared.close();
  }
}

class _Bible extends BibleService {
  final shared = StreamController<Map<String, BibleProgressModel>>.broadcast();
  final own = StreamController<Map<String, BibleProgressModel>>.broadcast();
  bool delayOwn = false;
  int reads = 0;
  @override
  Stream<Map<String, BibleProgressModel>> streamAllProgress(String uid) {
    reads++;
    return (() async* {
      if (!delayOwn) {
        yield {
          'Gênesis': BibleProgressModel(
            id: '${uid}_gênesis',
            userId: uid,
            bookName: 'Gênesis',
            readChapters: [1],
            updatedAt: DateTime(2020),
          ),
        };
      }
      yield* own.stream;
    })();
  }

  @override
  Stream<Map<String, BibleProgressModel>> streamSharedProgress(String uid) =>
      (() async* {
        yield <String, BibleProgressModel>{};
        yield* shared.stream;
      })();
  @override
  Stream<BibleProgressModel?> streamBookProgress(String uid, String name) =>
      Stream.value(
        BibleProgressModel(
          id: '$uid-genesis',
          userId: uid,
          bookName: name,
          readChapters: [1],
          updatedAt: DateTime(2020),
        ),
      );
  @override
  Stream<BibleProgressModel?> streamSharedBookProgress(
    String uid,
    String name,
  ) => Stream.value(null);
  Future<void> close() async {
    await shared.close();
    await own.close();
  }
}

void main() {
  setUpAll(useBundledTestFonts);
  late _Auth auth;
  late _Books books;
  late _Bible bible;
  setUp(() {
    auth = _Auth();
    books = _Books();
    bible = _Bible();
  });
  tearDown(() async {
    await books.close();
    await bible.close();
    auth.dispose();
  });
  Future<void> open(
    WidgetTester tester, {
    Widget? page,
    double width = 800,
    double height = 900,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page ?? MainNavigation(bookService: books, bibleService: bible),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Biblioteca/Nós preservam filtro e Bíblia/testamento ao trocar de destino e largura',
    (tester) async {
      await open(tester);
      await select(tester, 'Biblioteca');
      await tester.tap(find.text('Quero ler').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Livro de owner').hitTestable(), findsOneWidget);
      final reads = books.reads;
      await select(tester, 'Nós');
      expect(find.text('Nenhum vínculo ativo').hitTestable(), findsOneWidget);
      await select(tester, 'Biblioteca');
      expect(find.text('Livro de owner').hitTestable(), findsOneWidget);
      expect(books.reads, reads);
      await tester.tap(find.text('Acompanhar Bíblia').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo Testamento').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Mateus').hitTestable(), findsOneWidget);
      await select(tester, 'Início');
      await select(tester, 'Biblioteca');
      expect(find.text('Mateus').hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Mateus').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'parceiro sem apresentação continua consultável; término retira conteúdo e preserva pessoal',
    (tester) async {
      auth.partner = 'partner';
      await open(tester);
      await select(tester, 'Nós');
      await tester.tap(find.text('Biblioteca do parceiro').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quero ler').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Livro compartilhado').hitTestable(), findsOneWidget);
      expect(find.text('Adicionar livro').hitTestable(), findsNothing);
      auth.change();
      await tester.pumpAndSettle();
      expect(find.text('Livro compartilhado').hitTestable(), findsNothing);
      expect(find.text('Nenhum vínculo ativo').hitTestable(), findsOneWidget);
      await select(tester, 'Biblioteca');
      await tester.tap(find.text('Quero ler').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Livro de owner').hitTestable(), findsOneWidget);
    },
  );
  testWidgets('Bíblia retorna à origem por botão e pelo voltar do sistema', (
    tester,
  ) async {
    auth.partner = 'partner';
    await open(tester);
    await select(tester, 'Nós');
    await tester.tap(find.text('Comparar progresso bíblico').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('2% (1/50)').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Gerir vínculo').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Comparar progresso bíblico').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Gerir vínculo').hitTestable(), findsOneWidget);
    await select(tester, 'Biblioteca');
    await tester.tap(find.text('Acompanhar Bíblia').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gênesis').hitTestable());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('2% (1/50)').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'biblioteca distingue falha de vazio e permite repetir sem perder filtro',
    (tester) async {
      books.failOnce = true;
      await open(
        tester,
        page: BookshelfScreen(
          scope: BookshelfScope.personal,
          bookService: books,
        ),
      );
      expect(
        find.text('Não foi possível carregar a biblioteca'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quero ler'));
      await tester.pumpAndSettle();
      expect(find.text('Livro de owner'), findsOneWidget);
      expect(books.reads, 2);
    },
  );
  testWidgets(
    'falha/offline na comparação mantém a Bíblia pessoal e não inventa zero do parceiro',
    (tester) async {
      auth.partner = 'partner';
      await open(tester, page: BibleScreen(bibleService: bible));
      bible.shared.addError(const SharedDataUnconfirmed());
      await tester.pumpAndSettle();
      expect(find.textContaining('Comparação indisponível'), findsOneWidget);
      expect(find.text('2% (1/50)'), findsOneWidget);
      await tester.tap(find.text('Gênesis'));
      await tester.pumpAndSettle();
      expect(find.text('Gênesis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('progresso pessoal pendente não aparece como zero confirmado', (
    tester,
  ) async {
    bible.delayOwn = true;
    await open(tester, page: BibleScreen(bibleService: bible));
    expect(find.text('Carregando progresso da Bíblia'), findsOneWidget);
    expect(find.text('0% (0/50)'), findsNothing);
    bible.own.add({});
    await tester.pumpAndSettle();
    expect(find.text('0% (0/50)'), findsOneWidget);
  });
  testWidgets('troca de conta limpa destino e filtros da sessão anterior', (
    tester,
  ) async {
    await open(tester);
    await select(tester, 'Biblioteca');
    await tester.tap(find.text('Quero ler').hitTestable());
    await tester.pumpAndSettle();
    auth.change(ownerId: 'new-owner');
    await tester.pumpAndSettle();
    expect(find.text('Início').hitTestable(), findsWidgets);
    await select(tester, 'Biblioteca');
    expect(find.text('Livro de owner').hitTestable(), findsNothing);
    expect(
      find.text('Nenhum livro sendo lido no momento.').hitTestable(),
      findsOneWidget,
    );
  });
  testWidgets('menu compacto mantém os quatro destinos em 320 px e texto 2×', (
    tester,
  ) async {
    await open(tester, width: 320, height: 480, scale: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Navegar entre as telas'));
    await tester.pumpAndSettle();
    for (final label in ['Início', 'Biblioteca', 'Nós', 'Perfil']) {
      expect(find.widgetWithText(PopupMenuItem<int>, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(PopupMenuItem<int>, 'Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acompanhar Bíblia').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Progresso da Bíblia').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'estado de falha tem ação alcançável com texto ampliado em altura pequena',
    (tester) async {
      await open(
        tester,
        width: 320,
        height: 480,
        scale: 2,
        page: Scaffold(
          body: ContentState(
            title: 'Dados indisponíveis',
            message: 'Verifique sua conexão e tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: () {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Tentar novamente'));
      expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
