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
  int commits = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, anyOf('bible_progress', 'shared_bible_progress'));
    return _BibleCollection(this, path);
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
    if (transaction.id != null) {
      await commit(transaction.id!, transaction.pending!);
    }
    for (final entry in transaction.shared.entries) {
      if (entry.value == null) {
        documents.remove(entry.key);
      } else {
        documents[entry.key] = entry.value!;
      }
    }
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
  _BibleCollection(this.database, this.path);
  final BibleFirestoreFake database;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _BibleReference(database, path!, this.path);
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
    expect(field, 'userId');
    database.queriedOwner = isEqualTo;
    return _BibleQuery(database);
  }
}

// ignore: subtype_of_sealed_class
class _BibleReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _BibleReference(this.database, this.id, this.collectionPath);
  final BibleFirestoreFake database;
  final String collectionPath;
  @override
  String get path => '$collectionPath/$id';
  @override
  final String id;
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
  final shared = <String, Map<String, dynamic>?>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    final ref = reference as _BibleReference;
    return ProfileSnapshot(
          reference.id,
          database.documents[ref.collectionPath == 'bible_progress'
              ? ref.id
              : ref.path],
        )
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    final ref = reference as _BibleReference;
    if (ref.collectionPath == 'bible_progress') {
      id = reference.id;
      pending = Map.from(data as Map<String, dynamic>);
    } else {
      shared[ref.path] = Map.from(data as Map<String, dynamic>);
    }
    return this;
  }

  @override
  Transaction delete(DocumentReference reference) {
    shared[reference.path] = null;
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
  }) : docs = [_BibleQueryDocument(id, data)],
       metadata = ProfileSnapshot(id, data, pendingWrites: pending).metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

// ignore: subtype_of_sealed_class
class _BibleQueryDocument extends ProfileSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _BibleQueryDocument(super.id, super.data);
  @override
  Map<String, dynamic> data() => super.data()!;
}
