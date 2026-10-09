import 'series_sharing_service.dart';
import '../data/models/media_model.dart';
import '../data/models/series_record.dart';
import 'media_library_repository.dart';
import 'library_query_service.dart';
import 'series_catalog.dart';
import 'series_progress_service.dart';

class SeriesLibraryService {
  static const enabled =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS') ||
      bool.fromEnvironment('USE_SERIES_LIBRARY');
  SeriesLibraryService({
    MediaLibraryRepository? repository,
    LibraryQueryRepository? queries,
    SeriesCatalog? catalog,
    SeriesProgressService? progress,
    SeriesSharingService? sharing,
  }) : repository = repository ?? FirestoreMediaLibraryRepository(),
       queries = queries ?? FirestoreLibraryQueryRepository(),
       catalog = catalog ?? SeriesCatalog.configured(),
       progress = progress ?? SeriesProgressService(),
       sharing =
           sharing ?? SeriesSharingService(firestore: progress?.firestore);
  final MediaLibraryRepository repository;
  final LibraryQueryRepository queries;
  final SeriesCatalog catalog;
  final SeriesProgressService progress;
  final SeriesSharingService sharing;

  CatalogItem prepare(
    String owner,
    MediaMetadata metadata, {
    CatalogIdentity? identity,
  }) {
    if (metadata.mediaType != MediaType.series || metadata.title.length > 300) {
      throw const FormatException('Metadados de série inválidos');
    }
    return repository.newCatalog(
      ownerId: owner,
      metadata: metadata,
      identity: identity,
      fetchedAt: identity == null ? null : DateTime.now(),
    );
  }

  Future<SeriesRecord> save(CatalogItem prepared) async {
    if (prepared.identity.mediaType != MediaType.series) {
      throw const FormatException('Cadastro de outra mídia');
    }
    final row = await _record(await repository.save(prepared));
    await sharing.initialize(row.entry, row.catalog);
    return row;
  }

  Future<SeriesRecord> _record(LibraryEntry entry) async {
    if (entry.mediaType != MediaType.series) {
      throw const FormatException('Entrada de outra mídia');
    }
    final found = await repository.readCatalog(entry.ownerId, entry.catalogId);
    if (found == null) throw const FormatException('Metadados ausentes');
    return SeriesRecord(
      entry,
      found,
      await progress.read(entry.ownerId, entry.id),
    );
  }

  Future<SeriesRecord> read(String owner, String id) async {
    final found = await repository.readEntry(owner, id);
    if (found == null) throw StateError('Série não encontrada');
    if (found.ownerId != owner) throw const FormatException('Dono divergente');
    return _record(found);
  }

  Future<SeriesRecord> refreshEpisodes(SeriesRecord record) async {
    if (record.catalog.identity.isManual || !catalog.available) {
      throw const FormatException('Esta série não possui catálogo disponível');
    }
    final detailed = await catalog.details(record.catalog.identity);
    return applyEpisodes(record, detailed);
  }

  /// Importação incremental: conserva episódios ausentes e intenções pessoais.
  /// Falha parcial pode ser repetida; nunca redefine watched ou pausa pelo catálogo.
  Future<SeriesRecord> applyEpisodes(
    SeriesRecord record,
    SeriesCatalogItem detailed,
  ) async {
    if (record.catalog.identity.key != detailed.identity.key) {
      throw const FormatException('Referência de detalhes divergente');
    }
    final owner = record.entry.ownerId, id = record.entry.id;
    final current = await read(owner, id);
    final previous = {for (final e in current.progress.episodes) e.id: e};
    final incoming = {for (final e in detailed.episodes) e.id: e};
    if (incoming.length != detailed.episodes.length ||
        {...previous.keys, ...incoming.keys}.length > 500) {
      throw const FormatException(
        'Limite ou identidade de episódios inválidos',
      );
    }
    // Uma correção de disponibilidade não pode apagar uma marcação existente.
    if (incoming.values.any(
      (e) => previous[e.id]?.watched == true && !e.released(DateTime.now()),
    )) {
      throw const FormatException(
        'O catálogo tornou indisponível um episódio já visto',
      );
    }
    for (final e in incoming.values) {
      final old = previous[e.id];
      await progress.saveEpisode(
        owner,
        id,
        SeriesEpisode(
          id: e.id,
          season: e.season,
          number: e.number,
          availableOn: e.availableOn,
          available: e.available,
          revision: old?.revision ?? 0,
        ),
        watched: old?.watched ?? false,
      );
    }
    final latest = await progress.read(owner, id);
    await progress.configure(
      owner,
      id,
      latest,
      complete:
          detailed.complete &&
          latest.episodes
              .where((e) => e.season > 0)
              .every((e) => incoming.containsKey(e.id)),
      ended: detailed.ended,
      paused: latest.paused,
    );
    return read(owner, id);
  }

  Future<LibraryPage<SeriesRecord>> page(
    String owner, {
    LibraryCursor? after,
  }) async {
    final page = await queries.readMediaPage(
      owner,
      type: MediaType.series,
      after: after,
    );
    final rows = <SeriesRecord>[];
    for (final entry in page.items) {
      if (entry.ownerId != owner) {
        throw const FormatException('Dono divergente');
      }
      rows.add(await _record(entry));
    }
    return LibraryPage(rows, page.next);
  }

  Future<int> count(String owner) =>
      queries.countMedia(owner, type: MediaType.series);
  void close() => catalog.close();
}
