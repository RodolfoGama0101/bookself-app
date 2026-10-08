import 'dart:async';

import 'package:bookself_app/data/bible_data.dart';
import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/utils/error_handler.dart';
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

  test(
    'comparação não confirma escrita pendente nem perde recuperação do servidor',
    () async {
      final values = <Map<String, BibleProgressModel>>[];
      final errors = <Object>[];
      final subscription = service
          .streamSharedProgress('owner')
          .listen(values.add, onError: errors.add);
      database.allEvents.add(
        BibleQuerySnapshot(id, progress([1]), pending: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      expect(errors.single, isA<SharedDataUnconfirmed>());
      database.allEvents.add(BibleQuerySnapshot(id, progress([1, 2])));
      await Future<void>.delayed(Duration.zero);
      expect(values.single['1 Samuel']!.readChapters, [1, 2]);
      expect(database.allMetadata, isTrue);
      await subscription.cancel();
    },
  );

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
      final pending = service
          .markAllChapters('owner', '1 Samuel', 31, all)
          .then((value) {
            completed = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(database.documents[id]!['readChapters'], [2]);
      database.commitGate!.complete();
      final expected = all
          ? List<int>.generate(31, (index) => index + 1)
          : <int>[];
      expect(await pending, expected);
      expect(database.documents[id]!['readChapters'], expected);
    });
    for (final code in ['permission-denied', 'unavailable']) {
      test(
        '${all ? 'lote' : 'capítulo'} propaga $code sem confirmar progresso',
        () async {
          final existing = progress([2]);
          database.documents[id] = existing;
          database.commitGate = Completer<void>();
          final pending = all
              ? service.markAllChapters('owner', '1 Samuel', 31, true)
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

  test('primeiro e último capítulo são válidos nos 66 livros', () async {
    for (final book in BibleData.books) {
      expect(await service.toggleChapter('owner', book.name, 1, true), [1]);
      final expected = book.chapters == 1 ? [1] : [1, book.chapters];
      expect(
        await service.toggleChapter('owner', book.name, book.chapters, true),
        expected,
        reason: book.name,
      );
      expect(
        await service.toggleChapter('owner', book.name, book.chapters, true),
        expected,
        reason: 'Repetição em ${book.name}',
      );
    }
    expect(database.documents.keys.where((id) => !id.contains('/')).length, 66);
  });

  test('capítulos fora dos limites não escrevem em nenhum livro', () async {
    for (final book in BibleData.books) {
      for (final chapter in [-1, 0, book.chapters + 1]) {
        for (final isRead in [true, false]) {
          await expectLater(
            service.toggleChapter('owner', book.name, chapter, isRead),
            throwsRangeError,
            reason: '${book.name}: $chapter',
          );
        }
      }
    }
    expect(database.documents, isEmpty);
    expect(database.commits, 0);
  });

  test('lotes completos são idempotentes e isolados nos 66 livros', () async {
    for (final book in BibleData.books) {
      final docId = 'owner_${book.name.replaceAll(' ', '_').toLowerCase()}';
      final partnerId =
          'partner_${book.name.replaceAll(' ', '_').toLowerCase()}';
      final partnerProgress = {
        'userId': 'partner',
        'bookName': book.name,
        'readChapters': [1],
      };
      database.documents[partnerId] = partnerProgress;
      final all = List<int>.generate(book.chapters, (index) => index + 1);
      for (final isRead in [true, true, false, false]) {
        final commitsBefore = database.commits;
        final expected = isRead ? all : <int>[];
        expect(
          await service.markAllChapters(
            'owner',
            book.name,
            book.chapters,
            isRead,
          ),
          expected,
          reason: book.name,
        );
        expect(database.commits, commitsBefore + 1);
        expect(database.documents[docId]!['readChapters'], expected);
        expect(database.documents[docId]!['userId'], 'owner');
        expect(database.documents[partnerId], partnerProgress);
      }
    }
    expect(
      database.documents.keys.where((id) => !id.contains('/')).length,
      132,
    );
  });

  test(
    'lotes com totais divergentes são rejeitados antes da escrita',
    () async {
      for (final book in BibleData.books) {
        for (final total in [-1, 0, book.chapters - 1, book.chapters + 1]) {
          for (final isRead in [true, false]) {
            await expectLater(
              service.markAllChapters('owner', book.name, total, isRead),
              throwsArgumentError,
            );
          }
        }
      }
      expect(database.documents, isEmpty);
      expect(database.commits, 0);
    },
  );

  test('identidade ausente ou livro desconhecido não cria progresso', () async {
    final invalid = [
      ('', 'Gênesis'),
      ('   ', 'Gênesis'),
      ('owner/other', 'Gênesis'),
      ('owner', ''),
      ('owner', 'Desconhecido'),
      ('owner', 'genesis'),
    ];
    for (final (owner, book) in invalid) {
      await expectLater(
        service.toggleChapter(owner, book, 1, true),
        throwsArgumentError,
      );
      await expectLater(
        service.markAllChapters(owner, book, 1, true),
        throwsArgumentError,
      );
    }
    expect(database.documents, isEmpty);
    expect(database.commits, 0);
  });

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
      expect(events.length, 1);
      database.allEvents.add(BibleQuerySnapshot(id, progress([1, 2])));
      await tester.pump();
      expect(events.last['1 Samuel']?.readChapters, [1, 2]);
      expect(database.queriedOwner, 'owner');
      expect(database.allMetadata, isTrue);
    },
  );
}
