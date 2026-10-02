import 'dart:async';

import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/session_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';

void main() {
  late FakeFirebaseAuth auth;
  late FakeUserProfiles profiles;
  late AuthService service;

  setUp(() {
    auth = FakeFirebaseAuth();
    profiles = FakeUserProfiles();
    service = AuthService(auth: auth, profiles: profiles);
  });

  tearDown(() async {
    service.dispose();
    await auth.changes.close();
    await profiles.close();
  });

  Widget app() {
    return ChangeNotifierProvider.value(
      value: service,
      child: MaterialApp(
        home: SessionGate(
          signedOutBuilder: (_) => const Scaffold(body: Text('Login')),
          readyBuilder: (_) => const Scaffold(body: Text('Biblioteca')),
        ),
      ),
    );
  }

  testWidgets('sessão restaurada só abre biblioteca após carregar perfil', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.text('Restaurando sua sessão…'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    auth.emit(FakeUser('user'));
    await tester.pump();
    expect(find.text('Carregando seu perfil…'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    profiles.controller('user').add(profile('user'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca'), findsOneWidget);
  });

  testWidgets(
    'perfil ausente oferece conclusão e aguarda confirmação da escrita',
    (tester) async {
      await tester.pumpWidget(app());
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(null);
      await tester.pumpAndSettle();
      expect(find.text('Vamos concluir seu perfil'), findsOneWidget);
      expect(find.text('Login'), findsNothing);

      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu nome.'), findsOneWidget);
      expect(profiles.createCalls, 0);

      final write = Completer<UserModel>();
      profiles.onCreate = (_) => write.future;
      await tester.enterText(find.byType(TextFormField), 'Pessoa');
      await tester.tap(find.text('Salvar perfil'));
      await tester.pump();
      expect(find.text('Biblioteca'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      write.complete(profile('user'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca'), findsOneWidget);
      expect(auth.createCalls, 0);
    },
  );

  testWidgets(
    'erro de perfil oferece nova leitura ou saída, sem cair no login',
    (tester) async {
      await tester.pumpWidget(app());
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').addError(StateError('Detalhe técnico'));
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      expect(find.textContaining('Detalhe técnico'), findsNothing);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(find.text('Carregando seu perfil…'), findsOneWidget);
      profiles.controller('user').add(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(auth.signOutCalls, 1);
      expect(profiles.createCalls, 0);
    },
  );

  testWidgets(
    'fechar recuperação durante escrita rejeitada não usa contexto descartado',
    (tester) async {
      await tester.pumpWidget(app());
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(null);
      await tester.pumpAndSettle();
      final write = Completer<UserModel>();
      profiles.onCreate = (_) => write.future;
      await tester.enterText(find.byType(TextFormField), 'Pessoa');
      await tester.tap(find.text('Salvar perfil'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      write.completeError(StateError('Rejeitada'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.sessionState, AuthSessionState.profileError);
    },
  );

  testWidgets(
    'recuperação funciona em tela pequena com texto ampliado e teclado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app());
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(null);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Pessoa');
      await tester.ensureVisible(find.text('Salvar perfil'));
      expect(find.text('Salvar perfil').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
