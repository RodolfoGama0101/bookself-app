import 'package:flutter_test/flutter_test.dart';
import 'package:bookself_app/data/bible_data.dart';

void main() {
  group('Testes de Dados da Bíblia ARC', () {
    test('A Bíblia ARC deve conter exatamente 66 livros', () {
      expect(BibleData.books.length, 66);
    });

    test('O livro de Gênesis deve ter 50 capítulos', () {
      final genesis = BibleData.books.firstWhere((b) => b.name == 'Gênesis');
      expect(genesis.chapters, 50);
    });

    test('O livro de Apocalipse deve ter 22 capítulos', () {
      final apocalipse = BibleData.books.firstWhere(
        (b) => b.name == 'Apocalipse',
      );
      expect(apocalipse.chapters, 22);
    });

    test('O Novo Testamento deve começar a partir de Mateus', () {
      final matthew = BibleData.books.firstWhere((b) => b.name == 'Mateus');
      expect(matthew.isNewTestament, isTrue);
    });

    test('testamentos têm 39/27 livros e 929/260 capítulos', () {
      final old = BibleData.books.where((book) => !book.isNewTestament);
      final recent = BibleData.books.where((book) => book.isNewTestament);
      expect(old.length, 39);
      expect(recent.length, 27);
      expect(old.fold<int>(0, (total, book) => total + book.chapters), 929);
      expect(recent.fold<int>(0, (total, book) => total + book.chapters), 260);
      expect(
        BibleData.books.fold<int>(0, (total, book) => total + book.chapters),
        1189,
      );
    });

    test('a ordem mantém os testamentos contíguos e suas extremidades', () {
      expect(BibleData.books.first.name, 'Gênesis');
      expect(BibleData.books[38].name, 'Malaquias');
      expect(BibleData.books[39].name, 'Mateus');
      expect(BibleData.books.last.name, 'Apocalipse');
      expect(BibleData.books.take(39).every((b) => !b.isNewTestament), isTrue);
      expect(BibleData.books.skip(39).every((b) => b.isNewTestament), isTrue);
    });

    test('nomes e IDs persistidos são únicos e limites são positivos', () {
      final names = BibleData.books.map((book) => book.name).toList();
      final ids = names.map((name) => name.replaceAll(' ', '_').toLowerCase());
      expect(names.toSet().length, 66);
      expect(ids.toSet().length, 66);
      expect(names.every((name) => name.trim().isNotEmpty), isTrue);
      expect(BibleData.books.every((book) => book.chapters > 0), isTrue);
      expect(
        BibleData.books.singleWhere((b) => b.name == 'Salmos').chapters,
        150,
      );
      expect(
        BibleData.books.singleWhere((b) => b.name == 'Obadias').chapters,
        1,
      );
    });
  });
}
