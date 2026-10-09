import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/media_model.dart';
import '../data/models/couple_record.dart';
import 'firebase_environment.dart';
import 'library_query_service.dart';
import 'music_catalog.dart';

class MusicListen {
  MusicListen(this.id, this.owner, this.entry, this.date, this.createdAt);
  final String id, owner, entry, date;
  final Timestamp createdAt;
  factory MusicListen.fromMap(String id, Map<String, dynamic> data) {
    requireVersion(data);
    requireDocumentId(id);
    requireDocumentId(data['ownerId'] as String);
    requireDocumentId(data['entryId'] as String);
    requireCivilDate(data['listenedOn'] as String);
    if (data['revision'] != 1 || data['createdAt'] is! Timestamp) {
      throw const FormatException('Escuta inválida');
    }
    return MusicListen(
      id,
      data['ownerId'],
      data['entryId'],
      data['listenedOn'],
      data['createdAt'],
    );
  }
}

/// Escutas imutáveis e privadas. Uma identidade por intenção, não por data.
class MusicListenService {
  MusicListenService({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;
  CollectionReference<Map<String, dynamic>> _collection(String owner) {
    requireDocumentId(owner);
    return _db.collection('libraries').doc(owner).collection('listens');
  }

  String newId(String owner) => _collection(owner).doc().id;
  Future<void> save(String owner, String entry, String id, String date) async {
    requireDocumentId(entry);
    requireDocumentId(id);
    requireCivilDate(date);
    coupleDate(DateTime.parse(date));
    final ref = _collection(owner).doc(id);
    await _db.runTransaction((tx) async {
      final previous = await tx.get(ref);
      final personal = await tx.get(
        _db.collection('libraries').doc(owner).collection('entries').doc(entry),
      );
      if (!personal.exists) {
        throw StateError('Seleção não encontrada');
      }
      final music = LibraryEntry.fromMap(personal.id, personal.data()!);
      if (music.ownerId != owner || !isMusicType(music.mediaType)) {
        throw const FormatException('Escuta de outra mídia ou pessoa');
      }
      if (previous.exists) {
        final listen = MusicListen.fromMap(id, previous.data()!);
        if (listen.owner != owner ||
            listen.entry != entry ||
            listen.date != date) {
          throw const FormatException('Identidade de escuta já utilizada');
        }
        return;
      }
      tx.set(ref, {
        'schemaVersion': 1,
        'ownerId': owner,
        'entryId': entry,
        'listenedOn': date,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': 1,
      });
    });
  }

  Future<LibraryPage<MusicListen>> page(
    String owner,
    String entry, {
    LibraryCursor? after,
  }) async {
    requireDocumentId(entry);
    final scope = 'listens/$owner/$entry';
    if (after != null && after.scope != scope) {
      throw const FormatException('Cursor de outra escuta');
    }
    Query<Map<String, dynamic>> query = _collection(owner)
        .where('entryId', isEqualTo: entry)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(21);
    if (after != null) {
      query = query.startAfter([after.timestamp, after.documentId]);
    }
    final result = await query.get(const GetOptions(source: Source.server));
    if (result.metadata.isFromCache || result.metadata.hasPendingWrites) {
      throw StateError('Escutas não confirmadas');
    }
    final rows = result.docs
        .take(20)
        .map((doc) => MusicListen.fromMap(doc.id, doc.data()))
        .toList();
    if (rows.any((row) => row.owner != owner || row.entry != entry)) {
      throw const FormatException('Escuta divergente');
    }
    final last = rows.lastOrNull;
    return LibraryPage(
      rows,
      result.docs.length > 20 && last != null
          ? LibraryCursor(
              scope: scope,
              timestamp: last.createdAt,
              documentId: last.id,
            )
          : null,
    );
  }
}
