import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../../services/theme_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../utils/error_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _partnerCodeController = TextEditingController();
  bool _isPhotoLoading = false;

  ImageProvider? _getAvatarImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image/')) {
      final base64String = photoUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(photoUrl);
  }

  @override
  void dispose() {
    _partnerCodeController.dispose();
    super.dispose();
  }

  // Diálogo para editar o nome do usuário
  void _showEditNameDialog(BuildContext context, String currentName, String uid) {
    final nameController = TextEditingController(text: currentName);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Editar Nome',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Seu Nome',
              hintText: 'Como quer ser chamado(a)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  nameController.dispose();
                });
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'name': newName});
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nome atualizado com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    nameController.dispose();
                  });
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
  }

  // Diálogo para confirmar desvinculação
  void _confirmUnlink(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desvincular Casal?'),
          content: const Text(
            'Você tem certeza que deseja se desvincular do seu parceiro? '
            'Vocês deixarão de compartilhar a estante e o progresso da Bíblia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final error = await authService.unlinkPartner();
                if (context.mounted) {
                  Navigator.pop(context);
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vínculo desfeito.'), backgroundColor: Colors.orange),
                    );
                  }
                }
              },
              child: const Text(
                'Desvincular',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Realiza a seleção e salvamento da imagem como Base64 no Firestore
  Future<void> _pickAndUploadImage(String uid, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 75,
      );

      if (image == null) return; // cancelou

      setState(() {
        _isPhotoLoading = true;
      });

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      // Atualiza o campo da foto no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': dataUri});

      setState(() {
        _isPhotoLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isPhotoLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: ${ErrorHandler.getFriendlyErrorMessage(e)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Remove a foto do perfil e volta ao estado padrão (iniciais)
  Future<void> _removePhoto(String uid) async {
    setState(() {
      _isPhotoLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': null});

      setState(() {
        _isPhotoLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil removida com sucesso!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isPhotoLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover foto: ${ErrorHandler.getFriendlyErrorMessage(e)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Abre diálogo/bottomsheet com opções de câmera, galeria ou exclusão de foto
  void _showAvatarSelectionSheet(BuildContext context, String uid, bool hasPhoto) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600]?.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Alterar Foto de Perfil',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: theme.primaryColor),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(uid, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: theme.primaryColor),
                title: const Text('Tirar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(uid, ImageSource.camera);
                },
              ),
              if (hasPhoto) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Remover Foto', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto(uid);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Envia e-mail de redefinição de senha
  void _sendPasswordResetEmail(BuildContext context, AuthService authService, String email) async {
    final error = await authService.sendPasswordReset(email);
    if (context.mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar e-mail de redefinição: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link de redefinição enviado para: $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _submitLink(AuthService authService) async {
    final code = _partnerCodeController.text.trim();
    if (code.isEmpty) return;

    final error = await authService.linkPartner(code);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else if (mounted) {
      _partnerCodeController.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vínculo realizado com sucesso! Bem-vindos!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Perfil',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeService.isDarkMode 
                  ? Icons.light_mode_rounded 
                  : Icons.dark_mode_rounded
            ),
            tooltip: 'Alterar Tema',
            onPressed: () => themeService.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: theme.primaryColor.withOpacity(0.15),
                      backgroundImage: _getAvatarImage(user.photoUrl),
                      child: _isPhotoLoading
                          ? const CircularProgressIndicator()
                          : (user.photoUrl == null || user.photoUrl!.isEmpty
                              ? Text(
                                  user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _showAvatarSelectionSheet(
                          context,
                          user.uid,
                          user.photoUrl != null && user.photoUrl!.isNotEmpty,
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.primaryColor,
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: theme.textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            tooltip: 'Editar Nome',
                            onPressed: () => _showEditNameDialog(context, user.name, user.uid),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Card Vínculo do Casal
            Text(
              'Relacionamento',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (partner != null) ...[
                      Row(
                        children: [
                          Icon(Icons.favorite_rounded, color: theme.colorScheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vinculado com:',
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  partner.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  partner.email,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Desvincular Casal',
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        onPressed: () => _confirmUnlink(context, authService),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.favorite_border_rounded, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status:',
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  'Nenhum vínculo ativo',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Compartilhe suas estantes e progresso da Bíblia! Insira o código do seu parceiro abaixo para se conectar:',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _partnerCodeController,
                        label: 'Código do seu Parceiro',
                        hint: 'Cole o código dele(a) aqui',
                        prefixIcon: Icons.vpn_key_rounded,
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Vincular Casal',
                        isLoading: authService.isLoading,
                        onPressed: () => _submitLink(authService),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card Código Pessoal
            Text(
              'Compartilhamento',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seu Código de Convite',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.uid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copiar código',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: user.uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código copiado!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card Tema
            Text(
              'Aparência',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  themeService.isDarkMode 
                      ? Icons.dark_mode_rounded 
                      : Icons.light_mode_rounded,
                  color: theme.primaryColor,
                ),
                title: const Text('Tema Escuro'),
                subtitle: Text(
                  themeService.isDarkMode 
                      ? 'Ativado' 
                      : 'Desativado',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Switch(
                  value: themeService.isDarkMode,
                  activeColor: theme.primaryColor,
                  onChanged: (value) => themeService.toggleTheme(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card Segurança
            Text(
              'Segurança',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.lock_reset_rounded, color: theme.primaryColor),
                title: const Text('Redefinir Senha'),
                subtitle: const Text('Enviar link de alteração para o seu e-mail'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _sendPasswordResetEmail(context, authService, user.email),
              ),
            ),
            const SizedBox(height: 32),

            // Botão de Logout
            CustomButton(
              text: 'Sair da Conta',
              backgroundColor: theme.brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.grey[200],
              foregroundColor: theme.brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.black87,
              onPressed: () => authService.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
