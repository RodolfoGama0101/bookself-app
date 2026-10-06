import 'dart:async';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/ui/screens/sharing_screen.dart';
import 'package:bookself_app/ui/widgets/book_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'async_ui_test.dart' show UiAuth;
import 'support/test_fonts.dart';

class _Auth extends UiAuth {
  bool linked = true;
  @override
  UserModel get currentUserModel =>
      super.currentUserModel.copyWith(partnerUid: linked ? 'partner' : null);
  @override
  Stream<Map<String, String>> watchBlocks() =>
      Stream.multi((c) => c.add({}), isBroadcast: true);
}

final _book = BookModel(
  id: 'one',
  userId: 'partner',
  title: 'Leitura compartilhada',
  authors: ['Autor'],
  coverUrl: '',
  status: 'Lendo',
  publishedDate: '',
  addedAt: DateTime(2020),
);

class _Books extends BookService {
  final visible = StreamController<BookModel?>.broadcast();
  final pending = Completer<void>();
  int writes = 0;
  @override
  Stream<List<BookModel>> streamUserBooks(String uid) => Stream.multi(
    (c) => c.add([_book.copyWith(userId: uid)]),
    isBroadcast: true,
  );
  @override
  Stream<BookModel?> watchSharedBook(String id) async* {
    yield _book;
    yield* visible.stream;
  }

  @override
  Future<void> setVisibility(String id, bool value) {
    writes++;
    return pending.future;
  }
}

class _Bible extends BibleService {
  @override
  Stream<Map<String, BibleProgressModel>> streamAllProgress(String uid) =>
      Stream.multi((c) => c.add({}), isBroadcast: true);
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets(
    'ocultação bloqueia repetição, aguarda escrita e mantém opção após falha',
    (tester) async {
      final auth = _Auth();
      final books = _Books();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: SharingScreen(bookService: books, bibleService: _Bible()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final control = find.byType(SwitchListTile).first;
      await tester.tap(control);
      await tester.pump();
      expect(books.writes, 1);
      expect(tester.widget<SwitchListTile>(control).onChanged, isNull);
      expect(find.text('Compartilhamento atualizado.'), findsNothing);
      books.pending.completeError(StateError('falha fictícia'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(control).value, true);
      expect(tester.widget<SwitchListTile>(control).onChanged, isNotNull);
      expect(
        find.textContaining('Não foi possível atualizar.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await books.visible.close();
      auth.dispose();
    },
  );

  for (final reason in ['ocultação', 'término']) {
    testWidgets('detalhes abertos deixam de mostrar conteúdo após $reason', (
      tester,
    ) async {
      final auth = _Auth();
      final books = _Books();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showBookDetailsSheet(
                    context,
                    _book,
                    false,
                    bookService: books,
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Leitura compartilhada'), findsOneWidget);
      if (reason == 'ocultação') {
        books.visible.add(null);
      } else {
        auth.linked = false;
        auth.notifyListeners();
      }
      await tester.pumpAndSettle();
      expect(find.text('Leitura compartilhada'), findsNothing);
      expect(
        find.text('Este livro não está disponível para consulta.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(books.visible.hasListener, false);
      await books.visible.close();
      auth.dispose();
    });
  }

  testWidgets(
    'compartilhamento em tela pequena e texto 2× permite ocultar livro',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      final books = _Books();
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
            home: SharingScreen(bookService: books, bibleService: _Bible()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      for (var step = 0; step < 40; step++) {
        final label = find.text('Leitura compartilhada');
        if (label.evaluate().isNotEmpty &&
            tester.getCenter(label).dy > 100 &&
            tester.getCenter(label).dy < 400) {
          break;
        }
        scroll.jumpTo(scroll.pixels + 100);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Leitura compartilhada'));
      await tester.pump();
      expect(books.writes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      books.pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await books.visible.close();
      auth.dispose();
    },
  );
}
