import 'dart:async';

import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/media_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements MediaLibraryRepository {
  Completer<LibraryEntry>? gate;
  Object? failure;
  int writes = 0;
  CatalogItem? lastCatalog;
  LibraryEntry current = _entry('a', 1);
  @override
  Future<LibraryEntry> save(CatalogItem catalog) async {
    writes++;
    lastCatalog = catalog;
    if (failure != null) throw failure!;
    return gate == null ? current : gate!.future;
  }

  @override
  Future<LibraryEntry?> readEntry(String ownerId, String entryId) async =>
      current;
  @override
  Future<LibraryEntry> updatePersonal(
    String ownerId,
    String entryId, {
    required int expectedRevision,
    required MediaState? state,
    required bool favorite,
  }) async {
    writes++;
    if (expectedRevision != current.revision) {
      throw const MediaRevisionConflict();
    }
    if (failure != null) throw failure!;
    return current;
  }
}

LibraryEntry _entry(String owner, int revision) => LibraryEntry(
  id: 'entry',
  ownerId: owner,
  catalogId: 'catalog',
  mediaType: MediaType.book,
  state: MediaState(MediaType.book, 'planned'),
  favorite: false,
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
  revision: revision,
);
CatalogItem _catalog() => CatalogItem(
  id: 'catalog',
  ownerId: 'a',
  identity: CatalogIdentity.manual(MediaType.book, 'a', 'manual'),
  metadata: MediaMetadata(MediaType.book, {'title': 'Fictício', 'authors': []}),
);

void main() {
  late _Repository repository;
  late MediaSyncService service;
  setUp(() {
    repository = _Repository();
    service = MediaSyncService(repository)..selectOwner('a');
  });
  tearDown(() => service.dispose());

  test(
    'não confirma antes do commit e bloqueia intenção concorrente',
    () async {
      repository.gate = Completer();
      final pending = service.save(_catalog());
      expect(service.status, MediaSyncStatus.pending);
      expect(service.entry, isNull);
      await expectLater(service.save(_catalog()), throwsStateError);
      expect(repository.writes, 1);
      repository.gate!.complete(repository.current);
      await pending;
      expect(service.status, MediaSyncStatus.confirmed);
    },
  );
  test(
    'falha/retry preserva exatamente a identidade manual preparada',
    () async {
      final catalog = _catalog();
      repository.failure = StateError('offline');
      await service.save(catalog);
      expect(service.status, MediaSyncStatus.failed);
      expect(service.entry, isNull);
      repository.failure = null;
      await service.retry();
      expect(identical(repository.lastCatalog, catalog), isTrue);
      expect(service.status, MediaSyncStatus.confirmed);
      expect(repository.writes, 2);
    },
  );
  test(
    'conflito exige recarregar; não sobrescreve com retry da revisão antiga',
    () async {
      await service.reload('entry');
      repository.current = _entry('a', 2);
      await service.update(
        state: MediaState(MediaType.book, 'reading'),
        favorite: false,
      );
      expect(service.status, MediaSyncStatus.conflict);
      await expectLater(service.retry(), throwsStateError);
      expect(repository.writes, 1);
      await service.reload('entry');
      expect(service.entry!.revision, 2);
      await service.update(state: service.entry!.state, favorite: false);
      expect(service.status, MediaSyncStatus.confirmed);
    },
  );
  test('troca de conta e logout descartam conclusão e erro antigos', () async {
    for (final nextOwner in ['b', null]) {
      service.selectOwner('a');
      repository.gate = Completer();
      final pending = service.save(_catalog());
      service.selectOwner(nextOwner);
      repository.gate!.completeError(StateError('late error'));
      await pending;
      expect(service.status, MediaSyncStatus.idle);
      expect(service.entry, isNull);
      expect(service.error, isNull);
      await expectLater(service.retry(), throwsStateError);
    }
  });
  test(
    'descarte não publica confirmação tardia nem notifica listeners',
    () async {
      final other = MediaSyncService(repository)..selectOwner('a');
      repository.gate = Completer();
      var notifications = 0;
      other.addListener(() => notifications++);
      final pending = other.save(_catalog());
      other.dispose();
      repository.gate!.complete(repository.current);
      await pending;
      expect(notifications, 1);
      expect(other.entry, isNull);
    },
  );
  test('retorno de dono divergente não vira confirmação', () async {
    repository.current = _entry('b', 1);
    await service.save(_catalog());
    expect(service.status, MediaSyncStatus.failed);
    expect(service.entry, isNull);
    expect(service.error, isA<FormatException>());
  });
}
