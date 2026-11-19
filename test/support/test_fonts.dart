import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> useBundledTestFonts() async {
  // Estes testes verificam ciclo de vida, não tipografia. Reutilizam uma
  // fonte empacotada pelo Flutter sob os nomes pedidos, sem rede/disco externo.
  final font = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  final manifest = <String, Object>{};
  for (final family in ['Outfit', 'PlayfairDisplay']) {
    for (final weight in [
      'Thin',
      'ExtraLight',
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      final path = '$family-$weight.ttf';
      manifest[path] = [
        {'asset': path},
      ];
    }
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = const StringCodec().decodeMessage(message);
        if (path == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(manifest);
        }
        if (manifest.containsKey(path)) return font;
        return null;
      });
}
