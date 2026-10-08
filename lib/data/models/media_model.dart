import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { book, movie, series, track, album }

/// Identidade da obra; nunca é o ID de uma entrada pessoal.
class CatalogIdentity {
  CatalogIdentity.external(this.mediaType, this.provider, this.externalId)
    : ownerId = null,
      manualId = null {
    requireText(provider);
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(provider!)) {
      throw const FormatException('Namespace de fornecedor inválido');
    }
    requireText(externalId);
    key;
  }

  CatalogIdentity.manual(this.mediaType, this.ownerId, this.manualId)
    : provider = null,
      externalId = null {
    requireText(ownerId);
    requireText(manualId);
    requireDocumentId(ownerId!);
    requireDocumentId(manualId!);
    key;
  }

  final MediaType mediaType;
  final String? provider, externalId, ownerId, manualId;
  bool get isManual => manualId != null;

  String get key {
    final tuple = isManual
        ? [1, mediaType.name, 'manual', ownerId, manualId]
        : [1, mediaType.name, 'external', provider, externalId];
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode(tuple)))
        .replaceAll('=', '');
    // Margem abaixo dos 1.500 bytes de um segmento Firestore; sem truncamento.
    if (encoded.length > 1000) {
      throw const FormatException('Referência de catálogo muito longa');
    }
    return encoded;
  }

  Map<String, dynamic> toMap() => isManual
      ? {'kind': 'manual', 'ownerId': ownerId, 'manualId': manualId}
      : {'kind': 'external', 'provider': provider, 'externalId': externalId};

  factory CatalogIdentity.fromMap(MediaType type, Map<String, dynamic> data) {
    if (data['kind'] == 'external') {
      requireKeys(data, {'kind', 'provider', 'externalId'});
      return CatalogIdentity.external(
        type,
        data['provider'] as String,
        data['externalId'] as String,
      );
    }
    if (data['kind'] == 'manual') {
      requireKeys(data, {'kind', 'ownerId', 'manualId'});
      return CatalogIdentity.manual(
        type,
        data['ownerId'] as String,
        data['manualId'] as String,
      );
    }
    throw const FormatException('Identidade desconhecida');
  }
}

/// Snapshot imutável, validado por mídia. Ausência opcional equivale a null.
class MediaMetadata {
  MediaMetadata(this.mediaType, Map<String, dynamic> input) {
    final optional = switch (mediaType) {
      MediaType.book => {'coverUrl', 'publishedDate'},
      MediaType.movie => {'coverUrl', 'releaseYear'},
      MediaType.series => {'coverUrl', 'releaseYear', 'productionStatus'},
      MediaType.track => {'coverUrl', 'albumTitle', 'version', 'durationMs'},
      MediaType.album => {'coverUrl', 'releaseYear', 'edition'},
    };
    final peopleKey = switch (mediaType) {
      MediaType.book => 'authors',
      MediaType.track || MediaType.album => 'artists',
      _ => null,
    };
    requireKeys(input, {'title', ...optional, ?peopleKey});
    requireText(input['title']);
    final result = <String, dynamic>{'title': input['title']};
    if (peopleKey != null) {
      final people = input[peopleKey];
      if (people is! List || (peopleKey == 'artists' && people.isEmpty)) {
        throw const FormatException('Autores/artistas inválidos');
      }
      for (final person in people) {
        requireText(person);
      }
      result[peopleKey] = List<String>.unmodifiable(people.cast<String>());
    }
    for (final field in optional) {
      final value = input[field];
      if (value != null) {
        if (field == 'releaseYear' || field == 'durationMs') {
          if (value is! int ||
              value < 0 ||
              (field == 'releaseYear' && (value < 1 || value > 9999))) {
            throw const FormatException('Número de metadado inválido');
          }
        } else {
          requireText(value);
          if (field == 'publishedDate') {
            requireCivilDate(value as String, partial: true);
          }
          if (field == 'coverUrl') {
            final uri = Uri.tryParse(value as String);
            if (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty) {
              throw const FormatException('Capa precisa de URL HTTPS');
            }
          }
        }
      }
      result[field] = value;
    }
    _data = Map.unmodifiable(result);
  }

  final MediaType mediaType;
  late final Map<String, dynamic> _data;
  String get title => _data['title'] as String;
  Map<String, dynamic> toMap() => Map.of(_data);

  /// Omitir preserva; null limpa opcionais; obrigatórios não aceitam null.
  MediaMetadata patch(Map<String, dynamic> changes) =>
      MediaMetadata(mediaType, {..._data, ...changes});
}

class MediaState {
  MediaState(this.mediaType, this.status, {this.date}) {
    final allowed = switch (mediaType) {
      MediaType.book => {'planned', 'reading', 'completed'},
      MediaType.movie => {'planned', 'watched'},
      MediaType.series => {'in_progress', 'up_to_date', 'completed', 'paused'},
      _ => <String>{},
    };
    if (!allowed.contains(status)) {
      throw const FormatException('Estado incompatível com mídia');
    }
    if (date != null) {
      requireCivilDate(date!);
      if (!((mediaType == MediaType.book && status == 'completed') ||
          (mediaType == MediaType.movie && status == 'watched'))) {
        throw const FormatException('Data incompatível com estado');
      }
    }
  }
  final MediaType mediaType;
  final String status;
  final String? date;
  Map<String, dynamic> toMap() => {
    'status': status,
    if (mediaType == MediaType.book) 'finishedOn': date,
    if (mediaType == MediaType.movie) 'watchedOn': date,
  };
  factory MediaState.fromMap(MediaType type, Map<String, dynamic> data) {
    final field = type == MediaType.book
        ? 'finishedOn'
        : type == MediaType.movie
        ? 'watchedOn'
        : null;
    requireKeys(data, {'status', ?field});
    return MediaState(
      type,
      data['status'] as String,
      date: field == null ? null : data[field] as String?,
    );
  }
  static MediaState? initial(MediaType type) => switch (type) {
    MediaType.book || MediaType.movie => MediaState(type, 'planned'),
    MediaType.series => MediaState(type, 'in_progress'),
    _ => null,
  };
}

class CatalogItem {
  CatalogItem({
    required this.id,
    required this.ownerId,
    required this.identity,
    required this.metadata,
    this.fetchedAt,
  }) {
    requireDocumentId(id);
    requireDocumentId(ownerId);
    if (identity.mediaType != metadata.mediaType ||
        (identity.isManual && identity.ownerId != ownerId)) {
      throw const FormatException('Catálogo incompatível com dono/mídia');
    }
  }
  final String id, ownerId;
  final CatalogIdentity identity;
  final MediaMetadata metadata;
  final DateTime? fetchedAt;
  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'ownerId': ownerId,
    'mediaType': identity.mediaType.name,
    'identity': identity.toMap(),
    'metadata': metadata.toMap(),
    'catalogKey': identity.key,
    'fetchedAt': fetchedAt == null
        ? null
        : Timestamp.fromDate(fetchedAt!.toUtc()),
  };
  factory CatalogItem.fromMap(String id, Map<String, dynamic> data) {
    requireVersion(data);
    requireFields(data, {
      'schemaVersion',
      'ownerId',
      'identity',
      'mediaType',
      'metadata',
      'catalogKey',
    });
    requireKeys(data, {
      'schemaVersion',
      'ownerId',
      'identity',
      'mediaType',
      'metadata',
      'catalogKey',
      'fetchedAt',
    });
    final type = MediaType.values.byName(data['mediaType'] as String);
    final item = CatalogItem(
      id: id,
      ownerId: data['ownerId'] as String,
      identity: CatalogIdentity.fromMap(
        type,
        Map<String, dynamic>.from(data['identity'] as Map),
      ),
      metadata: MediaMetadata(
        type,
        Map<String, dynamic>.from(data['metadata'] as Map),
      ),
      fetchedAt: (data['fetchedAt'] as Timestamp?)?.toDate().toUtc(),
    );
    if (data['catalogKey'] != item.identity.key) {
      throw const FormatException('Chave de catálogo inconsistente');
    }
    return item;
  }
}

class LibraryEntry {
  LibraryEntry({
    required this.id,
    required this.ownerId,
    required this.catalogId,
    required this.mediaType,
    required this.state,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  }) {
    requireDocumentId(id);
    requireDocumentId(ownerId);
    requireDocumentId(catalogId);
    validatePersonalState(mediaType, state, favorite);
    if (revision < 1) throw const FormatException('Revisão inválida');
  }
  final String id, ownerId, catalogId;
  final MediaType mediaType;
  final MediaState? state;
  final bool favorite;
  final DateTime createdAt, updatedAt;
  final int revision;

  factory LibraryEntry.fromMap(String id, Map<String, dynamic> data) {
    requireVersion(data);
    final required = {
      'schemaVersion',
      'ownerId',
      'catalogId',
      'mediaType',
      'state',
      'favorite',
      'isShared',
      'createdAt',
      'updatedAt',
      'revision',
    };
    requireFields(data, required);
    requireKeys(data, {...required, 'legacyRef'});
    // Compartilhamento/importação não fazem parte do contrato incremental.
    if (data['isShared'] != false || data['legacyRef'] != null) {
      throw const FormatException(
        'Entrada requer contrato ainda não suportado',
      );
    }
    final type = MediaType.values.byName(data['mediaType'] as String);
    return LibraryEntry(
      id: id,
      ownerId: data['ownerId'] as String,
      catalogId: data['catalogId'] as String,
      mediaType: type,
      state: data['state'] == null
          ? null
          : MediaState.fromMap(
              type,
              Map<String, dynamic>.from(data['state'] as Map),
            ),
      favorite: data['favorite'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate().toUtc(),
      revision: data['revision'] as int,
    );
  }
}

void validatePersonalState(MediaType type, MediaState? state, bool favorite) {
  final musical = type == MediaType.track || type == MediaType.album;
  if ((musical && state != null) ||
      (!musical && (state == null || state.mediaType != type || favorite))) {
    throw const FormatException('Progresso/favorito incompatível com mídia');
  }
}

void requireVersion(Map<String, dynamic> data) {
  if (data['schemaVersion'] != 1 || data['schemaVersion'] is! int) {
    throw const FormatException('Versão de esquema não suportada');
  }
}

void requireKeys(Map<String, dynamic> data, Set<String> allowed) {
  if (data.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Campo desconhecido');
  }
}

void requireFields(Map<String, dynamic> data, Set<String> required) {
  if (required.any((key) => !data.containsKey(key))) {
    throw const FormatException('Campo obrigatório ausente');
  }
}

void requireText(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Texto obrigatório ausente');
  }
}

void requireDocumentId(String value) {
  if (value.isEmpty ||
      value.contains('/') ||
      value == '.' ||
      value == '..' ||
      RegExp(r'^__.*__$').hasMatch(value) ||
      utf8.encode(value).length > 128) {
    throw const FormatException('ID inválido');
  }
}

void requireCivilDate(String value, {bool partial = false}) {
  final pattern = partial
      ? r'^\d{4}(-\d{2}(-\d{2})?)?$'
      : r'^\d{4}-\d{2}-\d{2}$';
  if (!RegExp(pattern).hasMatch(value)) {
    throw const FormatException('Data civil inválida');
  }
  final parts = value.split('-').map(int.parse).toList();
  final year = parts[0],
      month = parts.length > 1 ? parts[1] : 1,
      day = parts.length > 2 ? parts[2] : 1;
  final parsed = DateTime.utc(year, month, day);
  if (year < 1 ||
      parsed.year != year ||
      parsed.month != month ||
      parsed.day != day) {
    throw const FormatException('Data civil inválida');
  }
}
