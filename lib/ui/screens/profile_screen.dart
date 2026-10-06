import 'sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';
import '../widgets/dialog_with_controllers.dart';
import '../../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/reading_surface.dart';
import 'partner_invitation_screen.dart';
import '../../services/theme_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../utils/error_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profiles, this.imagePicker});

  final UserProfileService? profiles;
  final ImagePicker? imagePicker;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isPhotoLoading = false;
  late final _profiles = widget.profiles ?? UserProfileService();
  late final _imagePicker = widget.imagePicker ?? ImagePicker();

  Future<void> _changeTheme(ThemeService service, [ThemeMode? mode]) async {
    final error = mode == null
        ? await service.toggleTheme(Theme.of(context).brightness)
        : await service.setThemeMode(mode);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _signOut(AuthService authService) async {
    try {
      await authService.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível sair. ${ErrorHandler.getFriendlyErrorMessage(error, operation: ErrorOperation.signOut)}',
          ),
        ),
      );
    }
  }

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
    super.dispose();
  }

  // O formulário retorna o valor; a escrita e o feedback pertencem à tela.
  void _showEditNameDialog(
    BuildContext context,
    String currentName,
    String uid,
  ) async {
    final nameController = TextEditingController(text: currentName);
    final theme = Theme.of(context);
    final newName = await showDialogWithControllers<String>(
      context: context,
      controllers: [nameController],
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Editar Nome',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.pop(dialogContext, name);
            },
            child: Text(
              'Salvar',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || newName == null) return;
    try {
      await _profiles.updateName(uid, newName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nome atualizado com sucesso!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível atualizar o nome: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.updateName)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _confirmUnlink(BuildContext context, AuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Desvincular Casal?'),
        content: const Text(
          'Você tem certeza que deseja se desvincular do seu parceiro? '
          'Vocês deixarão de compartilhar a estante e o progresso da Bíblia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Desvincular',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final error = await authService.unlinkPartner();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Vínculo desfeito.'),
        backgroundColor: error == null
            ? Theme.of(context).colorScheme.inverseSurface
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  // Seleção e persistência da foto sem usar estado descartado.
  Future<void> _pickAndUploadImage(String uid, ImageSource source) async {
    if (!mounted || _isPhotoLoading) return;
    setState(() => _isPhotoLoading = true);
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (!mounted || image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _profiles.updatePhoto(uid, dataUri);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto de perfil atualizada com sucesso!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao atualizar foto: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.updatePhoto)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  Future<void> _removePhoto(String uid) async {
    if (!mounted || _isPhotoLoading) return;
    setState(() => _isPhotoLoading = true);
    try {
      await _profiles.updatePhoto(uid, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto de perfil removida com sucesso!'),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao remover foto: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.updatePhoto)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPhotoLoading = false);
    }
  }

  // Abre diálogo/bottomsheet com opções de câmera, galeria ou exclusão de foto
  void _showAvatarSelectionSheet(
    BuildContext context,
    String uid,
    bool hasPhoto,
  ) {
    if (!mounted || _isPhotoLoading) return;
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
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Alterar Foto de Perfil',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: theme.primaryColor,
                  ),
                  title: const Text('Escolher da Galeria'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(uid, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt_rounded,
                    color: theme.primaryColor,
                  ),
                  title: const Text('Tirar Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(uid, ImageSource.camera);
                  },
                ),
                if (hasPhoto) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Remover Foto',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removePhoto(uid);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Envia e-mail de redefinição de senha
  void _sendPasswordResetEmail(
    BuildContext context,
    AuthService authService,
    String email,
  ) async {
    final error = await authService.sendPasswordReset(email);
    if (context.mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar e-mail de redefinição: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link de redefinição enviado para: $email'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ReadingPage(
      maxWidth: 720,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          actions: [
            IconButton(
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: 'Alterar Tema',
              onPressed: themeService.isSaving || themeService.isLoading
                  ? null
                  : () => _changeTheme(themeService),
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
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: _getAvatarImage(user.photoUrl),
                        child: _isPhotoLoading
                            ? const CircularProgressIndicator()
                            : (user.photoUrl == null || user.photoUrl!.isEmpty
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : '?',
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
                              color: theme.colorScheme.onPrimary,
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
                              onPressed: () => _showEditNameDialog(
                                context,
                                user.name,
                                user.uid,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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
                            Icon(
                              Icons.favorite_rounded,
                              color: theme.colorScheme.secondary,
                            ),
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
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!partner.isAvailable)
                                    Text(
                                      'Perfil do parceiro indisponível no momento.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Desvincular Casal',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.1),
                          foregroundColor: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmUnlink(context, authService),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'O vínculo começa somente quando a outra pessoa aceita o convite.',
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Convites do casal',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PartnerInvitationScreen(),
                            ),
                          ),
                        ),
                      ],
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Tema do aplicativo'),
                      DropdownButton<ThemeMode>(
                        key: const ValueKey('theme-mode-selector'),
                        value: themeService.themeMode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Claro'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Escuro'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Sistema'),
                          ),
                        ],
                        onChanged:
                            themeService.isSaving || themeService.isLoading
                            ? null
                            : (mode) {
                                if (mode != null) {
                                  _changeTheme(themeService, mode);
                                }
                              },
                      ),
                      if (themeService.themeMode == ThemeMode.system)
                        const Text('Acompanha o tema do dispositivo.'),
                      if (themeService.isSaving || themeService.isLoading) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          themeService.isSaving
                              ? 'Salvando tema…'
                              : 'Carregando tema…',
                        ),
                      ],
                      if (themeService.loadError != null) ...[
                        const SizedBox(height: 8),
                        Text(themeService.loadError!),
                        TextButton(
                          onPressed:
                              themeService.isSaving || themeService.isLoading
                              ? null
                              : themeService.retryLoading,
                          child: const Text('Tentar carregar novamente'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('Compartilhamento'),
                  subtitle: const Text(
                    'Ocultar livros, progresso bíblico e gerenciar bloqueios',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SharingScreen()),
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
                  leading: Icon(
                    Icons.lock_reset_rounded,
                    color: theme.primaryColor,
                  ),
                  title: const Text('Redefinir Senha'),
                  subtitle: const Text(
                    'Enviar link de alteração para o seu e-mail',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _sendPasswordResetEmail(context, authService, user.email),
                ),
              ),
              const SizedBox(height: 32),

              // Botão de Logout
              CustomButton(
                text: 'Sair da Conta',
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                onPressed: () => _signOut(authService),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
