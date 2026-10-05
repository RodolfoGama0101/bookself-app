import 'dart:async';
import 'package:bookself_app/data/models/partner_invitation.dart';
import 'package:bookself_app/services/partner_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/profile_firestore_fake.dart';

const code = '11111111111111111111111111111111';
const outgoingCode = '22222222222222222222222222222222';
Map<String, dynamic> invitation({
  String sender = 'sender',
  String? recipient = 'receiver',
  String status = 'pending',
  DateTime? createdAt,
}) => {
  'version': 1,
  'senderUid': sender,
  'senderEpoch': 0,
  'senderName': 'Pessoa remetente',
  'senderPhotoUrl': null,
  'recipientUid': recipient,
  'recipientEpoch': recipient == null ? null : 0,
  'recipientName': recipient == null ? null : 'Pessoa destinatária',
  'recipientPhotoUrl': null,
  'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
  'status': status,
  'decidedAt': null,
};
void main() {
  late ProfileFirestoreFake database;
  late PartnerService service;
  setUp(() {
    database = ProfileFirestoreFake();
    service = PartnerService(firestore: database);
    for (final uid in ['sender', 'receiver']) {
      database.documents[uid] = {
        'uid': uid,
        'name': 'Pessoa',
        'email': 'private@example.com',
        'partnerUid': null,
        'legacy': 'preservado',
      };
    }
    database.documents['partner_invites/$code'] = invitation();
  });
  tearDown(() => database.close());

  test(
    'código é aleatório, opaco e expiração exclui exatamente o limite de sete dias',
    () {
      final codes = List.generate(100, (_) => PartnerService.newCode());
      expect(codes.toSet(), hasLength(100));
      expect(codes.every(PartnerInvitation.validCode), isTrue);
      final model = PartnerInvitation.fromFirestore(
        ProfileSnapshot(code, invitation(createdAt: DateTime.utc(2026, 10, 1))),
      );
      expect(model.isPendingAt(DateTime.utc(2026, 10, 7, 23, 59, 59)), isTrue);
      expect(model.isPendingAt(DateTime.utc(2026, 10, 8)), isFalse);
      expect(PartnerInvitation.validCode('receiver'), isFalse);
      expect(
        () => PartnerInvitation.fromFirestore(
          ProfileSnapshot(code, {
            ...invitation(),
            'email': 'private@example.com',
          }),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'erro de domínio preserva mensagem quando o SDK web reempacota o callback',
    () async {
      database.wrapTransactionErrors = true;
      database.documents['partner_invites/$code'] = invitation(
        status: 'accepted',
      );
      await expectLater(
        service.claim('receiver', code),
        throwsA(
          isA<PartnerInvitationException>().having(
            (error) => error.message,
            'mensagem',
            contains('encerrado'),
          ),
        ),
      );
      expect(database.documents['receiver']!['partnerUid'], isNull);
    },
  );
  test('código inválido nunca consulta o SDK', () async {
    await expectLater(
      service.claim('receiver', 'sender'),
      throwsA(isA<PartnerInvitationException>()),
    );
    await expectLater(
      service.accept('receiver', ''),
      throwsA(isA<PartnerInvitationException>()),
    );
    expect(database.reads, 0);
    expect(database.writes, 0);
  });
  test(
    'criação aguarda confirmação, preserva perfil e reaproveita somente convite ativo',
    () async {
      database.commitGate = Completer<void>();
      var complete = false;
      final pending = service.create('sender').then((value) {
        complete = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(complete, isFalse);
      expect(database.writes, 0);
      database.commitGate!.complete();
      final generated = await pending;
      database.commitGate = null;
      expect(await service.create('sender'), generated);
      expect(database.documents['sender']!['partnerUid'], isNull);
      final data = database.documents['partner_invites/$generated']!;
      expect(data.containsKey('email'), isFalse);
      expect(data['senderUid'], 'sender');
      expect(database.writes, 2);
    },
  );
  test(
    'consulta reserva nome/foto sem ativar vínculo nem ler perfil alheio',
    () async {
      database.documents['partner_invites/$code'] = invitation(recipient: null);
      await service.claim('receiver', code);
      expect(
        database.documents['partner_invites/$code']!['recipientUid'],
        'receiver',
      );
      expect(
        database.documents['partner_invites/$code']!.containsKey('email'),
        isFalse,
      );
      expect(database.documents['receiver']!['partnerUid'], isNull);
      expect(database.readPaths, isNot(contains('users/sender')));
      await expectLater(
        service.claim('receiver', code),
        throwsA(isA<PartnerInvitationException>()),
      );
    },
  );
  test(
    'aceite guarda par e versão, cancela convite enviado e preserva dados legados',
    () async {
      database.documents['partner_invite_slots/receiver'] = {
        'code': outgoingCode,
        'issuedAt': Timestamp.now(),
      };
      database.documents['partner_invites/$outgoingCode'] = invitation(
        sender: 'receiver',
        recipient: null,
      );
      await service.accept('receiver', code);
      expect(database.documents['receiver']!['partnerUid'], 'sender');
      expect(database.documents['sender']!['partnerUid'], 'receiver');
      expect(database.documents['receiver']!['relationshipId'], code);
      expect(database.documents['sender']!['coupleEpoch'], 1);
      expect(database.documents['receiver']!['legacy'], 'preservado');
      expect(database.documents['receiver']!['email'], 'private@example.com');
      expect(
        database.documents['partner_invites/$code']!['status'],
        'accepted',
      );
      expect(
        database.documents['partner_invites/$outgoingCode']!['status'],
        'cancelled',
      );
      expect(database.readPaths, isNot(contains('users/sender')));
    },
  );
  for (final cancel in [true, false]) {
    test(
      '${cancel ? 'cancelar' : 'recusar'} não altera registros pessoais e é terminal',
      () async {
        await service.finish(
          cancel ? 'sender' : 'receiver',
          code,
          cancel: cancel,
        );
        expect(
          database.documents['partner_invites/$code']!['status'],
          cancel ? 'cancelled' : 'declined',
        );
        expect(database.documents['sender']!['partnerUid'], isNull);
        expect(database.documents['receiver']!['partnerUid'], isNull);
        final writes = database.writes;
        await expectLater(
          service.accept('receiver', code),
          throwsA(isA<PartnerInvitationException>()),
        );
        expect(database.writes, writes);
      },
    );
  }
  test(
    'expirado, destinatário errado e versão antiga não iniciam escrita de vínculo',
    () async {
      database.documents['partner_invites/$code'] = invitation(
        createdAt: DateTime(2020),
      );
      await expectLater(
        service.accept('receiver', code),
        throwsA(isA<PartnerInvitationException>()),
      );
      database.documents['partner_invites/$code'] = invitation(
        recipient: 'other',
      );
      await expectLater(
        service.accept('receiver', code),
        throwsA(isA<PartnerInvitationException>()),
      );
      database.documents['partner_invites/$code'] = invitation();
      database.documents['receiver']!['coupleEpoch'] = 1;
      await expectLater(
        service.accept('receiver', code),
        throwsA(isA<PartnerInvitationException>()),
      );
      expect(database.writes, 0);
    },
  );
  test(
    'desvínculo antigo do mesmo casal não encerra outra relação e legado continua suportado',
    () async {
      database.documents['receiver']!['partnerUid'] = 'sender';
      database.documents['sender']!['partnerUid'] = 'receiver';
      database.documents['receiver']!['relationshipId'] = outgoingCode;
      await expectLater(
        service.unlink('receiver', 'sender', relationshipId: code),
        throwsA(isA<PartnerInvitationException>()),
      );
      expect(database.writes, 0);
      database.documents['receiver']!.remove('relationshipId');
      await service.unlink('receiver', 'sender');
      expect(database.documents['receiver']!['partnerUid'], isNull);
      expect(database.documents['sender']!['partnerUid'], isNull);
      expect(database.documents['receiver']!['legacy'], 'preservado');
    },
  );
  test(
    'assinatura troca convite, ignora cache/escrita pendente e cancela as duas fontes',
    () async {
      final values = <PartnerInvitation?>[];
      final subscription = service
          .watchOwnInvitation('sender')
          .listen(values.add);
      database
          .controller('partner_invite_slots/sender')
          .add(ProfileSnapshot('sender', {'code': code}));
      await Future<void>.delayed(Duration.zero);
      final first = database.controller('partner_invites/$code');
      first.add(ProfileSnapshot(code, invitation(), fromCache: true));
      first.add(ProfileSnapshot(code, invitation(), pendingWrites: true));
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      first.add(ProfileSnapshot(code, invitation()));
      await Future<void>.delayed(Duration.zero);
      expect(values.single!.code, code);
      database
          .controller('partner_invite_slots/sender')
          .add(ProfileSnapshot('sender', {'code': outgoingCode}));
      await Future<void>.delayed(Duration.zero);
      expect(first.hasListener, isFalse);
      await subscription.cancel();
      expect(
        database.controller('partner_invite_slots/sender').hasListener,
        isFalse,
      );
      expect(
        database.controller('partner_invites/$outgoingCode').hasListener,
        isFalse,
      );
    },
  );
}
