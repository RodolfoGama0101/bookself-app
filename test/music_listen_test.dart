import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/services/music_listen_service.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake db;
  late MusicLibraryService library;
  late MusicListenService listens;
  setUp(() {
    db = ProfileFirestoreFake();
    library = MusicLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
    listens = MusicListenService(firestore: db);
  });
  test('favorito não registra escuta e conflito exige releitura', () async {
    final original = await library.save(
      library.prepare(
        'a',
        MediaMetadata(MediaType.track, {
          'title': 'Faixa',
          'artists': ['Artista'],
        }),
      ),
    );
    final favorite = await library.favorite(original, true);
    expect(favorite.entry.favorite, true);
    expect(favorite.entry.state, null);
    expect(db.documents.keys.any((p) => p.contains('/listens/')), false);
    await expectLater(
      library.favorite(original, false),
      throwsA(isA<MediaRevisionConflict>()),
    );
    final current = await library.read('a', original.entry.id);
    expect((await library.favorite(current, false)).entry.favorite, false);
  });
  test(
    'retry mantém escuta; nova intenção permite repetir data sem alterar álbum',
    () async {
      final album = await library.save(
        library.prepare(
          'a',
          MediaMetadata(MediaType.album, {
            'title': 'Álbum',
            'artists': ['Artista'],
          }),
        ),
      );
      final id = listens.newId('a');
      await listens.save('a', album.entry.id, id, '2020-02-29');
      final writes = db.writes;
      await listens.save('a', album.entry.id, id, '2020-02-29');
      expect(db.writes, writes);
      await listens.save('a', album.entry.id, listens.newId('a'), '2020-02-29');
      expect(
        db.documents.keys.where((p) => p.contains('/listens/')),
        hasLength(2),
      );
      expect(
        db.documents.keys.where((p) => p.contains('/entries/')),
        hasLength(1),
      );
      expect((await library.read('a', album.entry.id)).entry.revision, 1);
      await expectLater(
        listens.save('a', album.entry.id, id, '2020-03-01'),
        throwsFormatException,
      );
      await expectLater(
        listens.save('b', album.entry.id, 'wrong', '2020-02-29'),
        throwsStateError,
      );
    },
  );
  test('data inválida/futura e mídia incompatível não criam escuta', () async {
    for (final date in ['2020-02-31', '9999-01-01', '20-01-01']) {
      await expectLater(
        listens.save('a', 'missing', 'listen', date),
        throwsFormatException,
      );
    }
    final repo = FirestoreMediaLibraryRepository(firestore: db);
    final movie = await repo.save(
      repo.newCatalog(
        ownerId: 'a',
        metadata: MediaMetadata(MediaType.movie, {'title': 'Filme'}),
      ),
    );
    await expectLater(
      listens.save('a', movie.id, 'listen', '2020-01-01'),
      throwsFormatException,
    );
    expect(db.documents.keys.any((p) => p.contains('/listens/')), false);
  });
}
