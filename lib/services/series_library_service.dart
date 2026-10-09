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
  }) : repository = repository ?? FirestoreMediaLibraryRepository(),
       queries = queries ?? FirestoreLibraryQueryRepository(),
       catalog = catalog ?? SeriesCatalog.configured(),
       progress = progress ?? SeriesProgressService();
  final MediaLibraryRepository repository;
  final LibraryQueryRepository queries;
  final SeriesCatalog catalog;
  final SeriesProgressService progress;

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
    return _record(await repository.save(prepared));
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
