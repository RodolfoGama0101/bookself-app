import 'package:bookself_app/services/firebase_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'emuladores usam identidade demo, independente da configuração distribuída',
    () {
      const environment = FirebaseEnvironment(useEmulators: true);
      environment.validate();
      expect(environment.demoOptions.projectId, 'demo-bookself');
      expect(environment.demoOptions.apiKey, 'demo-key');
      expect(environment.host, '127.0.0.1');
      expect(environment.authPort, 9099);
      expect(environment.firestorePort, 8080);
    },
  );
  test(
    'configuração rejeita host remoto e portas inválidas antes de inicializar SDK',
    () {
      for (final environment in [
        const FirebaseEnvironment(useEmulators: true, host: 'example.com'),
        const FirebaseEnvironment(
          useEmulators: true,
          host: 'https://127.0.0.1',
        ),
        const FirebaseEnvironment(useEmulators: true, host: ''),
        const FirebaseEnvironment(useEmulators: true, authPort: 0),
        const FirebaseEnvironment(useEmulators: true, firestorePort: 65536),
        const FirebaseEnvironment(useEmulators: true, authPort: 8080),
      ]) {
        expect(environment.validate, throwsArgumentError);
      }
    },
  );
  test('web/simuladores podem usar loopback ou alias do emulador Android', () {
    for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
      FirebaseEnvironment(useEmulators: true, host: host).validate();
    }
  });
  test(
    'emuladores são opt-in; configuração local não ativa sozinha o modo',
    () {
      const FirebaseEnvironment(host: 'example.com').validate();
      expect(FirebaseEnvironment.fromDefines.useEmulators, isFalse);
    },
  );
}
