import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/series_record.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/services/series_progress_service.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  final now = DateTime(2026, 10, 9);
  SeriesEpisode e(
    String id, {
    bool watched = true,
    int season = 1,
    String? date,
    bool available = true,
  }) => SeriesEpisode(
    id: id,
    season: season,
    number: 1,
    watched: watched,
    availableOn: date,
    available: available,
  );
  test(
    'estados distinguem especiais, futuros, desconhecidos e catálogo incompleto',
    () {
      expect(SeriesProgress().statusAt(now), 'in_progress');
      expect(
        SeriesProgress(complete: true, ended: true).statusAt(now),
        'in_progress',
      );
      expect(
        SeriesProgress(
          complete: false,
          ended: true,
          episodes: [e('1')],
        ).statusAt(now),
        'in_progress',
      );
      expect(
        SeriesProgress(
          complete: true,
          episodes: [e('1'), e('sp', season: 0, watched: false)],
        ).statusAt(now),
        'up_to_date',
      );
      expect(
        SeriesProgress(
          complete: true,
          ended: true,
          episodes: [e('1'), e('sp', season: 0, watched: false)],
        ).statusAt(now),
        'completed',
      );
      expect(
        SeriesProgress(
          complete: true,
          ended: true,
          episodes: [
            e('1'),
            e('2', date: '2027-01-01', watched: false),
          ],
        ).statusAt(now),
        'up_to_date',
      );
      expect(
        SeriesProgress(
          complete: true,
          ended: true,
          episodes: [e('1'), e('2', available: false, watched: false)],
        ).statusAt(now),
        'up_to_date',
      );
      expect(
        SeriesProgress(
          complete: true,
          episodes: [e('1', watched: false)],
        ).statusAt(now),
        'in_progress',
      );
      expect(
        SeriesProgress(
          paused: true,
          complete: true,
          ended: true,
          episodes: [e('1')],
        ).statusAt(now),
        'paused',
      );
    },
  );
  late ProfileFirestoreFake db;
  late SeriesLibraryService service;
  setUp(() {
    db = ProfileFirestoreFake();
    service = SeriesLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
      progress: SeriesProgressService(firestore: db),
    );
  });
  tearDown(() => db.close());
  Future<SeriesRecord> create(String owner) => service.save(
    service.prepare(
      owner,
      MediaMetadata(MediaType.series, {'title': 'Série fictícia'}),
    ),
  );
  test(
    'marcar, retry, conflito, desmarcar e episódio novo preservam inclusão e progresso',
    () async {
      var row = await create('a');
      final created = row.entry.createdAt;
      final one = e('stable-id', watched: false);
      await service.progress.saveEpisode('a', row.entry.id, one, watched: true);
      await service.progress.saveEpisode('a', row.entry.id, one, watched: true);
      row = await service.read('a', row.entry.id);
      expect(row.progress.episodes.single.watched, isTrue);
      expect(row.progress.episodes.single.revision, 1);
      await expectLater(
        service.progress.saveEpisode('a', row.entry.id, one, watched: false),
        throwsA(isA<MediaRevisionConflict>()),
      );
      await service.progress.saveEpisode(
        'a',
        row.entry.id,
        e('new-id', watched: false),
        watched: false,
      );
      expect(
        (await service.read(
          'a',
          row.entry.id,
        )).progress.episodes.firstWhere((e) => e.id == 'stable-id').watched,
        isTrue,
      );
      await service.progress.saveEpisode(
        'a',
        row.entry.id,
        row.progress.episodes.single,
        watched: false,
      );
      row = await service.read('a', row.entry.id);
      expect(row.entry.createdAt, created);
      expect(row.progress.episodes.every((e) => !e.watched), isTrue);
    },
  );
  test(
    'escrita aguarda confirmação, futuro é rejeitado, dono não é inferido',
    () async {
      final row = await create('a');
      db.commitGate = Completer<void>();
      var finished = false;
      final pending = service.progress
          .saveEpisode('a', row.entry.id, e('one'), watched: true)
          .then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      db.commitGate!.complete();
      await pending;
      await expectLater(
        service.progress.saveEpisode(
          'a',
          row.entry.id,
          e('future', date: '9999-01-01'),
          watched: true,
        ),
        throwsFormatException,
      );
      await expectLater(
        service.progress.saveEpisode(
          'b',
          row.entry.id,
          e('foreign'),
          watched: true,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'configuração concorrente exige releitura e pausa não apaga marcações',
    () async {
      var row = await create('a');
      await service.progress.saveEpisode(
        'a',
        row.entry.id,
        e('one'),
        watched: true,
      );
      await service.progress.configure(
        'a',
        row.entry.id,
        row.progress,
        complete: true,
        ended: true,
        paused: false,
      );
      await expectLater(
        service.progress.configure(
          'a',
          row.entry.id,
          row.progress,
          complete: false,
          ended: false,
          paused: true,
        ),
        throwsA(isA<MediaRevisionConflict>()),
      );
      row = await service.read('a', row.entry.id);
      expect(row.status, 'completed');
      await service.progress.configure(
        'a',
        row.entry.id,
        row.progress,
        complete: true,
        ended: true,
        paused: true,
      );
      row = await service.read('a', row.entry.id);
      expect(row.status, 'paused');
      expect(row.progress.episodes.single.watched, isTrue);
    },
  );
}
