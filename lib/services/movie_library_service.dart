import '../data/models/media_model.dart';
import '../data/models/movie_record.dart';
import '../data/models/couple_record.dart';
import 'media_library_repository.dart';
import 'library_query_service.dart';
import 'movie_catalog.dart';

class MovieLibraryService {
  static const enabled =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS') ||
      bool.fromEnvironment('USE_MOVIE_LIBRARY');
  MovieLibraryService({
    MediaLibraryRepository? repository,
    LibraryQueryRepository? queries,
    MovieCatalog? catalog,
  }) : repository = repository ?? FirestoreMediaLibraryRepository(),
       queries = queries ?? FirestoreLibraryQueryRepository(),
       catalog = catalog ?? MovieCatalog.configured();
  final MediaLibraryRepository repository;
  final LibraryQueryRepository queries;
  final MovieCatalog catalog;

  CatalogItem prepare(
    String owner,
    MediaMetadata metadata, {
    CatalogIdentity? identity,
  }) {
    if (metadata.mediaType != MediaType.movie || metadata.title.length > 300) {
      throw const FormatException('Metadados de filme inválidos');
    }
    return repository.newCatalog(
      ownerId: owner,
      metadata: metadata,
      identity: identity,
      fetchedAt: identity == null ? null : DateTime.now(),
    );
  }

  Future<MovieRecord> save(CatalogItem prepared) async {
    if (prepared.identity.mediaType != MediaType.movie) {
      throw const FormatException('Cadastro de outra mídia');
    }
    return _record(await repository.save(prepared));
  }

  Future<MovieRecord> _record(LibraryEntry entry) async {
    if (entry.mediaType != MediaType.movie) {
      throw const FormatException('Entrada de outra mídia');
    }
    final found = await repository.readCatalog(entry.ownerId, entry.catalogId);
    if (found == null) throw const FormatException('Metadados ausentes');
    return MovieRecord(entry, found);
  }

  Future<MovieRecord> read(String owner, String id) async {
    final found = await repository.readEntry(owner, id);
    if (found == null) throw StateError('Filme não encontrado');
    if (found.ownerId != owner) throw const FormatException('Dono divergente');
    return _record(found);
  }

  Future<LibraryPage<MovieRecord>> page(
    String owner, {
    LibraryCursor? after,
  }) async {
    final page = await queries.readMediaPage(
      owner,
      type: MediaType.movie,
      after: after,
    );
    final rows = <MovieRecord>[];
    for (final entry in page.items) {
      if (entry.ownerId != owner) {
        throw const FormatException('Dono divergente');
      }
      rows.add(await _record(entry));
    }
    return LibraryPage(rows, page.next);
  }

  Future<int> count(String owner) =>
      queries.countMedia(owner, type: MediaType.movie);
  Future<MovieRecord> update(
    MovieRecord movie, {
    required bool watched,
    String? date,
  }) async {
    if (date != null) coupleDate(DateTime.parse(date));
    final entry = await repository.updatePersonal(
      movie.entry.ownerId,
      movie.entry.id,
      expectedRevision: movie.entry.revision,
      state: MediaState(
        MediaType.movie,
        watched ? 'watched' : 'planned',
        date: watched ? date : null,
      ),
      favorite: false,
    );
    return _record(entry);
  }

  void close() => catalog.close();
}
