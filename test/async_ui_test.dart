import 'dart:async';

import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/data/models/book_search_page.dart';
import 'package:bookself_app/services/theme_service.dart';
import 'package:bookself_app/services/user_profile_service.dart';
import 'package:bookself_app/ui/screens/bookshelf_screen.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/screens/profile_screen.dart';
import 'package:bookself_app/ui/screens/search_screen.dart';
import 'package:bookself_app/ui/widgets/book_details_sheet.dart';
import 'package:bookself_app/ui/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class UiAuth extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  UserModel get currentUserModel => UserModel(
    uid: 'owner',
    name: 'Pessoa',
    email: 'teste@example.com',
    createdAt: DateTime(2020),
  );
  @override
  PartnerProfile? get partnerUserModel => null;
  @override
  bool get isLoading => false;
  final reset = Completer<String?>();
  @override
  Future<String?> sendPasswordReset(String email) => reset.future;
}

class UiBooks extends BookService {
  @override
  Future<({BookModel book, bool created})> addCatalogBook(
    BookModel book,
  ) async {
    await saveBook(book);
    return (book: book, created: true);
  }

  Future<List<BookModel>> Function()? search;
  Future<void> Function()? save;
  Future<void> Function()? delete;
  int saves = 0;
  int searches = 0;
  int deletes = 0;
  final books = StreamController<List<BookModel>>.broadcast();

  @override
  Future<BookSearchPage> searchGoogleBooksPage(
    String query, {
    int startIndex = 0,
  }) async => BookSearchPage(books: await searchGoogleBooks(query));

  @override
  Future<List<BookModel>> searchGoogleBooks(String query) async {
    searches++;
    return search == null ? [] : await search!();
  }

  @override
  Future<void> saveBook(BookModel book) async {
    saves++;
    if (save != null) await save!();
  }

  @override
  Future<void> deleteBook(String id) async {
    deletes++;
    if (delete != null) await delete!();
  }

  @override
  Stream<List<BookModel>> streamSharedBooks(String uid) => streamUserBooks(uid);
  @override
  Stream<List<BookModel>> streamUserBooks(String uid) async* {
    yield [];
    yield* books.stream;
  }
}

class UiProfiles extends UserProfileService {
  final write = Completer<void>();
  int photos = 0;
  int names = 0;
  @override
  Future<void> updatePhoto(String uid, String? photoUrl) {
    photos++;
    return write.future;
  }

  @override
  Future<void> updateName(String uid, String name) {
    names++;
    return write.future;
  }
}

class UiPicker extends ImagePicker {
  final selection = Completer<XFile?>();
  bool? requestedFullMetadata;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    requestedFullMetadata = requestFullMetadata;
    return selection.future;
  }
}

class PendingImage extends Fake implements XFile {
  final bytes = Completer<Uint8List>();
  @override
  Future<Uint8List> readAsBytes() => bytes.future;
}

final book = BookModel(
  id: 'personal-book',
  userId: 'owner',
  title: 'Livro de teste',
  authors: ['Autor'],
  coverUrl: '',
  publishedDate: '2020',
  status: 'Quero Ler',
  addedAt: DateTime(2020),
);

void finish<T>(Completer<T> pending, T value, bool fails) {
  if (fails) {
    pending.completeError(StateError('falha simulada'));
  } else {
    pending.complete(value);
  }
}

Future<GlobalKey<NavigatorState>> openScreen(
  WidgetTester tester,
  Widget screen, {
  UiAuth? auth,
}) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => auth ?? UiAuth()),
        ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
      ],
      child: MaterialApp(
        navigatorKey: key,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return key;
}

Future<void> openManual(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cadastro Manual'));
  await tester.pumpAndSettle();
}

Future<void> fillManual(WidgetTester tester) async {
  final fields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.at(0), 'Livro manual');
  await tester.enterText(fields.at(1), 'Autor manual');
}

Future<void> selectPhoto(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.camera_alt_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Escolher da Galeria'));
  // Há um indicador enquanto o seletor externo está pendente.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  for (final fails in [false, true]) {
    final result = fails ? 'falha' : 'sucesso';
    testWidgets('busca descartada durante requisição: $result', (tester) async {
      final pending = Completer<List<BookModel>>();
      final service = UiBooks()..search = () => pending.future;
      final nav = await openScreen(tester, SearchScreen(bookService: service));
      await tester.enterText(find.byType(TextFormField), 'livro');
      await tester.tap(find.byIcon(Icons.search_rounded).last);
      await tester.pump();
      expect(service.searches, 1);
      nav.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);
      finish(pending, [book], fails);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await service.books.close();
    });

    testWidgets('manual cancelado durante escrita: $result', (tester) async {
      final pending = Completer<void>();
      final service = UiBooks()..save = () => pending.future;
      final nav = await openScreen(tester, SearchScreen(bookService: service));
      await openManual(tester);
      await fillManual(tester);
      await tester.tap(find.text('Cadastrar'));
      await tester.pump();
      expect(service.saves, 1);
      await tester.tap(find.text('Cancelar'));
      // Termina a escrita durante a animação: não pode fechar a busca por engano.
      await tester.pump();
      finish<void>(pending, null, fails);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining(
          fails ? 'Não foi possível cadastrar' : 'cadastrado com sucesso',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await service.books.close();
    });

    testWidgets('perfil fechado durante seletor de foto: $result', (
      tester,
    ) async {
      final profiles = UiProfiles();
      final picker = UiPicker();
      final nav = await openScreen(
        tester,
        ProfileScreen(profiles: profiles, imagePicker: picker),
      );
      await selectPhoto(tester);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      finish<XFile?>(
        picker.selection,
        XFile.fromData(Uint8List.fromList([1])),
        fails,
      );
      await tester.pumpAndSettle();
      expect(profiles.photos, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('perfil fechado durante leitura da imagem: $result', (
      tester,
    ) async {
      final profiles = UiProfiles();
      final picker = UiPicker();
      final image = PendingImage();
      picker.selection.complete(image);
      final nav = await openScreen(
        tester,
        ProfileScreen(profiles: profiles, imagePicker: picker),
      );
      await selectPhoto(tester);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      finish(image.bytes, Uint8List.fromList([1]), fails);
      await tester.pumpAndSettle();
      expect(profiles.photos, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('perfil fechado durante escrita de foto: $result', (
      tester,
    ) async {
      final profiles = UiProfiles();
      final picker = UiPicker()
        ..selection.complete(XFile.fromData(Uint8List.fromList([1])));
      final nav = await openScreen(
        tester,
        ProfileScreen(profiles: profiles, imagePicker: picker),
      );
      await selectPhoto(tester);
      expect(profiles.photos, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      finish<void>(profiles.write, null, fails);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('perfil fechado durante escrita do nome: $result', (
      tester,
    ) async {
      final profiles = UiProfiles();
      final nav = await openScreen(tester, ProfileScreen(profiles: profiles));
      await tester.tap(find.byTooltip('Editar Nome'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Novo nome');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(profiles.names, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      finish<void>(profiles.write, null, fails);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalhes fechados durante mudança de status: $result', (
      tester,
    ) async {
      final pending = Completer<void>();
      final service = UiBooks()..save = () => pending.future;
      final nav = await openScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookDetailsSheet(
                context,
                book,
                true,
                bookService: service,
              ),
              child: const Text('Detalhes'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Lendo'));
      await tester.pump();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      finish<void>(pending, null, fails);
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailsSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await service.books.close();
    });

    testWidgets(
      'exclusão entrega $result à estante após remover cartão e fechar detalhes',
      (tester) async {
        final pending = Completer<void>();
        final service = UiBooks()..delete = () => pending.future;
        await openScreen(tester, BookshelfScreen(bookService: service));
        service.books.add([book]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quero ler'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(book.title));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Excluir da Estante'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excluir da Estante'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        expect(service.deletes, 1);
        expect(find.byType(BookDetailsSheet), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        // O stream pode retirar o cartão antes de a Future da escrita responder.
        service.books.add([]);
        await tester.pumpAndSettle();
        finish<void>(pending, null, fails);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            fails ? 'Erro ao remover' : 'removido com sucesso',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.books.close();
      },
    );

    testWidgets('nome aguarda escrita e informa $result na tela ativa', (
      tester,
    ) async {
      final profiles = UiProfiles();
      await openScreen(tester, ProfileScreen(profiles: profiles));
      await tester.tap(find.byTooltip('Editar Nome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(profiles.names, 1);
      expect(find.byType(SnackBar), findsNothing);
      finish<void>(profiles.write, null, fails);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          fails
              ? 'Não foi possível atualizar o nome'
              : 'Nome atualizado com sucesso',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cadastro pendente ignora tela removida: $result', (
      tester,
    ) async {
      final pending = Completer<void>();
      final service = UiBooks()..save = () => pending.future;
      final nav = await openScreen(tester, SearchScreen(bookService: service));
      await openManual(tester);
      await fillManual(tester);
      await tester.tap(find.text('Cadastrar'));
      await tester.pump();
      expect(service.saves, 1);
      nav.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      finish<void>(pending, null, fails);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await service.books.close();
    });

    testWidgets(
      'atalho de exclusão mantém feedback após retirar cartão: $result',
      (tester) async {
        final pending = Completer<void>();
        final service = UiBooks()..delete = () => pending.future;
        await openScreen(tester, BookshelfScreen(bookService: service));
        service.books.add([book]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quero ler'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        expect(service.deletes, 1);
        service.books.add([]);
        await tester.pumpAndSettle();
        finish<void>(pending, null, fails);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            fails ? 'Erro ao remover' : 'removido com sucesso',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.books.close();
      },
    );
  }

  testWidgets('detalhes removidos enquanto seletor de data está aberto', (
    tester,
  ) async {
    final service = UiBooks();
    final nav = await openScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showBookDetailsSheet(context, book, true, bookService: service),
            child: const Text('Detalhes'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Detalhes'));
    await tester.pumpAndSettle();
    final sheetRoute = ModalRoute.of(
      tester.element(find.byType(BookDetailsSheet)),
    )!;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Lido'));
    await tester.pumpAndSettle();
    nav.currentState!.removeRoute(sheetRoute);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(service.saves, 0);
    expect(tester.takeException(), isNull);
    await service.books.close();
  });

  testWidgets('manual removido enquanto seletor de data está aberto', (
    tester,
  ) async {
    final service = UiBooks();
    final nav = await openScreen(tester, SearchScreen(bookService: service));
    await openManual(tester);
    final dialogRoute = ModalRoute.of(
      tester.element(find.byType(AlertDialog)),
    )!;
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lido').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Concluído:'));
    await tester.tap(find.textContaining('Concluído:'));
    await tester.pumpAndSettle();
    nav.currentState!.removeRoute(dialogRoute);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(service.saves, 0);
    expect(tester.takeException(), isNull);
    await service.books.close();
  });

  for (final close in ['cancelar', 'barreira', 'voltar']) {
    testWidgets('manual descarta controladores ao $close', (tester) async {
      final service = UiBooks();
      final nav = await openScreen(tester, SearchScreen(bookService: service));
      await openManual(tester);
      final fields = tester.widgetList<CustomTextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CustomTextField),
        ),
      );
      final controllers = fields.map((field) => field.controller).toList();
      if (close == 'cancelar') {
        await tester.tap(find.text('Cancelar'));
      } else if (close == 'barreira') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      for (final controller in controllers) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
      expect(service.saves, 0);
      expect(tester.takeException(), isNull);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await service.books.close();
    });
  }

  testWidgets('recuperação de senha mostra resultado na tela de login', (
    tester,
  ) async {
    final auth = UiAuth();
    await openScreen(tester, const LoginScreen(), auth: auth);
    await tester.tap(find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, 'teste@example.com');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    auth.reset.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.text('E-mail de recuperação enviado com sucesso!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
