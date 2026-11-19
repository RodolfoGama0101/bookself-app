import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/firebase_environment.dart';
import 'services/firebase_web_emulator.dart';
import 'ui/theme.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_navigation.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeFirebase();
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Não foi possível iniciar o aplicativo. Feche e tente novamente.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const BookselfApp(),
    ),
  );
}

Future<void> initializeFirebase() async {
  const environment = FirebaseEnvironment.fromDefines;
  environment.validate();
  final webAuthConfigured = await prepareWebEmulator(environment);
  final app = await Firebase.initializeApp(
    name: environment.useEmulators ? FirebaseEnvironment.demoProjectId : null,
    options: environment.useEmulators
        ? environment.demoOptions
        : DefaultFirebaseOptions.currentPlatform,
  );
  if (environment.useEmulators) {
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator(environment.host, environment.firestorePort);
    if (!webAuthConfigured) {
      await FirebaseAuth.instanceFor(
        app: app,
      ).useAuthEmulator(environment.host, environment.authPort);
    }
  }
}

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
