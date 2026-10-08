import 'package:flutter/material.dart';
import '../widgets/reading_surface.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'couple_screen.dart';
import 'profile_screen.dart';
import '../../services/book_service.dart';
import '../../services/bible_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.bookService, this.bibleService});
  final BookService? bookService;
  final BibleService? bibleService;
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _bibleOrigin = 1;
  final _contentKey = GlobalKey();
  String? _ownerId;
  final _showBible = ValueNotifier(false);
  late final _screens = [
    HomeScreen(bookService: widget.bookService, onOpenBible: _openBible),
    LibraryScreen(
      showBible: _showBible,
      bookService: widget.bookService,
      bibleService: widget.bibleService,
      onOpenBible: _openBible,
      onCloseBible: _closeBible,
    ),
    CoupleScreen(onOpenBible: _openBible, bookService: widget.bookService),
    const ProfileScreen(),
  ];
  static const _labels = ['Início', 'Biblioteca', 'Nós', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.library_books_outlined,
    Icons.favorite_border_rounded,
    Icons.person_outline_rounded,
  ];
  static const _selectedIcons = [
    Icons.home_rounded,
    Icons.library_books_rounded,
    Icons.favorite_rounded,
    Icons.person_rounded,
  ];
  void _select(int index) => setState(() => _selectedIndex = index);
  void _openBible() {
    _bibleOrigin = _selectedIndex;
    _showBible.value = true;
    _select(1);
  }

  void _closeBible() {
    _showBible.value = false;
    _select(_bibleOrigin);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.watch<AuthService>().currentUserModel?.uid;
    if (_ownerId != owner) {
      _ownerId = owner;
      _selectedIndex = 0;
      _showBible.value = false;
    }
  }

  @override
  void dispose() {
    _showBible.dispose();
    super.dispose();
  }

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
          child: IndexedStack(
            key: ValueKey(_ownerId),
            index: _selectedIndex,
            children: _screens,
          ),
        );
        return PopScope(
          canPop: _selectedIndex != 1 || !_showBible.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selectedIndex == 1 && _showBible.value) {
              _closeBible();
            }
          },
          child: Scaffold(
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
            bottomNavigationBar:
                !wide &&
                    constraints.maxWidth < 380 &&
                    MediaQuery.textScalerOf(context).scale(14) > 21
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: PopupMenuButton<int>(
                        tooltip: 'Navegar entre as telas',
                        onSelected: _select,
                        itemBuilder: (_) => List.generate(
                          _labels.length,
                          (i) => PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                Icon(_icons[i]),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_labels[i])),
                              ],
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.menu_rounded),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Navegar: ${_labels[_selectedIndex]}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : wide
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
          ),
        );
      },
    );
  }
}
