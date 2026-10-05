import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/firebase_environment.dart';
import 'ui/theme.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_navigation.dart';
import 'ui/screens/app_startup.dart';
import 'ui/screens/session_gate.dart';

import 'firebase_options.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    BookselfBootstrap(
      initialize: _initializeFirebase,
      readyBuilder: (_) => ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const BookselfApp(),
      ),
    ),
  );
}

/// Restaura o tema antes de abrir a interface e mantém a preferência no logout.
class BookselfBootstrap extends StatelessWidget {
  const BookselfBootstrap({
    super.key,
    required this.initialize,
    required this.readyBuilder,
    this.themeService,
  });

  final Future<void> Function() initialize;
  final WidgetBuilder readyBuilder;
  final ThemeService? themeService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>(
      create: (_) {
        final service = themeService ?? ThemeService();
        service.initialize();
        return service;
      },
      child: Builder(
        builder: (context) {
          final theme = context.read<ThemeService>();
          return AppStartup(
            initialize: () async {
              await theme.initialize();
              await initialize();
            },
            readyBuilder: readyBuilder,
          );
        },
      ),
    );
  }
}

Future<void> _initializeFirebase() async {
  const environment = FirebaseEnvironment.fromDefines;
  environment.validate();
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
    await FirebaseAuth.instanceFor(
      app: app,
    ).useAuthEmulator(environment.host, environment.authPort);
  }
}

class BookselfApp extends StatelessWidget {
  const BookselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          title: 'Bookself App',
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,

          home: SessionGate(
            signedOutBuilder: (_) => const LoginScreen(),
            readyBuilder: (_) => const MainNavigation(),
          ),
        );
      },
    );
  }
}
