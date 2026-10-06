import 'dart:async';

import 'package:bookself_app/data/models/partner_profile.dart';
import 'package:bookself_app/services/user_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  test(
    'publicação de legado preserva campos privados e limpa projeção contaminada',
    () async {
      final own = {
        ...profile('owner', partnerUid: 'partner').toMap(),
        'legacy': true,
      };
      database.documents['owner'] = Map.of(own);
      database.documents['partner_profiles/owner'] = {...own};
      await service.ensurePartnerProfile('owner');
      expect(database.documents['owner'], own);
      expect(database.documents['partner_profiles/owner'], {
        'name': 'Nome preservado',
        'photoUrl': 'foto-preservada',
      });
      expect(database.writes, 1);
      await service.ensurePartnerProfile('owner');
      expect(database.writes, 1);
    },
  );

  test(
    'publicação repetida após conflito usa nome/foto atuais sem reverter edição',
    () async {
      database.documents['owner'] = profile('owner').toMap();
      database.concurrentProfile = profile(
        'owner',
        name: 'Nome mais recente',
      ).copyWith(photoUrl: null).toMap();
      await service.ensurePartnerProfile('owner');
      expect(database.documents['partner_profiles/owner'], {
        'name': 'Nome mais recente',
        'photoUrl': null,
      });
    },
  );

  test(
    'editar nome e limpar foto conserva autoria, vínculo e campos legados nos dois documentos',
    () async {
      final own = {
        ...profile('owner', partnerUid: 'partner').toMap(),
        'legacy': true,
      };
      database.documents['owner'] = Map.of(own);
      await service.updateName('owner', 'Novo nome');
      await service.updatePhoto('owner', null);
      expect(database.documents['owner'], {
        ...own,
        'name': 'Novo nome',
        'photoUrl': null,
      });
      expect(database.documents['partner_profiles/owner'], {
        'name': 'Novo nome',
        'photoUrl': null,
      });
    },
  );

  for (final reject in [false, true]) {
    test(
      'edição aguarda confirmação atômica${reject ? ' e rejeição não deixa dados parciais' : ''}',
      () async {
        final own = profile('owner').toMap();
        database.documents['owner'] = Map.of(own);
        database.commitGate = Completer<void>();
        var completed = false;
        final update = service
            .updateName('owner', 'Novo nome')
            .then((_) => completed = true);
        final rejected = reject ? expectLater(update, throwsStateError) : null;
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect(database.documents['owner'], own);
        expect(database.documents['partner_profiles/owner'], isNull);
        if (reject) {
          database.commitGate!.completeError(StateError('fixture'));
          await rejected;
          expect(database.documents['owner'], own);
          expect(database.documents['partner_profiles/owner'], isNull);
        } else {
          database.commitGate!.complete();
          await update;
          expect(database.documents['owner']!['name'], 'Novo nome');
          expect(
            database.documents['partner_profiles/owner']!['name'],
            'Novo nome',
          );
        }
      },
    );
  }

  test(
    'perfil próprio ausente/inconsistente não é recriado nem publicado',
    () async {
      await expectLater(
        service.ensurePartnerProfile('owner'),
        throwsStateError,
      );
      await expectLater(service.updateName('owner', 'Nome'), throwsStateError);
      database.documents['owner'] = profile('other').toMap();
      await expectLater(
        service.ensurePartnerProfile('owner'),
        throwsFormatException,
      );
      await expectLater(
        service.updatePhoto('owner', null),
        throwsFormatException,
      );
      expect(database.writes, 0);
    },
  );

  test(
    'consulta do parceiro usa só perfil mínimo; cache, falha e ausência não abrem users',
    () async {
      final events = <PartnerProfile?>[];
      final errors = <Object>[];
      final subscription = service
          .watchPartnerProfile('partner')
          .listen(events.add, onError: errors.add);
      final stream = database.controller('partner_profiles/partner');
      stream.add(ProfileSnapshot('partner', null, fromCache: true));
      stream.add(
        ProfileSnapshot('partner', {'name': 'Companhia'}, pendingWrites: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      stream.add(
        ProfileSnapshot('partner', {'name': 'Companhia', 'photoUrl': null}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.single?.name, 'Companhia');
      stream.add(
        ProfileSnapshot('partner', {'name': 'Companhia'}, fromCache: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isNull);
      stream.add(
        ProfileSnapshot('partner', {
          'name': 'Companhia',
          'email': 'fixture@example.com',
        }),
      );
      stream.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      stream.add(ProfileSnapshot('partner', null));
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isA<FormatException>(), isA<FirebaseException>()]);
      expect(events.last, isNull);
      expect(database.streams.containsKey('partner'), isFalse);
      expect(database.reads, 0);
      await subscription.cancel();
      expect(stream.hasListener, isFalse);
    },
  );
}
