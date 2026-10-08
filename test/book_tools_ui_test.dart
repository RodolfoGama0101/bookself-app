import 'dart:async';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/ui/widgets/book_details_sheet.dart';
import 'package:bookself_app/ui/screens/bookshelf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'async_ui_test.dart' as fixtures;
import 'support/test_fonts.dart';

class _Books extends fixtures.UiBooks {
  final completion = Completer<BookModel>();
  int edits = 0;
  @override
  Future<BookModel> updateManualMetadata(
    BookModel expected, {
    required String title,
    required List<String> authors,
    required String coverUrl,
  }) {
    edits++;
    return completion.future;
  }

  @override
  Stream<List<BookModel>> streamUserBooks(String uid) =>
      Stream.value([fixtures.book.copyWith(publishedDate: 'Manual')]);
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets(
    'edição manual valida capa, espera confirmação e preserva status/datas',
    (tester) async {
      final service = _Books();
      await fixtures.openScreen(
        tester,
        Scaffold(
          body: BookDetailsSheet(
            book: fixtures.book.copyWith(publishedDate: 'Manual'),
            isEditable: true,
            bookService: service,
            onDeletionFeedback: (_) {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Editar livro manual'));
      await tester.tap(find.text('Editar livro manual'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Título corrigido');
      await tester.enterText(fields.at(2), 'http://example.test/capa.jpg');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Use um endereço HTTPS válido.'), findsOneWidget);
      expect(service.edits, 0);
      await tester.enterText(fields.at(2), '');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(find.text('Salvando…'), findsOneWidget);
      expect(find.text('Livro atualizado.'), findsNothing);
      service.completion.complete(
        fixtures.book.copyWith(
          title: 'Título corrigido',
          publishedDate: 'Manual',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Título corrigido'), findsOneWidget);
      expect(find.text('Livro atualizado.'), findsOneWidget);
      expect(find.text('Quero Ler'), findsWidgets);
    },
  );

  testWidgets(
    'filtros pessoais combinam texto/status e não oferecem edição do parceiro',
    (tester) async {
      final service = _Books();
      await fixtures.openScreen(
        tester,
        BookshelfScreen(scope: BookshelfScope.personal, bookService: service),
      );
      await tester.tap(find.text('Quero ler'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Buscar e filtrar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'inexistente');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Livro de teste'), findsNothing);
      expect(
        find.text('Nenhum livro corresponde aos filtros nesta aba.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Livro de teste'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: BookDetailsSheet(
            book: fixtures.book.copyWith(publishedDate: 'Manual'),
            isEditable: false,
            bookService: service,
            onDeletionFeedback: (_) {},
          ),
        ),
      );
      expect(find.text('Editar livro manual'), findsNothing);
      expect(find.text('Histórico de status'), findsNothing);
    },
  );
}
