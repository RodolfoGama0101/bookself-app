import 'package:bookself_app/data/models/book_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// O dublê fornece apenas o documento exigido pelos modelos.
// ignore: subtype_of_sealed_class
class TestSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  TestSnapshot(this.id, this.values);

  @override
  final String id;
  final Map<String, dynamic> values;

  @override
  Map<String, dynamic> data() => values;
}

void main() {
  final finished = DateTime(2025, 2, 20);
  BookModel book() => BookModel(
    id: 'book',
    userId: 'owner',
    title: 'Livro de teste',
    authors: const ['Autor'],
    coverUrl: '',
    status: 'Lido',
    publishedDate: '',
    finishedDate: finished,
    addedAt: DateTime(2025),
  );
  UserModel user() => UserModel(
    uid: 'owner',
    name: 'Pessoa',
    email: 'teste@example.com',
    partnerUid: 'partner',
    photoUrl: 'foto',
    createdAt: DateTime(2020),
  );

  test('cópia preserva conclusão omitida e aceita nova data', () {
    expect(book().copyWith(title: 'Novo').finishedDate, finished);
    final replacement = DateTime(2026, 1, 2);
    expect(
      book().copyWith(finishedDate: replacement).finishedDate,
      replacement,
    );
  });

  for (final status in ['Lendo', 'Quero Ler']) {
    test('sair de Lido para $status limpa e serializa a conclusão', () {
      final updated = book().copyWith(status: status, finishedDate: null);
      expect(updated.toMap(), containsPair('finishedDate', null));
      final restored = BookModel.fromFirestore(
        TestSnapshot(updated.id, updated.toMap()),
      );
      expect(restored.finishedDate, isNull);
      expect(restored.status, status);
      expect(restored.userId, 'owner');
      final reread = restored.copyWith(status: 'Lido', finishedDate: finished);
      expect(reread.copyWith(title: 'Novo').finishedDate, finished);
    });
  }

  test('livro legado sem conclusão continua sem data', () {
    final legacy = book().toMap()..remove('finishedDate');
    final restored = BookModel.fromFirestore(TestSnapshot('legacy', legacy));
    expect(restored.copyWith(title: 'Novo').finishedDate, isNull);
  });

  test(
    'cópia de perfil preserva omissões e limpa campos independentemente',
    () {
      final original = user();
      final renamed = original.copyWith(name: 'Outro');
      expect(renamed.partnerUid, 'partner');
      expect(renamed.photoUrl, 'foto');
      final unlinked = renamed.copyWith(partnerUid: null);
      expect(unlinked.toMap(), containsPair('partnerUid', null));
      expect(unlinked.photoUrl, 'foto');
      final noPhoto = renamed.copyWith(photoUrl: null);
      expect(noPhoto.toMap(), containsPair('photoUrl', null));
      expect(noPhoto.partnerUid, 'partner');
      expect(original.partnerUid, 'partner');
      expect(original.photoUrl, 'foto');
    },
  );

  test('perfil legado é lido e campos limpos podem ser preenchidos', () {
    final legacy = user().toMap()
      ..remove('partnerUid')
      ..remove('photoUrl');
    final restored = UserModel.fromFirestore(TestSnapshot('owner', legacy));
    expect(restored.partnerUid, isNull);
    expect(restored.photoUrl, isNull);
    final updated = restored.copyWith(partnerUid: 'novo', photoUrl: 'nova');
    expect(updated.partnerUid, 'novo');
    expect(updated.photoUrl, 'nova');
    expect(updated.createdAt, user().createdAt);
  });

  test('campos opcionais rejeitam tipos incompatíveis', () {
    expect(
      () => book().copyWith(finishedDate: '2025'),
      throwsA(isA<TypeError>()),
    );
    expect(() => user().copyWith(partnerUid: 123), throwsA(isA<TypeError>()));
    expect(
      () => user().copyWith(photoUrl: DateTime(2020)),
      throwsA(isA<TypeError>()),
    );
  });
}
