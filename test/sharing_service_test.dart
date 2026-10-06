import 'dart:async';
import 'package:bookself_app/services/sharing_service.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/data/models/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  late ProfileFirestoreFake db;
  late SharingService sharing;
  final book = BookModel(
    id: 'one',
    userId: 'a',
    title: 'Livro',
    authors: ['Autor'],
    coverUrl: '',
    status: 'Lendo',
    publishedDate: '',
    addedAt: DateTime(2020),
  );
  setUp(() {
    db = ProfileFirestoreFake();
    sharing = SharingService(firestore: db);
  });
  tearDown(() => db.close());

  test(
    'salvar conserva campos legados e permite limpar referência opcional',
    () async {
      db.documents['books/one'] = {
        ...book.copyWith(googleBooksId: 'external').toMap(),
        'legacy': 'preservado',
      };
      await BookService(
        firestore: db,
      ).saveBook(book.copyWith(googleBooksId: null));
      expect(db.documents['books/one']!.containsKey('googleBooksId'), false);
      expect(db.documents['books/one']!['legacy'], 'preservado');
    },
  );

  test(
    'detalhes compartilhados limpam conteúdo ao ficar offline ou sem documento',
    () async {
      final events = <BookModel?>[];
      final subscription = BookService(
        firestore: db,
      ).watchSharedBook('one').listen(events.add);
      final stream = db.controller('shared_books/one');
      stream.add(
        ProfileSnapshot(
          'one',
          SharingService.projection('books', book.toMap()),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.last?.title, 'Livro');
      stream.add(ProfileSnapshot('one', book.toMap(), fromCache: true));
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isNull);
      stream.add(ProfileSnapshot('one', null));
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isNull);
      await subscription.cancel();
      expect(stream.hasListener, false);
    },
  );

  test(
    'publicação do legado preserva documento pessoal e exclui campos privados',
    () async {
      final personal = {
        ...book.toMap(),
        'favorite': true,
        'opinion': 'Privada',
      };
      db.documents['books/one'] = personal;
      await sharing.publish('books', 'one');
      expect(db.documents['books/one'], personal);
      expect(db.documents['shared_books/one']!.containsKey('opinion'), false);
      expect(db.documents['shared_books/one']!.containsKey('favorite'), false);
      final writes = db.writes;
      await sharing.publish('books', 'one');
      expect(db.writes, writes);
    },
  );

  test(
    'ocultação aguarda confirmação e preserva dados e preferência ao republicar',
    () async {
      db.documents['books/one'] = book.toMap();
      await sharing.publish('books', 'one');
      db.commitGate = Completer<void>();
      var done = false;
      final pending = sharing
          .publish('books', 'one', isShared: false)
          .then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, false);
      expect(db.documents['shared_books/one'], isNotNull);
      db.commitGate!.complete();
      await pending;
      expect(db.documents['books/one']!['title'], 'Livro');
      expect(db.documents['books/one']!['isShared'], false);
      expect(db.documents['shared_books/one'], isNull);
      await sharing.publish('books', 'one');
      expect(db.documents['shared_books/one'], isNull);
    },
  );

  test(
    'falha de ocultação não anuncia sucesso nem perde projeção anterior',
    () async {
      db.documents['books/one'] = book.toMap();
      await sharing.publish('books', 'one');
      db.commitGate = Completer<void>();
      final pending = sharing.publish('books', 'one', isShared: false);
      final check = expectLater(pending, throwsA(isA<FirebaseException>()));
      await Future<void>.delayed(Duration.zero);
      db.commitGate!.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await check;
      expect(db.documents['books/one']!['isShared'], true);
      expect(db.documents['shared_books/one'], isNotNull);
    },
  );

  test(
    'edição com modelo antigo não torna visível um livro já oculto',
    () async {
      db.documents['books/one'] = book.copyWith(isShared: false).toMap();
      await BookService(
        firestore: db,
      ).saveBook(book.copyWith(status: 'Quero Ler'));
      expect(db.documents['books/one']!['isShared'], false);
      expect(db.documents['books/one']!['status'], 'Quero Ler');
      expect(db.documents['shared_books/one'], isNull);
    },
  );

  test('capítulo e lote preservam ocultação e capítulos pessoais', () async {
    final bible = BibleService(firestore: db);
    db.documents['bible_progress/a_rute'] = {
      'userId': 'a',
      'bookName': 'Rute',
      'readChapters': [1],
      'updatedAt': Timestamp.now(),
      'isShared': false,
    };
    expect(await bible.toggleChapter('a', 'Rute', 2, true), [1, 2]);
    expect(db.documents['bible_progress/a_rute']!['isShared'], false);
    expect(db.documents['shared_bible_progress/a_rute'], isNull);
    await bible.markAllChapters('a', 'Rute', 4, true);
    expect(db.documents['bible_progress/a_rute']!['readChapters'], [
      1,
      2,
      3,
      4,
    ]);
    expect(db.documents['bible_progress/a_rute']!['isShared'], false);
    await bible.setVisibility('a', 'Rute', true);
    expect(db.documents['shared_bible_progress/a_rute']!['readChapters'], [
      1,
      2,
      3,
      4,
    ]);
  });

  test(
    'ocultar Bíblia antes de começar não cria capítulos presumidos',
    () async {
      await BibleService(firestore: db).setVisibility('a', 'Rute', false);
      expect(db.documents['bible_progress/a_rute']!['readChapters'], isEmpty);
      expect(db.documents['bible_progress/a_rute']!['isShared'], false);
      expect(db.documents['shared_bible_progress/a_rute'], isNull);
    },
  );
}
