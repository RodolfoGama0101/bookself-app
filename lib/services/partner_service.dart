import 'firebase_environment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// As regras validam os estados anteriores e a reciprocidade após o lote.
/// Não consulta o perfil privado do destinatário antes do vínculo.
class PartnerService {
  PartnerService({FirebaseFirestore? firestore}) : _database = firestore;

  final FirebaseFirestore? _database;
  FirebaseFirestore get _firestore =>
      _database ?? FirebaseEnvironment.firestore;

  Future<void> link(String uid, String partnerUid) =>
      _writePair(uid, partnerUid, linking: true);

  Future<void> unlink(String uid, String partnerUid) =>
      _writePair(uid, partnerUid, linking: false);

  Future<void> _writePair(
    String uid,
    String partnerUid, {
    required bool linking,
  }) async {
    if (uid.isEmpty || partnerUid.isEmpty || uid == partnerUid) {
      throw ArgumentError('Identidades de vínculo inválidas');
    }
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'partnerUid': linking ? partnerUid : null,
    });
    batch.update(_firestore.collection('users').doc(partnerUid), {
      'partnerUid': linking ? uid : null,
    });
    await batch.commit();
  }
}
