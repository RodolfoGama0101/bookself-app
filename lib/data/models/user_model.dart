import 'package:cloud_firestore/cloud_firestore.dart';

enum _CopyWithValue { unchanged }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? partnerUid;
  final String? photoUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.partnerUid,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      partnerUid: data['partnerUid'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'partnerUid': partnerUid,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// [partnerUid]/[photoUrl] aceitam String ou null: omitido preserva, null limpa.
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    Object? partnerUid = _CopyWithValue.unchanged,
    Object? photoUrl = _CopyWithValue.unchanged,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      partnerUid: identical(partnerUid, _CopyWithValue.unchanged)
          ? this.partnerUid
          : partnerUid as String?,
      photoUrl: identical(photoUrl, _CopyWithValue.unchanged)
          ? this.photoUrl
          : photoUrl as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
