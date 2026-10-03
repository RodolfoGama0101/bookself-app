import 'dart:async';

import 'package:bookself_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/theme_preferences_fake.dart';

void main() {
  late ThemePreferencesFake preferences;
  late ThemeService service;
  var disposed = false;

  setUp(() {
    preferences = ThemePreferencesFake();
    service = ThemeService(preferences: preferences);
    disposed = false;
  });
  tearDown(() {
    if (!disposed) service.dispose();
  });

  test(
    'primeiro uso mantém escuro e não grava preferência implicitamente',
    () async {
      expect(preferences.reads, 0);
      await service.initialize();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.loadError, isNull);
      expect(preferences.values, isEmpty);
      expect(preferences.writes, 0);
    },
  );

  for (final mode in ThemeMode.values) {
    test('${mode.name} é restaurado após recriar o serviço', () async {
      expect(await service.setThemeMode(mode), isNull);
      expect(preferences.values[ThemeService.preferenceKey], mode.name);
      service.dispose();
      service = ThemeService(preferences: preferences);
      await service.initialize();
      expect(service.themeMode, mode);
      expect(preferences.writes, 1);
    });
  }

  test(
    'valor inválido usa escuro e permite reler sem apagar outros dados',
    () async {
      preferences.values.addAll({
        ThemeService.preferenceKey: 'invalid',
        'other': 'preserved',
      });
      await service.initialize();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.loadError, contains('carregar seu tema'));
      expect(preferences.writes, 0);
      expect(preferences.values['other'], 'preserved');
      preferences.values[ThemeService.preferenceKey] = 'light';
      await service.retryLoading();
      expect(service.themeMode, ThemeMode.light);
      expect(service.loadError, isNull);
      expect(preferences.values['other'], 'preserved');
    },
  );

  test(
    'falha de leitura não impede inicialização e pode ser recuperada',
    () async {
      preferences.controls.readFailure = PlatformException(
        code: 'PRIVATE_FIXTURE',
        message: 'PRIVATE_FIXTURE',
      );
      await service.initialize();
      expect(service.isLoading, isFalse);
      expect(service.themeMode, ThemeMode.dark);
      expect(service.loadError, isNot(contains('PRIVATE_FIXTURE')));
      preferences.controls.readFailure = null;
      preferences.values[ThemeService.preferenceKey] = 'system';
      await service.retryLoading();
      expect(service.themeMode, ThemeMode.system);
      expect(service.loadError, isNull);
    },
  );

  testWidgets(
    'leitura sem resposta libera início em cinco segundos e ignora resposta antiga',
    (tester) async {
      final read = Completer<String?>();
      preferences.controls.pendingRead = read;
      final loading = service.initialize();
      await tester.pump(const Duration(seconds: 5));
      await loading;
      expect(service.themeMode, ThemeMode.dark);
      expect(service.isLoading, isFalse);
      expect(service.loadError, contains('demorou'));
      expect(service.loadError, isNot(contains('conexão')));
      preferences.controls.pendingRead = null;
      expect(await service.setThemeMode(ThemeMode.system), isNull);
      read.complete('light');
      await tester.pump();
      expect(service.themeMode, ThemeMode.system);
    },
  );

  test('inicialização simultânea só lê uma vez', () async {
    final read = Completer<String?>();
    preferences.controls.pendingRead = read;
    final first = service.initialize();
    final second = service.initialize();
    expect(preferences.reads, 1);
    read.complete('light');
    await Future.wait([first, second]);
    await service.initialize();
    expect(preferences.reads, 1);
    expect(service.themeMode, ThemeMode.light);
  });

  test(
    'alteração durante restauração aguarda leitura e prevalece após escrita',
    () async {
      final read = Completer<String?>();
      preferences.controls.pendingRead = read;
      final loading = service.initialize();
      final saving = service.setThemeMode(ThemeMode.system);
      expect(preferences.writes, 0);
      read.complete('light');
      await loading;
      expect(await saving, isNull);
      expect(service.themeMode, ThemeMode.system);
      expect(preferences.values[ThemeService.preferenceKey], 'system');
    },
  );

  test(
    'mudança só é aplicada após confirmação e bloqueia gravações concorrentes',
    () async {
      await service.initialize();
      final write = Completer<void>();
      preferences.controls.pendingWrite = write;
      final saving = service.setThemeMode(ThemeMode.light);
      expect(service.isSaving, isTrue);
      expect(service.themeMode, ThemeMode.dark);
      expect(await service.setThemeMode(ThemeMode.system), contains('Aguarde'));
      await service.retryLoading();
      expect(preferences.writes, 1);
      expect(preferences.reads, 1);
      write.complete();
      expect(await saving, isNull);
      expect(service.themeMode, ThemeMode.light);
      expect(service.isSaving, isFalse);
    },
  );

  test(
    'falha de gravação preserva escolha anterior no serviço e no armazenamento',
    () async {
      preferences.values[ThemeService.preferenceKey] = 'system';
      await service.initialize();
      preferences.controls.writeFailure = StateError('PRIVATE_FIXTURE');
      final error = await service.setThemeMode(ThemeMode.light);
      expect(error, contains('salvar seu tema'));
      expect(error, isNot(contains('PRIVATE_FIXTURE')));
      expect(service.themeMode, ThemeMode.system);
      expect(preferences.values[ThemeService.preferenceKey], 'system');
      expect(service.isSaving, isFalse);
      preferences.controls.writeFailure = null;
      expect(await service.setThemeMode(ThemeMode.light), isNull);
      expect(service.themeMode, ThemeMode.light);
    },
  );

  for (final brightness in Brightness.values) {
    test(
      'atalho usa brilho efetivo ${brightness.name} para sair de Sistema',
      () async {
        preferences.values[ThemeService.preferenceKey] = 'system';
        await service.initialize();
        expect(await service.toggleTheme(brightness), isNull);
        final expected = brightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark;
        expect(service.themeMode, expected);
        expect(preferences.values[ThemeService.preferenceKey], expected.name);
      },
    );
  }

  for (final loading in [true, false]) {
    test(
      'descarte durante ${loading ? 'leitura' : 'escrita'} ignora retorno e novas operações',
      () async {
        var notifications = 0;
        service.addListener(() => notifications++);
        final read = Completer<String?>();
        final write = Completer<void>();
        final Future<Object?> operation;
        if (loading) {
          preferences.controls.pendingRead = read;
          operation = service.initialize();
        } else {
          await service.initialize();
          preferences.controls.pendingWrite = write;
          operation = service.setThemeMode(ThemeMode.light);
        }
        service.dispose();
        disposed = true;
        final previous = notifications;
        if (loading) {
          read.complete('light');
        } else {
          write.complete();
        }
        await operation;
        await service.initialize();
        await service.retryLoading();
        await service.setThemeMode(ThemeMode.system);
        expect(notifications, previous);
        expect(service.themeMode, ThemeMode.dark);
        expect(preferences.writes, loading ? 0 : 1);
      },
    );
  }
}
