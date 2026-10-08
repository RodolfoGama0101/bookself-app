import '../data/models/book_model.dart';

enum BookDateField { added, finished }

class BookLibraryFilter {
  const BookLibraryFilter({
    this.query = '',
    this.from,
    this.to,
    this.dateField = BookDateField.added,
  });
  final String query;
  final DateTime? from, to;
  final BookDateField dateField;
  bool get isActive => query.trim().isNotEmpty || from != null || to != null;

  bool matches(BookModel book) {
    final words = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final text = '${book.title} ${book.authors.join(' ')}'.toLowerCase();
    if (!words.every(text.contains)) return false;
    if (from == null && to == null) return true;
    final value = dateField == BookDateField.added
        ? book.addedAt
        : book.finishedDate;
    if (value == null) return false;
    final day = DateTime(value.year, value.month, value.day);
    return (from == null ||
            !day.isBefore(DateTime(from!.year, from!.month, from!.day))) &&
        (to == null || !day.isAfter(DateTime(to!.year, to!.month, to!.day)));
  }
}
