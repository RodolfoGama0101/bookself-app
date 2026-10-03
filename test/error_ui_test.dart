import 'dart:async';

import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/theme_service.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/screens/bible_screen.dart';
import 'package:bookself_app/ui/screens/profile_screen.dart';
import 'package:bookself_app/ui/screens/search_screen.dart';
import 'package:bookself_app/ui/screens/session_gate.dart';
import 'package:bookself_app/ui/widgets/custom_text_field.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/test_fonts.dart';

class UiFailureAuth extends FakeFirebaseAuth {
  Object failure = StateError('PRIVATE_FIXTURE');
  Completer<void>? pendingSignOut;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async => throw failure;

  @override
  Future<void> signOut() async {
    if (pendingSignOut != null) return pendingSignOut!.future;
    throw failure;
  }
}

class SummaryFailureBible extends BibleService {
  SummaryFailureBible(this.failedUid);
  final String failedUid;

  @override
  Stream<Map<String, BibleProgressModel>> streamAllProgress(String uid) =>
      uid == failedUid
      ? Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'index PRIVATE_FIXTURE',
          ),
        )
      : Stream.value({});
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is CustomTextField && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);
  late UiFailureAuth auth;
  late FakeUserProfiles profiles;
  late AuthService service;

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    bool signedIn = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth = UiFailureAuth();
    profiles = FakeUserProfiles();
    service = AuthService(auth: auth, profiles: profiles);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await auth.changes.close();
      await profiles.close();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => service),
          ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    auth.emit(signedIn ? FakeUser('owner') : null);
    await tester.pump();
    if (signedIn) {
      profiles
          .controller('owner')
          .add(profile('owner').copyWith(photoUrl: null));
    }
    await tester.pumpAndSettle();
  }

  void expectSafeMessage(String expected) {
    expect(find.textContaining(expected), findsOneWidget);
    expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
  }

  testWidgets(
    'login mostra credencial inválida em português e mantém formulário',
    (tester) async {
      await open(tester, const LoginScreen());
      auth.onSignIn = () async => throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'PRIVATE_FIXTURE',
      );
      await tester.enterText(field('E-mail'), 'teste@example.com');
      await tester.enterText(field('Senha'), 'fixture');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expectSafeMessage('E-mail ou senha incorretos');
      expect(field('Senha'), findsOneWidget);
    },
  );

  testWidgets('cadastro mostra fallback seguro sem detalhes do SDK', (
    tester,
  ) async {
    await open(tester, const LoginScreen());
    auth.onSignUp = () async => throw FirebaseAuthException(
      code: 'PRIVATE_FIXTURE',
      message: 'PRIVATE_FIXTURE',
    );
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Seu Nome'), 'Pessoa');
    await tester.enterText(field('E-mail'), 'teste@example.com');
    await tester.enterText(field('Senha'), 'fixture');
    await tester.tap(find.text('Criar Conta'));
    await tester.pumpAndSettle();
    expectSafeMessage('Não foi possível autenticar sua conta');
    expect(profiles.createCalls, 0);
  });

  testWidgets('recuperação de senha mostra falha de rede após fechar diálogo', (
    tester,
  ) async {
    await open(tester, const LoginScreen());
    auth.failure = http.ClientException('PRIVATE_FIXTURE');
    await tester.enterText(field('E-mail'), 'teste@example.com');
    await tester.tap(find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expectSafeMessage(ErrorHandler.networkMessage);
  });

  for (final status in [429, 503]) {
    testWidgets(
      'busca HTTP $status usa mensagem correspondente e mantém cadastro manual',
      (tester) async {
        final client = MockClient(
          (_) async => http.Response('PRIVATE_FIXTURE', status),
        );
        addTearDown(client.close);
        await open(
          tester,
          SearchScreen(bookService: BookService(httpClient: client)),
          signedIn: true,
        );
        await tester.enterText(field('Pesquisar livro'), 'Consulta de teste');
        await tester.tap(find.widgetWithIcon(IconButton, Icons.search_rounded));
        await tester.pumpAndSettle();
        expectSafeMessage(
          status == 429 ? 'Aguarde um pouco' : 'temporariamente indisponível',
        );
        expect(find.textContaining('API'), findsNothing);
        await tester.tap(find.text('Manual'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      },
    );
  }

  for (final profileScreen in [true, false]) {
    testWidgets(
      'falha ao sair ${profileScreen ? 'do perfil' : 'da recuperação'} tem feedback seguro',
      (tester) async {
        final screen = profileScreen
            ? const ProfileScreen()
            : SessionGate(
                signedOutBuilder: (_) => const SizedBox(),
                readyBuilder: (_) => const SizedBox(),
              );
        await open(tester, screen, signedIn: true);
        auth.failure = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'PRIVATE_FIXTURE',
        );
        if (!profileScreen) {
          profiles.controller('owner').add(null);
          await tester.pumpAndSettle();
        }
        final button = find.text(profileScreen ? 'Sair da Conta' : 'Sair');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expectSafeMessage(
          'Não foi possível sair. ${ErrorHandler.networkMessage}',
        );
        expect(service.hasAuthenticatedSession, isTrue);
      },
    );
  }

  for (final partner in [false, true]) {
    testWidgets(
      'resumo bíblico ${partner ? 'do parceiro' : 'pessoal'} oculta erro bruto e índice',
      (tester) async {
        await open(
          tester,
          BibleScreen(
            bibleService: SummaryFailureBible(partner ? 'partner' : 'owner'),
          ),
          signedIn: true,
        );
        if (partner) {
          profiles
              .controller('owner')
              .add(
                profile(
                  'owner',
                  partnerUid: 'partner',
                ).copyWith(photoUrl: null),
              );
          await tester.pump();
          profiles
              .controller('partner')
              .add(profile('partner').copyWith(photoUrl: null));
          await tester.pumpAndSettle();
        }
        expectSafeMessage('Não foi possível realizar esta ação agora');
        expect(find.textContaining('index'), findsNothing);
        expect(find.textContaining('failed-precondition'), findsNothing);
      },
    );
  }

  testWidgets('retorno de falha ao sair não usa o perfil descartado', (
    tester,
  ) async {
    await open(tester, const ProfileScreen(), signedIn: true);
    final pending = Completer<void>();
    auth.pendingSignOut = pending;
    await tester.ensureVisible(find.text('Sair da Conta'));
    await tester.tap(find.text('Sair da Conta'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('PRIVATE_FIXTURE'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });
}
