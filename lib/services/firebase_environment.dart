import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuração local explícita; o modo de emuladores usa sempre projeto demo.
class FirebaseEnvironment {
  const FirebaseEnvironment({
    this.useEmulators = false,
    this.host = '127.0.0.1',
    this.authPort = 9099,
    this.firestorePort = 8080,
  });

  static const fromDefines = FirebaseEnvironment(
    useEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    host: String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    ),
    authPort: int.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_PORT',
      defaultValue: 9099,
    ),
    firestorePort: int.fromEnvironment(
      'FIRESTORE_EMULATOR_PORT',
      defaultValue: 8080,
    ),
  );

  static const demoProjectId = 'demo-bookself';
  static FirebaseAuth get auth => fromDefines.useEmulators
      ? FirebaseAuth.instanceFor(app: Firebase.app(demoProjectId))
      : FirebaseAuth.instance;
  static FirebaseFirestore get firestore => fromDefines.useEmulators
      ? FirebaseFirestore.instanceFor(app: Firebase.app(demoProjectId))
      : FirebaseFirestore.instance;
  final bool useEmulators;
  final String host;
  final int authPort;
  final int firestorePort;

  FirebaseOptions get demoOptions => const FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:1234567890:web:demo',
    messagingSenderId: '1234567890',
    projectId: demoProjectId,
  );

  void validate() {
    if (!useEmulators) return;
    if (!['127.0.0.1', 'localhost', '10.0.2.2'].contains(host) ||
        authPort < 1 ||
        authPort > 65535 ||
        firestorePort < 1 ||
        firestorePort > 65535 ||
        authPort == firestorePort) {
      throw ArgumentError('Configuração local dos emuladores inválida');
    }
  }
}
