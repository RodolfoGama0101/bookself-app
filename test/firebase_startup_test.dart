import 'dart:async';

import 'package:bookself_app/services/firebase_startup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failedStage in ['web', 'app', 'firestore', 'auth']) {
    test(
      'retoma após falha em $failedStage sem abrir o ambiente padrão',
      () async {
        final calls = <String>[];
        var fail = true;
        final demoApp = Object();
        Future<void> stage(String name) async {
          calls.add(name);
          if (name == failedStage && fail) {
            fail = false;
            throw StateError('falha fictícia');
          }
        }

        final startup = FirebaseStartupCoordinator<Object>(
          validate: () => calls.add('validate-demo'),
          useEmulators: true,
          prepareWeb: () async {
            await stage('web');
            return false;
          },
          initializeApp: () async {
            await stage('app');
            return demoApp;
          },
          configureFirestore: (app) async {
            expect(app, same(demoApp));
            await stage('firestore');
          },
          configureAuth: (app) async {
            expect(app, same(demoApp));
            await stage('auth');
          },
        );
        await expectLater(startup.initialize(), throwsStateError);
        final order = ['web', 'app', 'firestore', 'auth'];
        expect(calls, [
          'validate-demo',
          ...order.take(order.indexOf(failedStage) + 1),
        ]);
        await startup.initialize();
        expect(calls.where((name) => name == failedStage), hasLength(2));
        for (final completed in order.take(order.indexOf(failedStage))) {
          expect(calls.where((name) => name == completed), hasLength(1));
        }
        expect(calls, isNot(contains('production')));
        final count = calls.length;
        await startup.initialize();
        expect(calls, hasLength(count));
      },
    );
  }

  test(
    'configuração inválida falha antes de inicializar qualquer serviço',
    () async {
      var services = 0;
      final startup = FirebaseStartupCoordinator<Object>(
        validate: () => throw ArgumentError('host inválido'),
        useEmulators: true,
        prepareWeb: () async {
          services++;
          return false;
        },
        initializeApp: () async {
          services++;
          return Object();
        },
        configureFirestore: (_) async {
          services++;
        },
        configureAuth: (_) async {
          services++;
        },
      );
      await expectLater(startup.initialize(), throwsArgumentError);
      expect(services, 0);
    },
  );

  test(
    'preparo web evita configurar Auth novamente após falha posterior',
    () async {
      var web = 0;
      var auth = 0;
      var firestore = 0;
      final startup = FirebaseStartupCoordinator<Object>(
        validate: () {},
        useEmulators: true,
        prepareWeb: () async {
          web++;
          return true;
        },
        initializeApp: () async => Object(),
        configureFirestore: (_) async {
          if (++firestore == 1) throw StateError('falha');
        },
        configureAuth: (_) async {
          auth++;
        },
      );
      await expectLater(startup.initialize(), throwsStateError);
      await startup.initialize();
      expect(web, 1);
      expect(firestore, 2);
      expect(auth, 0);
    },
  );

  test('tentativas concorrentes aguardam a mesma inicialização', () async {
    final gate = Completer<Object>();
    var calls = 0;
    final startup = FirebaseStartupCoordinator<Object>(
      validate: () {},
      useEmulators: false,
      prepareWeb: () async => false,
      initializeApp: () {
        calls++;
        return gate.future;
      },
      configureFirestore: (_) async => fail('não configura emulador'),
      configureAuth: (_) async => fail('não configura emulador'),
    );
    final first = startup.initialize();
    final second = startup.initialize();
    gate.complete(Object());
    await Future.wait([first, second]);
    expect(calls, 1);
  });
}
