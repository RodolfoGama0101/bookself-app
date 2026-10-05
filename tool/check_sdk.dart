import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final configFile = File.fromUri(Platform.script.resolve('flutter-sdk.json'));
  try {
    final expected =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final result = await Process.run('flutter', [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
    if (result.exitCode != 0) {
      stderr.writeln('Não foi possível consultar o Flutter no PATH.');
      exitCode = 1;
      return;
    }
    final actual = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final required = {
      'flutterVersion': expected['flutterVersion'],
      'dartSdkVersion': expected['dartVersion'],
      'channel': expected['channel'],
      'frameworkRevision': expected['frameworkRevision'],
    };
    for (final entry in required.entries) {
      if (actual[entry.key] != entry.value) {
        stderr.writeln(
          'SDK incompatível: ${entry.key} deve ser ${entry.value}. '
          'Siga docs/DEVELOPMENT.md para selecionar o SDK fixado.',
        );
        exitCode = 1;
        return;
      }
    }
    stdout.writeln(
      'SDK confirmado: Flutter ${expected['flutterVersion']}, '
      'Dart ${expected['dartVersion']}, ${expected['channel']}.',
    );
  } on Object {
    stderr.writeln(
      'Falha ao validar o SDK. Verifique o PATH e tool/flutter-sdk.json.',
    );
    exitCode = 1;
  }
}
