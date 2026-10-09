import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake db;
  late MusicLibraryService service;
  setUp(() {
    db = ProfileFirestoreFake();
    service = MusicLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
  });
  MediaMetadata metadata(MediaType type) => MediaMetadata(type, {
    'title': 'Obra',
    'artists': ['Artista'],
    if (type == MediaType.track) 'version': 'Ao vivo' else 'edition': 'Deluxe',
  });
  for (final type in [MediaType.track, MediaType.album]) {
    test('manual $type conserva metadados e retry sem escuta', () async {
      final prepared = service.prepare('a', metadata(type));
      final saved = await service.save(prepared);
      expect(saved.artists, 'Artista');
      expect(saved.version, type == MediaType.track ? 'Ao vivo' : 'Deluxe');
      expect(saved.cover, isEmpty);
      expect(saved.entry.state, null);
      expect(saved.entry.favorite, false);
      expect((await service.save(prepared)).entry.id, saved.entry.id);
      expect(
        db.documents.keys.where((p) => p.contains('/entries/')),
        hasLength(1),
      );
      expect(db.documents.keys.any((p) => p.contains('/listens/')), false);
    });
  }
  test('mesma referência deduplica somente por dono e tipo', () async {
    final a = await service.save(
      service.prepare(
        'a',
        metadata(MediaType.track),
        identity: CatalogIdentity.external(MediaType.track, 'example', '1'),
      ),
    );
    final b = await service.save(
      service.prepare(
        'b',
        metadata(MediaType.track),
        identity: CatalogIdentity.external(MediaType.track, 'example', '1'),
      ),
    );
    final album = await service.save(
      service.prepare(
        'a',
        metadata(MediaType.album),
        identity: CatalogIdentity.external(MediaType.album, 'example', '1'),
      ),
    );
    expect(a.entry.id, isNot(b.entry.id));
    expect(a.entry.id, isNot(album.entry.id));
    expect(a.selection.toMap().keys, isNot(contains('favorite')));
    expect(a.selection.subtitle, 'Artista');
  });
  test('salvar só resolve após confirmação', () async {
    db.commitGate = Completer<void>();
    var done = false;
    final pending = service
        .save(service.prepare('a', metadata(MediaType.track)))
        .then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, false);
    db.commitGate!.complete();
    await pending;
    expect(done, true);
  });
}
