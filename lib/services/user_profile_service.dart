import 'firebase_environment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user_model.dart';
import '../data/models/partner_profile.dart';

class UserProfileService {
  UserProfileService({this.firestore});

  final FirebaseFirestore? firestore;
  FirebaseFirestore get _database => firestore ?? FirebaseEnvironment.firestore;

  Future<void> updateName(String uid, String name) =>
      _updatePresentation(uid, {'name': name});

  Future<void> updatePhoto(String uid, String? photoUrl) =>
      _updatePresentation(uid, {'photoUrl': photoUrl});

  Future<void> _updatePresentation(String uid, Map<String, dynamic> patch) {
    final reference = _database.collection('users').doc(uid);
    return _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Perfil ausente');
      final current = UserModel.fromFirestore(snapshot);
      if (current.uid != uid) {
        throw const FormatException('Identidade de perfil inconsistente');
      }
      final sharedReference = _partnerReference(uid);
      final shared = await transaction.get(sharedReference);
      final sharedData = shared.data();
      final data = {...current.toMap(), ...patch};
      transaction.update(reference, patch);
      if (sharedData != null &&
          sharedData.length == 2 &&
          sharedData['name'] == current.name &&
          sharedData['photoUrl'] == current.photoUrl) {
        // Altera somente a intenção; uma edição concorrente do outro campo é preservada.
        transaction.update(sharedReference, patch);
      } else {
        transaction.set(sharedReference, {
          'name': data['name'],
          'photoUrl': data['photoUrl'],
        });
      }
    });
  }

  DocumentReference<Map<String, dynamic>> _partnerReference(String uid) =>
      _database.collection('partner_profiles').doc(uid);

  /// Nunca consulta users como alternativa para um perfil do parceiro ausente.
  Stream<PartnerProfile?> watchPartnerProfile(String uid) =>
      _partnerReference(uid)
          .snapshots(includeMetadataChanges: true)
          .where(
            (snapshot) =>
                !snapshot.metadata.hasPendingWrites &&
                (snapshot.exists || !snapshot.metadata.isFromCache),
          )
          .map(
            (snapshot) =>
                snapshot.exists ? PartnerProfile.fromFirestore(snapshot) : null,
          );

  /// Publica somente a apresentação do próprio dono, usando dados atuais.
  /// A leitura transacional impede que um retorno antigo reverta nome/foto.
  Future<void> ensurePartnerProfile(String uid) => _database.runTransaction((
    transaction,
  ) async {
    final own = await transaction.get(_database.collection('users').doc(uid));
    if (!own.exists) throw StateError('Perfil ausente');
    final current = UserModel.fromFirestore(own);
    if (current.uid != uid) {
      throw const FormatException('Identidade de perfil inconsistente');
    }
    final reference = _partnerReference(uid);
    final shared = await transaction.get(reference);
    final data = _presentation(current);
    final existing = shared.data();
    if (existing == null ||
        existing.length != data.length ||
        existing['name'] != data['name'] ||
        existing['photoUrl'] != data['photoUrl']) {
      transaction.set(reference, data);
    }
  });

  Map<String, dynamic> _presentation(UserModel profile) => PartnerProfile(
    uid: profile.uid,
    name: profile.name,
    photoUrl: profile.photoUrl,
  ).toMap();

  Stream<UserModel?> watchProfile(String uid) {
    return _database
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        // Ausência apenas no cache não comprova que o perfil precisa ser criado.
        .where(
          (snapshot) =>
              !snapshot.metadata.hasPendingWrites &&
              (snapshot.exists || !snapshot.metadata.isFromCache),
        )
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final profile = UserModel.fromFirestore(snapshot);
          if (profile.uid != uid) {
            throw const FormatException('Identidade de perfil inconsistente');
          }
          return profile;
        });
  }

  /// A transação preserva integralmente um perfil criado antes ou em paralelo.
  Future<UserModel> createIfMissing(UserModel profile) {
    final reference = _database.collection('users').doc(profile.uid);
    return _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        final existing = UserModel.fromFirestore(snapshot);
        if (existing.uid != profile.uid) {
          throw const FormatException('Identidade de perfil inconsistente');
        }
        transaction.set(
          _partnerReference(profile.uid),
          _presentation(existing),
        );
        return existing;
      }
      transaction.set(reference, profile.toMap());
      transaction.set(_partnerReference(profile.uid), _presentation(profile));
      return profile;
    });
  }
}
