import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class CheckingAuth extends ChangeNotifier implements AuthService {
  CheckingAuth(this.expectedPassword);

  final String expectedPassword;
  int loginCalls = 0;
  int signupCalls = 0;
  bool? passwordPreserved;

  @override
  bool get isLoading => false;

  @override
  Future<String?> signInWithEmail(String email, String password) async {
    loginCalls++;
    passwordPreserved = password == expectedPassword;
    return null;
  }

  @override
  Future<String?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    signupCalls++;
    passwordPreserved = password == expectedPassword;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is CustomTextField && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);

Future<CheckingAuth> openForm(
  WidgetTester tester, {
  required bool signUp,
  required String expectedPassword,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = CheckingAuth(expectedPassword);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  if (signUp) {
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Seu Nome'), 'Pessoa fictícia');
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

void main() {
  for (final signUp in [false, true]) {
    final flow = signUp ? 'cadastro' : 'login';
    for (final entry in <String, String>{
      'espaço inicial no limite': ' abcde',
      'espaço final no limite': 'abcde ',
      'espaços internos e nas extremidades': ' ab cd ',
      'seis espaços': '      ',
    }.entries) {
      testWidgets('$flow preserva ${entry.key}', (tester) async {
        final auth = await openForm(
          tester,
          signUp: signUp,
          expectedPassword: entry.value,
        );
        await tester.enterText(field('Senha'), entry.value);
        await submit(tester, signUp);
        expect(auth.passwordPreserved, isTrue);
        expect(auth.loginCalls, signUp ? 0 : 1);
        expect(auth.signupCalls, signUp ? 1 : 0);
      });
    }

    testWidgets('$flow rejeita senha curta e aceita correção', (tester) async {
      const corrected = ' abcde';
      final auth = await openForm(
        tester,
        signUp: signUp,
        expectedPassword: corrected,
      );
      await tester.enterText(field('Senha'), ' abc ');
      await submit(tester, signUp);
      expect(
        find.text('A senha deve ter pelo menos 6 caracteres'),
        findsOneWidget,
      );
      expect(auth.loginCalls + auth.signupCalls, 0);
      await tester.enterText(field('Senha'), corrected);
      await submit(tester, signUp);
      expect(auth.passwordPreserved, isTrue);
    });
  }
}
