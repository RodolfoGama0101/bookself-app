import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_handler.dart';

class ThemeService extends ChangeNotifier {
  ThemeService({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;

  static const preferenceKey = 'theme_mode';
  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();
  ThemeMode _themeMode = ThemeMode.dark;
  Future<void>? _initialization;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _loadError;

  ThemeMode get themeMode => _themeMode;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    return _initialization ??= _restore();
  }

  Future<void> _restore() async {
    _isLoading = true;
    notifyListeners();
    try {
      final saved = await _preferences
          .getString(preferenceKey)
          .timeout(const Duration(seconds: 5));
      final mode = switch (saved) {
        null || 'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => throw const FormatException(),
      };
      if (_disposed) return;
      _themeMode = mode;
      _loadError = null;
    } catch (error) {
      final message = ErrorHandler.getFriendlyErrorMessage(
        error,
        operation: ErrorOperation.loadTheme,
      );
      if (_disposed) return;
      _loadError = 'Não foi possível carregar seu tema salvo. $message';
    } finally {
      if (!_disposed) {
        _initialized = true;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryLoading() {
    if (_disposed || _isSaving || _isLoading) return Future.value();
    _initialization = null;
    return initialize();
  }

  Future<String?> toggleTheme(Brightness brightness) => setThemeMode(
    brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
  );

  Future<String?> setThemeMode(ThemeMode mode) async {
    if (_disposed) return null;
    if (!_initialized || _isLoading) await initialize();
    if (_disposed) return null;
    if (_isSaving) return 'Aguarde o tema terminar de salvar.';
    _isSaving = true;
    notifyListeners();
    try {
      await _preferences.setString(preferenceKey, mode.name);
      if (_disposed) return null;
      _themeMode = mode;
      _loadError = null;
      return null;
    } catch (error) {
      final message = ErrorHandler.getFriendlyErrorMessage(
        error,
        operation: ErrorOperation.saveTheme,
      );
      return 'Não foi possível salvar seu tema. $message';
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
