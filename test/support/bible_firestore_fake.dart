import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_firestore_fake.dart';

class BibleFirestoreFake extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final bookEvents =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  final allEvents =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  Completer<void>? commitGate;
  Map<String, dynamic>? concurrentProgress;
  String? watchedId;
  Object? queriedOwner;
  bool bookMetadata = false;
  bool allMetadata = false;
  Source? lastGetSource;
  bool serverPending = false;
  bool serverFromCache = false;
  int commits = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    assert(path == 'bible_progress');
    return _BibleCollection(this);
  }

  Future<void> commit(String id, Map<String, dynamic> data) async {
    if (commitGate != null) await commitGate!.future;
    documents[id] = Map.of(data)
      ..['updatedAt'] = Timestamp.fromDate(DateTime(2026));
    commits++;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    var transaction = _BibleTransaction(this);
    var result = await handler(transaction);
    if (concurrentProgress != null) {
      documents[transaction.id!] = concurrentProgress!;
      concurrentProgress = null;
      transaction = _BibleTransaction(this);
      result = await handler(transaction);
    }
    await commit(transaction.id!, transaction.pending!);
    return result;
  }

  Future<void> close() async {
    await bookEvents.close();
    await allEvents.close();
  }
}

// Dublês locais de APIs sealed do SDK; não são implementações de produção.
// ignore: subtype_of_sealed_class
class _BibleCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _BibleCollection(this.database);
  final BibleFirestoreFake database;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _BibleReference(database, path!);
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
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
  }) {
    assert(field == 'userId');
    database.queriedOwner = isEqualTo;
    return _BibleQuery(database);
  }
}

// ignore: subtype_of_sealed_class
class _BibleReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _BibleReference(this.database, this.id);
  final BibleFirestoreFake database;
  @override
  final String id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.lastGetSource = options?.source;
    return ProfileSnapshot(
      id,
      database.documents[id],
      pendingWrites: database.serverPending,
      fromCache: database.serverFromCache,
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      database.commit(id, data);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    database.watchedId = id;
    database.bookMetadata = includeMetadataChanges;
    return database.bookEvents.stream;
  }
}

// ignore: subtype_of_sealed_class
class _BibleQuery extends Fake implements Query<Map<String, dynamic>> {
  _BibleQuery(this.database);
  final BibleFirestoreFake database;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    database.allMetadata = includeMetadataChanges;
    return database.allEvents.stream;
  }
}

class _BibleTransaction extends Fake implements Transaction {
  _BibleTransaction(this.database);
  final BibleFirestoreFake database;
  String? id;
  Map<String, dynamic>? pending;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    return ProfileSnapshot(reference.id, database.documents[reference.id])
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    id = reference.id;
    pending = Map.from(data as Map<String, dynamic>);
    return this;
  }
}

// ignore: subtype_of_sealed_class
class BibleQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  BibleQuerySnapshot(
    String id,
    Map<String, dynamic> data, {
    bool pending = false,
  }) : docs = [_BibleQueryDocument(id, data, pending: pending)],
       metadata = ProfileSnapshot(id, data, pendingWrites: pending).metadata;
  BibleQuerySnapshot.multiple(
    Map<String, Map<String, dynamic>> values, {
    String? pendingId,
  }) : docs = [
         for (final entry in values.entries)
           _BibleQueryDocument(
             entry.key,
             entry.value,
             pending: entry.key == pendingId,
           ),
       ],
       metadata = ProfileSnapshot(
         '',
         null,
         pendingWrites: pendingId != null,
       ).metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

// ignore: subtype_of_sealed_class
class _BibleQueryDocument extends ProfileSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _BibleQueryDocument(super.id, super.data, {bool pending = false})
    : super(pendingWrites: pending);
  @override
  Map<String, dynamic> data() => super.data()!;
}
