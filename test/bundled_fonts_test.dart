import 'dart:convert';

import 'package:bookself_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'temas e pesos usados carregam fontes reais empacotadas sem rede',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/fonts/manifest.json'))
              as List;
      expect(manifest.length, 8);
      for (final item in manifest) {
        final bytes = await rootBundle.load('assets/fonts/${item['file']}');
        expect(bytes.lengthInBytes, item['bytes']);
      }
      final styles = <TextStyle>[];
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        styles.add(GoogleFonts.outfit(fontWeight: weight));
        styles.add(GoogleFonts.playfairDisplay(fontWeight: weight));
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: styles
                  .map((style) => Text('Leitura sem rede', style: style))
                  .toList(),
            ),
          ),
        ),
      );
      await GoogleFonts.pendingFonts();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
