import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/media_model.dart';
import '../data/models/couple_record.dart';
import 'firebase_environment.dart';
import 'library_query_service.dart';

class CoupleActivity {
  CoupleActivity(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  CoupleSelection get selection =>
      CoupleSelection.fromMap(Map<String, dynamic>.from(data['selection']));
  bool get confirmed => data['confirmed'] as bool;
  String get occurredOn => data['occurredOn'] as String;
  int get revision => data['revision'] as int;
  int get version => data['sourceVersion'] as int;
}

Map<String, dynamic> activityProjection(CoupleRecord record) => {
  'schemaVersion': 1,
  'mediaType': record.selection.type.name,
  'selection': record.selection.toMap(),
  'confirmed': record.confirmed,
  'occurredOn': record.occurredOn,
  'revision': record.revision,
  'sourceVersion': record.version,
  'createdAt': record.data['createdAt'],
  'updatedAt': record.data['updatedAt'],
};

/// Projeções das experiências consentidas; sem escutas/favoritos pessoais.
class CoupleActivityService {
  CoupleActivityService({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;
  CollectionReference<Map<String, dynamic>> _collection(
    String relation,
    String collection,
  ) {
    requireDocumentId(relation);
    return _db
        .collection('couple_relationships')
        .doc(relation)
        .collection(collection);
  }

  Query<Map<String, dynamic>> _query(String relation, MediaType? type) {
    Query<Map<String, dynamic>> query = _collection(relation, 'activity');
    return type == null
        ? query
        : query.where('mediaType', isEqualTo: type.name);
  }

  String _scope(String relation, MediaType? type) =>
      'joint/$relation/${type?.name ?? 'all'}';
  Query<Map<String, dynamic>> _ordered(
    String relation,
    MediaType? type,
    LibraryCursor? after,
  ) {
    Query<Map<String, dynamic>> query = _query(relation, type)
        .orderBy('updatedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      if (after.scope != _scope(relation, type)) {
        throw ArgumentError('Cursor de outra relação/filtro');
      }
      query = query.startAfter([after.timestamp, after.documentId]);
    }
    return query.limit(21);
  }

  LibraryPage<CoupleActivity> _page(
    String relation,
    MediaType? type,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Atividades não confirmadas');
    }
    final rows = snapshot.docs.take(20).toList();
    final last = rows.lastOrNull;
    return LibraryPage(
      rows.map((d) => CoupleActivity(d.id, d.data())),
      snapshot.docs.length > 20 && last != null
          ? LibraryCursor(
              scope: _scope(relation, type),
              timestamp: last.data()['updatedAt'] as Timestamp,
              documentId: last.id,
            )
          : null,
    );
  }

  Stream<LibraryPage<CoupleActivity>> watch(
    String relation, {
    MediaType? type,
  }) => _ordered(relation, type, null)
      .snapshots(includeMetadataChanges: true)
      .map((s) => _page(relation, type, s));
  Future<LibraryPage<CoupleActivity>> page(
    String relation, {
    MediaType? type,
    required LibraryCursor after,
  }) async => _page(
    relation,
    type,
    await _ordered(
      relation,
      type,
      after,
    ).get(const GetOptions(source: Source.server)),
  );
  Future<Map<MediaType, int>> counts(String relation) async {
    final originals = (await _collection(
      relation,
      'experiences',
    ).count().get()).count;
    final indexed = (await _collection(
      relation,
      'activity',
    ).count().get()).count;
    if (originals == null || originals != indexed) {
      throw StateError('Há experiências antigas sem índice confirmado');
    }
    final result = <MediaType, int>{};
    for (final type in MediaType.values) {
      final count = (await _query(
        relation,
        type,
      ).where('confirmed', isEqualTo: true).count().get()).count;
      if (count == null) throw StateError('Contagem indisponível');
      result[type] = count;
    }
    return result;
  }
}

String mediaLabel(MediaType type) => switch (type) {
  MediaType.book => 'Livros',
  MediaType.movie => 'Filmes',
  MediaType.series => 'Séries',
  MediaType.track => 'Faixas',
  MediaType.album => 'Álbuns',
};
