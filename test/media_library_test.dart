import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/media_library_repository.dart';

import 'support/profile_firestore_fake.dart';

CatalogItem book(
  String owner, {
  String id = 'catalog',
  String externalId = 'work',
  String provider = 'google_books',
}) => CatalogItem(
  id: id,
  ownerId: owner,
  identity: CatalogIdentity.external(MediaType.book, provider, externalId),
  metadata: MediaMetadata(MediaType.book, {
    'title': 'Obra fictícia',
    'authors': <String>[],
  }),
);

void main() {
  test('tupla reversível separa fornecedor, mídia, caixa e separadores', () {
    final identities = [
      CatalogIdentity.external(MediaType.book, 'google_books', 'a/b:c'),
      CatalogIdentity.external(MediaType.book, 'example_video', 'a/b:c'),
      CatalogIdentity.external(MediaType.movie, 'example_video', 'a/b:c'),
      CatalogIdentity.external(MediaType.book, 'google_books', 'A/b:c'),
      CatalogIdentity.manual(MediaType.book, 'a', 'b'),
      CatalogIdentity.manual(MediaType.book, 'b', 'a'),
    ];
    expect(identities.map((i) => i.key).toSet(), hasLength(6));
    expect(
      jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(identities.first.key)),
        ),
      ),
      [1, 'book', 'external', 'google_books', 'a/b:c'],
    );
    expect(
      CatalogIdentity.fromMap(MediaType.book, identities.first.toMap()).key,
      identities.first.key,
    );
  });

  test('rejeita namespace e chave longa sem truncamento', () {
    expect(
      () => CatalogIdentity.external(MediaType.book, 'Google Books', 'x'),
      throwsFormatException,
    );
    expect(
      () =>
          CatalogIdentity.external(MediaType.book, 'google_books', 'é' * 1000),
      throwsFormatException,
    );
    expect(
      () => CatalogIdentity.manual(MediaType.book, 'a/b', 'id'),
      throwsFormatException,
    );
  });

  test(
    'patch opcional omitido preserva e null limpa; autores vazios permanecem',
    () {
      final original = MediaMetadata(MediaType.book, {
        'title': 'Livro',
        'authors': [],
        'coverUrl': 'https://example.com/cover',
      });
      expect(
        original.patch({'title': 'Outro'}).toMap()['coverUrl'],
        'https://example.com/cover',
      );
      expect(original.patch({'coverUrl': null}).toMap()['coverUrl'], isNull);
      expect(original.toMap()['authors'], isEmpty);
      expect(() => original.patch({'authors': null}), throwsFormatException);
      expect(() => original.patch({'title': null}), throwsFormatException);
      expect(() => original.patch({'unexpected': true}), throwsFormatException);
    },
  );

  for (final type in MediaType.values) {
    test('roundtrip catálogo ${type.name} com opcionais ausentes', () {
      final metadata = MediaMetadata(type, {
        'title': 'Obra',
        if (type == MediaType.book) 'authors': [],
        if (type == MediaType.track || type == MediaType.album)
          'artists': ['Artista'],
      });
      final item = CatalogItem(
        id: 'c',
        ownerId: 'a',
        identity: CatalogIdentity.manual(type, 'a', 'manual'),
        metadata: metadata,
      );
      expect(CatalogItem.fromMap('c', item.toMap()).toMap(), item.toMap());
      expect(metadata.toMap()['coverUrl'], isNull);
    });
  }

  test('datas civis não normalizam datas inválidas nem perdem precisão', () {
    for (final date in ['2024', '2024-02', '2024-02-29']) {
      final metadata = MediaMetadata(MediaType.book, {
        'title': 'Livro',
        'authors': [],
        'publishedDate': date,
      });
      expect(metadata.toMap()['publishedDate'], date);
    }
    for (final date in [
      '2023-02-29',
      '2024-13-01',
      '2024-04-31',
      '0000-01-01',
      '2024-01-01T00:00:00Z',
    ]) {
      expect(
        () => MediaState(MediaType.book, 'completed', date: date),
        throwsFormatException,
      );
    }
    expect(
      () => MediaState(MediaType.movie, 'planned', date: '2024-01-01'),
      throwsFormatException,
    );
    expect(
      () => MediaMetadata(MediaType.track, {'title': 'Faixa', 'artists': []}),
      throwsFormatException,
    );
  });

  late ProfileFirestoreFake db;
  late MediaLibraryRepository repository;
  setUp(() {
    db = ProfileFirestoreFake();
    repository = FirestoreMediaLibraryRepository(firestore: db);
  });
  tearDown(() => db.close());

  test(
    'preparação manual gera identidade sem acesso ao banco e conserva retry',
    () async {
      final first = repository.newCatalog(
        ownerId: 'a',
        metadata: book('a').metadata,
      );
      final second = repository.newCatalog(
        ownerId: 'a',
        metadata: first.metadata,
      );
      expect(first.identity.isManual, isTrue);
      expect(first.identity.key, isNot(second.identity.key));
      expect(db.reads, 0);
      expect(db.writes, 0);
      final saved = await repository.save(first);
      expect((await repository.save(first)).id, saved.id);
    },
  );

  test(
    'leitura opcional ausente equivale a null e versão futura não é interpretada',
    () {
      final item = book('a');
      final data = item.toMap();
      data.remove('fetchedAt');
      (data['metadata'] as Map).remove('coverUrl');
      expect(CatalogItem.fromMap(item.id, data).toMap(), item.toMap());
      data['schemaVersion'] = 2;
      expect(() => CatalogItem.fromMap(item.id, data), throwsFormatException);
    },
  );

  test(
    'entrada futura/malformada não é regravada e estado de outra mídia é negado',
    () async {
      final saved = await repository.save(book('a'));
      final path = 'libraries/a/entries/${saved.id}';
      final data = Map<String, dynamic>.of(db.documents[path]!);
      final writes = db.writes;
      db.documents[path]!['schemaVersion'] = 2;
      await expectLater(
        repository.updatePersonal(
          'a',
          saved.id,
          expectedRevision: 1,
          state: saved.state,
          favorite: false,
        ),
        throwsFormatException,
      );
      expect(db.writes, writes);
      db.documents[path] = data;
      await expectLater(
        repository.updatePersonal(
          'a',
          saved.id,
          expectedRevision: 1,
          state: MediaState(MediaType.movie, 'watched'),
          favorite: false,
        ),
        throwsFormatException,
      );
      final malformed = {...data}..remove('state');
      expect(
        () => LibraryEntry.fromMap(saved.id, malformed),
        throwsFormatException,
      );
      expect(db.writes, writes);
    },
  );

  test(
    'duas contas salvam mesma obra e mantêm progresso independente',
    () async {
      final a = await repository.save(book('a'));
      final b = await repository.save(book('b'));
      expect(a.id, isNot(b.id));
      final changed = await repository.updatePersonal(
        'a',
        a.id,
        expectedRevision: 1,
        state: MediaState(MediaType.book, 'completed', date: '2026-10-08'),
        favorite: false,
      );
      expect(changed.createdAt, a.createdAt);
      expect(changed.state!.date, '2026-10-08');
      expect((await repository.readEntry('b', b.id))!.state!.status, 'planned');
      expect(
        db.documents.keys.every((p) => p.startsWith('libraries/')),
        isTrue,
      );
    },
  );

  test(
    'salvar de novo não redefine estado, datas nem catálogo confirmado',
    () async {
      final original = await repository.save(book('a'));
      await repository.updatePersonal(
        'a',
        original.id,
        expectedRevision: 1,
        state: MediaState(MediaType.book, 'reading'),
        favorite: false,
      );
      final writes = db.writes;
      final again = await repository.save(book('a', id: 'new-catalog'));
      expect(again.id, original.id);
      expect(again.state!.status, 'reading');
      expect(again.revision, 2);
      expect(db.writes, writes);
      expect(
        db.documents.containsKey('libraries/a/catalog/new-catalog'),
        isFalse,
      );
    },
  );

  test(
    'fornecedores, edições e inclusões manuais são distintos; retry manual não duplica',
    () async {
      final items = [
        book('a', id: 'c1'),
        book('a', id: 'c2', provider: 'example_video'),
        book('a', id: 'c3', externalId: 'edition'),
      ];
      for (final manualId in ['m1', 'm2']) {
        items.add(
          CatalogItem(
            id: manualId,
            ownerId: 'a',
            identity: CatalogIdentity.manual(MediaType.book, 'a', manualId),
            metadata: items.first.metadata,
          ),
        );
      }
      final saved = <LibraryEntry>[];
      for (final item in items) {
        saved.add(await repository.save(item));
      }
      expect(saved.map((e) => e.id).toSet(), hasLength(5));
      expect((await repository.save(items.last)).id, saved.last.id);
    },
  );

  test('música favoritada não inventa escuta ou progresso', () async {
    final item = CatalogItem(
      id: 'track',
      ownerId: 'a',
      identity: CatalogIdentity.manual(MediaType.track, 'a', 'm'),
      metadata: MediaMetadata(MediaType.track, {
        'title': 'Faixa',
        'artists': ['Artista'],
      }),
    );
    final saved = await repository.save(item);
    final changed = await repository.updatePersonal(
      'a',
      saved.id,
      expectedRevision: 1,
      state: null,
      favorite: true,
    );
    expect(changed.state, isNull);
    expect(changed.favorite, isTrue);
    expect(db.documents.keys.any((p) => p.contains('listens')), isFalse);
  });

  test(
    'atualização com revisão antiga rejeita conflito sem perder alteração',
    () async {
      db.wrapTransactionErrors = true;
      final saved = await repository.save(book('a'));
      await repository.updatePersonal(
        'a',
        saved.id,
        expectedRevision: 1,
        state: MediaState(MediaType.book, 'reading'),
        favorite: false,
      );
      await expectLater(
        repository.updatePersonal(
          'a',
          saved.id,
          expectedRevision: 1,
          state: MediaState(MediaType.book, 'completed'),
          favorite: false,
        ),
        throwsA(isA<MediaRevisionConflict>()),
      );
      expect(
        (await repository.readEntry('a', saved.id))!.state!.status,
        'reading',
      );
    },
  );

  test(
    'sem alteração não incrementa revisão; limpar data preserva inclusão',
    () async {
      final saved = await repository.save(book('a'));
      final noop = await repository.updatePersonal(
        'a',
        saved.id,
        expectedRevision: 1,
        state: saved.state,
        favorite: false,
      );
      expect(noop.revision, 1);
      await repository.updatePersonal(
        'a',
        saved.id,
        expectedRevision: 1,
        state: MediaState(MediaType.book, 'completed', date: '2020-01-01'),
        favorite: false,
      );
      final cleared = await repository.updatePersonal(
        'a',
        saved.id,
        expectedRevision: 2,
        state: MediaState(MediaType.book, 'planned'),
        favorite: false,
      );
      expect(cleared.state!.date, isNull);
      expect(cleared.createdAt, saved.createdAt);
    },
  );

  test(
    'não anuncia resultado antes do commit e falha não cria documentos',
    () async {
      db.commitGate = Completer<void>();
      var completed = false;
      final saving = repository.save(book('a')).then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(db.documents, isEmpty);
      db.commitGate!.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await expectLater(saving, throwsA(isA<FirebaseException>()));
      expect(db.documents, isEmpty);
      db.commitGate = null;
      expect((await repository.save(book('a'))).revision, 1);
    },
  );

  test('versão futura ou slot incompleto não são sobrescritos', () async {
    db.wrapTransactionErrors = true;
    final item = book('a');
    final path = 'libraries/a/reference_slots/${item.identity.key}';
    db.documents[path] = {'schemaVersion': 2, 'entryId': 'e', 'catalogId': 'c'};
    await expectLater(repository.save(item), throwsFormatException);
    expect(db.writes, 0);
    db.documents[path]!['schemaVersion'] = 1;
    await expectLater(repository.save(item), throwsFormatException);
    expect(db.writes, 0);
  });
}
