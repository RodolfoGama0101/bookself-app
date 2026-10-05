import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class ProfileFirestoreFake extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final streams =
      <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  Map<String, dynamic>? concurrentProfile;
  Completer<void>? commitGate;
  int writes = 0;
  int reads = 0;
  bool includeMetadataChanges = false;

  StreamController<DocumentSnapshot<Map<String, dynamic>>> controller(
    String uid,
  ) {
    return streams.putIfAbsent(uid, () => StreamController.broadcast());
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    expect(collectionPath, anyOf('users', 'partner_profiles'));
    return _ProfileCollection(this, collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    var transaction = _ProfileTransaction(this);
    var result = await transactionHandler(transaction);
    if (concurrentProfile != null) {
      // Simula a repetição do callback pelo SDK após conflito na leitura.
      documents[concurrentProfile!['uid'] as String] = concurrentProfile!;
      concurrentProfile = null;
      transaction = _ProfileTransaction(this);
      result = await transactionHandler(transaction);
    }
    if (commitGate != null) await commitGate!.future;
    for (final entry in transaction.pending.entries) {
      documents[entry.key] = entry.value;
      writes++;
    }
    return result;
  }

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

// Implementação restrita ao dublê de testes; o SDK marca esta API como sealed.
// ignore: subtype_of_sealed_class
class _ProfileCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _ProfileCollection(this.database, this.collectionPath);
  final ProfileFirestoreFake database;
  final String collectionPath;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _ProfileReference(database, path!, collectionPath);
  }
}

// ignore: subtype_of_sealed_class
class _ProfileReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _ProfileReference(this.database, this.id, this.collectionPath);
  final ProfileFirestoreFake database;
  final String collectionPath;
  @override
  String get path => '$collectionPath/$id';
  String get key => collectionPath == 'users' ? id : path;
  @override
  final String id;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    database.includeMetadataChanges = includeMetadataChanges;
    return database.controller(key).stream;
  }
}

class _ProfileTransaction extends Fake implements Transaction {
  _ProfileTransaction(this.database);
  final ProfileFirestoreFake database;
  final pending = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    database.reads++;
    final key = (reference as _ProfileReference).key;
    return ProfileSnapshot(reference.id, database.documents[key])
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    pending[(reference as _ProfileReference).key] = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    final key = (reference as _ProfileReference).key;
    pending[key] = {
      ...database.documents[key]!,
      ...Map<String, dynamic>.from(data),
    };
    return this;
  }
}

// ignore: subtype_of_sealed_class
class ProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  ProfileSnapshot(
    this.id,
    this._data, {
    bool fromCache = false,
    bool pendingWrites = false,
  }) : metadata = _ProfileMetadata(fromCache, pendingWrites);

  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  final SnapshotMetadata metadata;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() => _data;
}

class _ProfileMetadata extends Fake implements SnapshotMetadata {
  _ProfileMetadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}
