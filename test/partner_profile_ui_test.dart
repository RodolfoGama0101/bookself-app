import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/ui/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'async_ui_test.dart' show UiAuth, UiProfiles, openScreen;
import 'support/test_fonts.dart';

class LinkedAuth extends UiAuth {
  LinkedAuth(this.available);
  final bool available;
  int unlinks = 0;

  @override
  UserModel get currentUserModel =>
      super.currentUserModel.copyWith(partnerUid: 'partner');

  @override
  PartnerProfile get partnerUserModel => available
      ? const PartnerProfile(uid: 'partner', name: 'Companhia')
      : PartnerProfile.unavailable('partner');

  @override
  Future<String?> unlinkPartner() async {
    unlinks++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  for (final available in [true, false]) {
    testWidgets(
      'perfil do casal sem e-mail alheio mantém desvínculo${available ? '' : ' com apresentação ausente'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = LinkedAuth(available);
        await openScreen(
          tester,
          ProfileScreen(profiles: UiProfiles()),
          auth: auth,
        );
        expect(find.text('teste@example.com'), findsOneWidget);
        expect(find.text('partner@example.com'), findsNothing);
        expect(
          find.text(available ? 'Companhia' : 'Seu parceiro'),
          findsOneWidget,
        );
        expect(
          find.text('Perfil do parceiro indisponível no momento.'),
          available ? findsNothing : findsOneWidget,
        );
        final unlink = find.text('Desvincular Casal');
        await tester.ensureVisible(unlink);
        await tester.tap(unlink);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Desvincular'));
        await tester.pumpAndSettle();
        expect(auth.unlinks, 1);
        expect(find.text('Vínculo desfeito.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
