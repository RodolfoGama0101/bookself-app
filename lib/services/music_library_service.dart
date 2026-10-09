import '../data/models/media_model.dart';
import '../data/models/music_record.dart';
import 'media_library_repository.dart';
import 'library_query_service.dart';
import 'music_catalog.dart';

class MusicLibraryService {
  static const enabled =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS') ||
      bool.fromEnvironment('USE_MUSIC_LIBRARY');
  MusicLibraryService({
    MediaLibraryRepository? repository,
    LibraryQueryRepository? queries,
    MusicCatalog? catalog,
  }) : repository = repository ?? FirestoreMediaLibraryRepository(),
       queries = queries ?? FirestoreLibraryQueryRepository(),
       catalog = catalog ?? MusicCatalog.configured();
  final MediaLibraryRepository repository;
  final LibraryQueryRepository queries;
  final MusicCatalog catalog;

  CatalogItem prepare(
    String owner,
    MediaMetadata metadata, {
    CatalogIdentity? identity,
  }) {
    if (!isMusicType(metadata.mediaType) ||
        metadata.title.length > 300 ||
        (metadata.toMap()['artists'] as List).join(', ').length > 300) {
      throw const FormatException('Metadados musicais inválidos');
    }
    return repository.newCatalog(
      ownerId: owner,
      metadata: metadata,
      identity: identity,
      fetchedAt: identity == null ? null : DateTime.now(),
    );
  }

  Future<MusicRecord> save(CatalogItem prepared) async {
    if (!isMusicType(prepared.identity.mediaType)) {
      throw const FormatException('Cadastro de outra mídia');
    }
    return _record(await repository.save(prepared));
  }

  Future<MusicRecord> _record(LibraryEntry entry) async {
    if (!isMusicType(entry.mediaType)) {
      throw const FormatException('Entrada de outra mídia');
    }
    final found = await repository.readCatalog(entry.ownerId, entry.catalogId);
    if (found == null) throw const FormatException('Metadados ausentes');
    return MusicRecord(entry, found);
  }

  Future<MusicRecord> read(String owner, String id) async {
    final found = await repository.readEntry(owner, id);
    if (found == null) throw StateError('Seleção musical não encontrada');
    if (found.ownerId != owner) throw const FormatException('Dono divergente');
    return _record(found);
  }

  Future<LibraryPage<MusicRecord>> page(
    String owner, {
    required MediaType type,
    LibraryCursor? after,
  }) async {
    if (!isMusicType(type)) {
      throw const FormatException('Tipo musical inválido');
    }
    final page = await queries.readMediaPage(owner, type: type, after: after);
    final rows = <MusicRecord>[];
    for (final entry in page.items) {
      if (entry.ownerId != owner) {
        throw const FormatException('Dono divergente');
      }
      rows.add(await _record(entry));
    }
    return LibraryPage(rows, page.next);
  }

  Future<int> count(String owner, MediaType type) =>
      queries.countMedia(owner, type: type);
  Future<MusicRecord> favorite(MusicRecord music, bool value) async => _record(
    await repository.updatePersonal(
      music.entry.ownerId,
      music.entry.id,
      expectedRevision: music.entry.revision,
      state: null,
      favorite: value,
    ),
  );
  void close() => catalog.close();
}
