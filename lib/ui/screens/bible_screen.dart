import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/bible_data.dart';
import '../../services/auth_service.dart';
import '../../services/bible_service.dart';
import '../../data/models/bible_progress_model.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> with TickerProviderStateMixin {
  late TabController _testamentTabController;
  final BibleService _bibleService = BibleService();

  @override
  void initState() {
    super.initState();
    _testamentTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _testamentTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Filtra livros do Antigo e Novo Testamento
    final otBooks = BibleData.books.where((b) => !b.isNewTestament).toList();
    final ntBooks = BibleData.books.where((b) => b.isNewTestament).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Progresso da Bíblia',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _testamentTabController,
          tabs: const [
            Tab(text: 'Antigo Testamento'),
            Tab(text: 'Novo Testamento'),
          ],
        ),
      ),
      body: StreamBuilder<Map<String, BibleProgressModel>>(
        stream: _bibleService.streamAllProgress(user.uid),
        builder: (context, userProgressSnapshot) {
          if (userProgressSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SelectableText(
                  'Erro ao carregar progresso da Bíblia: ${userProgressSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final userProgress = userProgressSnapshot.data ?? {};

          return StreamBuilder<Map<String, BibleProgressModel>>(
            stream: partner != null 
                ? _bibleService.streamAllProgress(partner.uid) 
                : Stream.value({}),
            builder: (context, partnerProgressSnapshot) {
              if (partnerProgressSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SelectableText(
                      'Erro ao carregar progresso da Bíblia do parceiro: ${partnerProgressSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              final partnerProgress = partnerProgressSnapshot.data ?? {};

              return TabBarView(
                controller: _testamentTabController,
                children: [
                  _buildBookList(otBooks, user.uid, partner?.uid, userProgress, partnerProgress, partner?.name),
                  _buildBookList(ntBooks, user.uid, partner?.uid, userProgress, partnerProgress, partner?.name),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookList(
    List<BibleBook> books,
    String userId,
    String? partnerId,
    Map<String, BibleProgressModel> userProgress,
    Map<String, BibleProgressModel> partnerProgress,
    String? partnerName,
  ) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        
        // Calcula o progresso do Usuário Atual
        final uProg = userProgress[book.name];
        final uReadCount = uProg?.readChapters.length ?? 0;
        final uPercent = book.chapters > 0 ? uReadCount / book.chapters : 0.0;

        // Calcula o progresso do Parceiro
        final pProg = partnerProgress[book.name];
        final pReadCount = pProg?.readChapters.length ?? 0;
        final pPercent = book.chapters > 0 ? pReadCount / book.chapters : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BibleBookChaptersScreen(
                    book: book,
                    userId: userId,
                    partnerId: partnerId,
                    partnerName: partnerName,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do Livro e número de capítulos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        book.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                        ),
                      ),
                      Text(
                        '${book.chapters} cap.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barra de Progresso - Usuário Atual
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Você', style: theme.textTheme.bodySmall),
                          Text('${(uPercent * 100).toInt()}% ($uReadCount/${book.chapters})',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: uPercent,
                          backgroundColor: theme.primaryColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                  // Barra de Progresso - Parceiro (se houver parceiro vinculado)
                  if (partnerId != null) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(partnerName ?? 'Parceiro', style: theme.textTheme.bodySmall),
                            Text('${(pPercent * 100).toInt()}% ($pReadCount/${book.chapters})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pPercent,
                            backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// TELA DETALHADA DOS CAPÍTULOS DE UM LIVRO BÍBLICO
class BibleBookChaptersScreen extends StatelessWidget {
  final BibleBook book;
  final String userId;
  final String? partnerId;
  final String? partnerName;

  const BibleBookChaptersScreen({
    super.key,
    required this.book,
    required this.userId,
    this.partnerId,
    this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final bibleService = BibleService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          book.name,
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<BibleProgressModel?>(
        stream: bibleService.streamBookProgress(userId, book.name),
        builder: (context, userSnapshot) {
          final userProgress = userSnapshot.data?.readChapters ?? [];

          return StreamBuilder<BibleProgressModel?>(
            stream: partnerId != null 
                ? bibleService.streamBookProgress(partnerId!, book.name) 
                : Stream.value(null),
            builder: (context, partnerSnapshot) {
              final partnerProgress = partnerSnapshot.data?.readChapters ?? [];

              final isAllRead = userProgress.length == book.chapters;

              return Column(
                children: [
                  // Barra Superior de Controle (Marcar/Desmarcar Todos)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: theme.cardTheme.color?.withOpacity(0.4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Capítulos lidos: ${userProgress.length} / ${book.chapters}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            isAllRead ? Icons.bookmark_remove_rounded : Icons.bookmark_added_rounded,
                            size: 18,
                          ),
                          label: Text(isAllRead ? 'Desmarcar todos' : 'Marcar todos'),
                          onPressed: () {
                            bibleService.markAllChapters(
                              userId,
                              book.name,
                              book.chapters,
                              !isAllRead, // Inverte o estado atual
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAllRead
                                      ? 'Todos os capítulos de ${book.name} desmarcados.'
                                      : 'Todos os capítulos de ${book.name} marcados como lidos!',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Grade de Capítulos
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, // 5 botões por linha
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: book.chapters,
                      itemBuilder: (context, index) {
                        final chapterNum = index + 1;
                        final isReadByMe = userProgress.contains(chapterNum);
                        final isReadByPartner = partnerProgress.contains(chapterNum);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              bibleService.toggleChapter(
                                userId,
                                book.name,
                                chapterNum,
                                !isReadByMe,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isReadByMe 
                                    ? theme.primaryColor.withOpacity(0.2) 
                                    : theme.inputDecorationTheme.fillColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isReadByMe 
                                      ? theme.primaryColor 
                                      : theme.primaryColor.withOpacity(0.15),
                                  width: isReadByMe ? 1.5 : 1,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Número do Capítulo
                                  Text(
                                    '$chapterNum',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isReadByMe 
                                          ? theme.primaryColor 
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                  
                                  // Indicador de Leitura do Parceiro (Pequeno coração/círculo no canto)
                                  if (isReadByPartner)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(
                                        Icons.favorite_rounded,
                                        size: 10,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Legenda das cores no rodapé
                  if (partnerId != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.crop_square_rounded, color: theme.primaryColor),
                          const SizedBox(width: 4),
                          Text('Lido por você', style: theme.textTheme.bodySmall),
                          const SizedBox(width: 16),
                          Icon(Icons.favorite_rounded, color: theme.colorScheme.secondary, size: 14),
                          const SizedBox(width: 4),
                          Text('Lido por ${partnerName ?? 'Amor'}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
