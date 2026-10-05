import 'dart:async';
import 'package:bookself_app/data/models/partner_invitation.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/ui/screens/partner_invitation_screen.dart';
import 'package:bookself_app/ui/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'async_ui_test.dart' show UiAuth;
import 'support/test_fonts.dart';

const code = '11111111111111111111111111111111';
PartnerInvitation invite({String status = 'pending'}) => PartnerInvitation(
  code: code,
  senderUid: 'sender-private',
  senderName: 'Companhia',
  recipientUid: 'owner',
  recipientName: 'Pessoa',
  recipientEpoch: 0,
  createdAt: DateTime.now(),
  status: status,
);

class InvitationUiAuth extends UiAuth {
  final sent = StreamController<PartnerInvitation?>.broadcast();
  final received = StreamController<PartnerInvitation?>.broadcast();
  final create = Completer<InvitationResult<String>>();
  final accept = Completer<String?>();
  int creates = 0;
  int accepts = 0;
  int claims = 0;
  int finishes = 0;
  @override
  Stream<PartnerInvitation?> watchOwnInvitation() async* {
    yield null;
    yield* sent.stream;
  }

  @override
  Stream<PartnerInvitation?> watchInvitation(String code) => received.stream;
  @override
  Future<InvitationResult<String>> createInvitation() {
    creates++;
    return create.future;
  }

  @override
  Future<InvitationResult<PartnerInvitation>> claimInvitation(
    String code,
  ) async {
    claims++;
    return InvitationResult(value: invite());
  }

  @override
  Future<String?> acceptInvitation(String code) {
    accepts++;
    return accept.future;
  }

  @override
  Future<String?> finishInvitation(String code, {required bool cancel}) async {
    finishes++;
    received.add(invite(status: cancel ? 'cancelled' : 'declined'));
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);
  late InvitationUiAuth auth;
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    auth = InvitationUiAuth();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const PartnerInvitationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, String text) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  Future<void> consent(WidgetTester tester) async {
    await show(tester, 'Li e concordo com esse compartilhamento.');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(auth.sent.hasListener, isFalse);
    expect(auth.received.hasListener, isFalse);
    await auth.sent.close();
    await auth.received.close();
    auth.dispose();
  }

  testWidgets(
    'criação exige consentimento e não anuncia sucesso antes da confirmação',
    (tester) async {
      await open(tester);
      await show(tester, 'Criar convite');
      expect(
        tester
            .widget<CustomButton>(
              find.widgetWithText(CustomButton, 'Criar convite'),
            )
            .onPressed,
        isNull,
      );
      await consent(tester);
      await show(tester, 'Criar convite');
      await tester.tap(find.text('Criar convite'));
      await tester.pump();
      expect(auth.creates, 1);
      expect(
        find.text('Convite criado. Copie o código para enviar.'),
        findsNothing,
      );
      auth.create.complete(
        const InvitationResult(error: 'Conexão indisponível.'),
      );
      await tester.pumpAndSettle();
      await show(tester, 'Conexão indisponível.');
      expect(find.text('Conexão indisponível.'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets(
    'consulta identifica por nome, aceite aguarda confirmação e recusa encerra convite',
    (tester) async {
      await open(tester);
      await show(tester, 'Código de convite');
      await tester.enterText(find.byType(TextField), code);
      await show(tester, 'Consultar convite');
      await tester.tap(find.text('Consultar convite'));
      await tester.pumpAndSettle();
      await show(tester, 'Companhia');
      expect(find.text('sender-private'), findsNothing);
      expect(find.text('teste@example.com'), findsNothing);
      await consent(tester);
      await show(tester, 'Aceitar convite');
      await tester.tap(find.text('Aceitar convite'));
      await tester.pump();
      expect(auth.accepts, 1);
      expect(find.text('Convite aceito. Vínculo confirmado.'), findsNothing);
      auth.accept.complete('Convite indisponível.');
      await tester.pumpAndSettle();
      await show(tester, 'Recusar convite');
      await tester.tap(find.text('Recusar convite'));
      await tester.pumpAndSettle();
      expect(auth.finishes, 1);
      await close(tester);
    },
  );
  testWidgets(
    'layout pequeno com texto ampliado mantém consentimento e ações acessíveis',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, scale: 2);
      await consent(tester);
      await show(tester, 'Criar convite');
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    'descarte durante criação não mostra feedback nem mantém assinatura',
    (tester) async {
      await open(tester);
      await consent(tester);
      await show(tester, 'Criar convite');
      await tester.tap(find.text('Criar convite'));
      await tester.pump();
      await close(tester);
      auth.create.complete(const InvitationResult(value: code));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'copia somente código opaco e erro do clipboard não anuncia sucesso',
    (tester) async {
      final binding =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      binding.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          expect((call.arguments as Map)['text'], code);
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });
      addTearDown(
        () => binding.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(tester);
      auth.sent.add(invite());
      await tester.pumpAndSettle();
      await show(tester, 'Copiar convite');
      await tester.tap(find.text('Copiar convite'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Convite copiado. Envie somente à pessoa que você quer convidar.',
        ),
        findsNothing,
      );
      await show(
        tester,
        'Não foi possível copiar. Selecione o código para copiá-lo.',
      );
      await close(tester);
    },
  );
}
