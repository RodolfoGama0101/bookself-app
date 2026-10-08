import 'book_cover.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/book_model.dart';

class BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;
  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = book.status == 'Lido'
        ? scheme.primary
        : book.status == 'Lendo'
        ? scheme.secondary
        : scheme.onSurfaceVariant;
    final actions =
        trailing ??
        (onDelete == null
            ? null
            : IconButton(
                tooltip: 'Excluir livro',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: onDelete,
              ));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 380 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.authors.isEmpty
                        ? 'Autor não informado'
                        : book.authors.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          book.status,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (book.status == 'Lido' && book.finishedDate != null)
                        Text(
                          DateFormat('dd/MM/yyyy').format(book.finishedDate!),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  if (compact && actions != null)
                    Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: statusColor, width: 5),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: compact ? 60 : 80,
                        height: compact ? 90 : 116,
                        child: BookCover(
                          url: book.coverUrl,
                          placeholderBuilder: (_) => Container(
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .12),
                              border: Border(
                                left: BorderSide(
                                  color: scheme.primary.withValues(alpha: .25),
                                  width: 6,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 28,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                    if (!compact && actions != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: actions,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
