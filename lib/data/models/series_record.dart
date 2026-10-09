import 'media_model.dart';
import 'couple_record.dart';

class SeriesEpisode {
  SeriesEpisode({
    required this.id,
    required this.season,
    required this.number,
    this.availableOn,
    this.available = false,
    this.watched = false,
    this.revision = 0,
  }) {
    requireDocumentId(id);
    if (season < 0 ||
        season > 999 ||
        number < 1 ||
        number > 9999 ||
        revision < 0) {
      throw const FormatException('Episódio inválido');
    }
    if (availableOn != null) requireCivilDate(availableOn!);
  }
  final String id;
  final int season, number, revision;
  final String? availableOn;
  final bool available, watched;
  bool released(DateTime now) => availableOn == null
      ? available
      : availableOn!.compareTo(civilDay(now)) <= 0;
  String get label => 'Temporada $season · Episódio $number';
  Map<String, dynamic> toMap() => {
    'season': season,
    'number': number,
    'availableOn': availableOn,
    'available': available,
    'watched': watched,
  };
  factory SeriesEpisode.fromMap(String id, Map<String, dynamic> data) =>
      SeriesEpisode(
        id: id,
        season: data['season'] as int,
        number: data['number'] as int,
        availableOn: data['availableOn'] as String?,
        available: data['available'] as bool,
        watched: data['watched'] as bool,
        revision: data['revision'] as int,
      );
}

String civilDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class SeriesProgress {
  SeriesProgress({
    this.complete = false,
    this.ended = false,
    this.paused = false,
    this.revision = 0,
    Iterable<SeriesEpisode> episodes = const [],
  }) : episodes = List.unmodifiable(episodes);
  final bool complete, ended, paused;
  final int revision;
  final List<SeriesEpisode> episodes;
  String statusAt(DateTime now) {
    if (paused) return 'paused';
    final regular = episodes.where((e) => e.season > 0).toList();
    final available = regular.where((e) => e.released(now)).toList();
    if (!complete || available.isEmpty || available.any((e) => !e.watched)) {
      return 'in_progress';
    }
    if (ended && regular.every((e) => e.released(now) && e.watched)) {
      return 'completed';
    }
    return 'up_to_date';
  }
}

class SeriesRecord {
  SeriesRecord(this.entry, this.catalog, this.progress) {
    if (entry.mediaType != MediaType.series ||
        catalog.identity.mediaType != MediaType.series ||
        entry.ownerId != catalog.ownerId ||
        entry.catalogId != catalog.id) {
      throw const FormatException('Série pessoal inconsistente');
    }
  }
  final LibraryEntry entry;
  final CatalogItem catalog;
  final SeriesProgress progress;
  String get title => catalog.metadata.title;
  int? get year => catalog.metadata.toMap()['releaseYear'] as int?;
  String get cover => catalog.metadata.toMap()['coverUrl'] as String? ?? '';
  String get status => progress.statusAt(DateTime.now());
  String get statusLabel => seriesStatusLabel(status);
  CoupleSelection selection([SeriesEpisode? episode]) => CoupleSelection(
    type: MediaType.series,
    title: title,
    source: 'library',
    reference: catalog.identity.key,
    episode: episode == null
        ? null
        : {
            'id': episode.id,
            'season': episode.season,
            'number': episode.number,
          },
  );
}

String seriesStatusLabel(String status) => switch (status) {
  'up_to_date' => 'Em dia',
  'completed' => 'Concluída',
  'paused' => 'Pausada',
  _ => 'Em andamento',
};
