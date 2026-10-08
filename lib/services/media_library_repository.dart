import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/media_model.dart';
import 'firebase_environment.dart';

/// Repositório substituível; não altera livros/Bíblia nem publica projeções.
abstract interface class MediaLibraryRepository {
  /// Preparar uma vez e conservar o resultado durante falha/retry de save.
  CatalogItem newCatalog({
    required String ownerId,
    required MediaMetadata metadata,
    CatalogIdentity? identity,
    DateTime? fetchedAt,
  });
  Future<LibraryEntry> save(CatalogItem catalog);
  Future<LibraryEntry?> readEntry(String ownerId, String entryId);
  Future<CatalogItem?> readCatalog(String ownerId, String catalogId);
  Future<LibraryEntry> updatePersonal(
    String ownerId,
    String entryId, {
    required int expectedRevision,
    required MediaState? state,
    required bool favorite,
  });
}

class MediaRevisionConflict implements Exception {
  const MediaRevisionConflict();
}

class FirestoreMediaLibraryRepository implements MediaLibraryRepository {
  FirestoreMediaLibraryRepository({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;

  // FlutterFire web pode reempacotar erros Dart do callback como erro SDK.
  Future<T> _transaction<T>(Future<T> Function(Transaction) action) async {
    Exception? failure;
    try {
      return await _db.runTransaction((tx) async {
        failure = null;
        try {
          return await action(tx);
        } on MediaRevisionConflict catch (error) {
          failure = error;
          rethrow;
        } on FormatException catch (error) {
          failure = error;
          rethrow;
        }
      });
    } catch (_) {
      if (failure != null) {
        throw failure!;
      }
      rethrow;
    }
  }

  @override
  CatalogItem newCatalog({
    required String ownerId,
    required MediaMetadata metadata,
    CatalogIdentity? identity,
    DateTime? fetchedAt,
  }) {
    final id = _collection(ownerId, 'catalog').doc().id;
    return CatalogItem(
      id: id,
      ownerId: ownerId,
      identity:
          identity ?? CatalogIdentity.manual(metadata.mediaType, ownerId, id),
      metadata: metadata,
      fetchedAt: fetchedAt,
    );
  }

  CollectionReference<Map<String, dynamic>> _collection(
    String owner,
    String name,
  ) {
    requireDocumentId(owner);
    return _db.collection('libraries').doc(owner).collection(name);
  }

  DocumentReference<Map<String, dynamic>> _reference(
    String owner,
    String name,
    String id,
  ) {
    requireDocumentId(id);
    return _collection(owner, name).doc(id);
  }

  @override
  Future<LibraryEntry> save(CatalogItem catalog) async {
    final owner = catalog.ownerId;
    final slot = _collection(
      owner,
      'reference_slots',
    ).doc(catalog.identity.key);
    // IDs gerados fora do callback: o retry automático conserva a intenção.
    final entry = _collection(owner, 'entries').doc();
    final catalogRef = _reference(owner, 'catalog', catalog.id);
    final entryId = await _transaction((tx) async {
      final existing = await tx.get(slot);
      if (existing.exists) {
        final data = existing.data()!;
        requireVersion(data);
        requireFields(data, {'schemaVersion', 'entryId', 'catalogId'});
        requireKeys(data, {'schemaVersion', 'entryId', 'catalogId'});
        final ref = _reference(owner, 'entries', data['entryId'] as String);
        final found = await tx.get(ref);
        final source = await tx.get(
          _reference(owner, 'catalog', data['catalogId'] as String),
        );
        if (!found.exists || !source.exists) {
          throw const FormatException('Referência incompleta');
        }
        final saved = LibraryEntry.fromMap(found.id, found.data()!);
        final item = CatalogItem.fromMap(source.id, source.data()!);
        if (saved.ownerId != owner ||
            item.ownerId != owner ||
            saved.catalogId != item.id ||
            item.identity.key != catalog.identity.key ||
            saved.mediaType != item.identity.mediaType) {
          throw const FormatException('Referência inconsistente');
        }
        return found.id;
      }
      if ((await tx.get(catalogRef)).exists || (await tx.get(entry)).exists) {
        throw const FormatException('ID pessoal já utilizado');
      }
      tx.set(catalogRef, catalog.toMap());
      tx.set(entry, {
        'schemaVersion': 1,
        'ownerId': owner,
        'catalogId': catalog.id,
        'mediaType': catalog.identity.mediaType.name,
        'state': MediaState.initial(catalog.identity.mediaType)?.toMap(),
        'isShared': false,
        'favorite': false,
        'legacyRef': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': 1,
      });
      tx.set(slot, {
        'schemaVersion': 1,
        'entryId': entry.id,
        'catalogId': catalog.id,
      });
      return entry.id;
    });
    return (await readEntry(owner, entryId))!;
  }

  @override
  Future<LibraryEntry?> readEntry(String ownerId, String entryId) async {
    final doc = await _reference(
      ownerId,
      'entries',
      entryId,
    ).get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    final entry = LibraryEntry.fromMap(doc.id, doc.data()!);
    if (entry.ownerId != ownerId) {
      throw const FormatException('Dono inconsistente');
    }
    return entry;
  }

  @override
  Future<CatalogItem?> readCatalog(String ownerId, String catalogId) async {
    final doc = await _reference(
      ownerId,
      'catalog',
      catalogId,
    ).get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    final catalog = CatalogItem.fromMap(doc.id, doc.data()!);
    if (catalog.ownerId != ownerId) {
      throw const FormatException('Dono inconsistente');
    }
    return catalog;
  }

  @override
  Future<LibraryEntry> updatePersonal(
    String ownerId,
    String entryId, {
    required int expectedRevision,
    required MediaState? state,
    required bool favorite,
  }) async {
    final ref = _reference(ownerId, 'entries', entryId);
    await _transaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Entrada ausente');
      final entry = LibraryEntry.fromMap(doc.id, doc.data()!);
      if (entry.ownerId != ownerId) {
        throw const FormatException('Dono inconsistente');
      }
      if (entry.revision != expectedRevision) {
        throw const MediaRevisionConflict();
      }
      validatePersonalState(entry.mediaType, state, favorite);
      final sameState =
          entry.state?.status == state?.status &&
          entry.state?.date == state?.date;
      if (sameState && entry.favorite == favorite) return;
      tx.update(ref, {
        'state': state?.toMap(),
        'favorite': favorite,
        'revision': entry.revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return (await readEntry(ownerId, entryId))!;
  }
}
