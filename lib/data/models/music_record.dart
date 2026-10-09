import 'media_model.dart';
import 'couple_record.dart';

class MusicRecord {
  MusicRecord(this.entry, this.catalog) {
    if (!(entry.mediaType == MediaType.track ||
            entry.mediaType == MediaType.album) ||
        entry.mediaType != catalog.identity.mediaType ||
        entry.ownerId != catalog.ownerId ||
        entry.catalogId != catalog.id) {
      throw const FormatException('Seleção musical inconsistente');
    }
  }
  final LibraryEntry entry;
  final CatalogItem catalog;
  String get title => catalog.metadata.title;
  String get artists =>
      (catalog.metadata.toMap()['artists'] as List).join(', ');
  String get cover => catalog.metadata.toMap()['coverUrl'] as String? ?? '';
  String get typeLabel =>
      entry.mediaType == MediaType.track ? 'Faixa' : 'Álbum';
  String? get version =>
      catalog.metadata.toMap()[entry.mediaType == MediaType.track
              ? 'version'
              : 'edition']
          as String?;
  CoupleSelection get selection => CoupleSelection(
    type: entry.mediaType,
    title: title,
    subtitle: artists,
    source: 'library',
    reference: catalog.identity.key,
  );
}
