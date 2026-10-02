import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/widgets/custom_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/test_fonts.dart';

// Compara apenas credenciais fictícias; não inclui senhas no resultado do teste.
class PasswordCheckingAuth extends FakeFirebaseAuth {
  PasswordCheckingAuth(this.expectedPassword);

  final String expectedPassword;
  int loginCalls = 0;
  bool? passwordPreserved;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    loginCalls++;
    passwordPreserved = password == expectedPassword;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    passwordPreserved = password == expectedPassword;
    return super.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is CustomTextField && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);

Future<PasswordCheckingAuth> openForm(
  WidgetTester tester, {
  required bool signUp,
  required String expectedPassword,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final auth = PasswordCheckingAuth(expectedPassword);
  final profiles = FakeUserProfiles();
  final service = AuthService(auth: auth, profiles: profiles);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.changes.close();
    await profiles.close();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>(
      create: (_) => service,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  auth.emit(null);
  await tester.pumpAndSettle();
  if (signUp) {
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Seu Nome'), 'Pessoa de teste');
  }
  await tester.enterText(field('E-mail'), 'teste@example.com');
  return auth;
}

Future<void> submit(WidgetTester tester, bool signUp) async {
  final button = find.text(signUp ? 'Criar Conta' : 'Entrar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void expectSubmission(PasswordCheckingAuth auth, bool signUp) {
  expect(auth.passwordPreserved, isTrue);
  expect(auth.createCalls, signUp ? 1 : 0);
  expect(auth.loginCalls, signUp ? 0 : 1);
}

void expectPasswordField(
  WidgetTester tester,
  String expected, {
  required bool obscureText,
}) {
  final passwordField = field('Senha');
  expect(
    tester.widget<TextFormField>(passwordField).controller?.text == expected,
    isTrue,
  );
  final editable = tester.widget<EditableText>(
    find.descendant(of: passwordField, matching: find.byType(EditableText)),
  );
  expect(editable.obscureText, obscureText);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  final validCases = {
    'espaço inicial no limite de seis caracteres': ' abcde',
    'espaço final no limite de seis caracteres': 'abcde ',
    'espaços nas duas extremidades': ' abcdef ',
    'espaços internos': 'ab cd e',
    'seis espaços sem normalização': '      ',
  };
  final invalidCases = {
    'senha vazia': '',
    'cinco caracteres incluindo espaços': ' abc ',
  };

  for (final signUp in [false, true]) {
    final flow = signUp ? 'cadastro' : 'login';
    for (final entry in validCases.entries) {
      testWidgets('$flow preserva ${entry.key} até o SDK', (tester) async {
        final auth = await openForm(
          tester,
          signUp: signUp,
          expectedPassword: entry.value,
        );
        await tester.enterText(field('Senha'), entry.value);
        await submit(tester, signUp);
        expectSubmission(auth, signUp);
        expect(
          find.text('A senha deve ter pelo menos 6 caracteres'),
          findsNothing,
        );
      });
    }

    for (final entry in invalidCases.entries) {
      testWidgets('$flow rejeita ${entry.key} e permite corrigir', (
        tester,
      ) async {
        const corrected = ' abcde';
        final auth = await openForm(
          tester,
          signUp: signUp,
          expectedPassword: corrected,
        );
        await tester.enterText(field('Senha'), entry.value);
        await submit(tester, signUp);
        expect(
          find.text('A senha deve ter pelo menos 6 caracteres'),
          findsOneWidget,
        );
        expect(auth.createCalls, 0);
        expect(auth.loginCalls, 0);

        await tester.enterText(field('Senha'), corrected);
        await submit(tester, signUp);
        expectSubmission(auth, signUp);
        expect(
          find.text('A senha deve ter pelo menos 6 caracteres'),
          findsNothing,
        );
      });
    }

    testWidgets('$flow mantém o valor ao mostrar e ocultar senha', (
      tester,
    ) async {
      const password = ' abcdef ';
      final auth = await openForm(
        tester,
        signUp: signUp,
        expectedPassword: password,
      );
      await tester.enterText(field('Senha'), password);
      expectPasswordField(tester, password, obscureText: true);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expectPasswordField(tester, password, obscureText: false);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expectPasswordField(tester, password, obscureText: true);
      await submit(tester, signUp);
      expectSubmission(auth, signUp);
    });
  }
}
