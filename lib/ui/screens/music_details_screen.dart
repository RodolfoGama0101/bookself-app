import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_record.dart';
import '../../services/auth_service.dart';
import '../../services/music_library_service.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';

class MusicDetailsScreen extends StatefulWidget {
  const MusicDetailsScreen({
    super.key,
    required this.music,
    required this.service,
  });
  final MusicRecord music;
  final MusicLibraryService service;
  @override
  State<MusicDetailsScreen> createState() => _MusicDetailsScreenState();
}

class _MusicDetailsScreenState extends State<MusicDetailsScreen> {
  late final MusicRecord _music = widget.music;
  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid == _music.entry.ownerId;
  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    if (!_current) {
      return const Scaffold(
        body: ContentState(
          title: 'Sua conta mudou',
          message: 'Volte à Biblioteca para continuar.',
        ),
      );
    }
    final data = _music.catalog.metadata.toMap();
    return ReadingPage(
      maxWidth: 680,
      child: Scaffold(
        appBar: AppBar(title: Text('Detalhes · ${_music.typeLabel}')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: 180,
              child: BookCover(
                url: _music.cover,
                placeholderBuilder: (_) =>
                    const Icon(Icons.music_note_outlined, size: 64),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _music.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _music.artists,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_music.version != null)
              Text('Versão/edição: ${_music.version}'),
            if (data['albumTitle'] != null)
              Text('Álbum: ${data['albumTitle']}'),
            if (data['releaseYear'] != null)
              Text('Lançamento: ${data['releaseYear']}'),
            if (data['durationMs'] != null)
              Text(
                'Duração: ${Duration(milliseconds: data['durationMs'] as int).inSeconds} segundos',
              ),
            Text(
              _music.catalog.identity.isManual
                  ? 'Cadastro manual'
                  : 'Catálogo: ${_music.catalog.identity.provider}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Salvar uma faixa ou álbum não registra uma escuta. As faixas de um álbum são independentes.',
            ),
          ],
        ),
      ),
    );
  }
}
