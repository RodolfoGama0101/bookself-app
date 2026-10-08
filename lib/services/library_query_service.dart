import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/book_model.dart';
import '../data/models/media_model.dart';
import 'firebase_environment.dart';

/// Cursor vinculado à consulta. O desempate por ID suporta datas iguais e
/// continua funcionando quando o documento anterior é removido.
class LibraryCursor {
  const LibraryCursor({
    required this.scope,
    required this.timestamp,
    required this.documentId,
  });
  final String scope;
  final Timestamp timestamp;
  final String documentId;
}

class LibraryPage<T> {
  LibraryPage(Iterable<T> items, this.next)
    : items = List<T>.unmodifiable(items);
  final List<T> items;
  final LibraryCursor? next;
}

abstract interface class LibraryQueryRepository {
  Future<LibraryPage<LibraryEntry>> readMediaPage(
    String ownerId, {
    MediaType? type,
    int pageSize = 20,
    LibraryCursor? after,
  });
  Future<int> countMedia(String ownerId, {MediaType? type, String? status});
  Future<LibraryPage<BookModel>> readBookPage(
    String ownerId, {
    bool shared = false,
    DateTime? activitySince,
    int pageSize = 20,
    LibraryCursor? after,
  });
  Future<int> countBooks(
    String ownerId, {
    bool shared = false,
    String? status,
    DateTime? finishedFrom,
    DateTime? finishedBefore,
  });
}

class FirestoreLibraryQueryRepository implements LibraryQueryRepository {
  FirestoreLibraryQueryRepository({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;

  Query<Map<String, dynamic>> _media(String ownerId, MediaType? type) {
    requireDocumentId(ownerId);
    Query<Map<String, dynamic>> query = _db
        .collection('libraries')
        .doc(ownerId)
        .collection('entries');
    if (type != null) query = query.where('mediaType', isEqualTo: type.name);
    return query;
  }

  Query<Map<String, dynamic>> _books(String ownerId, bool shared) {
    requireDocumentId(ownerId);
    return _db
        .collection(shared ? 'shared_books' : 'books')
        .where('userId', isEqualTo: ownerId);
  }

  Future<LibraryPage<T>> _page<T>(
    Query<Map<String, dynamic>> query, {
    required String scope,
    required String timeField,
    required int pageSize,
    required LibraryCursor? after,
    required T Function(QueryDocumentSnapshot<Map<String, dynamic>>) decode,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw RangeError.range(pageSize, 1, 100, 'pageSize');
    }
    if (after != null) {
      if (after.scope != scope) throw ArgumentError('Cursor de outra consulta');
      requireDocumentId(after.documentId);
    }
    query = query
        .orderBy(timeField, descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter([after.timestamp, after.documentId]);
    }
    // Um documento extra determina o término sem outra leitura de página vazia.
    final snapshot = await query
        .limit(pageSize + 1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Página sem confirmação do servidor');
    }
    final visible = snapshot.docs.take(pageSize).toList();
    final last = visible.lastOrNull;
    return LibraryPage(
      visible.map(decode),
      snapshot.docs.length > pageSize && last != null
          ? LibraryCursor(
              scope: scope,
              timestamp: last.data()[timeField] as Timestamp,
              documentId: last.id,
            )
          : null,
    );
  }

  @override
  Future<LibraryPage<LibraryEntry>> readMediaPage(
    String ownerId, {
    MediaType? type,
    int pageSize = 20,
    LibraryCursor? after,
  }) => _page(
    _media(ownerId, type),
    scope: 'media/$ownerId/${type?.name ?? "all"}',
    timeField: 'createdAt',
    pageSize: pageSize,
    after: after,
    decode: (doc) {
      final entry = LibraryEntry.fromMap(doc.id, doc.data());
      if (entry.ownerId != ownerId) {
        throw const FormatException('Dono divergente');
      }
      return entry;
    },
  );

  @override
  Future<int> countMedia(
    String ownerId, {
    MediaType? type,
    String? status,
  }) async {
    var query = _media(ownerId, type);
    if (status != null) {
      if (type == null) throw ArgumentError('Estado exige mídia explícita');
      // Valida estado pelo mesmo contrato usado nas escritas.
      MediaState(type, status);
      query = query.where('state.status', isEqualTo: status);
    }
    return (await query.count().get()).count!;
  }

  @override
  Future<LibraryPage<BookModel>> readBookPage(
    String ownerId, {
    bool shared = false,
    DateTime? activitySince,
    int pageSize = 20,
    LibraryCursor? after,
  }) {
    var query = _books(ownerId, shared);
    if (activitySince != null) {
      query = query.where(
        'activityAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(activitySince),
      );
    }
    return _page(
      query,
      scope:
          'books/$ownerId/$shared/${activitySince?.toUtc().toIso8601String() ?? "library"}',
      timeField: activitySince == null ? 'addedAt' : 'activityAt',
      pageSize: pageSize,
      after: after,
      decode: BookModel.fromFirestore,
    );
  }

  @override
  Future<int> countBooks(
    String ownerId, {
    bool shared = false,
    String? status,
    DateTime? finishedFrom,
    DateTime? finishedBefore,
  }) async {
    var query = _books(ownerId, shared);
    if (status != null) {
      if (!const ['Quero Ler', 'Lendo', 'Lido'].contains(status)) {
        throw ArgumentError('Estado de livro inválido');
      }
      query = query.where('status', isEqualTo: status);
    }
    if (finishedFrom != null || finishedBefore != null) {
      if (status != 'Lido' ||
          finishedFrom == null ||
          finishedBefore == null ||
          !finishedFrom.isBefore(finishedBefore)) {
        throw ArgumentError('Período de conclusão inválido');
      }
      query = query
          .where(
            'finishedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(finishedFrom),
          )
          .where(
            'finishedDate',
            isLessThan: Timestamp.fromDate(finishedBefore),
          );
    }
    // Contagem independente do cursor/limite; nunca usa só a página visível.
    return (await query.count().get()).count!;
  }
}
