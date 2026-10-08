import 'media_model.dart';
import 'couple_record.dart';

class MovieRecord {
  MovieRecord(this.entry, this.catalog) {
    if (entry.mediaType != MediaType.movie ||
        catalog.identity.mediaType != MediaType.movie ||
        entry.ownerId != catalog.ownerId ||
        entry.catalogId != catalog.id) {
      throw const FormatException('Filme pessoal inconsistente');
    }
  }
  final LibraryEntry entry;
  final CatalogItem catalog;
  String get title => catalog.metadata.title;
  int? get year => catalog.metadata.toMap()['releaseYear'] as int?;
  String get cover => catalog.metadata.toMap()['coverUrl'] as String? ?? '';
  bool get watched => entry.state!.status == 'watched';
  String get statusLabel => watched ? 'Assistido' : 'Quero assistir';
  String? get watchedOn => entry.state!.date;
  CoupleSelection get selection => CoupleSelection(
    type: MediaType.movie,
    title: title,
    subtitle: year?.toString() ?? '',
    source: 'library',
    reference: catalog.identity.key,
  );
}
