import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../data/models/book_model.dart';
import '../widgets/book_card.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_details_sheet.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _cachedUserPhotoUrl;
  MemoryImage? _cachedUserAvatarImage;
  String? _cachedPartnerPhotoUrl;
  MemoryImage? _cachedPartnerAvatarImage;

  ImageProvider? _getAvatarImage(String? photoUrl, bool isPartner) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image/')) {
      if (isPartner) {
        if (_cachedPartnerPhotoUrl == photoUrl && _cachedPartnerAvatarImage != null) {
          return _cachedPartnerAvatarImage;
        }
        _cachedPartnerPhotoUrl = photoUrl;
        final base64String = photoUrl.split(',').last;
        _cachedPartnerAvatarImage = MemoryImage(base64Decode(base64String));
        return _cachedPartnerAvatarImage;
      } else {
        if (_cachedUserPhotoUrl == photoUrl && _cachedUserAvatarImage != null) {
          return _cachedUserAvatarImage;
        }
        _cachedUserPhotoUrl = photoUrl;
        final base64String = photoUrl.split(',').last;
        _cachedUserAvatarImage = MemoryImage(base64Decode(base64String));
        return _cachedUserAvatarImage;
      }
    }
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;
    final theme = Theme.of(context);
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bookService = BookService();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_rounded, color: theme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              'Bookself App',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<BookModel>>(
        stream: bookService.streamCoupleFeed(user.uid, user.partnerUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SelectableText(
                  'Erro ao carregar feed: ${ErrorHandler.getFriendlyErrorMessage(snapshot.error)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];
          
          // Estatísticas do mês e ano atual
          final now = DateTime.now();
          final months = [
            'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
            'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
          ];
          final currentMonthName = months[now.month - 1];

          // Mês atual
          final userReadThisMonth = books.where((b) => 
            b.userId == user.uid && 
            b.status == 'Lido' && 
            b.finishedDate != null && 
            b.finishedDate!.month == now.month && 
            b.finishedDate!.year == now.year
          ).length;

          final partnerReadThisMonth = books.where((b) => 
            partner != null && 
            b.userId == partner.uid && 
            b.status == 'Lido' && 
            b.finishedDate != null && 
            b.finishedDate!.month == now.month && 
            b.finishedDate!.year == now.year
          ).length;

          // Ano atual
          final userReadThisYear = books.where((b) => 
            b.userId == user.uid && 
            b.status == 'Lido' && 
            b.finishedDate != null && 
            b.finishedDate!.year == now.year
          ).length;

          final partnerReadThisYear = books.where((b) => 
            partner != null && 
            b.userId == partner.uid && 
            b.status == 'Lido' && 
            b.finishedDate != null && 
            b.finishedDate!.year == now.year
          ).length;

          return RefreshIndicator(
            onRefresh: () async {},
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Bloco de Estatísticas do Casal (Dashboard)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor.withOpacity(0.15),
                            theme.colorScheme.secondary.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Nossas Leituras em $currentMonthName',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Estatísticas do Usuário Atual
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: theme.primaryColor.withOpacity(0.2),
                                    backgroundImage: _getAvatarImage(user.photoUrl, false),
                                    child: user.photoUrl == null || user.photoUrl!.isEmpty
                                        ? Text(
                                            user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                                            style: TextStyle(
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Você',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$userReadThisMonth ${userReadThisMonth == 1 ? 'livro lido' : 'livros lidos'}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'no mês',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '$userReadThisYear ${userReadThisYear == 1 ? 'livro lido' : 'livros lidos'}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'no ano de ${now.year}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                              
                              // Ícone de Divisória Romântica
                              Icon(
                                Icons.favorite_rounded,
                                color: theme.colorScheme.secondary.withOpacity(0.7),
                                size: 28,
                              ),
                              
                              // Estatísticas do Parceiro
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                                    backgroundImage: _getAvatarImage(partner?.photoUrl, true),
                                    child: partner == null || partner.photoUrl == null || partner.photoUrl!.isEmpty
                                        ? Text(
                                            partner != null && partner.name.isNotEmpty 
                                                ? partner.name.substring(0, 1).toUpperCase() 
                                                : '?',
                                            style: TextStyle(
                                              color: theme.colorScheme.secondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    partner != null ? partner.name : 'Parceiro',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  partner != null 
                                      ? Column(
                                          children: [
                                            Text(
                                              '$partnerReadThisMonth ${partnerReadThisMonth == 1 ? 'livro lido' : 'livros lidos'}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.secondary,
                                              ),
                                            ),
                                            Text(
                                              'no mês',
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '$partnerReadThisYear ${partnerReadThisYear == 1 ? 'livro lido' : 'livros lidos'}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.secondary,
                                              ),
                                            ),
                                            Text(
                                              'no ano de ${now.year}',
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                            ),
                                          ],
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            'Aguardando',
                                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                          ),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Título da Seção do Feed
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                    child: Text(
                      'Histórico do Casal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                // Lista de Atividades do Feed
                if (books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books_outlined, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma leitura registrada ainda.\nAdicione livros na sua Estante para começar!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = books[index];
                        final isMe = book.userId == user.uid;
                        final authorName = isMe ? 'Você' : (partner?.name ?? 'Parceiro');
                        
                        // Determina o texto de ação com base no status do livro
                        String actionText = '';
                        IconData actionIcon;
                        Color actionColor;
                        
                        switch (book.status) {
                          case 'Lido':
                            actionText = 'concluiu a leitura de';
                            actionIcon = Icons.check_circle_rounded;
                            actionColor = Colors.green;
                            break;
                          case 'Lendo':
                            actionText = 'começou a ler';
                            actionIcon = Icons.chrome_reader_mode_rounded;
                            actionColor = theme.primaryColor;
                            break;
                          default:
                            actionText = 'quer ler';
                            actionIcon = Icons.bookmark_add_rounded;
                            actionColor = Colors.grey;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Linha do feed indicando a ação
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0, top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(actionIcon, size: 16, color: actionColor),
                                    const SizedBox(width: 6),
                                    RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                                        children: [
                                          TextSpan(
                                            text: authorName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(text: ' $actionText '),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Card do Livro do Feed
                              BookCard(
                                book: book,
                                onTap: () => showBookDetailsSheet(context, book, isMe),
                              ),
                              const Divider(height: 16, thickness: 0.5, indent: 8, endIndent: 8),
                            ],
                          ),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
