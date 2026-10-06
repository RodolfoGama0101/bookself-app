import 'dart:async';
import 'sharing_service.dart';
import 'firebase_environment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/bible_data.dart';
import '../data/models/bible_progress_model.dart';

class BibleService {
  BibleService({FirebaseFirestore? firestore}) : _database = firestore;

  final FirebaseFirestore? _database;
  FirebaseFirestore get _firestore =>
      _database ?? FirebaseEnvironment.firestore;

  Future<void> setVisibility(String uid, String bookName, bool value) async {
    _validateBook(uid, bookName);
    final id = '${uid}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final ref = _firestore.collection('bible_progress').doc(id);
    await _firestore.runTransaction((tx) async {
      final current = (await tx.get(ref)).data();
      final data = {
        ...?current,
        'userId': uid,
        'bookName': bookName,
        'readChapters': current?['readChapters'] ?? <int>[],
        'updatedAt': FieldValue.serverTimestamp(),
        'isShared': value,
      };
      tx.set(ref, data);
      SharingService(
        firestore: _firestore,
      ).mirror(tx, 'bible_progress', id, data);
    });
  }

  Stream<Map<String, BibleProgressModel>> streamSharedProgress(String uid) =>
      _firestore
          .collection('shared_bible_progress')
          .where('userId', isEqualTo: uid)
          .snapshots(includeMetadataChanges: true)
          .map(
            (s) => s.metadata.isFromCache || s.metadata.hasPendingWrites
                ? <String, BibleProgressModel>{}
                : {
                    for (final d in s.docs)
                      d.data()['bookName'] as String:
                          BibleProgressModel.fromFirestore(d),
                  },
          );

  Stream<BibleProgressModel?> streamSharedBookProgress(
    String uid,
    String name,
  ) => streamSharedProgress(uid).map((all) => all[name]);

  BibleBook _validateBook(String userId, String bookName) {
    if (userId.trim().isEmpty || userId.contains('/')) {
      throw ArgumentError.value(userId, 'userId', 'Proprietário inválido');
    }
    for (final book in BibleData.books) {
      if (book.name == bookName) return book;
    }
    throw ArgumentError.value(bookName, 'bookName', 'Livro bíblico inválido');
  }

  // Stream do progresso de um livro bíblico específico de um usuário
  Stream<BibleProgressModel?> streamBookProgress(
    String userId,
    String bookName,
  ) {
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    return _firestore
        .collection('bible_progress')
        .doc(docId)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            return BibleProgressModel.fromFirestore(docSnapshot);
          }
          return null;
        });
  }

  // Stream de todo o progresso da Bíblia de um usuário específico
  // Retorna um Map estruturado como { NomeDoLivro: ProgressoModel } para busca rápida
  Stream<Map<String, BibleProgressModel>> streamAllProgress(String userId) {
    return _firestore
        .collection('bible_progress')
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) {
          final Map<String, BibleProgressModel> progressMap = {};
          for (var doc in snapshot.docs) {
            final progress = BibleProgressModel.fromFirestore(doc);
            progressMap[progress.bookName] = progress;
          }
          unawaited(
            SharingService(firestore: _firestore)
                .publishOwn('bible_progress', snapshot.docs.map((d) => d.id))
                .catchError((Object _) {}),
          );
          return progressMap;
        });
  }

  /// Marca/desmarca e retorna a lista somente após confirmar a transação.
  Future<List<int>> toggleChapter(
    String userId,
    String bookName,
    int chapter,
    bool isRead,
  ) async {
    final book = _validateBook(userId, bookName);
    if (chapter < 1 || chapter > book.chapters) {
      throw RangeError.range(chapter, 1, book.chapters, 'chapter');
    }
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final docRef = _firestore.collection('bible_progress').doc(docId);

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      final current = snapshot.data() as Map<String, dynamic>?;
      List<int> readChapters = [];
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        readChapters = List<int>.from(data['readChapters'] ?? []);
      }

      if (isRead) {
        if (!readChapters.contains(chapter)) {
          readChapters.add(chapter);
        }
      } else {
        readChapters.remove(chapter);
      }

      // Ordena os capítulos para consistência no banco
      readChapters.sort();

      final data = {
        ...?current,
        'userId': userId,
        'bookName': bookName,
        'readChapters': readChapters,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(docRef, data);
      SharingService(
        firestore: _firestore,
      ).mirror(transaction, 'bible_progress', docId, data);
      return readChapters;
    });
  }

  /// Marca/desmarca o livro e retorna a lista somente após confirmar a escrita.
  Future<List<int>> markAllChapters(
    String userId,
    String bookName,
    int totalChapters,
    bool isRead,
  ) async {
    final book = _validateBook(userId, bookName);
    if (totalChapters != book.chapters) {
      throw ArgumentError.value(
        totalChapters,
        'totalChapters',
        'O total deve corresponder ao catálogo bíblico',
      );
    }
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final docRef = _firestore.collection('bible_progress').doc(docId);

    List<int> readChapters = [];
    if (isRead) {
      // Preenche a lista com todos os capítulos (ex: [1, 2, 3, ..., totalChapters])
      readChapters = List<int>.generate(totalChapters, (index) => index + 1);
    }

    await _firestore.runTransaction((tx) async {
      final current = (await tx.get(docRef)).data();
      final data = {
        ...?current,
        'userId': userId,
        'bookName': bookName,
        'readChapters': readChapters,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(docRef, data);
      SharingService(
        firestore: _firestore,
      ).mirror(tx, 'bible_progress', docId, data);
    });
    return readChapters;
  }
}
