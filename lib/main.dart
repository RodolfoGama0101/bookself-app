import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'ui/theme.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_navigation.dart';
import 'ui/screens/app_startup.dart';
import 'ui/screens/session_gate.dart';

import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    AppStartup(
      initialize: _initializeFirebase,
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

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class BookselfApp extends StatelessWidget {
  const BookselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          title: 'Bookself App',
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
