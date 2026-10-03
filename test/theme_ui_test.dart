import 'dart:async';

import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/main.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/theme_service.dart';
import 'package:bookself_app/ui/screens/login_screen.dart';
import 'package:bookself_app/ui/screens/profile_screen.dart';
import 'package:bookself_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/test_fonts.dart';
import 'support/theme_preferences_fake.dart';

class ThemeProfiles extends FakeUserProfiles {
  bool missingProfile = false;
  @override
  Stream<UserModel?> watchProfile(String uid) async* {
    yield missingProfile ? null : profile(uid).copyWith(photoUrl: null);
    yield* super.watchProfile(uid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);
  late ThemePreferencesFake preferences;
  late FakeFirebaseAuth auth;
  late ThemeProfiles profiles;
  late ThemeService theme;

  setUp(() {
    preferences = ThemePreferencesFake();
    auth = FakeFirebaseAuth();
    profiles = ThemeProfiles();
    theme = ThemeService(preferences: preferences);
  });
  tearDown(() async {
    await auth.changes.close();
    await profiles.close();
  });

  Widget app({bool showProfile = false, Future<void> Function()? initialize}) {
    return BookselfBootstrap(
      themeService: theme,
      initialize: initialize ?? () async {},
      readyBuilder: (_) => ChangeNotifierProvider<AuthService>(
        create: (_) {
          final service = AuthService(auth: auth, profiles: profiles);
          auth.emit(showProfile ? FakeUser('owner') : null);
          return service;
        },
        child: showProfile
            ? Consumer<ThemeService>(
                builder: (_, service, _) => MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: service.themeMode,
                  home: const ProfileScreen(),
                ),
              )
            : const BookselfApp(),
      ),
    );
  }

  Future<void> openProfile(
    WidgetTester tester, {
    Size size = const Size(800, 1000),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(showProfile: true));
    await tester.pumpAndSettle();
  }

  Finder selector() => find.byKey(const ValueKey('theme-mode-selector'));
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.ensureVisible(selector());
    await tester.tap(selector());
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Brightness brightness(WidgetTester tester, Type screen) =>
      Theme.of(tester.element(find.byType(screen))).brightness;

  testWidgets(
    'tema salvo é restaurado antes de inicialização e do primeiro login',
    (tester) async {
      final read = Completer<String?>();
      preferences.controls.pendingRead = read;
      var initializeCalls = 0;
      await tester.pumpWidget(
        app(
          initialize: () async {
            initializeCalls++;
            expect(theme.themeMode, ThemeMode.light);
          },
        ),
      );
      expect(find.byType(LoginScreen), findsNothing);
      expect(initializeCalls, 0);
      read.complete('light');
      await tester.pumpAndSettle();
      expect(initializeCalls, 1);
      expect(brightness(tester, LoginScreen), Brightness.light);
      expect(preferences.writes, 0);
    },
  );

  testWidgets(
    'sem preferência o primeiro login é escuro mesmo com sistema claro',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(brightness(tester, LoginScreen), Brightness.dark);
      expect(preferences.writes, 0);
    },
  );

  testWidgets('Sistema acompanha brilho sem sobrescrever preferência', (
    tester,
  ) async {
    preferences.values[ThemeService.preferenceKey] = 'system';
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(brightness(tester, LoginScreen), Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(tester, LoginScreen), Brightness.dark);
    expect(preferences.values[ThemeService.preferenceKey], 'system');
    expect(preferences.writes, 0);
  });

  testWidgets('escolha no perfil é restaurada no login após recriar a árvore', (
    tester,
  ) async {
    await openProfile(tester);
    await choose(tester, 'Claro');
    await tester.pumpWidget(const SizedBox.shrink());
    theme = ThemeService(preferences: preferences);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(brightness(tester, LoginScreen), Brightness.light);
    expect(preferences.writes, 1);
  });

  testWidgets('mudança de sessão e logout preservam tema local e instância', (
    tester,
  ) async {
    preferences.values[ThemeService.preferenceKey] = 'light';
    profiles.missingProfile = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final originalTheme = theme;
    auth.emit(FakeUser('owner'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      identical(
        Provider.of<ThemeService>(
          tester.element(find.byType(BookselfApp)),
          listen: false,
        ),
        originalTheme,
      ),
      isTrue,
    );
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(brightness(tester, LoginScreen), Brightness.light);
    expect(preferences.values[ThemeService.preferenceKey], 'light');
    expect(preferences.reads, 1);
    expect(preferences.writes, 0);
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('$mode explícito ignora mudança de brilho do sistema', (
      tester,
    ) async {
      preferences.values[ThemeService.preferenceKey] = mode;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final expected = mode == 'light' ? Brightness.light : Brightness.dark;
      expect(brightness(tester, LoginScreen), expected);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(tester, LoginScreen), expected);
    });
  }

  testWidgets('falha local de leitura não impede abrir o app', (tester) async {
    preferences.controls.readFailure = StateError('PRIVATE_FIXTURE');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(brightness(tester, LoginScreen), Brightness.dark);
    expect(theme.loadError, contains('carregar seu tema'));
    expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
  });

  testWidgets(
    'nova tentativa de Firebase preserva restauração e não duplica leitura',
    (tester) async {
      preferences.values[ThemeService.preferenceKey] = 'light';
      var calls = 0;
      await tester.pumpWidget(
        app(
          initialize: () async {
            calls++;
            if (calls == 1) throw StateError('PRIVATE_FIXTURE');
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(preferences.reads, 1);
      expect(brightness(tester, LoginScreen), Brightness.light);
    },
  );

  testWidgets(
    'perfil confirma gravação antes de trocar o tema e bloqueia atalhos',
    (tester) async {
      await openProfile(tester);
      final write = Completer<void>();
      preferences.controls.pendingWrite = write;
      await choose(tester, 'Claro');
      expect(find.text('Salvando tema…'), findsOneWidget);
      expect(brightness(tester, ProfileScreen), Brightness.dark);
      expect(
        tester.widget<DropdownButton<ThemeMode>>(selector()).value,
        ThemeMode.dark,
      );
      expect(
        tester.widget<DropdownButton<ThemeMode>>(selector()).onChanged,
        isNull,
      );
      final shortcut = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Alterar Tema',
      );
      expect(tester.widget<IconButton>(shortcut).onPressed, isNull);
      write.complete();
      await tester.pumpAndSettle();
      expect(brightness(tester, ProfileScreen), Brightness.light);
      expect(find.text('Salvando tema…'), findsNothing);
      expect(preferences.values[ThemeService.preferenceKey], 'light');
      expect(preferences.writes, 1);
    },
  );

  testWidgets('falha ao salvar mantém tema e mostra erro com nova tentativa', (
    tester,
  ) async {
    await openProfile(tester);
    preferences.controls.writeFailure = StateError('PRIVATE_FIXTURE');
    await choose(tester, 'Claro');
    expect(brightness(tester, ProfileScreen), Brightness.dark);
    expect(
      find.textContaining('Não foi possível salvar seu tema'),
      findsOneWidget,
    );
    expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
    expect(
      tester.widget<DropdownButton<ThemeMode>>(selector()).onChanged,
      isNotNull,
    );
    preferences.controls.writeFailure = null;
    await choose(tester, 'Claro');
    expect(brightness(tester, ProfileScreen), Brightness.light);
    expect(preferences.values[ThemeService.preferenceKey], 'light');
  });

  testWidgets('perfil recupera leitura salva e oferece Sistema', (
    tester,
  ) async {
    preferences.controls.readFailure = StateError('PRIVATE_FIXTURE');
    await openProfile(tester);
    expect(
      find.textContaining('Não foi possível carregar seu tema salvo'),
      findsOneWidget,
    );
    preferences.controls.readFailure = null;
    preferences.values[ThemeService.preferenceKey] = 'light';
    await tester.ensureVisible(find.text('Tentar carregar novamente'));
    await tester.tap(find.text('Tentar carregar novamente'));
    await tester.pumpAndSettle();
    expect(brightness(tester, ProfileScreen), Brightness.light);
    expect(theme.loadError, isNull);
    await choose(tester, 'Sistema');
    expect(find.text('Acompanha o tema do dispositivo.'), findsOneWidget);
    expect(preferences.values[ThemeService.preferenceKey], 'system');
  });

  testWidgets('atalho no modo Sistema persiste o oposto do brilho visível', (
    tester,
  ) async {
    preferences.values[ThemeService.preferenceKey] = 'system';
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openProfile(tester);
    await tester.tap(find.byTooltip('Alterar Tema'));
    await tester.pumpAndSettle();
    expect(brightness(tester, ProfileScreen), Brightness.light);
    expect(preferences.values[ThemeService.preferenceKey], 'light');
    expect(
      tester.widget<DropdownButton<ThemeMode>>(selector()).value,
      ThemeMode.light,
    );
  });

  testWidgets(
    'controle de tema permanece utilizável em 320 × 480 com texto 2×',
    (tester) async {
      await openProfile(tester, size: const Size(320, 480), scale: 2);
      await choose(tester, 'Sistema');
      expect(preferences.values[ThemeService.preferenceKey], 'system');
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'perfil descartado durante gravação: ${fails ? 'falha' : 'sucesso'}',
      (tester) async {
        await openProfile(tester);
        final write = Completer<void>();
        preferences.controls.pendingWrite = write;
        await choose(tester, 'Claro');
        await tester.pumpWidget(const SizedBox.shrink());
        if (fails) {
          write.completeError(StateError('PRIVATE_FIXTURE'));
        } else {
          write.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }
}
