import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_environment.dart';

typedef ExportReader =
    Future<Map<String, Map<String, dynamic>>> Function(
      String path,
      String? ownerField,
      String owner,
    );

/// Exportação parcial pessoal: nunca consulta projeções ou bibliotecas alheias.
class PersonalExportService {
  PersonalExportService({
    this.firestore,
    String? Function()? currentUid,
    this.reader,
  }) : _currentUid =
           currentUid ?? (() => FirebaseEnvironment.auth.currentUser?.uid);
  final FirebaseFirestore? firestore;
  final String? Function() _currentUid;
  final ExportReader? reader;
  static const maxDocuments = 5000;

  Future<Map<String, Map<String, dynamic>>> _read(
    String path,
    String? ownerField,
    String owner,
  ) async {
    if (reader != null) return reader!(path, ownerField, owner);
    final db = firestore ?? FirebaseEnvironment.firestore;
    if (path == 'users/$owner') {
      final doc = await db
          .doc(path)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists ||
          doc.metadata.hasPendingWrites ||
          doc.metadata.isFromCache) {
        throw StateError('Perfil indisponível');
      }
      return {doc.id: doc.data()!};
    }
    Query<Map<String, dynamic>> query = db.collection(path);
    if (ownerField != null) query = query.where(ownerField, isEqualTo: owner);
    query = query.orderBy(FieldPath.documentId).limit(100);
    final result = <String, Map<String, dynamic>>{};
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      _checkOwner(owner);
      final page =
          await (cursor == null ? query : query.startAfterDocument(cursor)).get(
            const GetOptions(source: Source.server),
          );
      if (page.metadata.isFromCache || page.metadata.hasPendingWrites) {
        throw StateError('Dados não confirmados');
      }
      for (final doc in page.docs) {
        result[doc.id] = doc.data();
      }
      if (result.length > maxDocuments) {
        throw StateError('Exportação muito grande');
      }
      if (page.docs.length < 100) return result;
      cursor = page.docs.last;
    }
  }

  void _checkOwner(String owner) {
    if (owner.isEmpty || owner.contains('/') || _currentUid() != owner) {
      throw StateError('Sessão alterada');
    }
  }

  Future<String> export(String owner) async {
    _checkOwner(owner);
    final collections = <String, dynamic>{};
    var total = 0;
    for (final source in <String, String?>{
      'users/$owner': null,
      'books': 'userId',
      'bible_progress': 'userId',
      'libraries/$owner/catalog': null,
      'libraries/$owner/entries': null,
    }.entries) {
      _checkOwner(owner);
      final rows = await _read(
        source.key,
        source.value,
        owner,
      ).timeout(const Duration(seconds: 30));
      _checkOwner(owner);
      total += rows.length;
      if (total > maxDocuments) throw StateError('Exportação muito grande');
      final ownerField =
          source.value ??
          (source.key.startsWith('libraries/') ? 'ownerId' : 'uid');
      if (rows.values.any((row) => row[ownerField] != owner)) {
        throw StateError('Dono divergente');
      }
      collections[source.key] = rows.map(
        (id, data) => MapEntry(
          id,
          source.key == 'users/$owner'
              ? {
                  for (final key in [
                    'uid',
                    'name',
                    'email',
                    'photoUrl',
                    'createdAt',
                  ])
                    if (data.containsKey(key)) key: data[key],
                }
              : data,
        ),
      );
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'scope': 'personal-library-only',
      'ownerId': owner,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'atomicSnapshot': false,
      'collections': _jsonValue(collections),
    });
  }

  static Object? _jsonValue(Object? value) {
    if (value is Timestamp) {
      return {
        'type': 'timestamp',
        'seconds': value.seconds,
        'nanoseconds': value.nanoseconds,
        'utc': value.toDate().toUtc().toIso8601String(),
      };
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonValue(item)),
      );
    }
    if (value is List) return value.map(_jsonValue).toList();
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw const FormatException('Tipo não suportado na exportação');
  }
}
