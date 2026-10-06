import 'dart:async';

import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/data/models/book_search_page.dart';
import 'package:bookself_app/ui/screens/bookshelf_screen.dart';
import 'package:bookself_app/ui/screens/search_screen.dart';
import 'package:bookself_app/ui/widgets/book_details_sheet.dart';
import 'package:bookself_app/ui/widgets/completion_date_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class DateAuth extends ChangeNotifier implements AuthService {
  @override
  UserModel get currentUserModel => UserModel(
    uid: 'owner',
    name: 'Pessoa',
    email: 'owner@example.com',
    createdAt: DateTime(2020),
    partnerUid: 'partner',
  );
  @override
  PartnerProfile get partnerUserModel =>
      PartnerProfile(uid: 'partner', name: 'Companhia');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DateBooks extends BookService {
  @override
  Stream<BookModel?> watchSharedBook(String id) =>
      Stream.value(library.firstWhere((b) => b.id == id));
  final saved = <BookModel>[];
  List<BookModel> library = [];
  Future<void> Function()? write;

  @override
  Future<BookSearchPage> searchGoogleBooksPage(
    String query, {
    int startIndex = 0,
  }) async => BookSearchPage(books: await searchGoogleBooks(query));

  @override
  Future<void> saveBook(BookModel book) async {
    saved.add(book);
    if (write != null) await write!();
  }

  @override
  Stream<List<BookModel>> streamSharedBooks(String uid) => streamUserBooks(uid);
  @override
  Stream<List<BookModel>> streamUserBooks(String userId) =>
      Stream.value(library.where((book) => book.userId == userId).toList());
  @override
  Future<List<BookModel>> searchGoogleBooks(String query) async => [readBook];
}

final readBook = BookModel(
  id: 'read-book',
  userId: 'owner',
  title: 'Leitura antiga',
  authors: ['Autor'],
  coverUrl: '',
  status: 'Lido',
  publishedDate: '1990',
  addedAt: DateTime(2020, 7, 9),
);

Future<void> open(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>(
      create: (_) => DateAuth(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> details(
  WidgetTester tester,
  DateBooks books,
  BookModel book, {
  bool editable = true,
}) => open(
  tester,
  Scaffold(
    body: BookDetailsSheet(
      book: book,
      isEditable: editable,
      bookService: books,
      onDeletionFeedback: (_) {},
    ),
  ),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterDate(WidgetTester tester, String date) async {
  final pickerContext = tester.element(find.byType(DatePickerDialog));
  await tester.tap(
    find.byTooltip(
      MaterialLocalizations.of(pickerContext).inputDateModeButtonLabel,
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextFormField),
    ),
    date,
  );
  await tester.tap(find.text('Confirmar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  testWidgets(
    'seletor pt-BR rejeita futuro/formato inválido e aceita data anterior a 2000',
    (tester) async {
      DateTime? selected;
      await open(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showCompletionDatePicker(context);
              },
              child: const Text('Data'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Data'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DatePickerDialog));
      expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
      await enterDate(tester, '31/12/9999');
      expect(find.text('Informe uma data válida até hoje.'), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(find.byType(TextFormField), 'texto');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Use o formato dd/mm/aaaa.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '31/12/1998');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(1998, 12, 31));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'livro sem data só confirma correção após escrita e preserva status/inclusão',
    (tester) async {
      final pending = Completer<void>();
      final books = DateBooks()..write = () => pending.future;
      await details(tester, books, readBook);
      expect(find.text('Data não informada'), findsOneWidget);
      await tapVisible(tester, find.text('Informar data de conclusão'));
      await enterDate(tester, '31/12/1998');
      expect(books.saved.single.status, 'Lido');
      expect(books.saved.single.finishedDate, DateTime(1998, 12, 31));
      expect(books.saved.single.addedAt, readBook.addedAt);
      expect(find.text('Data de conclusão atualizada!'), findsNothing);
      expect(find.text('Data não informada'), findsOneWidget);
      final action = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Informar data de conclusão'),
      );
      expect(action.onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('31/12/1998'), findsOneWidget);
      expect(find.text('Data de conclusão atualizada!'), findsOneWidget);
    },
  );

  testWidgets('edição rejeitada mantém data e permite repetir', (tester) async {
    final books = DateBooks()
      ..write = () async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      };
    await details(
      tester,
      books,
      readBook.copyWith(finishedDate: DateTime(2020, 1, 2)),
    );
    await tapVisible(tester, find.text('Editar data de conclusão'));
    await enterDate(tester, '31/12/1998');
    await tester.pumpAndSettle();
    expect(find.text('02/01/2020'), findsOneWidget);
    expect(
      find.textContaining('Não foi possível atualizar a data:'),
      findsOneWidget,
    );
    expect(find.text('Data de conclusão atualizada!'), findsNothing);
    books.write = null;
    await tapVisible(tester, find.text('Editar data de conclusão'));
    await enterDate(tester, '31/12/1998');
    await tester.pumpAndSettle();
    expect(books.saved, hasLength(2));
    expect(find.text('31/12/1998'), findsOneWidget);
  });

  testWidgets('data futura legada continua visível e abre correção em hoje', (
    tester,
  ) async {
    final books = DateBooks();
    await details(
      tester,
      books,
      readBook.copyWith(finishedDate: DateTime(9999, 12, 31)),
    );
    expect(find.text('31/12/9999'), findsOneWidget);
    await tapVisible(tester, find.text('Editar data de conclusão'));
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateUtils.dateOnly(DateTime.now()),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(books.saved, isEmpty);
    expect(find.text('31/12/9999'), findsOneWidget);
  });

  testWidgets('cancelar ou confirmar a mesma data não escreve', (tester) async {
    final books = DateBooks();
    await details(
      tester,
      books,
      readBook.copyWith(finishedDate: DateTime(1998, 12, 31, 15, 30)),
    );
    await tapVisible(tester, find.text('Editar data de conclusão'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Editar data de conclusão'));
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(books.saved, isEmpty);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'descarte durante edição ${fails ? 'rejeitada' : 'confirmada'} ignora retorno',
      (tester) async {
        final pending = Completer<void>();
        final books = DateBooks()..write = () => pending.future;
        await details(tester, books, readBook);
        await tapVisible(tester, find.text('Informar data de conclusão'));
        await enterDate(tester, '31/12/1998');
        await tester.pumpWidget(const SizedBox());
        if (fails) {
          pending.completeError(StateError('falha'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('parceiro vê conclusão ausente sem controles de correção', (
    tester,
  ) async {
    await details(tester, DateBooks(), readBook, editable: false);
    expect(find.text('Data não informada'), findsOneWidget);
    expect(find.text('Informar data de conclusão'), findsNothing);
    expect(find.text('Editar data de conclusão'), findsNothing);
  });

  for (final partner in [false, true]) {
    testWidgets(
      'Lidos ${partner ? 'do parceiro' : 'pessoais'} mantém livros sem data e agrupados',
      (tester) async {
        final owner = partner ? 'partner' : 'owner';
        final books = DateBooks()
          ..library = [
            readBook.copyWith(userId: owner),
            readBook.copyWith(
              id: 'dated',
              title: 'Com data',
              userId: owner,
              finishedDate: DateTime(1998, 12, 31),
            ),
          ];
        await open(tester, BookshelfScreen(bookService: books));
        if (partner) {
          await tester.tap(find.text('Estante de Companhia'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Lidos').last);
        await tester.pumpAndSettle();
        expect(find.text('Dezembro / 1998'), findsOneWidget);
        expect(find.text('Com data'), findsOneWidget);
        expect(find.text('Data de conclusão não informada'), findsOneWidget);
        expect(find.text('Leitura antiga'), findsOneWidget);
        await tester.tap(find.text('Leitura antiga'));
        await tester.pumpAndSettle();
        expect(find.text('Data não informada'), findsOneWidget);
        expect(
          find.text('Informar data de conclusão'),
          partner ? findsNothing : findsOneWidget,
        );
        expect(books.saved, isEmpty);
      },
    );
  }

  testWidgets(
    'atalho Lendo aguarda confirmação e bloqueia submissão repetida',
    (tester) async {
      final pending = Completer<void>();
      final books = DateBooks()
        ..library = [readBook.copyWith(status: 'Lendo')]
        ..write = () => pending.future;
      await open(tester, BookshelfScreen(bookService: books));
      await tester.tap(find.byTooltip('Marcar como Lido'));
      await tester.pumpAndSettle();
      await enterDate(tester, '31/12/1998');
      expect(books.saved.single.finishedDate, DateTime(1998, 12, 31));
      expect(books.saved.single.status, 'Lido');
      expect(find.textContaining('marcado como lido!'), findsNothing);
      await tester.tap(find.byTooltip('Marcar como Lido'));
      await tester.pump();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(books.saved, hasLength(1));
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('marcado como lido!'), findsOneWidget);
    },
  );

  for (final manual in [false, true]) {
    testWidgets(
      'inclusão ${manual ? 'manual' : 'do catálogo'} persiste data pt-BR',
      (tester) async {
        final books = DateBooks();
        await open(tester, SearchScreen(bookService: books));
        if (manual) {
          await tester.tap(find.byTooltip('Cadastro Manual'));
          await tester.pumpAndSettle();
          final fields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          );
          await tester.enterText(fields.at(0), 'Livro manual');
          await tester.enterText(fields.at(1), 'Autor');
        } else {
          await tester.enterText(find.byType(TextFormField), 'Livro');
          await tester.tap(find.byIcon(Icons.search_rounded).last);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Adicionar à estante'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lido').last);
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.textContaining(manual ? 'Concluído:' : 'Concluído em:'),
        );
        await enterDate(tester, '31/12/1998');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(manual ? 'Cadastrar' : 'Salvar'));
        expect(books.saved.single.finishedDate, DateTime(1998, 12, 31));
        expect(books.saved.single.status, 'Lido');
      },
    );
  }

  testWidgets('detalhes permitem informar data em 320x480 com texto 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final books = DateBooks();
    await open(
      tester,
      Scaffold(
        body: BookDetailsSheet(
          book: readBook,
          isEditable: true,
          bookService: books,
          onDeletionFeedback: (_) {},
        ),
      ),
      textScale: 2,
    );
    await tapVisible(tester, find.text('Informar data de conclusão'));
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(books.saved.single.finishedDate, DateUtils.dateOnly(DateTime.now()));
    expect(tester.takeException(), isNull);
  });
}
