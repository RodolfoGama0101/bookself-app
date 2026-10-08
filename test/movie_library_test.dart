import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/movie_library_service.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake db;
  late MovieLibraryService service;
  setUp(() {
    db = ProfileFirestoreFake();
    service = MovieLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
  });
  MediaMetadata metadata() =>
      MediaMetadata(MediaType.movie, {'title': 'Filme fictício'});
  test(
    'manual persiste opcionais ausentes, criação separada e retry idempotente',
    () async {
      final prepared = service.prepare('a', metadata());
      final saved = await service.save(prepared);
      expect(saved.year, isNull);
      expect(saved.cover, isEmpty);
      expect(saved.watched, isFalse);
      expect(saved.watchedOn, isNull);
      expect(saved.entry.id, isNot(saved.catalog.identity.key));
      expect((await service.save(prepared)).entry.id, saved.entry.id);
      expect(
        db.documents.keys.where((p) => p.contains('/entries/')),
        hasLength(1),
      );
      expect(
        db.documents.keys.any(
          (p) => p.startsWith('books/') || p.startsWith('bible_progress/'),
        ),
        isFalse,
      );
    },
  );
  test('confirmação só conclui depois do commit', () async {
    db.commitGate = Completer<void>();
    var completed = false;
    final pending = service.save(service.prepare('a', metadata())).then((
      value,
    ) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    db.commitGate!.complete();
    await pending;
    expect(completed, isTrue);
  });
  test(
    'datas opcionais editáveis, retorno a planejado limpa data e preserva inclusão',
    () async {
      var movie = await service.save(service.prepare('a', metadata()));
      final created = movie.entry.createdAt;
      movie = await service.update(movie, watched: true);
      expect(movie.watched, isTrue);
      expect(movie.watchedOn, isNull);
      movie = await service.update(movie, watched: true, date: '2020-02-29');
      expect(movie.watchedOn, '2020-02-29');
      movie = await service.update(movie, watched: true, date: '2020-03-01');
      expect(movie.watchedOn, '2020-03-01');
      movie = await service.update(movie, watched: false);
      expect(movie.watchedOn, isNull);
      expect(movie.entry.createdAt, created);
    },
  );
  test('rejeita data inexistente/futura antes de escrever', () async {
    final movie = await service.save(service.prepare('a', metadata()));
    final writes = db.writes;
    await expectLater(
      service.update(movie, watched: true, date: '2020-02-31'),
      throwsFormatException,
    );
    await expectLater(
      service.update(movie, watched: true, date: '9999-01-01'),
      throwsFormatException,
    );
    expect(db.writes, writes);
  });
  test(
    'estado de outra sessão gera conflito; releitura permite nova intenção',
    () async {
      final movie = await service.save(service.prepare('a', metadata()));
      await service.update(movie, watched: true);
      await expectLater(
        service.update(movie, watched: false),
        throwsA(isA<MediaRevisionConflict>()),
      );
      final latest = await service.read('a', movie.entry.id);
      expect(latest.watched, isTrue);
      expect((await service.update(latest, watched: false)).watched, isFalse);
    },
  );
  test(
    'mesma obra entre donos/fornecedores tem registros pessoais independentes',
    () async {
      final identity = CatalogIdentity.external(
        MediaType.movie,
        'example_video',
        '1',
      );
      final a = await service.save(
        service.prepare('a', metadata(), identity: identity),
      );
      final b = await service.save(
        service.prepare('b', metadata(), identity: identity),
      );
      final other = await service.save(
        service.prepare(
          'a',
          metadata(),
          identity: CatalogIdentity.external(
            MediaType.movie,
            'other_video',
            '1',
          ),
        ),
      );
      expect(other.entry.id, isNot(a.entry.id));
      await service.update(a, watched: true, date: '2020-01-01');
      expect((await service.read('b', b.entry.id)).watched, isFalse);
      expect(a.selection.toMap().keys.toSet(), {
        'mediaType',
        'title',
        'subtitle',
        'source',
        'reference',
        'episode',
      });
      expect(a.selection.toMap().containsKey('watchedOn'), isFalse);
      expect(a.selection.reference, identity.key);
    },
  );
}
