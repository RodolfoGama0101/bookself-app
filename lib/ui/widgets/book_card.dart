import 'book_cover.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    // Formata a data de conclusão se o livro estiver "Lido"
    String? finishedDateStr;
    if (book.status == 'Lido' && book.finishedDate != null) {
      finishedDateStr = DateFormat('dd/MM/yyyy').format(book.finishedDate!);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Capa do Livro com fallback em gradiente caso não exista imagem
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 75,
                  height: 104,
                  child: BookCover(
                    url: book.coverUrl,
                    placeholderBuilder: (_) => _buildCoverPlaceholder(theme),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Detalhes do Livro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.authors.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges de Status
                    Row(
                      children: [
                        _buildStatusChip(context, book.status),
                        if (finishedDateStr != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              finishedDateStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Ações adicionais (como botão de excluir ou ícone customizado)
              if (trailing != null)
                trailing!
              else if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.book, size: 28, color: Colors.grey),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final theme = Theme.of(context);
    Color chipColor;
    Color textColor;

    switch (status) {
      case 'Lido':
        chipColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.greenAccent[700] ?? Colors.green;
        break;
      case 'Lendo':
        chipColor = theme.primaryColor.withValues(alpha: 0.15);
        textColor = theme.primaryColor;
        break;
      default: // "Quero Ler"
        chipColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey[600] ?? Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
