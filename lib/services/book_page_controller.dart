import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/book_model.dart';
import 'library_query_service.dart';

typedef BookWindow =
    Stream<LibraryPage<BookModel>> Function(
      String owner,
      bool shared,
      DateTime? since,
      int limit,
    );

/// Páginas confirmadas com buffer por origem e uma janela viva limitada.
class BookPageController extends ChangeNotifier {
  BookPageController({
    required this.repository,
    required this.watch,
    required this.owner,
    this.partner,
    this.since,
    this.feed = false,
    this.ownerShared = false,
    this.pageSize = 20,
  });
  final LibraryQueryRepository repository;
  final BookWindow watch;
  final String owner;
  final String? partner;
  final DateTime? since;
  final bool feed;
  final bool ownerShared;
  final int pageSize;
  final _origins = <String, _Origin>{};
  final counts = <String, int>{};
  bool busy = false, _disposed = false;
  Object? error;
  int _generation = 0, _visible = 0;
  bool _loadedBefore = false;
  Stream<List<BookModel>> asStream() {
    late StreamController<List<BookModel>> output;
    void emit() {
      if (error != null) {
        output.addError(error!);
      } else if (_visible > 0 || _loadedBefore) {
        output.add(items);
      }
    }

    output = StreamController<List<BookModel>>(
      onListen: () {
        addListener(emit);
        unawaited(start());
      },
      onCancel: () {
        removeListener(emit);
      },
    );
    return output.stream;
  }

  List<BookModel> get items {
    final rows = _origins.values.expand((o) => o.rows.values).toList()
      ..sort(_compare);
    return List.unmodifiable(feed ? rows.take(_visible) : rows);
  }

  bool get hasMore =>
      _origins.values.any((o) => !o.done) ||
      (feed &&
          _origins.values.fold<int>(0, (n, o) => n + o.rows.length) > _visible);
  int _compare(BookModel a, BookModel b) {
    final time = feed
        ? (b.activityAt ?? DateTime(1970)).compareTo(
            a.activityAt ?? DateTime(1970),
          )
        : b.addedAt.compareTo(a.addedAt);
    return time != 0 ? time : b.id.compareTo(a.id);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (busy || _disposed) return;
    _generation++;
    for (final origin in _origins.values) {
      await origin.subscription?.cancel();
    }
    if (_disposed) return;
    _origins.clear();
    counts.clear();
    _visible = 0;
    error = null;
    _origins[owner] = _Origin(ownerShared);
    if (partner != null) _origins[partner!] = _Origin(true);
    await loadMore();
  }

  Future<void> _read(String uid, _Origin origin, int generation) async {
    final page = await repository.readBookPage(
      uid,
      shared: origin.shared,
      activitySince: feed ? since ?? DateTime(1970) : null,
      pageSize: pageSize,
      after: origin.cursor,
    );
    if (_disposed || generation != _generation) return;
    for (final row in page.items) {
      origin.rows[row.id] = row.copyWith(feedVisible: feed);
    }
    origin.cursor = page.next;
    origin.done = page.next == null;
    origin.loaded += page.items.length;
  }

  Future<void> loadMore() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    final generation = _generation;
    // Cursores só avançam após confirmação; falha conserva a próxima tentativa.
    try {
      final target = _visible + pageSize;
      for (final entry in _origins.entries) {
        if (!entry.value.done && (entry.value.rows.isEmpty || !feed)) {
          await _read(entry.key, entry.value, generation);
        }
      }
      if (feed) {
        while (!_disposed && generation == _generation) {
          final merged = _origins.values.expand((o) => o.rows.values).toList()
            ..sort(_compare);
          final boundary = merged.isEmpty
              ? null
              : merged[(target - 1).clamp(0, merged.length - 1)];
          var advanced = false;
          for (final entry in _origins.entries) {
            final origin = entry.value;
            final rows = origin.rows.values.toList()..sort(_compare);
            if (!origin.done &&
                (merged.length < target ||
                    rows.isEmpty ||
                    boundary == null ||
                    _compare(rows.last, boundary) <= 0)) {
              await _read(entry.key, origin, generation);
              advanced = true;
            }
          }
          if (!advanced) break;
        }
      }
      if (_disposed || generation != _generation) return;
      _visible = target;
      _loadedBefore = true;
      await _counts(generation);
      if (_disposed || generation != _generation) return;
      for (final entry in _origins.entries) {
        final origin = entry.value;
        await origin.subscription?.cancel();
        if (_disposed || generation != _generation) return;
        final windowSize = origin.loaded < pageSize ? pageSize : origin.loaded;
        origin.loaded = windowSize;
        origin.subscription =
            watch(
              entry.key,
              origin.shared,
              feed ? since ?? DateTime(1970) : null,
              windowSize,
            ).listen(
              (window) {
                if (_disposed || generation != _generation) return;
                if (busy) return;
                final visible = window.items;
                origin.done = window.next == null;
                origin.cursor = window.next;
                origin.rows
                  ..clear()
                  ..addEntries(
                    visible.map(
                      (b) => MapEntry(b.id, b.copyWith(feedVisible: feed)),
                    ),
                  );
                // A borda confirmada conserva o timestamp exato; IDs são deduplicados.
                unawaited(_refreshCounts(generation));
                _notify();
              },
              onError: (Object failure) {
                if (_disposed || generation != _generation) return;
                if (origin.shared) {
                  origin.rows.clear();
                  counts.removeWhere((k, _) => k.startsWith('${entry.key}/'));
                }
                error = failure;
                _notify();
              },
            );
      }
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        // Conteúdo alheio não permanece visível após falha/offline.
        for (final entry in _origins.entries.where((e) => e.value.shared)) {
          entry.value.rows.clear();
          counts.removeWhere((k, _) => k.startsWith('${entry.key}/'));
        }
        error = failure;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _refreshCounts(int generation) async {
    try {
      await _counts(generation);
      if (generation == _generation) _notify();
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        for (final entry in _origins.entries.where((e) => e.value.shared)) {
          entry.value.rows.clear();
          counts.removeWhere((k, _) => k.startsWith('${entry.key}/'));
        }
        error = failure;
        _notify();
      }
    }
  }

  Future<void> _counts(int generation) async {
    final now = DateTime.now();
    final result = <String, int>{};
    for (final entry in _origins.entries) {
      final uid = entry.key, shared = entry.value.shared;
      result['$uid/total'] = await repository.countBooks(uid, shared: shared);
      if (feed) {
        result['$uid/month'] = await repository.countBooks(
          uid,
          shared: shared,
          status: 'Lido',
          finishedFrom: DateTime(now.year, now.month),
          finishedBefore: DateTime(now.year, now.month + 1),
        );
        result['$uid/year'] = await repository.countBooks(
          uid,
          shared: shared,
          status: 'Lido',
          finishedFrom: DateTime(now.year),
          finishedBefore: DateTime(now.year + 1),
        );
      }
    }
    if (!_disposed && generation == _generation) {
      counts
        ..clear()
        ..addAll(result);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final origin in _origins.values) {
      unawaited(origin.subscription?.cancel());
      origin.rows.clear();
    }
    counts.clear();
    super.dispose();
  }
}

class _Origin {
  _Origin(this.shared);
  final bool shared;
  final rows = <String, BookModel>{};
  LibraryCursor? cursor;
  bool done = false;
  int loaded = 0;
  StreamSubscription<LibraryPage<BookModel>>? subscription;
}
