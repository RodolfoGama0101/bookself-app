import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';
import 'bookshelf_screen.dart';
import 'partner_invitation_screen.dart';
import 'sharing_screen.dart';
import 'partner_blocks_screen.dart';

class CoupleScreen extends StatefulWidget {
  const CoupleScreen({super.key, required this.onOpenBible, this.bookService});
  final VoidCallback onOpenBible;
  final BookService? bookService;
  @override
  State<CoupleScreen> createState() => _CoupleScreenState();
}

class _CoupleScreenState extends State<CoupleScreen> {
  bool _showLibrary = false;
  String? _relationship;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUserModel;
    final relationship =
        '${user?.uid}/${user?.partnerUid}/${user?.relationshipId}';
    if (_relationship != relationship) {
      _relationship = relationship;
      _showLibrary = false;
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUserModel;
    final partner = auth.partnerUserModel;
    if (user == null) {
      return const ContentState(title: 'Carregando sua conta', loading: true);
    }
    return IndexedStack(
      index: _showLibrary && user.partnerUid != null ? 1 : 0,
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Nós')),
          body: ListView(
            key: PageStorageKey('couple/${user.uid}'),
            padding: const EdgeInsets.all(20),
            children: [
              ReadingSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.partnerUid == null
                          ? 'Nenhum vínculo ativo'
                          : partner?.name ?? 'Seu parceiro',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.partnerUid == null
                          ? 'Envie ou aceite um convite para acompanhar leituras juntos.'
                          : 'Consulte as leituras compartilhadas e compare o progresso bíblico.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (user.partnerUid != null) ...[
                ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: const Text('Biblioteca do parceiro'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _showLibrary = true),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Comparar progresso bíblico'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenBible,
                ),
              ],
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: Text(
                  user.partnerUid == null
                      ? 'Convites do casal'
                      : 'Gerir vínculo',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const PartnerInvitationScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Compartilhamento'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _open(SharingScreen(bookService: widget.bookService)),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline_rounded),
                title: const Text('Pessoas e bloqueios'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const PartnerBlocksScreen()),
              ),
            ],
          ),
        ),
        BookshelfScreen(
          key: ValueKey(_relationship),
          scope: BookshelfScope.partner,
          bookService: widget.bookService,
          onClose: () => setState(() => _showLibrary = false),
        ),
      ],
    );
  }
}
