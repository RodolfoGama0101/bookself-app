import 'dart:async';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/services/book_page_controller.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class PageRepository extends Fake implements LibraryQueryRepository {
  final rows = <String, List<BookModel>>{};
  final reads = <(String, bool, String?)>[];
  final cursors = <LibraryCursor?>[];
  Completer<LibraryPage<BookModel>>? gate;
  bool fail = false;
  @override
  Future<LibraryPage<BookModel>> readBookPage(
    String ownerId, {
    bool shared = false,
    DateTime? activitySince,
    int pageSize = 20,
    LibraryCursor? after,
  }) async {
    reads.add((ownerId, shared, after?.documentId));
    cursors.add(after);
    if (gate != null) return gate!.future;
    if (fail) throw StateError('offline');
    final all = rows[ownerId] ?? [];
    final index = after == null
        ? 0
        : all.indexWhere((r) => r.id == after.documentId) + 1;
    final page = all.skip(index).take(pageSize).toList();
    return LibraryPage(
      page,
      index + page.length < all.length
          ? LibraryCursor(
              scope: 'test',
              timestamp: Timestamp.fromDate(page.last.addedAt),
              documentId: page.last.id,
            )
          : null,
    );
  }

  @override
  Future<int> countBooks(
    String ownerId, {
    bool shared = false,
    String? status,
    DateTime? finishedFrom,
    DateTime? finishedBefore,
  }) async => status == null ? (rows[ownerId]?.length ?? 0) : 42;
}

BookModel pageBook(String uid, int day) => BookModel(
  id: '$uid-$day',
  userId: uid,
  title: 'Livro $day',
  authors: [],
  coverUrl: '',
  status: 'Lendo',
  publishedDate: '',
  addedAt: DateTime(2020, 1, day),
  activityAt: DateTime(2020, 1, day),
  activityStatus: 'Lendo',
  activityAction: 'status_changed',
);

void main() {
  test(
    'janela viva conserva timestamp exato e não perde itens deslocados por inclusão',
    () async {
      final repository = PageRepository()
        ..rows['a'] = [for (var i = 7; i > 0; i--) pageBook('a', i)];
      final updates = StreamController<LibraryPage<BookModel>>.broadcast();
      final page = BookPageController(
        repository: repository,
        watch: (_, _, _, _) => updates.stream,
        owner: 'a',
        pageSize: 2,
      );
      await page.start();
      repository.rows['a']!.insert(0, pageBook('a', 9));
      final timestamp = Timestamp(123, 123456789);
      updates.add(
        LibraryPage(
          [pageBook('a', 9), pageBook('a', 7)],
          LibraryCursor(scope: 'test', timestamp: timestamp, documentId: 'a-7'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await page.loadMore();
      expect(repository.cursors.last?.timestamp, timestamp);
      expect(page.items.map((b) => b.id), ['a-9', 'a-7', 'a-6', 'a-5']);
      page.dispose();
      await updates.close();
    },
  );
  test(
    'páginas mantêm cursor, total completo, bloqueiam repetição e preservam retry',
    () async {
      final repository = PageRepository()
        ..rows['a'] = [for (var i = 7; i > 0; i--) pageBook('a', i)];
      final page = BookPageController(
        repository: repository,
        watch: (_, _, _, _) => const Stream.empty(),
        owner: 'a',
        pageSize: 2,
      );
      await page.start();
      expect(page.items.length, 2);
      expect(page.counts['a/total'], 7);
      repository.fail = true;
      await page.loadMore();
      expect(page.items.length, 2);
      expect(page.error, isNotNull);
      repository.fail = false;
      await page.loadMore();
      expect(page.items.map((b) => b.id), ['a-7', 'a-6', 'a-5', 'a-4']);
      expect(repository.reads.last.$3, 'a-6');
      page.dispose();
    },
  );
  test(
    'feed mescla origens assimétricas com buffers e métricas fora da página',
    () async {
      final repository = PageRepository()
        ..rows['a'] = [for (var i = 9; i >= 4; i--) pageBook('a', i)]
        ..rows['b'] = [pageBook('b', 3), pageBook('b', 2), pageBook('b', 1)];
      final page = BookPageController(
        repository: repository,
        watch: (_, _, _, _) => const Stream.empty(),
        owner: 'a',
        partner: 'b',
        feed: true,
        pageSize: 2,
      );
      await page.start();
      expect(page.items.map((b) => b.id), ['a-9', 'a-8']);
      expect(page.counts['b/month'], 42);
      await page.loadMore();
      expect(page.items.map((b) => b.id), ['a-9', 'a-8', 'a-7', 'a-6']);
      await page.loadMore();
      await page.loadMore();
      await page.loadMore();
      expect(page.items.map((b) => b.id), [
        'a-9',
        'a-8',
        'a-7',
        'a-6',
        'a-5',
        'a-4',
        'b-3',
        'b-2',
        'b-1',
      ]);
      expect(page.hasMore, isFalse);
      expect(repository.reads.any((r) => r.$1 == 'b' && r.$2), isTrue);
      page.dispose();
    },
  );
  test(
    'offline retira origem alheia; dispose cancela ouvintes e descarta respostas atrasadas',
    () async {
      final repository = PageRepository()
        ..rows['a'] = [pageBook('a', 2)]
        ..rows['b'] = [pageBook('b', 1)];
      final updates = StreamController<LibraryPage<BookModel>>.broadcast();
      final page = BookPageController(
        repository: repository,
        watch: (_, shared, _, _) =>
            shared ? updates.stream : const Stream.empty(),
        owner: 'a',
        partner: 'b',
        feed: true,
      );
      await page.start();
      expect(updates.hasListener, isTrue);
      updates.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(page.items.any((b) => b.userId == 'b'), isFalse);
      expect(page.counts.containsKey('b/month'), isFalse);
      page.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(updates.hasListener, isFalse);
      await updates.close();
      final delayed = PageRepository()
        ..gate = Completer<LibraryPage<BookModel>>();
      final old = BookPageController(
        repository: delayed,
        watch: (_, _, _, _) => const Stream.empty(),
        owner: 'old',
      );
      final pending = old.start();
      old.dispose();
      delayed.gate!.complete(LibraryPage([pageBook('old', 1)], null));
      await pending;
      expect(old.items, isEmpty);
      expect(old.counts, isEmpty);
    },
  );
}
