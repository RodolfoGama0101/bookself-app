import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user_model.dart';

class UserProfileService {
  UserProfileService({this.firestore});

  final FirebaseFirestore? firestore;
  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

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
        return existing;
      }
      transaction.set(reference, profile.toMap());
      return profile;
    });
  }
}
