import 'book_model.dart';

class BookSearchPage {
  const BookSearchPage({
    required this.books,
    this.nextStartIndex,
    this.skippedCount = 0,
  });

  final List<BookModel> books;
  final int? nextStartIndex;
  final int skippedCount;
}
