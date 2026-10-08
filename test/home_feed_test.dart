import 'dart:async';

import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class FeedAuth extends ChangeNotifier implements AuthService {
  FeedAuth({this.withPartner = false});

  final bool withPartner;

  @override
  UserModel get currentUserModel => UserModel(
    uid: 'owner',
    name: 'Pessoa',
    email: 'owner@example.com',
    createdAt: DateTime(2020),
    partnerUid: withPartner ? 'partner' : null,
  );

  @override
  PartnerProfile? get partnerUserModel =>
      withPartner ? PartnerProfile(uid: 'partner', name: 'Companhia') : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FeedBooks extends BookService {
  final updates = StreamController<List<BookModel>>.broadcast();
  final requests = <(String, String?)>[];

  @override
  Stream<List<BookModel>> streamCoupleFeed(String userId, String? partnerId) {
    requests.add((userId, partnerId));
    return updates.stream;
  }
}

BookModel reading(String title, {String owner = 'owner'}) {
  final now = DateTime.now();
  return BookModel(
    id: '$owner-$title',
    userId: owner,
    title: title,
    authors: ['Autor'],
    coverUrl: '',
    status: 'Lido',
    publishedDate: '2020',
    finishedDate: now,
    addedAt: now,
    activityStatus: 'Lido',
    activityAction: 'status_changed',
    activityAt: now,
  );
}

Future<void> openFeed(
  WidgetTester tester,
  FeedBooks books, {
  bool withPartner = false,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>(
      create: (_) => FeedAuth(withPartner: withPartner),
      child: MaterialApp(home: HomeScreen(bookService: books)),
    ),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  books.updates.add([]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'atividade anterior ao vínculo fica fora do feed mas conta no período permitido',
    (tester) async {
      final books = FeedBooks();
      addTearDown(books.updates.close);
      await openFeed(tester, books, withPartner: true);
      books.updates.add([
        reading(
          'Leitura histórica',
          owner: 'partner',
        ).copyWith(feedVisible: false),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Leitura histórica'), findsNothing);
      expect(find.text('1 livro lido'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  testWidgets('feed vazio recebe inclusões e remoções sem atualização manual', (
    tester,
  ) async {
    final books = FeedBooks();
    addTearDown(books.updates.close);
    await openFeed(tester, books);
    expect(books.requests, [('owner', null)]);
    expect(find.text('0 livros lidos'), findsNWidgets(2));

    // Arrastar a lista vazia não anuncia uma atualização inexistente.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    expect(books.requests, hasLength(1));

    books.updates.add([reading('Nova leitura')]);
    await tester.pumpAndSettle();
    expect(find.text('Nova leitura'), findsOneWidget);
    expect(find.text('1 livro lido'), findsNWidgets(2));

    books.updates.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Nova leitura'), findsNothing);
    expect(find.text('0 livros lidos'), findsNWidgets(2));
    expect(books.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(books.updates.hasListener, isFalse);
  });

  testWidgets('mudanças do casal atualizam cartões e contagens pelo stream', (
    tester,
  ) async {
    final books = FeedBooks();
    addTearDown(books.updates.close);
    await openFeed(tester, books, withPartner: true);
    expect(books.requests, [('owner', 'partner')]);
    expect(find.text('0 livros lidos'), findsNWidgets(4));

    final mine = reading('Minha leitura');
    final partner = reading('Leitura compartilhada', owner: 'partner');
    books.updates.add([mine, partner]);
    await tester.pumpAndSettle();
    expect(find.text('Minha leitura'), findsOneWidget);
    expect(find.text('Leitura compartilhada'), findsOneWidget);
    expect(find.text('1 livro lido'), findsNWidgets(4));

    books.updates.add([
      mine.copyWith(
        status: 'Lendo',
        activityStatus: 'Lendo',
        finishedDate: null,
      ),
      partner,
    ]);
    await tester.pumpAndSettle();
    expect(find.text('0 livros lidos'), findsNWidgets(2));
    expect(find.text('1 livro lido'), findsNWidgets(2));
    expect(
      find.textContaining('Você começou a ler', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Companhia concluiu a leitura de',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(books.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(books.updates.hasListener, isFalse);
  });
}
