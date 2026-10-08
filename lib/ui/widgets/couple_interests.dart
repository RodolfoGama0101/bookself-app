import 'package:flutter/material.dart';
import '../../data/models/couple_record.dart';
import '../../data/models/media_model.dart';
import '../../services/couple_interests.dart';

class CoupleInterests extends StatefulWidget {
  const CoupleInterests({
    super.key,
    required this.rows,
    required this.uid,
    required this.partnerUid,
  });
  final List<CoupleRecord> rows;
  final String uid, partnerUid;
  @override
  State<CoupleInterests> createState() => _CoupleInterestsState();
}

class _CoupleInterestsState extends State<CoupleInterests> {
  int _next = 0;
  String _label(CoupleSelection selection) {
    final type = switch (selection.type) {
      MediaType.book => 'Livro',
      MediaType.movie => 'Filme',
      MediaType.series => 'Série',
      MediaType.track => 'Faixa',
      MediaType.album => 'Álbum',
    };
    return '$type: ${selection.title}${selection.subtitle.isEmpty ? "" : " · ${selection.subtitle}"}';
  }

  @override
  Widget build(BuildContext context) {
    final matches = commonCoupleSelections(
      widget.rows,
      widget.uid,
      widget.partnerUid,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Interesses em comum',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Compara somente as seleções que cada pessoa adicionou a esta lista. Não consulta bibliotecas ou preferências privadas.',
            ),
            if (matches.isEmpty)
              const Text(
                'Ainda não há coincidências nesta lista. Cada pessoa pode adicionar o que deseja escolher em conjunto.',
              )
            else ...[
              const Text(
                'Texto igual pode representar edições diferentes; confiram antes de escolher.',
              ),
              for (final selection in matches)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${_label(selection)}\nOs dois adicionaram seleções com a mesma mídia, origem, referência e título/artista.',
                  ),
                ),
              OutlinedButton(
                onPressed: () => setState(() => _next++),
                child: const Text('Destacar próxima opção'),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Opção ${(_next % matches.length) + 1} de ${matches.length}: ${_label(matches[_next % matches.length])}. Conversem para decidir; isso não registra uma experiência nem altera progresso.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
