import 'package:bookself_app/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_firestore_fake.dart';

void main() {
  UserModel user() => UserModel(
    uid: 'owner',
    name: 'Nome original',
    email: 'teste@example.com',
    partnerUid: 'partner',
    photoUrl: 'foto-original',
    createdAt: DateTime(2020),
  );

  test('editar nome preserva vínculo, foto e identidade', () {
    final original = user();
    final updated = original.copyWith(name: 'Nome corrigido');
    expect(updated.name, 'Nome corrigido');
    expect(updated.partnerUid, 'partner');
    expect(updated.photoUrl, 'foto-original');
    expect(updated.uid, original.uid);
    expect(updated.email, original.email);
    expect(updated.createdAt, original.createdAt);
    expect(original.name, 'Nome original');
  });

  test('limpar vínculo preserva foto e persiste null explícito', () {
    final original = user();
    final updated = original.copyWith(partnerUid: null);
    expect(updated.partnerUid, isNull);
    expect(updated.photoUrl, original.photoUrl);
    expect(updated.toMap(), containsPair('partnerUid', null));
    expect(original.partnerUid, 'partner');
    final restored = UserModel.fromFirestore(
      ProfileSnapshot(updated.uid, updated.toMap()),
    );
    expect(restored.partnerUid, isNull);
    expect(restored.photoUrl, original.photoUrl);
  });

  test('limpar foto preserva vínculo e persiste null explícito', () {
    final original = user();
    final updated = original.copyWith(photoUrl: null);
    expect(updated.photoUrl, isNull);
    expect(updated.partnerUid, original.partnerUid);
    expect(updated.toMap(), containsPair('photoUrl', null));
    expect(original.photoUrl, 'foto-original');
  });

  test('campos opcionais podem ser limpos juntos e preenchidos novamente', () {
    final cleared = user().copyWith(partnerUid: null, photoUrl: null);
    expect(cleared.partnerUid, isNull);
    expect(cleared.photoUrl, isNull);
    final updated = cleared.copyWith(
      partnerUid: 'new-partner',
      photoUrl: 'nova-foto',
    );
    expect(updated.partnerUid, 'new-partner');
    expect(updated.photoUrl, 'nova-foto');
    expect(updated.uid, cleared.uid);
    expect(updated.createdAt, cleared.createdAt);
  });

  test('perfil legado sem campos opcionais permanece compatível', () {
    final legacy = user().toMap()
      ..remove('partnerUid')
      ..remove('photoUrl');
    final restored = UserModel.fromFirestore(ProfileSnapshot('owner', legacy));
    final updated = restored.copyWith(name: 'Nome corrigido');
    expect(updated.partnerUid, isNull);
    expect(updated.photoUrl, isNull);
    expect(updated.createdAt, DateTime(2020));
  });

  test('campos opcionais rejeitam valores de tipo incompatível', () {
    expect(() => user().copyWith(partnerUid: 123), throwsA(isA<TypeError>()));
    expect(
      () => user().copyWith(photoUrl: DateTime(2020)),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => user().copyWith(partnerUid: const Object()),
      throwsA(isA<TypeError>()),
    );
  });
}
