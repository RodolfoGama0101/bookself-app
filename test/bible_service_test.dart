import 'dart:async';

import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bible_firestore_fake.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late BibleFirestoreFake database;
  late BibleService service;
  const id = 'owner_1_samuel';
  Map<String, dynamic> progress(List<int> chapters) => {
    'userId': 'owner',
    'bookName': '1 Samuel',
    'readChapters': chapters,
    'updatedAt': Timestamp.fromDate(DateTime(2020)),
  };
  setUp(() {
    database = BibleFirestoreFake();
    service = BibleService(firestore: database);
  });
  tearDown(() => database.close());

  for (final pending in [true, false]) {
    test(
      'reconciliação rejeita ${pending ? 'escrita pendente' : 'cache'}',
      () async {
        database.documents[id] = progress([1, 3]);
        database.serverPending = pending;
        database.serverFromCache = !pending;
        await expectLater(
          service.readBookProgressFromServer('owner', '1 Samuel'),
          throwsStateError,
        );
        expect(database.lastGetSource, Source.server);
      },
    );
  }

  testWidgets('reconciliação lê o servidor e ignora cache ao reassinar', (
    tester,
  ) async {
    database.documents[id] = progress([1, 3]);
    final latest = await service.readBookProgressFromServer(
      'owner',
      '1 Samuel',
    );
    expect(database.lastGetSource, Source.server);
    expect(latest?.readChapters, [1, 3]);
    final events = <BibleProgressModel?>[];
    final subscription = service
        .streamBookProgressFromServer('owner', '1 Samuel')
        .listen(events.add);
    addTearDown(subscription.cancel);
    database.bookEvents.add(
      ProfileSnapshot(id, progress([2]), fromCache: true),
    );
    await tester.pump();
    expect(events, isEmpty);
    database.bookEvents.add(ProfileSnapshot(id, progress([1, 3])));
    await tester.pump();
    expect(events.single?.readChapters, [1, 3]);
  });

  test(
    'capítulo aguarda commit, cria documento próprio e confirma capítulos',
    () async {
      database.commitGate = Completer<void>();
      var completed = false;
      final pending = service.toggleChapter('owner', '1 Samuel', 2, true).then((
        value,
      ) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(database.documents, isEmpty);
      database.commitGate!.complete();
      expect(await pending, [2]);
      expect(database.documents[id]!['userId'], 'owner');
      expect(database.documents[id]!['bookName'], '1 Samuel');
      expect(database.documents[id]!['updatedAt'], isA<Timestamp>());
    },
  );

  test(
    'marcar/desmarcar repetidamente preserva outros capítulos e proprietários',
    () async {
      database.documents[id] = progress([3, 1]);
      database.documents['partner_1_samuel'] = {
        'userId': 'partner',
        'readChapters': [4],
      };
      expect(await service.toggleChapter('owner', '1 Samuel', 2, true), [
        1,
        2,
        3,
      ]);
      expect(await service.toggleChapter('owner', '1 Samuel', 2, true), [
        1,
        2,
        3,
      ]);
      expect(await service.toggleChapter('owner', '1 Samuel', 2, false), [
        1,
        3,
      ]);
      expect(await service.toggleChapter('owner', '1 Samuel', 2, false), [
        1,
        3,
      ]);
      expect(database.documents['partner_1_samuel']!['readChapters'], [4]);
    },
  );

  test(
    'repetição da transação após conflito retorna também capítulos concorrentes',
    () async {
      database.documents[id] = progress([1]);
      database.concurrentProgress = progress([1, 3]);
      expect(await service.toggleChapter('owner', '1 Samuel', 2, true), [
        1,
        2,
        3,
      ]);
      expect(database.documents[id]!['readChapters'], [1, 2, 3]);
      expect(database.commits, 1);
    },
  );

  for (final all in [false, true]) {
    test('lote ${all ? 'marca' : 'desmarca'} somente após commit', () async {
      database.documents[id] = progress([2]);
      database.commitGate = Completer<void>();
      var completed = false;
      final pending = service.markAllChapters('owner', '1 Samuel', 3, all).then(
        (value) {
          completed = true;
          return value;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(database.documents[id]!['readChapters'], [2]);
      database.commitGate!.complete();
      expect(await pending, all ? [1, 2, 3] : []);
      expect(database.documents[id]!['readChapters'], all ? [1, 2, 3] : []);
    });
    for (final code in ['permission-denied', 'unavailable']) {
      test(
        '${all ? 'lote' : 'capítulo'} propaga $code sem confirmar progresso',
        () async {
          final existing = progress([2]);
          database.documents[id] = existing;
          database.commitGate = Completer<void>();
          final pending = all
              ? service.markAllChapters('owner', '1 Samuel', 3, true)
              : service.toggleChapter('owner', '1 Samuel', 1, true);
          final rejection = FirebaseException(
            plugin: 'cloud_firestore',
            code: code,
          );
          final expectation = expectLater(pending, throwsA(same(rejection)));
          await Future<void>.delayed(Duration.zero);
          database.commitGate!.completeError(rejection);
          await expectation;
          expect(database.documents[id], existing);
          expect(database.commits, 0);
        },
      );
    }
  }

  testWidgets(
    'stream de livro ignora escrita local e recebe confirmação por metadata',
    (tester) async {
      final events = <BibleProgressModel?>[];
      final subscription = service
          .streamBookProgress('owner', '1 Samuel')
          .listen(events.add);
      addTearDown(subscription.cancel);
      database.bookEvents.add(ProfileSnapshot(id, progress([1])));
      await tester.pump();
      database.bookEvents.add(
        ProfileSnapshot(id, progress([1, 2]), pendingWrites: true),
      );
      await tester.pump();
      expect(events.map((event) => event?.readChapters), [
        [1],
      ]);
      database.bookEvents.add(ProfileSnapshot(id, progress([1, 2])));
      await tester.pump();
      expect(events.last?.readChapters, [1, 2]);
      expect(database.watchedId, id);
      expect(database.bookMetadata, isTrue);
    },
  );

  testWidgets(
    'resumo ignora escrita pendente e mantém consulta por proprietário',
    (tester) async {
      final events = <Map<String, BibleProgressModel>>[];
      final subscription = service
          .streamAllProgress('owner')
          .listen(events.add);
      addTearDown(subscription.cancel);
      database.allEvents.add(BibleQuerySnapshot(id, progress([1])));
      await tester.pump();
      database.allEvents.add(
        BibleQuerySnapshot(id, progress([1, 2]), pending: true),
      );
      await tester.pump();
      expect(events.last['1 Samuel']?.readChapters, [1]);
      database.allEvents.add(BibleQuerySnapshot(id, progress([1, 2])));
      await tester.pump();
      expect(events.last['1 Samuel']?.readChapters, [1, 2]);
      expect(database.queriedOwner, 'owner');
      expect(database.allMetadata, isTrue);
    },
  );

  testWidgets('escrita pendente em livro não bloqueia outro livro', (
    tester,
  ) async {
    final events = <Map<String, BibleProgressModel>>[];
    final subscription = service.streamAllProgress('owner').listen(events.add);
    addTearDown(subscription.cancel);
    Map<String, dynamic> second(List<int> chapters) => {
      ...progress(chapters),
      'bookName': 'Rute',
    };
    database.allEvents.add(
      BibleQuerySnapshot.multiple({
        id: progress([1]),
        'owner_rute': second([1]),
      }),
    );
    await tester.pump();
    database.allEvents.add(
      BibleQuerySnapshot.multiple({
        id: progress([1, 2]),
        'owner_rute': second([1, 2]),
      }, pendingId: id),
    );
    await tester.pump();
    expect(events.last['1 Samuel']?.readChapters, [1]);
    expect(events.last['Rute']?.readChapters, [1, 2]);
  });
}
