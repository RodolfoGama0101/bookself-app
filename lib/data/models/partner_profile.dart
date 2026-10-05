import 'package:cloud_firestore/cloud_firestore.dart';

/// Apresentação mínima; não contém e-mail ou estado privado da conta.
class PartnerProfile {
  const PartnerProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.isAvailable = true,
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final bool isAvailable;

  factory PartnerProfile.unavailable(String uid) =>
      PartnerProfile(uid: uid, name: 'Seu parceiro', isAvailable: false);

  factory PartnerProfile.fromFirestore(DocumentSnapshot snapshot) {
    final data = snapshot.data();
    if (data is! Map<String, dynamic> ||
        data.keys.any((key) => key != 'name' && key != 'photoUrl') ||
        data['name'] is! String ||
        (data['name'] as String).isEmpty ||
        (data['name'] as String).length > 200 ||
        (data['photoUrl'] != null && data['photoUrl'] is! String)) {
      throw const FormatException('Perfil consultável inválido');
    }
    return PartnerProfile(
      uid: snapshot.id,
      name: data['name'] as String,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'photoUrl': photoUrl};
}
