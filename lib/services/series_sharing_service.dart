import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/series_record.dart';
import '../data/models/media_model.dart';
import 'firebase_environment.dart';

class SharedSeries {
  SharedSeries(this.id, this.title, this.reference);
  final String id, title, reference;
}

/// Projeção por série: números e marcações, sem títulos/sinopses de episódios.
class SeriesSharingService {
  SeriesSharingService({this.firestore});
  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseEnvironment.firestore;
  DocumentReference<Map<String, dynamic>> _visibility(
    String owner,
    String entry,
  ) => _db
      .collection('libraries')
      .doc(owner)
      .collection('series_visibility')
      .doc(entry);
  DocumentReference<Map<String, dynamic>> _shared(String owner, String entry) =>
      _db
          .collection('shared_series')
          .doc(owner)
          .collection('entries')
          .doc(entry);
  Future<bool> visible(String owner, String entry) async =>
      (await _visibility(
        owner,
        entry,
      ).get(const GetOptions(source: Source.server))).data()?['visible'] ==
      true;

  /// Inicialização única não reexibe uma série ocultada em outra sessão.
  Future<void> initialize(LibraryEntry entry, CatalogItem catalog) =>
      _set(entry, catalog, null);
  Future<void> setVisible(SeriesRecord series, bool visible) =>
      _set(series.entry, series.catalog, visible);
  Future<void> _set(
    LibraryEntry entry,
    CatalogItem catalog,
    bool? visible,
  ) async {
    requireDocumentId(entry.ownerId);
    requireDocumentId(entry.id);
    final ref = _visibility(entry.ownerId, entry.id),
        shared = _shared(entry.ownerId, entry.id);
    await _db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (visible == null && current.exists) return;
      final source = await tx.get(
        _db
            .collection('libraries')
            .doc(entry.ownerId)
            .collection('entries')
            .doc(entry.id),
      );
      final metadata = await tx.get(
        _db
            .collection('libraries')
            .doc(entry.ownerId)
            .collection('catalog')
            .doc(entry.catalogId),
      );
      if (source.data()?['catalogId'] != catalog.id ||
          source.data()?['mediaType'] != 'series' ||
          metadata.data()?['catalogKey'] != catalog.identity.key) {
        throw const FormatException('Série divergente');
      }
      tx.set(ref, {
        'schemaVersion': 1,
        'visible': visible ?? true,
        'revision': (current.data()?['revision'] as int? ?? 0) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (visible ?? true) {
        tx.set(shared, {
          'schemaVersion': 1,
          'title': catalog.metadata.title,
          'reference': catalog.identity.key,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(shared);
      }
    });
  }

  Stream<List<SharedSeries>> series(String owner) {
    requireDocumentId(owner);
    return _db
        .collection('shared_series')
        .doc(owner)
        .collection('entries')
        .limit(501)
        .snapshots(includeMetadataChanges: true)
        .map((s) {
          if (s.metadata.isFromCache ||
              s.metadata.hasPendingWrites ||
              s.docs.length > 500) {
            throw StateError('Compartilhamento não confirmado');
          }
          return s.docs
              .map(
                (d) => SharedSeries(
                  d.id,
                  d.data()['title'] as String,
                  d.data()['reference'] as String,
                ),
              )
              .toList();
        });
  }

  Stream<List<SeriesEpisode>> episodes(String owner, String entry) {
    requireDocumentId(owner);
    requireDocumentId(entry);
    return _shared(owner, entry)
        .collection('episodes')
        .limit(501)
        .snapshots(includeMetadataChanges: true)
        .map((s) {
          if (s.metadata.isFromCache ||
              s.metadata.hasPendingWrites ||
              s.docs.length > 500) {
            throw StateError('Progresso não confirmado');
          }
          return s.docs
              .map(
                (d) => SeriesEpisode(
                  id: d.id,
                  season: d.data()['season'] as int,
                  number: d.data()['number'] as int,
                  watched: d.data()['watched'] as bool,
                  available: true,
                ),
              )
              .toList();
        });
  }
}
