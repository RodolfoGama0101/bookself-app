import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/series_record.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/series_catalog.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/services/series_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/profile_firestore_fake.dart';

class RefreshCatalog extends SeriesCatalog {
  late SeriesCatalogItem response;
  bool fail = false;
  @override
  bool get available => true;
  @override
  Future<SeriesCatalogItem> details(CatalogIdentity identity) async {
    if (fail) throw StateError('rede indisponível');
    return response;
  }

  @override
  Future<SeriesCatalogPage> search(String query, {String? cursor}) async =>
      SeriesCatalogPage([], null);
}

class RacingProgress extends SeriesProgressService {
  RacingProgress({super.firestore});
  bool race = false;
  @override
  Future<void> saveEpisode(
    String owner,
    String entry,
    SeriesEpisode episode, {
    required bool watched,
  }) async {
    if (race) {
      race = false;
      await super.saveEpisode(owner, entry, episode, watched: true);
    }
    return super.saveEpisode(owner, entry, episode, watched: watched);
  }
}

void main() {
  final identity = CatalogIdentity.external(
    MediaType.series,
    'fixture_video',
    'series',
  );
  final metadata = MediaMetadata(MediaType.series, {
    'title': 'Série de ensaio',
  });
  SeriesEpisode episode(String id, int number, {String? date}) => SeriesEpisode(
    id: id,
    season: 1,
    number: number,
    available: true,
    availableOn: date,
  );
  late ProfileFirestoreFake db;
  late RefreshCatalog catalog;
  late RacingProgress progress;
  late SeriesLibraryService library;
  late SeriesRecord own;
  setUp(() async {
    db = ProfileFirestoreFake();
    catalog = RefreshCatalog();
    progress = RacingProgress(firestore: db);
    library = SeriesLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
      progress: progress,
      catalog: catalog,
    );
    own = await library.save(
      library.prepare('a', metadata, identity: identity),
    );
    catalog.response = SeriesCatalogItem(
      identity,
      metadata,
      complete: true,
      episodes: [episode('one', 1)],
    );
    own = await library.refreshEpisodes(own);
  });
  tearDown(() => db.close());
  test(
    'atualização preserva visto, pausa, ocultação e episódios ausentes; incompleto não conclui',
    () async {
      await progress.saveEpisode(
        'a',
        own.entry.id,
        own.progress.episodes.single,
        watched: true,
      );
      await progress.configure(
        'a',
        own.entry.id,
        own.progress,
        complete: true,
        ended: false,
        paused: true,
      );
      await library.sharing.setVisible(own, false);
      catalog.response = SeriesCatalogItem(
        identity,
        metadata,
        complete: true,
        ended: true,
        episodes: [episode('two', 2)],
      );
      own = await library.refreshEpisodes(own);
      expect(own.progress.episodes, hasLength(2));
      expect(own.progress.episodes.first.watched, true);
      expect(own.progress.episodes.last.watched, false);
      expect(own.progress.complete, false);
      expect(own.progress.paused, true);
      expect(await library.sharing.visible('a', own.entry.id), false);
      final created = own.entry.createdAt;
      own = await library.refreshEpisodes(own);
      expect(own.progress.episodes, hasLength(2));
      expect(own.entry.createdAt, created);
    },
  );
  test(
    'correção para futuro ou outra referência e erro de rede não apagam progresso',
    () async {
      await progress.saveEpisode(
        'a',
        own.entry.id,
        own.progress.episodes.single,
        watched: true,
      );
      final writes = db.writes;
      catalog.response = SeriesCatalogItem(
        identity,
        metadata,
        episodes: [episode('one', 1, date: '9999-01-01')],
      );
      await expectLater(library.refreshEpisodes(own), throwsFormatException);
      catalog.response = SeriesCatalogItem(
        CatalogIdentity.external(MediaType.series, 'fixture_video', 'other'),
        metadata,
      );
      await expectLater(library.refreshEpisodes(own), throwsFormatException);
      catalog.fail = true;
      await expectLater(library.refreshEpisodes(own), throwsStateError);
      expect(db.writes, writes);
      expect(
        (await library.read(
          'a',
          own.entry.id,
        )).progress.episodes.single.watched,
        true,
      );
    },
  );
  test(
    'marcação concorrente vence importação antiga e exige releitura',
    () async {
      progress.race = true;
      await expectLater(
        library.refreshEpisodes(own),
        throwsA(isA<MediaRevisionConflict>()),
      );
      expect(
        (await library.read(
          'a',
          own.entry.id,
        )).progress.episodes.single.watched,
        true,
      );
      own = await library.refreshEpisodes(own);
      expect(own.progress.episodes.single.watched, true);
    },
  );
}
