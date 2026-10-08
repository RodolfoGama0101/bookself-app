import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_environment.dart';

/// Projeções mínimas para o casal; os documentos pessoais ficam privados.
class SharingService {
  SharingService({FirebaseFirestore? firestore}) : _database = firestore;
  final FirebaseFirestore? _database;
  FirebaseFirestore get database => _database ?? FirebaseEnvironment.firestore;

  static Map<String, dynamic> projection(
    String collection,
    Map<String, dynamic> data,
  ) {
    final fields = collection == 'books'
        ? [
            'userId',
            'title',
            'authors',
            'coverUrl',
            'status',
            'publishedDate',
            'addedAt',
            'finishedDate',
            'googleBooksId',
            'activityAt',
            'activityStatus',
            'activityAction',
          ]
        : ['userId', 'bookName', 'readChapters', 'updatedAt'];
    return {
      for (final field in fields)
        if (data.containsKey(field)) field: data[field],
    };
  }

  static bool _same(Map<String, dynamic>? a, Map<String, dynamic> b) =>
      a != null &&
      a.length == b.length &&
      b.entries.every(
        (e) => e.value is List
            ? listEquals(a[e.key] as List?, e.value as List)
            : a[e.key] == e.value,
      );

  void mirror(
    Transaction tx,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) {
    final ref = database.collection('shared_$collection').doc(id);
    if (data['isShared'] == false) {
      tx.delete(ref);
    } else {
      tx.set(ref, projection(collection, data));
    }
  }

  /// Releitura transacional evita que uma publicação atrasada reexponha um item.
  Future<void> publish(String collection, String id, {bool? isShared}) async {
    await database.runTransaction((tx) async {
      final own = database.collection(collection).doc(id);
      final shared = database.collection('shared_$collection').doc(id);
      final snapshot = await tx.get(own);
      final existing = await tx.get(shared);
      final raw = snapshot.data();
      final data = raw == null ? null : Map<String, dynamic>.of(raw);
      if (data == null) return;
      if (isShared != null && (data['isShared'] ?? true) != isShared) {
        data['isShared'] = isShared;
        if (collection == 'books') data['activityAt'] = null;
        tx.update(own, {
          'isShared': isShared,
          if (collection == 'books') 'activityAt': null,
        });
      }
      if (data['isShared'] == false) {
        if (existing.exists) tx.delete(shared);
      } else {
        final minimal = projection(collection, data);
        if (!_same(existing.data(), minimal)) tx.set(shared, minimal);
      }
    });
  }

  /// Publicação repetível do próprio legado, sem modificar registros pessoais.
  Future<void> publishOwn(String collection, Iterable<String> ids) async {
    for (final id in ids) {
      await publish(collection, id);
    }
  }
}
