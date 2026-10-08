import 'dart:async';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/book_page_controller.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/bookshelf_screen.dart';
import 'package:bookself_app/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'async_ui_test.dart' show UiAuth;
import 'book_page_controller_test.dart' show PageRepository, pageBook;
import 'support/test_fonts.dart';

class PagedUiBooks extends BookService {
  final updates = StreamController<LibraryPage<BookModel>>.broadcast();
  final repository = PageRepository()
    ..rows['owner'] = [for (var i = 7; i > 0; i--) pageBook('owner', i)];
  @override
  BookPageController pagedBooks(
    String owner, {
    bool shared = false,
    bool feed = false,
    String? partner,
    DateTime? since,
  }) => BookPageController(
    repository: repository,
    watch: (_, _, _, _) => updates.stream,
    owner: owner,
    ownerShared: shared,
    partner: partner,
    feed: feed,
    since: since,
    pageSize: 2,
  );
  @override
  Future<DateTime?> feedStart(String uid, String? partner) async =>
      DateTime(1970);
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets(
    'carregar mais conserva filtros/aba e informa total independente da página',
    (tester) async {
      final auth = UiAuth(), books = PagedUiBooks();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: BookshelfScreen(
              bookService: books,
              paginated: true,
              scope: BookshelfScope.personal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 carregados de 7 livros'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar e filtrar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Livro 4');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nenhum dos livros carregados'),
        findsOneWidget,
      );
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Carregar mais'),
      );
      expect(button.onPressed, isNotNull);
      await tester.runAsync(() async {
        await (button.onPressed as dynamic)();
      });
      await tester.pumpAndSettle();
      expect(find.text('4 carregados de 7 livros'), findsOneWidget);
      expect(find.text('Livro 4'), findsOneWidget);
      expect(
        find.byTooltip('Buscar e filtrar · filtros ativos'),
        findsOneWidget,
      );
      expect(books.repository.reads.last.$3, 'owner-6');
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets(
    'Início usa agregações completas e carregar mais acrescenta atividades',
    (tester) async {
      final auth = UiAuth(), books = PagedUiBooks();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: HomeScreen(bookService: books, paginated: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('42 livros lidos'), findsNWidgets(2));
      expect(
        books.repository.reads.length,
        2,
      ); // Primeira página e buffer de continuação.
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Carregar mais atividades'),
      );
      expect(button.onPressed, isNotNull);
      await tester.runAsync(() async {
        await (button.onPressed as dynamic)();
      });
      await tester.pumpAndSettle();
      expect(books.repository.reads.last.$3, 'owner-4');
      expect(find.text('42 livros lidos'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      await books.updates.close();
      auth.dispose();
    },
  );
}
