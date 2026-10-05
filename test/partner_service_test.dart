import 'dart:async';

import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/partner_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';

class ControlledPartners extends PartnerService {
  final calls = <(String, String, bool)>[];
  Completer<void> pending = Completer<void>();
  @override
  Future<void> accept(String uid, String partnerUid) {
    calls.add((uid, partnerUid, true));
    return pending.future;
  }

  @override
  Future<void> unlink(String uid, String partnerUid, {String? relationshipId}) {
    calls.add((uid, partnerUid, false));
    return pending.future;
  }
}

void main() {
  group('sessão durante operação do casal', () {
    late FakeFirebaseAuth auth;
    late FakeUserProfiles profiles;
    late ControlledPartners partners;
    late AuthService service;
    bool disposed = false;
    setUp(() {
      auth = FakeFirebaseAuth();
      profiles = FakeUserProfiles();
      partners = ControlledPartners();
      service = AuthService(auth: auth, profiles: profiles, partners: partners);
      disposed = false;
    });
    tearDown(() async {
      if (!disposed) service.dispose();
      await auth.changes.close();
      await profiles.close();
    });
    Future<void> ready(
      WidgetTester tester,
      String uid, {
      String? partnerUid,
    }) async {
      if (partners.calls.isEmpty) partners.pending = Completer<void>();
      auth.emit(FakeUser(uid));
      await tester.pump();
      profiles.controller(uid).add(profile(uid, partnerUid: partnerUid));
      await tester.pump();
    }

    testWidgets(
      'confirma vínculo apenas após escrita e bloqueia submissões concorrentes',
      (tester) async {
        await ready(tester, 'owner');
        final write = service.acceptInvitation(' partner ');
        expect(service.isLoading, isTrue);
        expect(await service.acceptInvitation('other'), contains('Aguarde'));
        expect(partners.calls, [('owner', 'partner', true)]);
        partners.pending.complete();
        await tester.pump();
        expect(await write, isNull);
        expect(service.isLoading, isFalse);
        // O perfil é atualizado pelo stream, sem inventar confirmação de leitura.
        expect(service.currentUserModel!.partnerUid, isNull);
      },
    );

    testWidgets('conta já vinculada impede novo aceite sem escrever', (
      tester,
    ) async {
      await ready(tester, 'owner', partnerUid: 'partner');
      expect(await service.acceptInvitation('other'), contains('Desvincule'));
      expect(partners.calls, isEmpty);
    });

    testWidgets('ausência de sessão/perfil não inicia vínculo', (tester) async {
      expect(
        await service.acceptInvitation('partner'),
        contains('Entre novamente'),
      );
      auth.emit(FakeUser('owner'));
      await tester.pump();
      expect(
        await service.acceptInvitation('partner'),
        contains('Entre novamente'),
      );
      expect(partners.calls, isEmpty);
    });

    testWidgets(
      'desvínculo captura ambas as identidades e erro libera nova tentativa',
      (tester) async {
        await ready(tester, 'owner', partnerUid: 'partner');
        final write = service.unlinkPartner();
        partners.pending.completeError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        await tester.pump();
        expect(await write, contains('indisponível'));
        expect(service.isLoading, isFalse);
        expect(service.currentUserModel!.partnerUid, 'partner');
        partners.pending = Completer<void>();
        final retry = service.unlinkPartner();
        expect(partners.calls, [
          ('owner', 'partner', false),
          ('owner', 'partner', false),
        ]);
        partners.pending.complete();
        await tester.pump();
        expect(await retry, isNull);
      },
    );

    for (final change in ['logout', 'troca de conta', 'descarte']) {
      testWidgets(
        '$change durante vínculo não anuncia sucesso na sessão seguinte',
        (tester) async {
          await ready(tester, 'owner');
          final write = service.acceptInvitation('partner');
          if (change == 'descarte') {
            service.dispose();
            disposed = true;
          } else if (change == 'logout') {
            auth.emit(null);
            await tester.pump();
          } else {
            await ready(tester, 'other');
          }
          partners.pending.complete();
          await tester.pump();
          expect(await write, contains('sessão mudou'));
          expect(tester.takeException(), isNull);
          if (change != 'descarte') expect(service.isLoading, isFalse);
        },
      );
    }

    testWidgets('retorno da conta anterior não desbloqueia operação nova', (
      tester,
    ) async {
      await ready(tester, 'owner');
      final oldPending = partners.pending;
      final oldWrite = service.acceptInvitation('partner');
      await ready(tester, 'other');
      partners.pending = Completer<void>();
      final newWrite = service.acceptInvitation('new-partner');
      oldPending.complete();
      await tester.pump();
      expect(await oldWrite, contains('sessão mudou'));
      expect(service.isLoading, isTrue);
      partners.pending.complete();
      await tester.pump();
      expect(await newWrite, isNull);
      expect(service.isLoading, isFalse);
    });
  });
}
