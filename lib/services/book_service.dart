import 'dart:async';
import 'sharing_service.dart';
import 'firebase_environment.dart';
import 'dart:convert';
import 'dart:math';
import '../data/models/book_search_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../data/models/book_model.dart';
import '../utils/error_handler.dart';
import 'book_page_controller.dart';
import 'library_query_service.dart';

class BookService {
  static const paginationEnabled =
      bool.fromEnvironment('USE_PAGED_LIBRARY') ||
      bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  BookPageController pagedBooks(
    String owner, {
    bool shared = false,
    bool feed = false,
    String? partner,
    DateTime? since,
  }) => BookPageController(
    repository: FirestoreLibraryQueryRepository(firestore: _firestore),
    watch: (uid, projection, start, limit) =>
        watchBookWindow(uid, projection || shared, start, limit),
    owner: owner,
    ownerShared: shared,
    partner: partner,
    since: since,
    feed: feed,
  );

  Stream<LibraryPage<BookModel>> watchBookWindow(
    String uid,
    bool shared,
    DateTime? since,
    int limit,
  ) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(shared ? 'shared_books' : 'books')
        .where('userId', isEqualTo: uid);
    final field = since == null ? 'addedAt' : 'activityAt';
    if (since != null) {
      query = query.where(
        'activityAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    return query
        .orderBy(field, descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit + 1)
        .snapshots(includeMetadataChanges: true)
        .where(
          (s) =>
              shared ||
              (!s.metadata.isFromCache && !s.metadata.hasPendingWrites),
        )
        .map((s) {
          if (s.metadata.isFromCache || s.metadata.hasPendingWrites) {
            throw const SharedDataUnconfirmed();
          }
          final visible = s.docs.take(limit).toList();
          final rows = visible.map(BookModel.fromFirestore).toList();
          if (!shared) {
            unawaited(
              SharingService(firestore: _firestore)
                  .publishOwn('books', rows.map((b) => b.id))
                  .catchError((Object _) {}),
            );
          }
          final last = visible.lastOrNull;
          return LibraryPage(
            rows,
            s.docs.length > limit && last != null
                ? LibraryCursor(
                    scope:
                        'books/$uid/$shared/${since?.toUtc().toIso8601String() ?? "library"}',
                    timestamp: last.data()[field] as Timestamp,
                    documentId: last.id,
                  )
                : null,
          );
        });
  }

  Future<DateTime?> feedStart(String uid, String? partner) async {
    if (partner == null) return DateTime(1970);
    final own = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final code = own.data()?['relationshipId'];
    if (code is! String) return null;
    final invitation = await _firestore
        .collection('partner_invites')
        .doc(code)
        .get(const GetOptions(source: Source.server));
    return invitation.data()?['status'] == 'accepted'
        ? (invitation.data()?['decidedAt'] as Timestamp?)?.toDate()
        : null;
  }

  BookService({
    FirebaseFirestore? firestore,
    this.httpClient,
    String? apiKey,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _database = firestore,
       _apiKey = apiKey ?? _googleBooksApiKey;

  final FirebaseFirestore? _database;
  final String _apiKey;
  final Duration requestTimeout;

  /// O chamador mantém a responsabilidade de fechar um cliente injetado.
  final http.Client? httpClient;
  FirebaseFirestore get _firestore =>
      _database ?? FirebaseEnvironment.firestore;

  static const String _googleBooksApiKey = String.fromEnvironment(
    'GOOGLE_BOOKS_API_KEY',
  );

  Future<List<BookModel>> searchGoogleBooks(String query) async =>
      (await searchGoogleBooksPage(query)).books;

  Future<BookSearchPage> searchGoogleBooksPage(
    String query, {
    int startIndex = 0,
  }) async {
    if (startIndex < 0) throw RangeError.value(startIndex, 'startIndex');
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const BookSearchPage(books: []);
    if (_apiKey.trim().isEmpty) throw const CatalogConfigurationException();
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': trimmed,
      'maxResults': '20',
      'startIndex': '$startIndex',
      'key': _apiKey,
    });
    final client = httpClient ?? http.Client();
    late final http.Response response;
    try {
      response = await client.get(uri).timeout(requestTimeout);
    } finally {
      if (httpClient == null) client.close();
    }
    if (response.statusCode != 200) {
      if (response.statusCode == 403 && _isQuotaResponse(response.body)) {
        throw const CatalogQuotaException(403);
      }
      throw CatalogRequestException(response.statusCode);
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        (data['items'] != null && data['items'] is! List)) {
      throw const FormatException('Resposta de catálogo inválida');
    }
    final items = data['items'] as List? ?? [];
    final books = <BookModel>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final info = item['volumeInfo'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 200 ||
          info is! Map<String, dynamic>) {
        continue;
      }
      String text(Object? value, String fallback) =>
          value is String && value.trim().isNotEmpty ? value.trim() : fallback;
      final rawAuthors = info['authors'];
      final authors = rawAuthors is List
          ? rawAuthors
                .whereType<String>()
                .where((a) => a.trim().isNotEmpty)
                .map((a) => a.trim())
                .take(50)
                .toList()
          : <String>[];
      final images = info['imageLinks'];
      final cover = images is Map
          ? images['thumbnail'] ?? images['smallThumbnail']
          : null;
      books.add(
        BookModel(
          id: id,
          googleBooksId: id,
          userId: '',
          title: text(info['title'], 'Sem título'),
          authors: authors.isEmpty ? ['Autor desconhecido'] : authors,
          coverUrl: cover is String ? cover : '',
          status: 'Quero Ler',
          publishedDate: text(info['publishedDate'], 'Data desconhecida'),
          addedAt: DateTime.now(),
        ),
      );
    }
    final total = data['totalItems'];
    final next = startIndex + items.length;
    final hasMore =
        items.isNotEmpty && (total is int ? next < total : items.length >= 20);
    return BookSearchPage(
      books: books,
      nextStartIndex: hasMore ? next : null,
      skippedCount: items.length - books.length,
    );
  }

  bool _isQuotaResponse(String body) {
    try {
      final data = jsonDecode(body);
      final errors = data is Map && data['error'] is Map
          ? data['error']['errors']
          : null;
      return errors is List &&
          errors.any(
            (error) =>
                error is Map &&
                const {
                  'dailyLimitExceeded',
                  'userRateLimitExceeded',
                  'rateLimitExceeded',
                  'quotaExceeded',
                }.contains(error['reason']),
          );
    } on FormatException {
      return false;
    }
  }

  // Salva ou atualiza um livro na estante do usuário no Firestore
  static String catalogBookId(String ownerId, String externalId) {
    if (ownerId.isEmpty ||
        ownerId.length > 128 ||
        externalId.isEmpty ||
        externalId.length > 200) {
      throw ArgumentError('Referência de livro inválida');
    }
    final id =
        'catalog_${base64Url.encode(utf8.encode(jsonEncode([1, ownerId, 'book', 'google_books', externalId]))).replaceAll('=', '')}';
    if (id.length > 1400) {
      throw ArgumentError('Referência longa demais');
    }
    return id;
  }

  static String newManualId() =>
      'manual_${base64Url.encode(List.generate(24, (_) => Random.secure().nextInt(256))).replaceAll('=', '')}';

  Future<BookModel> updateManualMetadata(
    BookModel expected, {
    required String title,
    required List<String> authors,
    required String coverUrl,
  }) async {
    final normalizedTitle = title.trim();
    final uri = coverUrl.isEmpty ? null : Uri.tryParse(coverUrl);
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 500 ||
        authors.length > 50 ||
        (uri != null && (uri.scheme != 'https' || uri.host.isEmpty)) ||
        (coverUrl.isNotEmpty && uri == null)) {
      throw ArgumentError('Metadados inválidos');
    }
    final ref = _firestore.collection('books').doc(expected.id);
    BookMetadataConflict? conflict;
    try {
      await _firestore.runTransaction((tx) async {
        conflict = null;
        final data = (await tx.get(ref)).data();
        if (data == null ||
            data['userId'] != expected.userId ||
            data['googleBooksId'] != null ||
            data['publishedDate'] != 'Manual') {
          throw StateError('Registro manual indisponível');
        }
        if (data['title'] != expected.title ||
            jsonEncode(data['authors']) != jsonEncode(expected.authors) ||
            data['coverUrl'] != expected.coverUrl) {
          conflict = const BookMetadataConflict();
          throw conflict!;
        }
        final updated = {
          ...data,
          'title': normalizedTitle,
          'authors': authors,
          'coverUrl': coverUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        tx.set(ref, updated);
        SharingService(
          firestore: _firestore,
        ).mirror(tx, 'books', ref.id, updated);
      });
    } catch (_) {
      if (conflict != null) throw conflict!;
      rethrow;
    }
    return BookModel.fromFirestore(
      await ref.get(const GetOptions(source: Source.server)),
    );
  }

  /// Mesma referência retorna o registro pessoal sem redefinir seu progresso.
  Future<({BookModel book, bool created})> addCatalogBook(
    BookModel book,
  ) async {
    final external = book.googleBooksId;
    if (external == null) throw ArgumentError('Referência de catálogo ausente');
    final id = catalogBookId(book.userId, external);
    final legacy = await _firestore
        .collection('books')
        .where('userId', isEqualTo: book.userId)
        .where('googleBooksId', isEqualTo: external)
        .limit(2)
        .get(const GetOptions(source: Source.server));
    if (legacy.docs.length > 1) throw const DuplicateBookReferences();
    final reference = _firestore
        .collection('books')
        .doc(legacy.docs.isEmpty ? id : legacy.docs.single.id);
    final event = reference.collection('activity').doc();
    bool created;
    try {
      created = await _firestore.runTransaction((tx) async {
        final current = await tx.get(reference);
        if (current.exists) {
          if (current.data()?['userId'] != book.userId ||
              current.data()?['googleBooksId'] != external) {
            throw StateError('Referência alterada');
          }
          return false;
        }
        _writeBook(tx, reference, event, book.copyWith(id: reference.id), null);
        return true;
      });
    } on FirebaseException {
      // Uma disputa pode ser rejeitada pelas regras antes de o SDK repetir o
      // callback. A intenção já foi cumprida apenas se a referência própria
      // estiver confirmada; falha de leitura continua sendo propagada.
      final existing = await reference.get(
        const GetOptions(source: Source.server),
      );
      final data = existing.data();
      if (data == null ||
          data['userId'] != book.userId ||
          data['googleBooksId'] != external ||
          existing.metadata.hasPendingWrites ||
          existing.metadata.isFromCache) {
        rethrow;
      }
      created = false;
    }
    final confirmed = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!confirmed.exists ||
        confirmed.metadata.hasPendingWrites ||
        confirmed.metadata.isFromCache) {
      throw const SharedDataUnconfirmed();
    }
    return (book: BookModel.fromFirestore(confirmed), created: created);
  }

  void _writeBook(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    DocumentReference<Map<String, dynamic>> event,
    BookModel book,
    Map<String, dynamic>? current,
  ) {
    if (current != null && current['userId'] != book.userId) {
      throw StateError('Proprietário divergente');
    }
    final data = {
      ...?current, ...book.toMap(),
      'isShared': current?['isShared'] ?? book.isShared,
      'addedAt': current?['addedAt'] ?? Timestamp.fromDate(book.addedAt),
      // Legado não comprova criação original: nunca atribuir hoje ao passado.
      'createdAt': current == null
          ? FieldValue.serverTimestamp()
          : current['createdAt'],
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (book.googleBooksId == null) data.remove('googleBooksId');
    if (current == null || current['status'] != book.status) {
      final action = current == null ? 'added' : 'status_changed';
      data.addAll({
        'activityAt': FieldValue.serverTimestamp(),
        'latestActivityAt': FieldValue.serverTimestamp(),
        'activityEventId': event.id,
        'activityStatus': book.status,
        'activityAction': action,
      });
      tx.set(event, {
        'userId': book.userId,
        'bookId': ref.id,
        'action': action,
        'beforeStatus': current?['status'],
        'status': book.status,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    } else {
      for (final key in [
        'activityAt',
        'latestActivityAt',
        'activityEventId',
        'activityStatus',
        'activityAction',
      ]) {
        if (current.containsKey(key)) {
          data[key] = current[key];
        } else {
          data.remove(key);
        }
      }
    }
    tx.set(ref, data);
    SharingService(firestore: _firestore).mirror(tx, 'books', ref.id, data);
  }

  Future<void> saveBook(BookModel book) async {
    // Se o livro já tem ID e existe no banco, atualiza. Caso contrário, gera novo ID.
    final docRef = book.id.isEmpty
        ? _firestore.collection('books').doc()
        : _firestore.collection('books').doc(book.id);

    final finalBook = book.id.isEmpty ? book.copyWith(id: docRef.id) : book;
    final event = docRef.collection('activity').doc();

    await _firestore.runTransaction((tx) async {
      final current = (await tx.get(docRef)).data();
      _writeBook(tx, docRef, event, finalBook, current);
    });
  }

  Stream<List<Map<String, dynamic>>> streamBookActivity(String id) => _firestore
      .collection('books')
      .doc(id)
      .collection('activity')
      .orderBy('occurredAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  // Remove um livro da estante
  Future<void> deleteBook(String bookId) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('books').doc(bookId));
    batch.delete(_firestore.collection('shared_books').doc(bookId));
    await batch.commit();
  }

  Future<void> setVisibility(String id, bool value) => SharingService(
    firestore: _firestore,
  ).publish('books', id, isShared: value);

  Stream<List<BookModel>> streamSharedBooks(String uid) => _firestore
      .collection('shared_books')
      .where('userId', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        if (s.metadata.isFromCache || s.metadata.hasPendingWrites) {
          throw const SharedDataUnconfirmed();
        }
        return s.docs.map(BookModel.fromFirestore).toList();
      });

  Stream<BookModel?> watchSharedBook(String id) => _firestore
      .collection('shared_books')
      .doc(id)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) =>
            s.metadata.isFromCache || s.metadata.hasPendingWrites || !s.exists
            ? null
            : BookModel.fromFirestore(s),
      );

  // Stream que retorna os livros de um usuário específico
  Stream<List<BookModel>> streamUserBooks(String userId) {
    return _firestore
        .collection('books')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final books = snapshot.docs
              .map((doc) => BookModel.fromFirestore(doc))
              .toList();
          unawaited(
            SharingService(firestore: _firestore)
                .publishOwn('books', snapshot.docs.map((d) => d.id))
                .catchError((Object _) {}),
          );
          books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return books;
        });
  }

  // Consultas pessoais e compartilhadas separadas, com cancelamento conjunto.
  Stream<List<BookModel>> streamCoupleFeed(String userId, String? partnerId) {
    late StreamController<List<BookModel>> controller;
    StreamSubscription? mineSubscription;
    StreamSubscription? partnerSubscription;
    var mine = <BookModel>[];
    var theirs = <BookModel>[];
    DateTime? started;
    var cancelled = false;
    void emit() {
      if (cancelled) return;
      final books =
          [...mine, ...theirs]
              .map(
                (b) => b.copyWith(
                  feedVisible:
                      b.activityAt != null &&
                      b.activityStatus != null &&
                      b.activityAction != null &&
                      (partnerId == null ||
                          (started != null &&
                              !b.activityAt!.isBefore(started!))),
                ),
              )
              .toList()
            ..sort(
              (a, b) => (b.activityAt ?? DateTime(1970)).compareTo(
                a.activityAt ?? DateTime(1970),
              ),
            );
      controller.add(books);
    }

    controller = StreamController<List<BookModel>>(
      onListen: () async {
        try {
          if (partnerId != null) {
            final own = await _firestore
                .collection('users')
                .doc(userId)
                .get(const GetOptions(source: Source.server));
            final code = own.data()?['relationshipId'];
            if (code is String) {
              final invite = await _firestore
                  .collection('partner_invites')
                  .doc(code)
                  .get(const GetOptions(source: Source.server));
              started = (invite.data()?['decidedAt'] as Timestamp?)?.toDate();
            }
          }
          if (cancelled) return;
          mineSubscription = streamUserBooks(userId).listen((b) {
            mine = b;
            emit();
          }, onError: controller.addError);
          if (partnerId != null) {
            partnerSubscription = streamSharedBooks(partnerId).listen(
              (b) {
                theirs = b;
                emit();
              },
              onError: (Object e) {
                theirs = [];
                emit();
                controller.addError(e);
              },
            );
          }
        } catch (e, stack) {
          if (!cancelled) controller.addError(e, stack);
        }
      },
      onCancel: () async {
        cancelled = true;
        mine.clear();
        theirs.clear();
        await mineSubscription?.cancel();
        await partnerSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
