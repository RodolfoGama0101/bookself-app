import 'dart:async';

import 'package:bookself_app/data/models/book_search_page.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/ui/screens/search_screen.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'async_ui_test.dart' as fixtures;
import 'support/test_fonts.dart';

class PageRequest {
  PageRequest(this.query, this.startIndex);
  final String query;
  final int startIndex;
  final result = Completer<BookSearchPage>();
}

class ControlledPages extends BookService {
  final requests = <PageRequest>[];
  @override
  Future<BookSearchPage> searchGoogleBooksPage(
    String query, {
    int startIndex = 0,
  }) {
    final request = PageRequest(query, startIndex);
    requests.add(request);
    return request.result.future;
  }
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextFormField), query);
  await tester.tap(find.widgetWithIcon(IconButton, Icons.search_rounded));
  await tester.pump();
}

BookSearchPage page(String title, {int? next}) => BookSearchPage(
  books: [
    fixtures.book.copyWith(id: title, googleBooksId: title, title: title),
  ],
  nextStartIndex: next,
);

void main() {
  setUpAll(useBundledTestFonts);

  for (final oldFails in [false, true]) {
    testWidgets('busca antiga não substitui resultado novo: falha=$oldFails', (
      tester,
    ) async {
      final service = ControlledPages();
      await fixtures.openScreen(tester, SearchScreen(bookService: service));
      await search(tester, 'antiga');
      await search(tester, 'nova');
      service.requests.last.result.complete(page('Resultado novo'));
      await tester.pumpAndSettle();
      if (oldFails) {
        service.requests.first.result.completeError(
          const CatalogRequestException(503),
        );
      } else {
        service.requests.first.result.complete(page('Resultado antigo'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Resultado novo'), findsOneWidget);
      expect(find.text('Resultado antigo'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'paginação mantém consulta original, bloqueia repetição e elimina duplicatas',
    (tester) async {
      final service = ControlledPages();
      await fixtures.openScreen(tester, SearchScreen(bookService: service));
      await search(tester, 'consulta');
      service.requests.single.result.complete(page('Primeiro', next: 20));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'texto ainda não buscado',
      );
      await tester.tap(find.text('Carregar mais'));
      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      expect(service.requests.length, 2);
      expect(service.requests.last.query, 'consulta');
      expect(service.requests.last.startIndex, 20);
      service.requests.last.result.complete(
        BookSearchPage(
          books: [...page('Primeiro').books, ...page('Segundo').books],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Primeiro'), findsOneWidget);
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'falha de página preserva livros e permite tentar a mesma posição',
    (tester) async {
      final service = ControlledPages();
      await fixtures.openScreen(tester, SearchScreen(bookService: service));
      await search(tester, 'consulta');
      service.requests.single.result.complete(page('Primeiro', next: 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      service.requests.last.result.completeError(
        const CatalogRequestException(503),
      );
      await tester.pumpAndSettle();
      expect(find.text('Primeiro'), findsOneWidget);
      await tester.tap(find.text('Tentar carregar mais'));
      await tester.pump();
      expect(service.requests.last.startIndex, 20);
      service.requests.last.result.complete(page('Segundo'));
      await tester.pumpAndSettle();
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Tentar carregar mais'), findsNothing);
    },
  );

  testWidgets(
    'página pendente da consulta anterior não entra na consulta nova',
    (tester) async {
      final service = ControlledPages();
      await fixtures.openScreen(tester, SearchScreen(bookService: service));
      await search(tester, 'antiga');
      service.requests.single.result.complete(page('Primeiro', next: 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      await search(tester, 'nova');
      service.requests.last.result.complete(page('Novo'));
      await tester.pumpAndSettle();
      service.requests[1].result.complete(page('Antigo', next: 40));
      await tester.pumpAndSettle();
      expect(find.text('Novo'), findsOneWidget);
      expect(find.text('Antigo'), findsNothing);
      expect(find.text('Carregar mais'), findsNothing);
    },
  );

  testWidgets(
    'falha oferece nova tentativa e cadastro manual em tela pequena',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = ControlledPages();
      await fixtures.openScreen(tester, SearchScreen(bookService: service));
      await search(tester, 'consulta');
      service.requests.single.result.completeError(
        const CatalogConfigurationException(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cadastrar manualmente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SnackBar), const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(service.requests.length, 2);
      service.requests.last.result.complete(const BookSearchPage(books: []));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhum resultado'), findsOneWidget);
      await fixtures.openManual(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
