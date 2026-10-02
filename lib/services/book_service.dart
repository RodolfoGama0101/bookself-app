import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../data/models/book_model.dart';

class BookService {
  BookService({FirebaseFirestore? firestore}) : _database = firestore;

  final FirebaseFirestore? _database;
  FirebaseFirestore get _firestore => _database ?? FirebaseFirestore.instance;

  static const String _googleBooksApiKey =
      'AIzaSyBOwkyhx8GhZeByri7DSF7KRePM9L_XPI4';

  // Busca livros usando a Google Books API
  Future<List<BookModel>> searchGoogleBooks(String query) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query);
    final url =
        'https://www.googleapis.com/books/v1/volumes?q=$encodedQuery&maxResults=20&key=$_googleBooksApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?;

        if (items == null) return [];

        List<BookModel> results = [];
        for (var item in items) {
          final volumeInfo = item['volumeInfo'];
          if (volumeInfo == null) continue;

          // Extrai informações com fallbacks
          final title = volumeInfo['title'] ?? 'Sem Título';

          List<String> authors = [];
          if (volumeInfo['authors'] != null) {
            authors = List<String>.from(volumeInfo['authors']);
          } else {
            authors = ['Autor Desconhecido'];
          }

          // Busca a imagem de capa em melhor resolução possível
          String coverUrl = '';
          if (volumeInfo['imageLinks'] != null) {
            final imageLinks = volumeInfo['imageLinks'];
            coverUrl =
                imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'] ?? '';
            // Força HTTPS nas imagens da API do Google
            if (coverUrl.startsWith('http://')) {
              coverUrl = coverUrl.replaceFirst('http://', 'https://');
            }
          }

          final publishedDate =
              volumeInfo['publishedDate'] ?? 'Data Desconhecida';

          results.add(
            BookModel(
              id:
                  item['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              userId: '', // Será preenchido ao salvar na estante do usuário
              title: title,
              authors: authors,
              coverUrl: coverUrl,
              status: 'Quero Ler', // Padrão inicial
              publishedDate: publishedDate,
              addedAt: DateTime.now(),
            ),
          );
        }
        return results;
      } else {
        throw Exception(
          'Erro ao buscar livros na API (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Erro ao buscar livros: $e');
      rethrow;
    }
  }

  // Salva ou atualiza um livro na estante do usuário no Firestore
  Future<void> saveBook(BookModel book) async {
    try {
      // Se o livro já tem ID e existe no banco, atualiza. Caso contrário, gera novo ID.
      final docRef = book.id.isEmpty
          ? _firestore.collection('books').doc()
          : _firestore.collection('books').doc(book.id);

      final finalBook = book.id.isEmpty ? book.copyWith(id: docRef.id) : book;

      await docRef.set(finalBook.toMap());
      print('Livro salvo com sucesso no Firestore: ${finalBook.title}');
    } catch (e) {
      print('Erro ao salvar livro no Firestore: $e');
      rethrow;
    }
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
