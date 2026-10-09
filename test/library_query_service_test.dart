import 'package:bookself_app/services/music_listen_service.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/services/personal_export_service.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Database extends Fake implements FirebaseFirestore {
  final rows = <String, List<_Document>>{};
  int reads = 0;
  int aggregates = 0;
  int? lastLimit;
  Source? lastSource;
  bool cache = false;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Reference(this, path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(
    this.db,
    this.path, {
    this.filters = const [],
    this.orders = const [],
    this.cursor,
    this.cap,
  });
  final _Database db;
  @override
  final String path;
  final List<bool Function(Map<String, dynamic>)> filters;
  final List<(Object, bool)> orders;
  final List<Object?>? cursor;
  final int? cap;
  dynamic field(Map<String, dynamic> data, Object key) {
    dynamic value = data;
    for (final part in key.toString().split('.')) {
      value = (value as Map?)?[part];
    }
    return value;
  }

  int compare(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) return a.compareTo(b);
    return (a as Comparable).compareTo(b);
  }

  List<_Document> result() {
    var result = (db.rows[path] ?? [])
        .where((d) => filters.every((f) => f(d.data())))
        .toList();
    result.sort((a, b) {
      for (final (key, descending) in orders) {
        final x = key == FieldPath.documentId ? a.id : field(a.data(), key);
        final y = key == FieldPath.documentId ? b.id : field(b.data(), key);
        final order = compare(x, y) * (descending ? -1 : 1);
        if (order != 0) return order;
      }
      return 0;
    });
    if (cursor != null) {
      result = result.where((d) {
        for (var i = 0; i < orders.length; i++) {
          final (key, descending) = orders[i];
          final value = key == FieldPath.documentId
              ? d.id
              : field(d.data(), key);
          final order = compare(value, cursor![i]) * (descending ? -1 : 1);
          if (order != 0) return order > 0;
        }
        return false;
      }).toList();
    }
    return cap == null ? result : result.take(cap!).toList();
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Reference(db, '$path/$id');
  @override
  Query<Map<String, dynamic>> where(
    Object key, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query(
    db,
    path,
    filters: [
      ...filters,
      (data) {
        final value = field(data, key);
        if (isEqualTo != null && value != isEqualTo) return false;
        if (isGreaterThanOrEqualTo != null &&
            (value == null || compare(value, isGreaterThanOrEqualTo) < 0)) {
          return false;
        }
        if (isLessThan != null &&
            (value == null || compare(value, isLessThan) >= 0)) {
          return false;
        }
        return true;
      },
    ],
    orders: orders,
    cursor: cursor,
    cap: cap,
  );
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _Query(
    db,
    path,
    filters: filters,
    orders: [...orders, (field, descending)],
    cursor: cursor,
    cap: cap,
  );
  @override
  Query<Map<String, dynamic>> startAfter(Iterable<Object?> values) => _Query(
    db,
    path,
    filters: filters,
    orders: orders,
    cursor: values.toList(),
    cap: cap,
  );
  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot<Object?> snapshot,
  ) => startAfter([snapshot.id]);
  @override
  Query<Map<String, dynamic>> limit(int value) => _Query(
    db,
    path,
    filters: filters,
    orders: orders,
    cursor: cursor,
    cap: value,
  );
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.reads++;
    db.lastLimit = cap;
    db.lastSource = options?.source;
    return _Snapshot(result(), db.cache);
  }

  @override
  AggregateQuery count() => _Aggregate(this);
}

// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    db.lastSource = options?.source;
    final parts = path.split('/');
    return db.rows[parts.first]!.firstWhere((d) => d.id == parts.last);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Query(db, '$path/$name');
}

// Dublê restrito ao teste de consultas, como os demais fakes do projeto.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  bool get exists => true;
  @override
  SnapshotMetadata get metadata => _Metadata(false);
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache);
  @override
  final bool isFromCache;
  @override
  bool get hasPendingWrites => false;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs, bool cache) : metadata = _Metadata(cache);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

class _Aggregate extends Fake implements AggregateQuery {
  _Aggregate(this.query);
  @override
  final _Query query;
  @override
  Future<AggregateQuerySnapshot> get({
    AggregateSource source = AggregateSource.server,
  }) async {
    query.db.aggregates++;
    return _Count(query.result().length);
  }
}

class _Count extends Fake implements AggregateQuerySnapshot {
  _Count(this.count);
  @override
  final int? count;
}

Map<String, dynamic> entry(String type) => {
  'schemaVersion': 1,
  'ownerId': 'a',
  'catalogId': 'catalog',
  'mediaType': type,
  'state': {
    'status': 'planned',
    if (type == 'book') 'finishedOn': null,
    if (type == 'movie') 'watchedOn': null,
  },
  'favorite': false,
  'isShared': false,
  'createdAt': Timestamp.fromDate(DateTime.utc(2020)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2020)),
  'revision': 1,
  'legacyRef': null,
};
void main() {
  test('escutas percorrem páginas e isolam cursor/dono/cache', () async {
    final db = _Database();
    db.rows['libraries/a/listens'] = [
      for (var i = 0; i < 45; i++)
        _Document('listen-${i.toString().padLeft(2, '0')}', {
          'schemaVersion': 1,
          'ownerId': 'a',
          'entryId': 'track',
          'revision': 1,
          'listenedOn': '2020-01-01',
          'createdAt': Timestamp(100, 123),
        }),
      _Document('other', {'entryId': 'other'}),
    ];
    final service = MusicListenService(firestore: db);
    final first = await service.page('a', 'track');
    final second = await service.page('a', 'track', after: first.next);
    final third = await service.page('a', 'track', after: second.next);
    expect(
      [first.items.length, second.items.length, third.items.length],
      [20, 20, 5],
    );
    expect({
      ...first.items.map((r) => r.id),
      ...second.items.map((r) => r.id),
      ...third.items.map((r) => r.id),
    }, hasLength(45));
    expect(third.next, null);
    expect(db.lastLimit, 21);
    expect(db.lastSource, Source.server);
    await expectLater(
      service.page('b', 'track', after: first.next),
      throwsFormatException,
    );
    await expectLater(
      service.page('a', 'other', after: first.next),
      throwsFormatException,
    );
    db.cache = true;
    await expectLater(service.page('a', 'track'), throwsStateError);
  });
  test(
    'exportação lê mais de 100 registros com cursor e somente do servidor',
    () async {
      final database = _Database();
      database.rows['users'] = [
        _Document('a', {'uid': 'a'}),
      ];
      database.rows['books'] = [
        for (var i = 0; i < 205; i++)
          _Document('book-${i.toString().padLeft(3, '0')}', {'userId': 'a'}),
        _Document('foreign', {'userId': 'b'}),
      ];
      final json = await PersonalExportService(
        firestore: database,
        currentUid: () => 'a',
      ).export('a');
      final rows = jsonDecode(json)['collections']['books'] as Map;
      expect(rows, hasLength(205));
      expect(rows.containsKey('foreign'), false);
      expect(database.lastSource, Source.server);
      expect(database.lastLimit, 100);
      expect(database.reads, 7);
    },
  );
  test(
    'exportação recusa resultado do cache em vez de oferecer cópia incompleta',
    () async {
      final database = _Database()..cache = true;
      database.rows['users'] = [
        _Document('a', {'uid': 'a'}),
      ];
      await expectLater(
        PersonalExportService(
          firestore: database,
          currentUid: () => 'a',
        ).export('a'),
        throwsStateError,
      );
    },
  );
  late _Database db;
  late LibraryQueryRepository repository;
  setUp(() {
    db = _Database();
    repository = FirestoreLibraryQueryRepository(firestore: db);
    db.rows['libraries/a/entries'] = [
      for (var i = 0; i < 7; i++)
        _Document('id-$i', entry(i == 6 ? 'movie' : 'book')),
    ];
  });
  test(
    'páginas limitadas com empate e cursor de documento removido não perdem itens',
    () async {
      final first = await repository.readMediaPage('a', pageSize: 2);
      expect(first.items.map((e) => e.id), ['id-6', 'id-5']);
      expect(db.lastLimit, 3);
      expect(db.lastSource, Source.server);
      db.rows['libraries/a/entries']!.removeWhere((d) => d.id == 'id-5');
      final second = await repository.readMediaPage(
        'a',
        pageSize: 2,
        after: first.next,
      );
      final third = await repository.readMediaPage(
        'a',
        pageSize: 2,
        after: second.next,
      );
      final fourth = await repository.readMediaPage(
        'a',
        pageSize: 2,
        after: third.next,
      );
      expect(
        [...second.items, ...third.items, ...fourth.items].map((e) => e.id),
        ['id-4', 'id-3', 'id-2', 'id-1', 'id-0'],
      );
      expect(fourth.next, isNull);
    },
  );
  test(
    'contagem completa por categoria/estado independe do limite de página',
    () async {
      expect(
        (await repository.readMediaPage(
          'a',
          type: MediaType.book,
          pageSize: 2,
        )).items,
        hasLength(2),
      );
      final reads = db.reads;
      expect(
        await repository.countMedia(
          'a',
          type: MediaType.book,
          status: 'planned',
        ),
        6,
      );
      expect(await repository.countMedia('a', type: MediaType.movie), 1);
      expect(db.reads, reads);
      expect(db.aggregates, 2);
    },
  );
  test(
    'cursor de outra conta/filtro e tamanhos inválidos são recusados sem leitura',
    () async {
      final first = await repository.readMediaPage('a', pageSize: 2);
      final reads = db.reads;
      await expectLater(
        repository.readMediaPage('b', after: first.next),
        throwsArgumentError,
      );
      await expectLater(
        repository.readMediaPage('a', type: MediaType.movie, after: first.next),
        throwsArgumentError,
      );
      for (final size in [0, 101]) {
        await expectLater(
          repository.readMediaPage('a', pageSize: size),
          throwsRangeError,
        );
      }
      expect(db.reads, reads);
    },
  );
  test(
    'cache não confirma página e períodos inválidos não consultam o servidor',
    () async {
      db.cache = true;
      await expectLater(repository.readMediaPage('a'), throwsStateError);
      final reads = db.reads;
      await expectLater(
        repository.countBooks(
          'a',
          status: 'Lendo',
          finishedFrom: DateTime.utc(2020),
          finishedBefore: DateTime.utc(2021),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.countMedia('a', status: 'planned'),
        throwsArgumentError,
      );
      expect(db.reads, reads);
      expect(db.aggregates, 0);
    },
  );
  test(
    'feed usa atividade e contagem por período não depende da página',
    () async {
      final date = Timestamp.fromDate(DateTime.utc(2020));
      db.rows['shared_books'] = [
        for (var i = 0; i < 5; i++)
          _Document('book-$i', {
            'userId': 'a',
            'title': 'Fictício',
            'authors': <String>[],
            'status': 'Lido',
            'addedAt': date,
            'activityAt': date,
            'finishedDate': i == 4 ? null : date,
          }),
        _Document('other', {
          'userId': 'b',
          'status': 'Lido',
          'finishedDate': date,
        }),
      ];
      final first = await repository.readBookPage(
        'a',
        shared: true,
        activitySince: DateTime.utc(2019),
        pageSize: 2,
      );
      expect(first.items.map((b) => b.id), ['book-4', 'book-3']);
      final second = await repository.readBookPage(
        'a',
        shared: true,
        activitySince: DateTime.utc(2019),
        pageSize: 2,
        after: first.next,
      );
      expect(second.items.map((b) => b.id), ['book-2', 'book-1']);
      expect(await repository.countBooks('a', shared: true, status: 'Lido'), 5);
      expect(
        await repository.countBooks(
          'a',
          shared: true,
          status: 'Lido',
          finishedFrom: DateTime.utc(2020),
          finishedBefore: DateTime.utc(2021),
        ),
        4,
      );
      await expectLater(
        repository.readBookPage('a', shared: true, after: first.next),
        throwsArgumentError,
      );
    },
  );
}
