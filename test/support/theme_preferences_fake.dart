import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceControls {
  Completer<String?>? pendingRead;
  Completer<void>? pendingWrite;
  Object? readFailure;
  Object? writeFailure;
  int reads = 0;
  int writes = 0;
}

class ThemePreferencesFake extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  final controls = ThemePreferenceControls();
  int get reads => controls.reads;
  int get writes => controls.writes;

  @override
  Future<String?> getString(String key) async {
    controls.reads++;
    if (controls.readFailure != null) throw controls.readFailure!;
    if (controls.pendingRead != null) return controls.pendingRead!.future;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    controls.writes++;
    if (controls.pendingWrite != null) await controls.pendingWrite!.future;
    if (controls.writeFailure != null) throw controls.writeFailure!;
    values[key] = value;
  }
}
