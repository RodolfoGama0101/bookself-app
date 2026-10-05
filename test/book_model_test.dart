import 'package:bookself_app/data/models/book_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_firestore_fake.dart';

void main() {
  final addedAt = DateTime(2025, 1, 10);
  final finishedDate = DateTime(2025, 2, 20);

  BookModel readBook() => BookModel(
    id: 'book',
    userId: 'owner',
    title: 'Livro de teste',
    authors: ['Autoria de teste'],
    coverUrl: '',
    status: 'Lido',
    publishedDate: '2020',
    finishedDate: finishedDate,
    addedAt: addedAt,
  );

  test('alterar outro campo preserva conclusão, autoria e datas originais', () {
    final original = readBook();
    final updated = original.copyWith(title: 'Título corrigido');
    expect(updated.title, 'Título corrigido');
    expect(updated.finishedDate, finishedDate);
    expect(updated.id, original.id);
    expect(updated.userId, original.userId);
    expect(updated.authors, original.authors);
    expect(updated.addedAt, addedAt);
    expect(original.title, 'Livro de teste');
    expect(updated.toMap()['finishedDate'], Timestamp.fromDate(finishedDate));
  });

  test(
    'conclusão pode ser corrigida sem alterar status ou data de inclusão',
    () {
      final correctedDate = DateTime(2025, 2, 19);
      final updated = readBook().copyWith(finishedDate: correctedDate);
      expect(updated.finishedDate, correctedDate);
      expect(updated.status, 'Lido');
      expect(updated.addedAt, addedAt);
    },
  );

  test('null explícito limpa conclusão inclusive no mapa persistido', () {
    final original = readBook();
    final updated = original.copyWith(finishedDate: null);
    expect(updated.finishedDate, isNull);
    expect(updated.status, 'Lido');
    expect(updated.toMap(), containsPair('finishedDate', null));
    expect(original.finishedDate, finishedDate);
    final restored = BookModel.fromFirestore(
      ProfileSnapshot(updated.id, updated.toMap()),
    );
    expect(restored.finishedDate, isNull);
    expect(restored.userId, original.userId);
  });

  for (final status in ['Lendo', 'Quero Ler']) {
    test(
      'sair de Lido para $status remove a conclusão sem perder identidade',
      () {
        final updated = readBook().copyWith(status: status, finishedDate: null);
        final restored = BookModel.fromFirestore(
          ProfileSnapshot(updated.id, updated.toMap()),
        );
        expect(restored.status, status);
        expect(restored.finishedDate, isNull);
        expect(restored.id, 'book');
        expect(restored.userId, 'owner');
        expect(restored.addedAt, addedAt);
      },
    );
  }

  test(
    'concluir novamente usa a nova data, e cópias seguintes a preservam',
    () {
      final reading = readBook().copyWith(status: 'Lendo', finishedDate: null);
      final newDate = DateTime(2026, 3, 12);
      final reread = reading.copyWith(status: 'Lido', finishedDate: newDate);
      final saved = reread.copyWith(id: 'saved-id');
      expect(saved.finishedDate, newDate);
      expect(saved.status, 'Lido');
      expect(saved.id, 'saved-id');
      expect(saved.addedAt, addedAt);
    },
  );

  test('livro legado sem conclusão continua sem data ao copiar', () {
    final legacy = readBook().toMap()..remove('finishedDate');
    final restored = BookModel.fromFirestore(ProfileSnapshot('legacy', legacy));
    expect(restored.copyWith(title: 'Título corrigido').finishedDate, isNull);
    expect(restored.status, 'Lido');
  });

  test('finishedDate rejeita valores de tipo incompatível', () {
    expect(
      () => readBook().copyWith(finishedDate: '2025-02-20'),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => readBook().copyWith(finishedDate: const Object()),
      throwsA(isA<TypeError>()),
    );
  });

  test('referência Google Books preserva identidade pessoal independente', () {
    final original = readBook().copyWith(googleBooksId: 'catalog-id');
    final restored = BookModel.fromFirestore(
      ProfileSnapshot('personal-id', original.toMap()),
    );
    expect(restored.id, 'personal-id');
    expect(restored.googleBooksId, 'catalog-id');
    expect(
      restored.copyWith(title: 'Outro título').googleBooksId,
      'catalog-id',
    );
    expect(
      restored
          .copyWith(googleBooksId: null)
          .toMap()
          .containsKey('googleBooksId'),
      isFalse,
    );
    expect(readBook().toMap().containsKey('googleBooksId'), isFalse);
  });
}
