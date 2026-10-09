import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/media_model.dart';
import '../data/models/series_record.dart';
import 'firebase_environment.dart';
import 'media_library_repository.dart';

/// Metadados de episódio e marcações privadas; nenhum título/sinopse é armazenado.
class SeriesProgressService {
  SeriesProgressService({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;
  DocumentReference<Map<String, dynamic>> _ref(String owner, String entry) {
    requireDocumentId(owner);
    requireDocumentId(entry);
    return _db
        .collection('libraries')
        .doc(owner)
        .collection('series')
        .doc(entry);
  }

  String newEpisodeId() => _db.collection('libraries').doc().id;
  Future<SeriesProgress> read(String owner, String entry) async {
    final ref = _ref(owner, entry);
    final doc = await ref.get(const GetOptions(source: Source.server));
    final rows = await ref
        .collection('episodes')
        .where('schemaVersion', isEqualTo: 1)
        .limit(501)
        .get(const GetOptions(source: Source.server));
    if (rows.docs.length > 500) {
      throw StateError('Limite de episódios excedido');
    }
    final data = doc.data();
    final episodes =
        rows.docs.map((d) => SeriesEpisode.fromMap(d.id, d.data())).toList()
          ..sort((a, b) {
            final s = a.season.compareTo(b.season);
            return s == 0 ? a.number.compareTo(b.number) : s;
          });
    return SeriesProgress(
      complete: data?['complete'] == true,
      ended: data?['ended'] == true,
      paused: data?['paused'] == true,
      revision: data?['revision'] as int? ?? 0,
      episodes: episodes,
    );
  }

  Future<void> configure(
    String owner,
    String entry,
    SeriesProgress current, {
    required bool complete,
    required bool ended,
    required bool paused,
  }) async {
    final ref = _ref(owner, entry);
    await _write(owner, entry, (tx) async {
      final data = (await tx.get(ref)).data();
      if ((data?['revision'] ?? 0) != current.revision) {
        throw const MediaRevisionConflict();
      }
      tx.set(ref, {
        'schemaVersion': 1,
        'complete': complete,
        'ended': ended,
        'paused': paused,
        'revision': current.revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Retry repete uma intenção explícita; nunca inverte o estado corrente.
  Future<void> saveEpisode(
    String owner,
    String entry,
    SeriesEpisode episode, {
    required bool watched,
  }) async {
    if (watched && !episode.released(DateTime.now())) {
      throw const FormatException('Episódio indisponível');
    }
    final ref = _ref(owner, entry).collection('episodes').doc(episode.id);
    await _write(owner, entry, (tx) async {
      final data = (await tx.get(ref)).data();
      final revision = data?['revision'] as int? ?? 0;
      final values = {...episode.toMap(), 'watched': watched};
      if (data != null && values.entries.every((v) => data[v.key] == v.value)) {
        return;
      }
      if (revision != episode.revision) throw const MediaRevisionConflict();
      final projection = _db
          .collection('shared_series')
          .doc(owner)
          .collection('entries')
          .doc(entry)
          .collection('episodes')
          .doc(episode.id);
      tx.set(projection, {
        'schemaVersion': 1,
        'season': episode.season,
        'number': episode.number,
        'watched': watched,
        'revision': revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(ref, {
        'schemaVersion': 1,
        ...values,
        'revision': revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _write(
    String owner,
    String entry,
    Future<void> Function(Transaction) action,
  ) async {
    MediaRevisionConflict? conflict;
    try {
      await _db.runTransaction((tx) async {
        conflict = null;
        final parent = await tx.get(
          _db
              .collection('libraries')
              .doc(owner)
              .collection('entries')
              .doc(entry),
        );
        if (parent.data()?['mediaType'] != 'series' ||
            parent.data()?['ownerId'] != owner) {
          throw const FormatException('Série ausente');
        }
        try {
          await action(tx);
        } on MediaRevisionConflict catch (e) {
          conflict = e;
          rethrow;
        }
      });
    } catch (_) {
      if (conflict != null) throw conflict!;
      rethrow;
    }
  }
}
