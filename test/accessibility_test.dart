import 'package:bookself_app/ui/widgets/custom_button.dart';
import 'package:bookself_app/ui/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test('texto e botões primários têm contraste mínimo nos dois temas', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final scheme = theme.colorScheme;
      for (final surface in [
        theme.scaffoldBackgroundColor,
        scheme.surface,
        scheme.surfaceContainerHighest,
      ]) {
        expect(contrast(scheme.primary, surface), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets('botão mantém nome acessível enquanto aguarda escrita', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomButton(
            text: 'Salvar livro',
            onPressed: null,
            isLoading: true,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Salvar livro. Aguarde, operação em andamento'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              'Salvar livro. Aguarde, operação em andamento',
            ),
          )
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('botão recebe foco por Tab e ativa por Enter', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomButton(text: 'Salvar livro', onPressed: () => saved++),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(saved, 1);
  });
}
