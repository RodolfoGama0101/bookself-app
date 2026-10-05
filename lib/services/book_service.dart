import 'firebase_environment.dart';
import 'dart:convert';
import '../data/models/book_search_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../data/models/book_model.dart';
import '../utils/error_handler.dart';

class BookService {
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
  Future<void> saveBook(BookModel book) async {
    // Se o livro já tem ID e existe no banco, atualiza. Caso contrário, gera novo ID.
    final docRef = book.id.isEmpty
        ? _firestore.collection('books').doc()
        : _firestore.collection('books').doc(book.id);

    final finalBook = book.id.isEmpty ? book.copyWith(id: docRef.id) : book;

    await docRef.set(finalBook.toMap());
  }

  // Remove um livro da estante
  Future<void> deleteBook(String bookId) async {
    await _firestore.collection('books').doc(bookId).delete();
  }

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
          books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return books;
        });
  }

  // Stream unificada de atividades recentes do casal (Feed)
  // Como o Firestore limita queries com 'in' em múltiplos ids a 30 elementos, e queremos tempo real,
  // podemos combinar streams ou fazer uma query direta caso tenhamos os ids
  Stream<List<BookModel>> streamCoupleFeed(String userId, String? partnerId) {
    List<String> ids = [userId];
    if (partnerId != null && partnerId.isNotEmpty) {
      ids.add(partnerId);
    }

    return _firestore
        .collection('books')
        .where('userId', whereIn: ids)
        .snapshots()
        .map((snapshot) {
          final books = snapshot.docs
              .map((doc) => BookModel.fromFirestore(doc))
              .toList();
          books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return books;
        });
  }
}
