import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/bible_progress_model.dart';
import 'firebase_environment.dart';

class BibleService {
  BibleService({FirebaseFirestore? firestore}) : _database = firestore;

  final FirebaseFirestore? _database;
  FirebaseFirestore get _firestore =>
      _database ?? FirebaseEnvironment.firestore;

  // Stream do progresso de um livro bíblico específico de um usuário
  Stream<BibleProgressModel?> streamBookProgress(
    String userId,
    String bookName,
  ) => _streamBookProgress(userId, bookName, serverOnly: false);

  /// Reinicia a observação após reconciliação, sem reapresentar cache antigo.
  Stream<BibleProgressModel?> streamBookProgressFromServer(
    String userId,
    String bookName,
  ) => _streamBookProgress(userId, bookName, serverOnly: true);

  Stream<BibleProgressModel?> _streamBookProgress(
    String userId,
    String bookName, {
    required bool serverOnly,
  }) {
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    return _firestore
        .collection('bible_progress')
        .doc(docId)
        .snapshots(includeMetadataChanges: true)
        .where(
          (snapshot) =>
              !snapshot.metadata.hasPendingWrites &&
              (!serverOnly || !snapshot.metadata.isFromCache),
        )
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            return BibleProgressModel.fromFirestore(docSnapshot);
          }
          return null;
        });
  }

  /// Obtém o estado atual do servidor depois de uma escrita confirmada.
  Future<BibleProgressModel?> readBookProgressFromServer(
    String userId,
    String bookName,
  ) async {
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final snapshot = await _firestore
        .collection('bible_progress')
        .doc(docId)
        .get(const GetOptions(source: Source.server));
    // Source.server pode incluir uma sobreposição de escrita local pendente.
    // Não apresente esse valor como confirmado nem permita outra intenção.
    if (snapshot.metadata.hasPendingWrites || snapshot.metadata.isFromCache) {
      throw StateError('O progresso confirmado ainda não está disponível.');
    }
    return snapshot.exists ? BibleProgressModel.fromFirestore(snapshot) : null;
  }

  // Stream de todo o progresso da Bíblia de um usuário específico
  // Retorna um Map estruturado como { NomeDoLivro: ProgressoModel } para busca rápida
  Stream<Map<String, BibleProgressModel>> streamAllProgress(String userId) {
    final confirmedById = <String, BibleProgressModel>{};
    final snapshots = _firestore
        .collection('bible_progress')
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true);
    return snapshots.map((snapshot) {
      final seen = <String>{};
      for (final doc in snapshot.docs) {
        seen.add(doc.id);
        if (doc.metadata.hasPendingWrites) continue;
        final progress = BibleProgressModel.fromFirestore(doc);
        confirmedById[doc.id] = progress;
      }
      // Ausências durante uma escrita local podem ser exclusões ainda não
      // confirmadas; aguarda o próximo snapshot confirmado para removê-las.
      if (!snapshot.metadata.hasPendingWrites) {
        confirmedById.removeWhere((id, _) => !seen.contains(id));
      }
      return {
        for (final progress in confirmedById.values)
          progress.bookName: progress,
      };
    });
  }

  /// Marca/desmarca e retorna a lista somente após confirmar a transação.
  Future<List<int>> toggleChapter(
    String userId,
    String bookName,
    int chapter,
    bool isRead,
  ) async {
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final docRef = _firestore.collection('bible_progress').doc(docId);

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

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

      transaction.set(docRef, {
        'userId': userId,
        'bookName': bookName,
        'readChapters': readChapters,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    final docId = '${userId}_${bookName.replaceAll(' ', '_').toLowerCase()}';
    final docRef = _firestore.collection('bible_progress').doc(docId);

    List<int> readChapters = [];
    if (isRead) {
      // Preenche a lista com todos os capítulos (ex: [1, 2, 3, ..., totalChapters])
      readChapters = List<int>.generate(totalChapters, (index) => index + 1);
    }

    await docRef.set({
      'userId': userId,
      'bookName': bookName,
      'readChapters': readChapters,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return readChapters;
  }
}
