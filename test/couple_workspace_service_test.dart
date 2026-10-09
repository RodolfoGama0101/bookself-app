import 'dart:async';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake database;
  late CoupleWorkspaceService service;
  final selection = CoupleSelection(
    type: MediaType.movie,
    title: 'Filme fictício',
  );
  const path = 'couple_relationships/relation/experiences/experience';
  CoupleRecord record() =>
      CoupleRecord('experience', database.documents[path]!);
  setUp(() {
    database = ProfileFirestoreFake();
    database.documents.addAll({
      'a': {'partnerUid': 'b', 'relationshipId': 'relation'},
      'b': {'partnerUid': 'a', 'relationshipId': 'relation'},
      'partner_invites/relation': {
        'status': 'accepted',
        'senderUid': 'a',
        'recipientUid': 'b',
      },
    });
    service = CoupleWorkspaceService(firestore: database);
  });
  tearDown(() => database.close());
  test(
    'confirma somente após commit; retry conserva ID e não redefine a proposta',
    () async {
      database.commitGate = Completer<void>();
      var confirmed = false;
      final pending = service
          .propose('a', 'relation', 'experience', selection, DateTime(2020))
          .then((_) => confirmed = true);
      await Future<void>.delayed(Duration.zero);
      expect(confirmed, isFalse);
      expect(database.documents[path], isNull);
      database.commitGate!.complete();
      await pending;
      expect(confirmed, isTrue);
      expect(record().confirmed, isFalse);
      await service.respond('b', 'relation', record(), 'confirmed');
      expect(record().confirmed, isTrue);
      await service.propose(
        'a',
        'relation',
        'experience',
        selection,
        DateTime(2021),
      );
      expect(record().occurredOn, '2020-01-01');
      expect(record().confirmed, isTrue);
      expect(
        database.documents.keys
            .where((p) => p.startsWith('$path/history/'))
            .length,
        2,
      );
      expect(database.documents['users/b/couple_history/relation'], isNotNull);
      expect(database.readPaths, isNot(contains('b')));
    },
  );
  test(
    'correção exige nova resposta e conflito não sobrescreve nem perde erro no web',
    () async {
      await service.propose(
        'a',
        'relation',
        'experience',
        selection,
        DateTime(2020),
      );
      await service.respond('b', 'relation', record(), 'confirmed');
      final old = record();
      await service.propose(
        'a',
        'relation',
        'experience',
        selection,
        DateTime(2021),
        previous: old,
      );
      expect(record().confirmed, isFalse);
      expect(record().revision, 2);
      database.wrapTransactionErrors = true;
      await expectLater(
        service.respond('b', 'relation', old, 'confirmed'),
        throwsA(isA<CoupleConflict>()),
      );
      expect(record().version, 3);
      database.wrapTransactionErrors = false;
      await expectLater(
        service.propose(
          'b',
          'relation',
          'experience',
          selection,
          DateTime(2022),
          previous: record(),
        ),
        throwsStateError,
      );
      await service.respond('b', 'relation', record(), 'confirmed');
      expect(record().confirmed, isTrue);
      await service.respond('a', 'relation', record(), 'withdrawn');
      expect(record().confirmed, isFalse);
    },
  );
  test(
    'término nega edições, aceita retirada própria e não consulta registros pessoais',
    () async {
      await service.propose(
        'a',
        'relation',
        'experience',
        selection,
        DateTime(2020),
      );
      await service.respond('b', 'relation', record(), 'confirmed');
      database.documents['a'] = {'partnerUid': null, 'relationshipId': null};
      database.documents['b'] = {'partnerUid': null, 'relationshipId': null};
      await expectLater(
        service.respond('b', 'relation', record(), 'confirmed'),
        throwsStateError,
      );
      await service.respond('b', 'relation', record(), 'withdrawn');
      expect(record().confirmed, isFalse);
      await expectLater(
        service.respond('c', 'relation', record(), 'withdrawn'),
        throwsStateError,
      );
      expect(
        database.readPaths.any(
          (p) => p.startsWith('books/') || p.startsWith('libraries/'),
        ),
        isFalse,
      );
    },
  );
  test(
    'listas preservam origem; remoção usa revisão e adições independentes',
    () async {
      await service.createList('a', 'relation', 'list', 'Próximos');
      await Future.wait([
        service.addItem('a', 'relation', 'list', 'one', selection),
        service.addItem('b', 'relation', 'list', 'two', selection),
      ]);
      const itemPath = 'couple_relationships/relation/lists/list/items/one';
      final old = CoupleRecord('one', database.documents[itemPath]!);
      await service.removeItem('b', 'relation', 'list', old);
      expect(database.documents[itemPath]!['authorId'], 'a');
      expect(database.documents[itemPath]!['removedBy'], 'b');
      await expectLater(
        service.removeItem('a', 'relation', 'list', old),
        throwsA(isA<CoupleConflict>()),
      );
      await service.addItem('a', 'relation', 'list', 'one', selection);
      expect(database.documents[itemPath]!['removed'], isTrue);
    },
  );
  test(
    'seleção mínima rejeita campos privados e datas futuras antes de escrita',
    () async {
      expect(
        () => CoupleSelection.fromMap({...selection.toMap(), 'favorite': true}),
        throwsFormatException,
      );
      expect(
        () => CoupleSelection(type: MediaType.track, title: 'Faixa'),
        throwsFormatException,
      );
      expect(
        () => service.propose(
          'a',
          'relation',
          'experience',
          selection,
          DateTime.now().add(const Duration(days: 2)),
        ),
        throwsFormatException,
      );
      expect(database.writes, 0);
    },
  );
}
