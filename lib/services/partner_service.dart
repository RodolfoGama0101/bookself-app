import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/partner_invitation.dart';
import 'firebase_environment.dart';

class PartnerService {
  PartnerService({FirebaseFirestore? firestore}) : _database = firestore;
  final FirebaseFirestore? _database;
  // FlutterFire web pode reempacotar a exceção Dart do callback como erro SDK.
  // Preserve apenas erros de domínio com mensagens fixas e sem dados pessoais.
  Future<T> _transaction<T>(Future<T> Function(Transaction) action) async {
    PartnerInvitationException? failure;
    try {
      return await _firestore.runTransaction((transaction) async {
        failure = null;
        try {
          return await action(transaction);
        } on PartnerInvitationException catch (error) {
          failure = error;
          rethrow;
        }
      });
    } catch (_) {
      if (failure != null) {
        throw failure!;
      }
      rethrow;
    }
  }

  FirebaseFirestore get _firestore =>
      _database ?? FirebaseEnvironment.firestore;
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _slot(String uid) =>
      _firestore.collection('partner_invite_slots').doc(uid);
  DocumentReference<Map<String, dynamic>> _invite(String code) =>
      _firestore.collection('partner_invites').doc(code);
  DocumentReference<Map<String, dynamic>> _contact(String uid, String other) =>
      _firestore
          .collection('partner_contacts')
          .doc(uid)
          .collection('targets')
          .doc(other);
  DocumentReference<Map<String, dynamic>> _block(String uid, String other) =>
      _firestore
          .collection('partner_blocks')
          .doc(uid)
          .collection('targets')
          .doc(other);

  void _rememberInvitation(
    Transaction tx,
    PartnerInvitation invitation,
    String recipient,
    String recipientName,
  ) {
    tx.set(_contact(recipient, invitation.senderUid), {
      'name': invitation.senderName,
      'invitationCode': invitation.code,
    });
    tx.set(_contact(invitation.senderUid, recipient), {
      'name': recipientName,
      'invitationCode': invitation.code,
    });
  }

  Future<void> _rememberRelationship(
    Transaction tx,
    String uid,
    String other,
    String ownName,
  ) async {
    // Término/bloqueio não dependem da disponibilidade do perfil alheio.
    final contact = (await tx.get(_contact(uid, other))).data();
    tx.set(_contact(uid, other), {
      'name': contact?['name'] ?? 'Pessoa conhecida',
      'invitationCode': null,
    });
    tx.set(_contact(other, uid), {'name': ownName, 'invitationCode': null});
  }

  static String newCode() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _validate(String code) {
    if (!PartnerInvitation.validCode(code)) {
      throw const PartnerInvitationException(
        'Informe um código de convite válido.',
      );
    }
  }

  void _pending(PartnerInvitation invitation) {
    if (!invitation.isPendingAt(DateTime.now())) {
      throw const PartnerInvitationException(
        'Este convite expirou ou já foi encerrado. Peça um novo convite.',
      );
    }
  }

  void _free(Map<String, dynamic>? user) {
    if (user == null || user['partnerUid'] != null) {
      throw const PartnerInvitationException(
        'Verifique seu perfil e encerre o vínculo atual antes de continuar.',
      );
    }
  }

  Future<String> create(String uid) async {
    final code = newCode();
    return _transaction((tx) async {
      final user = (await tx.get(_user(uid))).data();
      _free(user);
      final slot = (await tx.get(_slot(uid))).data();
      if (slot != null) {
        final old = PartnerInvitation.fromFirestore(
          await tx.get(_invite(slot['code'])),
        );
        if (old.isPendingAt(DateTime.now())) {
          return old.code;
        }
        if (DateTime.now().difference(
              (slot['issuedAt'] as Timestamp).toDate(),
            ) <
            const Duration(minutes: 1)) {
          throw const PartnerInvitationException(
            'Aguarde um minuto antes de criar outro convite.',
          );
        }
      }
      tx.set(_invite(code), {
        'version': 1,
        'senderUid': uid,
        'senderEpoch': user!['coupleEpoch'] ?? 0,
        'senderName': user['name'],
        'senderPhotoUrl': user['photoUrl'],
        'recipientUid': null,
        'recipientEpoch': null,
        'recipientName': null,
        'recipientPhotoUrl': null,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'decidedAt': null,
      });
      tx.set(_slot(uid), {
        'code': code,
        'issuedAt': FieldValue.serverTimestamp(),
      });
      return code;
    });
  }

  /// Reserva para esta conta e apresenta nome/foto ao remetente, sem acesso pessoal.
  Future<PartnerInvitation> claim(String uid, String code) async {
    _validate(code);
    final lookup = _firestore.collection('partner_invite_lookups').doc(uid);
    // O intervalo é validado também pelas regras, inclusive para códigos ausentes.
    await _transaction((tx) async {
      final previous = (await tx.get(lookup)).data();
      if (previous != null &&
          DateTime.now().difference(
                (previous['requestedAt'] as Timestamp).toDate(),
              ) <
              const Duration(seconds: 5)) {
        throw const PartnerInvitationException(
          'Aguarde alguns segundos antes de consultar outro código.',
        );
      }
      tx.set(lookup, {
        'code': code,
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
    return _transaction((tx) async {
      final user = (await tx.get(_user(uid))).data();
      _free(user);
      final invitation = PartnerInvitation.fromFirestore(
        await tx.get(_invite(code)),
      );
      _pending(invitation);
      if (invitation.senderUid == uid ||
          (invitation.recipientUid != null && invitation.recipientUid != uid)) {
        throw const PartnerInvitationException(
          'Este convite não está disponível para sua conta.',
        );
      }
      if (invitation.recipientUid == null) {
        tx.update(_invite(code), {
          'recipientUid': uid,
          'recipientEpoch': user!['coupleEpoch'] ?? 0,
          'recipientName': user['name'],
          'recipientPhotoUrl': user['photoUrl'],
        });
      }
      _rememberInvitation(
        tx,
        invitation,
        uid,
        invitation.recipientName ?? user!['name'] as String,
      );
      return invitation;
    });
  }

  Future<void> accept(String uid, String code) async {
    _validate(code);
    await _transaction((tx) async {
      final invitation = PartnerInvitation.fromFirestore(
        await tx.get(_invite(code)),
      );
      final user = (await tx.get(_user(uid))).data();
      final slot = (await tx.get(_slot(uid))).data();
      PartnerInvitation? outgoing;
      if (slot != null) {
        outgoing = PartnerInvitation.fromFirestore(
          await tx.get(_invite(slot['code'])),
        );
      }
      _free(user);
      _pending(invitation);
      if (invitation.recipientUid != uid) {
        throw const PartnerInvitationException(
          'Confira o convite antes de aceitar.',
        );
      }
      if (invitation.recipientEpoch != (user!['coupleEpoch'] ?? 0)) {
        throw const PartnerInvitationException(
          'Este convite não está mais disponível. Peça um novo convite.',
        );
      }
      tx.update(_invite(code), {
        'status': 'accepted',
        'decidedAt': FieldValue.serverTimestamp(),
      });
      tx.update(_user(uid), {
        'partnerUid': invitation.senderUid,
        'relationshipId': code,
        'coupleEpoch': invitation.recipientEpoch! + 1,
      });
      tx.update(_user(invitation.senderUid), {
        'partnerUid': uid,
        'relationshipId': code,
        'coupleEpoch': invitation.senderEpoch + 1,
      });
      if (outgoing != null && outgoing.status == 'pending') {
        tx.update(_invite(outgoing.code), {
          'status': 'cancelled',
          'decidedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> finish(String uid, String code, {required bool cancel}) async {
    _validate(code);
    await _transaction((tx) async {
      final invitation = PartnerInvitation.fromFirestore(
        await tx.get(_invite(code)),
      );
      if ((cancel ? invitation.senderUid : invitation.recipientUid) != uid ||
          invitation.status != 'pending') {
        throw const PartnerInvitationException(
          'Este convite já foi encerrado ou não está disponível.',
        );
      }
      tx.update(_invite(code), {
        'status': cancel ? 'cancelled' : 'declined',
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<PartnerInvitation?> watchInvitation(String code) {
    _validate(code);
    return _invite(code)
        .snapshots(includeMetadataChanges: true)
        .where(
          (doc) => !doc.metadata.hasPendingWrites && !doc.metadata.isFromCache,
        )
        .map((doc) => doc.exists ? PartnerInvitation.fromFirestore(doc) : null);
  }

  Stream<PartnerInvitation?> watchOwnInvitation(String uid) {
    late StreamController<PartnerInvitation?> controller;
    StreamSubscription? slotSubscription;
    StreamSubscription? invitationSubscription;
    var revision = 0;
    controller = StreamController<PartnerInvitation?>(
      onListen: () {
        slotSubscription = _slot(uid)
            .snapshots(includeMetadataChanges: true)
            .listen((doc) async {
              if (doc.metadata.hasPendingWrites || doc.metadata.isFromCache) {
                return;
              }
              final current = ++revision;
              await invitationSubscription?.cancel();
              if (controller.isClosed || current != revision) {
                return;
              }
              final code = doc.data()?['code'];
              if (code == null) {
                controller.add(null);
                return;
              }
              try {
                invitationSubscription = watchInvitation(
                  code,
                ).listen(controller.add, onError: controller.addError);
              } catch (error, stack) {
                controller.addError(error, stack);
              }
            }, onError: controller.addError);
      },
      onCancel: () async {
        revision++;
        await slotSubscription?.cancel();
        await invitationSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> unlink(
    String uid,
    String partnerUid, {
    String? relationshipId,
  }) async {
    if (uid.isEmpty || partnerUid.isEmpty || uid == partnerUid) {
      throw ArgumentError('Identidades inválidas');
    }
    await _transaction((tx) async {
      final user = (await tx.get(_user(uid))).data();
      if (user?['partnerUid'] != partnerUid ||
          user?['relationshipId'] != relationshipId) {
        throw const PartnerInvitationException(
          'O vínculo mudou. Confira seu perfil novamente.',
        );
      }
      await _rememberRelationship(tx, uid, partnerUid, user!['name'] as String);
      tx.update(_user(uid), {'partnerUid': null, 'relationshipId': null});
      tx.update(_user(partnerUid), {
        'partnerUid': null,
        'relationshipId': null,
      });
    });
  }

  Stream<Map<String, String>> watchBlocks(String uid) => _firestore
      .collection('partner_blocks')
      .doc(uid)
      .collection('targets')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: d.data()['name'] as String});

  Stream<Map<String, String>> watchContacts(String uid) => _firestore
      .collection('partner_contacts')
      .doc(uid)
      .collection('targets')
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        if (s.metadata.isFromCache || s.metadata.hasPendingWrites) {
          throw const PartnerInvitationException(
            'Não foi possível confirmar as pessoas conhecidas. Verifique sua conexão.',
          );
        }
        return {for (final d in s.docs) d.id: d.data()['name'] as String};
      });

  Future<void> blockContact(String uid, String other) async {
    if (uid.isEmpty ||
        other.isEmpty ||
        uid == other ||
        uid.contains('/') ||
        other.contains('/')) {
      throw ArgumentError('Identidades inválidas');
    }
    await _transaction((tx) async {
      final own = (await tx.get(_user(uid))).data();
      final contact = (await tx.get(_contact(uid, other))).data();
      final blocked = await tx.get(_block(uid, other));
      if (contact == null || own == null || own['partnerUid'] == other) {
        throw const PartnerInvitationException(
          'Confira a pessoa e o vínculo novamente antes de bloquear.',
        );
      }
      if (blocked.exists) return;
      tx.set(_block(uid, other), {
        'name': contact['name'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Invalida também convites ainda pendentes: desbloquear exige um novo código.
      tx.update(_user(uid), {
        'coupleEpoch': (own['coupleEpoch'] as int? ?? 0) + 1,
        'lastBlockedUid': other,
      });
    });
  }

  Future<void> unblock(String uid, String other) => _firestore
      .collection('partner_blocks')
      .doc(uid)
      .collection('targets')
      .doc(other)
      .delete();

  Future<void> block(
    String uid,
    String other,
    String name,
    String? relationshipId,
  ) async {
    await _transaction((tx) async {
      final own = (await tx.get(_user(uid))).data();
      if (own?['partnerUid'] != other ||
          own?['relationshipId'] != relationshipId) {
        throw const PartnerInvitationException(
          'O vínculo mudou. Confira seu perfil novamente.',
        );
      }
      await _rememberRelationship(tx, uid, other, own!['name'] as String);
      tx.set(
        _firestore
            .collection('partner_blocks')
            .doc(uid)
            .collection('targets')
            .doc(other),
        {'name': name, 'createdAt': FieldValue.serverTimestamp()},
      );
      tx.update(_user(uid), {
        'partnerUid': null,
        'relationshipId': null,
        'coupleEpoch': (own['coupleEpoch'] as int? ?? 0) + 1,
      });
      tx.update(_user(other), {'partnerUid': null, 'relationshipId': null});
    });
  }
}
