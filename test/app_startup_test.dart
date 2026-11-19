import 'dart:async';

import 'package:bookself_app/ui/screens/app_startup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget readyApp(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: Text('Aplicativo pronto')));
  }

  testWidgets('timeout do SDK é tratado como falha concluída', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          attempts++;
          if (attempts == 1) throw TimeoutException('falha do SDK');
        },
        readyBuilder: readyApp,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('inicialização está demorando'), findsNothing);
    expect(find.textContaining('Verifique sua conexão'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets(
    'tempo esgotado permite aguardar sem iniciar tentativa concorrente',
    (tester) async {
      final initialization = Completer<void>();
      var attempts = 0;
      await tester.pumpWidget(
        AppStartup(
          timeout: const Duration(seconds: 2),
          initialize: () {
            attempts++;
            return initialization.future;
          },
          readyBuilder: readyApp,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(
        find.textContaining('inicialização está demorando'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(attempts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      initialization.complete();
      await tester.pumpAndSettle();
      expect(find.text('Aplicativo pronto'), findsOneWidget);
      expect(attempts, 1);
    },
  );

  testWidgets('sucesso após timeout é aproveitado sem reiniciar o SDK', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        timeout: const Duration(seconds: 2),
        initialize: () {
          attempts++;
          return initialization.future;
        },
        readyBuilder: readyApp,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    initialization.complete();
    await tester.pump();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(attempts, 1);
  });

  testWidgets('falha após timeout permite nova inicialização', (tester) async {
    final first = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        timeout: const Duration(seconds: 2),
        initialize: () {
          attempts++;
          return attempts == 1 ? first.future : Future.value();
        },
        readyBuilder: readyApp,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    first.completeError(StateError('falha tardia'));
    await tester.pump();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('só cria o aplicativo após a inicialização válida', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var readyBuilds = 0;
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          attempts++;
          return initialization.future;
        },
        readyBuilder: (context) {
          readyBuilds++;
          return readyApp(context);
        },
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(readyBuilds, 0);
    expect(attempts, 1);

    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(readyBuilds, 1);
  });

  testWidgets('falha bloqueia serviços e permite tentar novamente', (
    tester,
  ) async {
    final firstAttempt = Completer<void>();
    final secondAttempt = Completer<void>();
    var attempts = 0;
    var readyBuilds = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          attempts++;
          return attempts == 1 ? firstAttempt.future : secondAttempt.future;
        },
        readyBuilder: (context) {
          readyBuilds++;
          return readyApp(context);
        },
      ),
    );

    firstAttempt.completeError(
      FirebaseException(
        plugin: 'firebase_core',
        code: 'network-request-failed',
        message: 'Detalhe técnico confidencial',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o aplicativo'), findsOneWidget);
    expect(find.textContaining('confidencial'), findsNothing);
    expect(readyBuilds, 0);

    await tester.tap(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(readyBuilds, 0);

    secondAttempt.complete();
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo pronto'), findsOneWidget);
    expect(readyBuilds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro síncrono de configuração também oferece recuperação', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStartup(
        initialize: () => throw UnsupportedError('Plataforma sem configuração'),
        readyBuilder: readyApp,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Aplicativo pronto'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conclusão após descarte não usa estado ou contexto antigo', (
    tester,
  ) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () => initialization.future,
        readyBuilder: readyApp,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    initialization.completeError(StateError('Falha tardia'));
    await tester.pump();

    expect(find.text('Aplicativo pronto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carregamento e falha cabem em tela pequena com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final initialization = Completer<void>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () => initialization.future,
        readyBuilder: readyApp,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    initialization.completeError(StateError('Falha de inicialização'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tentar novamente'));
    expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
