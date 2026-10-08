import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/services/sharing_service.dart';
import 'package:bookself_app/utils/book_library_filter.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/profile_firestore_fake.dart';

BookModel book({String id = 'manual', String owner = 'a', String? external}) =>
    BookModel(
      id: id,
      userId: owner,
      title: 'Título original',
      authors: ['Autor'],
      coverUrl: '',
      status: 'Lendo',
      publishedDate: 'Manual',
      addedAt: DateTime(2020, 1, 2),
      googleBooksId: external,
    );

void main() {
  late ProfileFirestoreFake db;
  late BookService service;
  setUp(() {
    db = ProfileFirestoreFake();
    service = BookService(firestore: db);
  });
  tearDown(() => db.close());

  test(
    'status não altera inclusão; registra histórico, metadata não cria atividade',
    () async {
      await service.saveBook(book());
      final original = db.documents['books/manual']!;
      final creation = original['createdAt'];
      await service.saveBook(
        book().copyWith(status: 'Quero Ler', addedAt: DateTime(2030)),
      );
      final changed = db.documents['books/manual']!;
      expect(changed['addedAt'], Timestamp.fromDate(DateTime(2020, 1, 2)));
      expect(changed['createdAt'], creation);
      expect(changed['updatedAt'], isA<Timestamp>());
      final events = db.documents.entries
          .where((entry) => entry.key.startsWith('books/manual/activity/'))
          .map((entry) => entry.value)
          .toList();
      expect(events.map((event) => event['action']), [
        'added',
        'status_changed',
      ]);
      expect(events.last['beforeStatus'], 'Lendo');
      final current = BookModel.fromFirestore(
        ProfileSnapshot('manual', changed),
      );
      await service.updateManualMetadata(
        current,
        title: 'Corrigido',
        authors: [],
        coverUrl: '',
      );
      expect(
        db.documents.keys.where(
          (key) => key.startsWith('books/manual/activity/'),
        ),
        hasLength(2),
      );
      expect(
        db.documents['books/manual']!['activityEventId'],
        changed['activityEventId'],
      );
      expect(db.documents['shared_books/manual']!['title'], 'Corrigido');
    },
  );

  test(
    'legado preserva campos/datas e criação desconhecida; preferência não destrói histórico',
    () async {
      db.documents['books/manual'] = {
        ...book().toMap(),
        'legacy': 'preservado',
      };
      await service.saveBook(book().copyWith(status: 'Quero Ler'));
      expect(db.documents['books/manual']!['createdAt'], isNull);
      expect(db.documents['books/manual']!['legacy'], 'preservado');
      await SharingService(
        firestore: db,
      ).publish('books', 'manual', isShared: false);
      final hidden = db.documents['books/manual']!;
      expect(hidden['activityAt'], isNull);
      expect(hidden['latestActivityAt'], isA<Timestamp>());
      expect(db.documents['shared_books/manual'], isNull);
      expect(
        db.documents.keys.where((key) => key.contains('/activity/')),
        hasLength(1),
      );
    },
  );

  test(
    'mesma referência retorna sem substituir progresso; dono e edição distintos não colidem',
    () async {
      final first = await service.addCatalogBook(
        book(id: '', external: 'volume'),
      );
      await service.saveBook(first.book.copyWith(status: 'Quero Ler'));
      final again = await service.addCatalogBook(
        book(id: '', external: 'volume'),
      );
      expect(again.created, isFalse);
      expect(again.book.id, first.book.id);
      expect(again.book.status, 'Quero Ler');
      expect(
        (await service.addCatalogBook(
          book(id: '', owner: 'b', external: 'volume'),
        )).book.id,
        isNot(first.book.id),
      );
      expect(
        (await service.addCatalogBook(
          book(id: '', external: 'outra-edição'),
        )).book.id,
        isNot(first.book.id),
      );
    },
  );

  test(
    'legado único reencontrado; duplicatas legadas não são fundidas silenciosamente',
    () async {
      db.documents['books/old'] = book(external: 'legacy-volume').toMap();
      expect(
        (await service.addCatalogBook(book(external: 'legacy-volume'))).book.id,
        'old',
      );
      db.documents['books/other'] = book(external: 'legacy-volume').toMap();
      await expectLater(
        service.addCatalogBook(book(external: 'legacy-volume')),
        throwsA(isA<DuplicateBookReferences>()),
      );
      expect(
        db.documents.keys.where((key) => key.startsWith('books/')),
        hasLength(2),
      );
    },
  );

  test(
    'retry manual é estável; correção concorrente e edição alheia não sobrescrevem',
    () async {
      final manual = book(id: BookService.newManualId());
      await service.saveBook(manual);
      await service.saveBook(manual);
      expect(
        db.documents.keys.where((key) => key.contains('/activity/')),
        hasLength(1),
      );
      db.documents['books/${manual.id}']!['title'] = 'Alterado em outra tela';
      // FlutterFire web pode reempacotar a exceção do callback transacional.
      db.wrapTransactionErrors = true;
      await expectLater(
        service.updateManualMetadata(
          manual,
          title: 'Desatualizado',
          authors: [],
          coverUrl: '',
        ),
        throwsA(isA<BookMetadataConflict>()),
      );
      db.wrapTransactionErrors = false;
      await expectLater(
        service.updateManualMetadata(
          manual.copyWith(userId: 'b'),
          title: 'Alheio',
          authors: [],
          coverUrl: '',
        ),
        throwsStateError,
      );
      expect(
        db.documents['books/${manual.id}']!['title'],
        'Alterado em outra tela',
      );
    },
  );

  test('filtro combina palavras/autores, período inclusivo e data ausente', () {
    final value = book().copyWith(
      status: 'Lido',
      finishedDate: DateTime(2020, 2, 20, 23),
    );
    expect(
      const BookLibraryFilter(query: 'AUTOR título').matches(value),
      isTrue,
    );
    expect(const BookLibraryFilter(query: 'outro').matches(value), isFalse);
    final filter = BookLibraryFilter(
      from: DateTime(2020, 2, 20),
      to: DateTime(2020, 2, 20),
      dateField: BookDateField.finished,
    );
    expect(filter.matches(value), isTrue);
    expect(filter.matches(book()), isFalse);
    expect(
      BookLibraryFilter(
        from: DateTime(2020, 1, 2),
        to: DateTime(2020, 1, 2),
      ).matches(value),
      isTrue,
    );
  });
}
