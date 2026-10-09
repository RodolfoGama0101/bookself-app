import 'package:flutter/material.dart';

/// Tokens de layout do sistema visual. Valores em pixels lógicos.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double section = 32;
  static const double pageMax = 1000;
  static const double formMax = 720;
  static const double railBreakpoint = 720;

  static EdgeInsets page(BuildContext context) =>
      EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? lg : xl);
}

/// Ações com separação real nos dois eixos, inclusive com texto ampliado.
class ActionGroup extends StatelessWidget {
  const ActionGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 420 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.md),
              children[i],
            ],
          ],
        );
      }
      return Wrap(
        spacing: AppSpace.md,
        runSpacing: AppSpace.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    },
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.section, bottom: AppSpace.md),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// Destino identificado por nome e descrição; toda a superfície é acionável.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpace.lg),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          title: Text(title, style: theme.textTheme.titleSmall),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(subtitle),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Categorias entregues e acompanhamento bíblico têm papéis separados.
class LibraryDestinations extends StatelessWidget {
  const LibraryDestinations({
    super.key,
    this.moviesSelected = false,
    this.onBooks,
    this.onMovies,
    this.onBible,
  });
  final bool moviesSelected;
  final VoidCallback? onBooks;
  final VoidCallback? onMovies;
  final VoidCallback? onBible;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.md,
    runSpacing: AppSpace.md,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ChoiceChip(
        avatar: const Icon(Icons.library_books_outlined, size: 20),
        label: const Text('Livros'),
        selected: !moviesSelected,
        onSelected: (_) => onBooks?.call(),
      ),
      if (onMovies != null || moviesSelected)
        ChoiceChip(
          avatar: const Icon(Icons.movie_outlined, size: 20),
          label: const Text('Filmes'),
          selected: moviesSelected,
          onSelected: (_) => onMovies?.call(),
        ),
      if (onBible != null)
        TextButton.icon(
          onPressed: onBible,
          icon: const Icon(Icons.menu_book_outlined, size: 20),
          label: const Text('Acompanhar Bíblia'),
        ),
    ],
  );
}
