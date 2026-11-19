import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/firebase_environment.dart';
import 'services/firebase_startup.dart';
import 'services/firebase_web_emulator.dart';
import 'ui/theme.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_navigation.dart';
import 'ui/screens/app_startup.dart';

import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppStartup(
      initialize: initializeFirebase,
      readyBuilder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => ThemeService()),
        ],
        child: const BookselfApp(),
      ),
    ),
  );
}

const _environment = FirebaseEnvironment.fromDefines;
final _firebaseStartup = FirebaseStartupCoordinator<FirebaseApp>(
  validate: _environment.validate,
  useEmulators: _environment.useEmulators,
  prepareWeb: () => prepareWebEmulator(_environment),
  initializeApp: () => Firebase.initializeApp(
    name: _environment.useEmulators ? FirebaseEnvironment.demoProjectId : null,
    options: _environment.useEmulators
        ? _environment.demoOptions
        : DefaultFirebaseOptions.currentPlatform,
  ),
  configureFirestore: (app) async {
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator(
      _environment.host,
      _environment.firestorePort,
    );
  },
  configureAuth: (app) => FirebaseAuth.instanceFor(
    app: app,
  ).useAuthEmulator(_environment.host, _environment.authPort),
);

Future<void> initializeFirebase() => _firebaseStartup.initialize();

class BookselfApp extends StatelessWidget {
  const BookselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, ThemeService>(
      builder: (context, authService, themeService, _) {
        final user = authService.currentUserModel;

        return MaterialApp(
          title: 'Bookself App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,

          // Fluxo de Rotas Inteligente (Apenas verifica se o usuário está logado)
          home: user != null ? const MainNavigation() : const LoginScreen(),
        );
      },
    );
  }
}
