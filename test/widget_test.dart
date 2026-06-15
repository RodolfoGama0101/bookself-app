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
      final apocalipse = BibleData.books.firstWhere((b) => b.name == 'Apocalipse');
      expect(apocalipse.chapters, 22);
    });

    test('O Novo Testamento deve começar a partir de Mateus', () {
      final matthew = BibleData.books.firstWhere((b) => b.name == 'Mateus');
      expect(matthew.isNewTestament, isTrue);
    });
  });
}
