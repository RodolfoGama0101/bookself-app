import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_firestore_fake.dart';

void main() {
  test('perfil mínimo admite ausência de foto sem copiar dados privados', () {
    final profile = PartnerProfile.fromFirestore(
      ProfileSnapshot('partner', {'name': 'Companhia'}),
    );
    expect(profile.uid, 'partner');
    expect(profile.toMap(), {'name': 'Companhia', 'photoUrl': null});
    expect(profile.isAvailable, isTrue);
  });

  test('campos privados e formato inválido são rejeitados integralmente', () {
    for (final data in <Map<String, dynamic>>[
      {'name': 'Companhia', 'email': 'fixture@example.com'},
      {'name': 'Companhia', 'partnerUid': 'owner'},
      {'name': 'Companhia', 'uid': 'other'},
      {'name': ''},
      {'name': 'x' * 201},
      {'name': 1},
      {'name': 'Companhia', 'photoUrl': 2},
    ]) {
      expect(
        () => PartnerProfile.fromFirestore(ProfileSnapshot('partner', data)),
        throwsFormatException,
      );
    }
  });
}
