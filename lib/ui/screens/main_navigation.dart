import 'package:flutter/material.dart';
import '../widgets/reading_surface.dart';
import 'home_screen.dart';
import 'bookshelf_screen.dart';
import 'bible_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final _contentKey = GlobalKey();
  final _screens = const [
    HomeScreen(),
    BookshelfScreen(),
    BibleScreen(),
    ProfileScreen(),
  ];
  static const _labels = ['Início', 'Estante', 'Bíblia', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.library_books_outlined,
    Icons.menu_book_outlined,
    Icons.person_outline_rounded,
  ];
  static const _selectedIcons = [
    Icons.home_rounded,
    Icons.library_books_rounded,
    Icons.menu_book_rounded,
    Icons.person_rounded,
  ];
  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Texto ampliado conserva a navegação compacta, com mais espaço para conteúdo.
        final wide =
            constraints.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final content = ReadingPage(
          key: _contentKey,
          child: IndexedStack(index: _selectedIndex, children: _screens),
        );
        return Scaffold(
          body: wide
              ? SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        extended: true,
                        minExtendedWidth: 208,
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _select,
                        leading: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Bookself App',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        destinations: List.generate(
                          _labels.length,
                          (i) => NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            selectedIcon: Icon(_selectedIcons[i]),
                            label: Text(_labels[i]),
                          ),
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  ),
                )
              : content,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _select,
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_selectedIcons[i]),
                      label: _labels[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
