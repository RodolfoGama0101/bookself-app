import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../data/models/book_model.dart';
import '../widgets/book_card.dart';
import '../widgets/custom_text_field.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_details_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _bookService = BookService();
  
  List<BookModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Executa busca na Google Books API
  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _bookService.searchGoogleBooks(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final uid = authService.currentUserModel?.uid ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A API do Google Books excedeu a cota de uso ou está indisponível. '
              'Você pode cadastrar o livro manualmente clicando no botão "+" no topo direito!',
            ),
            duration: const Duration(seconds: 7),
            backgroundColor: Colors.orange[800],
            action: SnackBarAction(
              label: 'Manual',
              textColor: Colors.white,
              onPressed: () {
                if (uid.isNotEmpty) {
                  _showManualAddDialog(context, uid);
                }
              },
            ),
          ),
        );
      }
    }
  }

  // Abre diálogo para escolher o status e data ao salvar o livro
  void _showAddBookDialog(BuildContext context, BookModel book, String userId) {
    String selectedStatus = 'Quero Ler';
    DateTime selectedDate = DateTime.now();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Adicionar à Estante',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Dropdown de seleção de Status
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status de Leitura'),
                    items: ['Quero Ler', 'Lendo', 'Lido']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedStatus = val;
                        });
                      }
                    },
                  ),
                  
                  // Seletor de Data de Término se o status for "Lido"
                  if (selectedStatus == 'Lido') ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'Data de Conclusão',
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Concluído em: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Icon(Icons.calendar_today, color: theme.primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    // Prepara o livro com o ID do usuário e status selecionados
                    final bookToSave = book.copyWith(
                      id: '', // Força gerar um novo ID no Firestore
                      userId: userId,
                      status: selectedStatus,
                      finishedDate: selectedStatus == 'Lido' ? selectedDate : null,
                      addedAt: DateTime.now(),
                    );

                    try {
                      await _bookService.saveBook(bookToSave);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${book.title}" adicionado com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Não foi possível salvar o livro. ${ErrorHandler.getFriendlyErrorMessage(e)}'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Salvar',
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Abre formulário para cadastro de livro manual
  void _showManualAddDialog(BuildContext context, String userId) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final coverController = TextEditingController();
    String selectedStatus = 'Quero Ler';
    DateTime selectedDate = DateTime.now();
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Adicionar Manualmente',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: titleController,
                        label: 'Título do Livro',
                        hint: 'Ex: Dom Casmurro',
                        validator: (val) => val == null || val.isEmpty ? 'Insira o título' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: authorController,
                        label: 'Autor(es)',
                        hint: 'Ex: Machado de Assis',
                        validator: (val) => val == null || val.isEmpty ? 'Insira o autor' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: coverController,
                        label: 'URL da Capa (Opcional)',
                        hint: 'https://exemplo.com/capa.jpg',
                        keyboardType: TextInputType.url,
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final uri = Uri.tryParse(val.trim());
                            if (uri == null || !uri.hasAbsolutePath || !uri.scheme.startsWith('http')) {
                              return 'Insira uma URL válida (http/https) ou deixe vazio';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status de Leitura'),
                        items: ['Quero Ler', 'Lendo', 'Lido']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      if (selectedStatus == 'Lido') ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              helpText: 'Data de Conclusão',
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: theme.inputDecorationTheme.fillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Concluído: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Icon(Icons.calendar_today, color: theme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      titleController.dispose();
                      authorController.dispose();
                      coverController.dispose();
                    });
                  },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final bookToSave = BookModel(
                      id: '', // Novo ID
                      userId: userId,
                      title: titleController.text.trim(),
                      authors: [authorController.text.trim()],
                      coverUrl: coverController.text.trim(),
                      status: selectedStatus,
                      publishedDate: 'Manual',
                      finishedDate: selectedStatus == 'Lido' ? selectedDate : null,
                      addedAt: DateTime.now(),
                    );

                    try {
                      await _bookService.saveBook(bookToSave);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${bookToSave.title}" cadastrado com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        titleController.dispose();
                        authorController.dispose();
                        coverController.dispose();
                      });
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Não foi possível cadastrar o livro. ${ErrorHandler.getFriendlyErrorMessage(e)}'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Cadastrar',
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final theme = Theme.of(context);

    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Buscar Livros',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Cadastro Manual',
            onPressed: () => _showManualAddDialog(context, user.uid),
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _searchController,
                    label: 'Pesquisar livro',
                    hint: 'Título, autor ou ISBN...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.search_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _performSearch,
                ),
              ],
            ),
          ),

          // Área de Resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hasSearched 
                                    ? Icons.search_off_rounded 
                                    : Icons.library_books_rounded,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _hasSearched
                                    ? 'Nenhum resultado encontrado.\nTente buscar por outros termos ou adicione manualmente.'
                                    : 'Pesquise pelo título ou autor para encontrar novos livros na API do Google.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final book = _searchResults[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: BookCard(
                              book: book,
                              onTap: () => showBookDetailsSheet(context, book, false),
                              trailing: IconButton(
                                icon: Icon(Icons.add_box_rounded, color: theme.primaryColor, size: 28),
                                tooltip: 'Adicionar à estante',
                                onPressed: () => _showAddBookDialog(context, book, user.uid),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
