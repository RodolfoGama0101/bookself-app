import 'dart:js_interop';

import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_core_web/firebase_core_web_interop.dart' as core;

import 'firebase_environment.dart';

/// Configura Auth antes da restauração que FlutterFire aguarda em initializeApp.
Future<bool> prepareWebEmulator(FirebaseEnvironment environment) async {
  environment.validate();
  if (!environment.useEmulators) return false;
  final options = environment.demoOptions;
  await _prepareDemoFirebase(
    supportedFirebaseJsSdkVersion.toJS,
    core.FirebaseOptions(
      apiKey: options.apiKey.toJS,
      authDomain: options.authDomain?.toJS,
      databaseURL: options.databaseURL?.toJS,
      projectId: options.projectId.toJS,
      storageBucket: options.storageBucket?.toJS,
      messagingSenderId: options.messagingSenderId.toJS,
      measurementId: options.measurementId?.toJS,
      appId: options.appId.toJS,
    ),
    'http://${environment.host}:${environment.authPort}'.toJS,
  ).toDart;
  return true;
}

@JS('bookselfPrepareDemoFirebase')
external JSPromise<JSAny?> _prepareDemoFirebase(
  JSString version,
  JSObject options,
  JSString origin,
);
