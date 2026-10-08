import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_model.dart';

/// Conteúdo mínimo que a pessoa escolheu compartilhar, sem estado pessoal.
class CoupleSelection {
  CoupleSelection({
    required this.type,
    required String title,
    String subtitle = '',
    this.source = 'manual',
    this.reference,
    Map<String, dynamic>? episode,
  }) : title = title.trim(),
       subtitle = subtitle.trim(),
       episode = episode == null ? null : Map.unmodifiable(episode) {
    requireText(this.title);
    if (episode != null) {
      requireKeys(episode, {'id', 'season', 'number'});
      requireDocumentId(episode['id'] as String);
      if (type != MediaType.series ||
          episode['season'] is! int ||
          episode['number'] is! int ||
          (episode['season'] as int) < 0 ||
          (episode['number'] as int) < 1) {
        throw const FormatException('Episódio inválido');
      }
    }
    if (this.title.length > 300 ||
        this.subtitle.length > 300 ||
        !const ['manual', 'library', 'catalog'].contains(source) ||
        (reference != null &&
            (reference!.isEmpty || reference!.length > 1000))) {
      throw const FormatException('Seleção inválida');
    }
    if ((type == MediaType.track || type == MediaType.album) &&
        this.subtitle.isEmpty) {
      throw const FormatException('Informe o artista');
    }
  }
  final MediaType type;
  final String title, subtitle, source;
  final String? reference;
  final Map<String, dynamic>? episode;
  Map<String, dynamic> toMap() => {
    'mediaType': type.name,
    'title': title,
    'subtitle': subtitle,
    'source': source,
    'reference': reference,
    'episode': episode,
  };
  factory CoupleSelection.fromMap(Map<String, dynamic> data) {
    requireKeys(data, {
      'mediaType',
      'title',
      'subtitle',
      'source',
      'reference',
      'episode',
    });
    return CoupleSelection(
      type: MediaType.values.byName(data['mediaType']),
      title: data['title'],
      subtitle: data['subtitle'],
      source: data['source'],
      reference: data['reference'],
      episode: data['episode'] == null
          ? null
          : Map<String, dynamic>.from(data['episode']),
    );
  }
}

class CoupleRecord {
  CoupleRecord(this.id, Map<String, dynamic> data)
    : data = Map.unmodifiable(data);
  final String id;
  final Map<String, dynamic> data;
  int get version => data['version'] as int;
  int get revision => data['revision'] as int;
  String get author => data['authorId'] as String;
  CoupleSelection get selection =>
      CoupleSelection.fromMap(Map<String, dynamic>.from(data['selection']));
  String get occurredOn => data['occurredOn'] as String;
  Map<String, dynamic> get responses =>
      Map<String, dynamic>.from(data['responses']);
  bool get confirmed => (data['participantIds'] as List).every(
    (uid) =>
        responses[uid]?['decision'] == 'confirmed' &&
        responses[uid]?['revision'] == revision,
  );
}

/// Revisão concorrente exige releitura e outra intenção, nunca sobrescrita.
class CoupleConflict implements Exception {
  const CoupleConflict();
}

String coupleDate(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final now = DateTime.now();
  if (day.isAfter(DateTime(now.year, now.month, now.day)) || day.year < 1) {
    throw const FormatException('Data da experiência inválida');
  }
  return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

bool confirmedSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
    !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites;
