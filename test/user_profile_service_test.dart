import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake database;
  late UserProfileService service;

  setUp(() {
    database = ProfileFirestoreFake();
    service = UserProfileService(firestore: database);
  });
  tearDown(() => database.close());

  testWidgets('ausência no cache e escritas pendentes não confirmam perfil', (
    tester,
  ) async {
    final events = <UserModel?>[];
    final subscription = service.watchProfile('user').listen(events.add);
    addTearDown(subscription.cancel);
    database
        .controller('user')
        .add(ProfileSnapshot('user', null, fromCache: true));
    database
        .controller('user')
        .add(
          ProfileSnapshot('user', profile('user').toMap(), pendingWrites: true),
        );
    await tester.pump();
    expect(events, isEmpty);
    expect(database.includeMetadataChanges, isTrue);

    database.controller('user').add(ProfileSnapshot('user', null));
    await tester.pump();
    expect(events, [null]);

    database
        .controller('user')
        .add(ProfileSnapshot('user', profile('user').toMap(), fromCache: true));
    await tester.pump();
    expect(events.last?.name, 'Nome preservado');
  });

  test('recuperação cria documento ausente com os campos atuais', () async {
    final candidate = profile('user');
    final result = await service.createIfMissing(candidate);
    expect(result, same(candidate));
    expect(database.documents['user'], candidate.toMap());
    expect(database.writes, 2);
    expect(database.documents['partner_profiles/user'], {
      'name': candidate.name,
      'photoUrl': candidate.photoUrl,
    });
  });

  test(
    'recuperação preserva todos os campos existentes, inclusive desconhecidos',
    () async {
      final existing = profile('user', partnerUid: 'partner').toMap();
      existing['legacyField'] = 'preservar';
      database.documents['user'] = Map.of(existing);
      final result = await service.createIfMissing(
        profile('user', name: 'Outro nome'),
      );
      expect(result.name, 'Nome preservado');
      expect(result.partnerUid, 'partner');
      expect(result.photoUrl, 'foto-preservada');
      expect(result.createdAt, DateTime(2020));
      expect(database.documents['user'], existing);
      expect(database.writes, 1);
      expect(database.documents['partner_profiles/user'], {
        'name': 'Nome preservado',
        'photoUrl': 'foto-preservada',
      });
    },
  );

  test(
    'callback repetido após conflito preserva perfil criado em paralelo',
    () async {
      final existing = profile('user', partnerUid: 'partner').toMap();
      existing['legacyField'] = 'preservar';
      database.concurrentProfile = existing;
      final result = await service.createIfMissing(
        profile('user', name: 'Outro nome'),
      );
      expect(result.name, 'Nome preservado');
      expect(database.documents['user'], existing);
      expect(database.reads, 2);
      expect(database.writes, 1);
    },
  );

  testWidgets('perfil inconsistente vira erro de leitura e não é sobrescrito', (
    tester,
  ) async {
    final errors = <Object>[];
    final subscription = service
        .watchProfile('user')
        .listen((_) {}, onError: errors.add);
    addTearDown(subscription.cancel);
    final inconsistent = profile('another').toMap();
    database.controller('user').add(ProfileSnapshot('user', inconsistent));
    await tester.pump();
    expect(errors.single, isA<FormatException>());
    database.documents['user'] = inconsistent;
    await expectLater(
      service.createIfMissing(profile('user')),
      throwsFormatException,
    );
    expect(database.documents['user'], inconsistent);
    expect(database.writes, 0);
  });
}
