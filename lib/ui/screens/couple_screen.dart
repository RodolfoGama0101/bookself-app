import 'couple_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../services/couple_workspace_service.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';
import '../widgets/design_components.dart';
import 'bookshelf_screen.dart';
import 'partner_invitation_screen.dart';
import 'sharing_screen.dart';
import 'partner_blocks_screen.dart';
import 'couple_workspace_screen.dart';

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
            padding: AppSpace.page(context),
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
              if (user.partnerUid == null) ...[
                const SizedBox(height: AppSpace.xl),
                FilledButton.icon(
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Convites do casal'),
                  onPressed: () => _open(const PartnerInvitationScreen()),
                ),
              ],
              if (CoupleWorkspaceService.enabled || user.partnerUid != null)
                const SectionHeading('Compartilhar momentos'),
              if (CoupleWorkspaceService.enabled &&
                  user.partnerUid != null &&
                  user.relationshipId != null)
                DestinationCard(
                  icon: Icons.timeline,
                  title: 'Atividades do casal',
                  subtitle: 'Experiências e contagens por mídia.',
                  onTap: () => _open(const CoupleActivityScreen()),
                ),
              if (CoupleWorkspaceService.enabled)
                DestinationCard(
                  icon: Icons.playlist_add_check,
                  title: 'Listas e experiências',
                  subtitle: 'Organizem escolhas e registrem momentos juntos.',
                  onTap: () => _open(const CoupleWorkspaceScreen()),
                ),
              if (user.partnerUid != null) ...[
                DestinationCard(
                  icon: Icons.library_books_outlined,
                  title: 'Biblioteca do parceiro',
                  subtitle: 'Consulte as leituras compartilhadas com você.',
                  onTap: () => setState(() => _showLibrary = true),
                ),
                DestinationCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Comparar progresso bíblico',
                  subtitle: 'Acompanhem os capítulos lidos por cada pessoa.',
                  onTap: widget.onOpenBible,
                ),
              ],
              const SectionHeading('Vínculo e privacidade'),
              if (user.partnerUid != null)
                DestinationCard(
                  icon: Icons.mail_outline_rounded,
                  title: 'Gerir vínculo',
                  subtitle: 'Consulte os convites e a situação da relação.',
                  onTap: () => _open(const PartnerInvitationScreen()),
                ),
              DestinationCard(
                icon: Icons.visibility_outlined,
                title: 'Compartilhamento',
                subtitle: 'Escolha quais livros e progressos ficam visíveis.',
                onTap: () =>
                    _open(SharingScreen(bookService: widget.bookService)),
              ),
              DestinationCard(
                icon: Icons.people_outline_rounded,
                title: 'Pessoas e bloqueios',
                subtitle: 'Consulte e gerencie as pessoas bloqueadas.',
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
