import 'package:bookself_app/ui/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'async_ui_test.dart' as fixtures;
import 'support/test_fonts.dart';

void main() {
  setUpAll(useBundledTestFonts);
  for (final source in ['Escolher da Galeria', 'Tirar Foto']) {
    testWidgets(
      'cancelar $source preserva foto e dispensa metadados completos',
      (tester) async {
        final profiles = fixtures.UiProfiles();
        final picker = fixtures.UiPicker();
        await fixtures.openScreen(
          tester,
          ProfileScreen(profiles: profiles, imagePicker: picker),
        );
        await tester.tap(find.byIcon(Icons.camera_alt_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text(source));
        await tester.pump();
        picker.selection.complete(null);
        await tester.pumpAndSettle();
        expect(picker.requestedFullMetadata, isFalse);
        expect(profiles.photos, 0);
        expect(find.byType(SnackBar), findsNothing);
        await tester.tap(find.byIcon(Icons.camera_alt_rounded));
        await tester.pumpAndSettle();
        expect(find.text(source), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final code in [
    'camera_access_denied',
    'camera_access_denied_without_prompt',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_denied_without_prompt',
    'photo_access_restricted',
  ]) {
    testWidgets('$code informa permissão sem escrever nem revelar erro bruto', (
      tester,
    ) async {
      final profiles = fixtures.UiProfiles();
      final picker = fixtures.UiPicker();
      await fixtures.openScreen(
        tester,
        ProfileScreen(profiles: profiles, imagePicker: picker),
      );
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          code.startsWith('camera') ? 'Tirar Foto' : 'Escolher da Galeria',
        ),
      );
      await tester.pump();
      picker.selection.completeError(
        PlatformException(code: code, message: 'PRIVATE_FIXTURE'),
      );
      await tester.pumpAndSettle();
      expect(profiles.photos, 0);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
      expect(
        find.textContaining(
          code.contains('restricted') ? 'restrito' : 'Permita',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tirar Foto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
