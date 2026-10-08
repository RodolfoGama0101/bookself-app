import 'dart:async';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/partner_blocks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'async_ui_test.dart' show UiAuth;
import 'support/test_fonts.dart';

class _Auth extends UiAuth {
  String uid = 'owner';
  String? partner;
  bool blocked = false;
  bool readError = false;
  int writes = 0;
  Completer<String?>? pending;
  @override
  UserModel get currentUserModel =>
      super.currentUserModel.copyWith(uid: uid, partnerUid: partner);
  @override
  Stream<Map<String, String>> watchContacts() => readError
      ? Stream.error(StateError('Erro privado'))
      : Stream.value({'known': 'Pessoa conhecida'});
  @override
  Stream<Map<String, String>> watchBlocks() =>
      Stream.value(blocked ? {'known': 'Pessoa conhecida'} : {});
  @override
  Future<String?> blockKnownPerson(String other) {
    expect(other, 'known');
    writes++;
    return pending?.future ?? Future.value(null);
  }

  @override
  Future<String?> unblockPartner(String other) {
    expect(other, 'known');
    writes++;
    return pending?.future ?? Future.value(null);
  }

  void changeAccount() {
    uid = 'other-owner';
    notifyListeners();
  }
}

Future<void> _open(WidgetTester tester, _Auth auth) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: const MaterialApp(home: PartnerBlocksScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets('cancelar confirmação não escreve nem mostra identificadores', (
    tester,
  ) async {
    final auth = _Auth();
    await _open(tester, auth);
    expect(find.text('known'), findsNothing);
    await tester.tap(find.text('Bloquear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(auth.writes, 0);
    auth.dispose();
  });
  testWidgets(
    'bloqueio aguarda confirmação, bloqueia repetição e permite repetir após falha',
    (tester) async {
      final auth = _Auth()..pending = Completer<String?>();
      await _open(tester, auth);
      await tester.tap(find.text('Bloquear'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(auth.writes, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(find.text('Pessoa bloqueada.'), findsNothing);
      auth.pending!.complete('Não foi possível salvar. Tente novamente.');
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível salvar. Tente novamente.'),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      auth.pending = null;
      await tester.tap(find.text('Bloquear'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pumpAndSettle();
      expect(auth.writes, 2);
      expect(find.text('Pessoa bloqueada.'), findsOneWidget);
      auth.dispose();
    },
  );
  testWidgets(
    'desbloqueio esclarece independência e novo convite, inclusive em tela ampliada',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = _Auth()..blocked = true;
      await _open(tester, auth);
      await tester.scrollUntilVisible(
        find.text('Desbloquear'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bloqueio da outra pessoa'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Desbloquear'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
      await tester.pumpAndSettle();
      expect(auth.writes, 1);
      expect(tester.takeException(), isNull);
      auth.dispose();
    },
  );
  testWidgets('erro de leitura retira ações e nova tentativa recarrega lista', (
    tester,
  ) async {
    final auth = _Auth()..readError = true;
    await _open(tester, auth);
    expect(find.text('Erro privado'), findsNothing);
    expect(find.text('Bloquear'), findsNothing);
    auth.readError = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Pessoa conhecida'), findsWidgets);
    auth.dispose();
  });
  testWidgets(
    'troca de conta durante confirmação não bloqueia na nova sessão',
    (tester) async {
      final auth = _Auth();
      await _open(tester, auth);
      await tester.tap(find.text('Bloquear'));
      await tester.pumpAndSettle();
      auth.changeAccount();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pumpAndSettle();
      expect(auth.writes, 0);
      auth.dispose();
    },
  );
  testWidgets('descarte durante escrita não acessa tela fechada', (
    tester,
  ) async {
    final auth = _Auth()..pending = Completer<String?>();
    await _open(tester, auth);
    await tester.tap(find.text('Bloquear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    auth.pending!.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    auth.dispose();
  });
}
