import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/ui/screens/home_screen.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/theme.dart';
import 'package:bookself_app/ui/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class _DesignAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isLoading => false;
  @override
  UserModel get currentUserModel => UserModel(
    uid: 'demo-owner',
    name: 'Pessoa de demonstração',
    email: 'owner@example.test',
    partnerUid: 'demo-partner',
    createdAt: DateTime(2026),
  );
  @override
  PartnerProfile get partnerUserModel => PartnerProfile(
    uid: 'demo-partner',
    name: 'Pessoa parceira com um nome extenso',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _book = BookModel(
  id: 'demo-book',
  userId: 'demo-owner',
  title:
      'Um título longo para verificar a leitura e as ações em uma tela pequena',
  authors: ['Autoria fictícia com nome extenso'],
  coverUrl: '',
  status: 'Lido',
  publishedDate: 'Manual',
  addedAt: DateTime(2026),
  finishedDate: DateTime(2026, 10, 5),
);

class _DesignBooks extends BookService {
  @override
  Stream<List<BookModel>> streamCoupleFeed(String userId, String? partnerId) =>
      Stream.value([_book]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(
    WidgetTester tester,
    Widget child,
    ThemeData theme, {
    double width = 320,
    double scale = 2,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => _DesignAuth(),
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await GoogleFonts.pendingFonts();
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.lightTheme
        : AppTheme.darkTheme;
    testWidgets(
      'cartão $brightness preserva data e duas ações com texto 2× em 320 px',
      (tester) async {
        var taps = 0;
        await open(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: BookCard(
                book: _book,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => taps++,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      onPressed: () => taps++,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          theme,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('05/10/2026'), findsOneWidget);
        for (final label in ['Editar', 'Excluir']) {
          await tester.ensureVisible(find.byTooltip(label));
          await tester.tap(find.byTooltip(label));
        }
        expect(taps, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'resumo $brightness acomoda nomes do casal e atividades com texto 2×',
      (tester) async {
        await open(tester, HomeScreen(bookService: _DesignBooks()), theme);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Pessoa parceira com um nome extenso'),
          200,
        );
        await tester.scrollUntilVisible(find.text(_book.title), 200);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'login $brightness permite alcançar os campos e entrar com texto 2×',
      (tester) async {
        await open(tester, const LoginScreen(), theme);
        await tester.ensureVisible(find.text('Entrar'));
        expect(find.text('Entrar').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('login $brightness limita o formulário em tela de 1440 px', (
      tester,
    ) async {
      await open(tester, const LoginScreen(), theme, width: 1440, scale: 1);
      expect(
        tester.getSize(find.byType(TextFormField).first).width,
        lessThan(500),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
