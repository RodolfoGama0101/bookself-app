import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../data/models/media_model.dart';
import '../utils/error_handler.dart';

bool isMusicType(MediaType type) =>
    type == MediaType.track || type == MediaType.album;

class MusicCatalogItem {
  MusicCatalogItem(this.identity, this.metadata) {
    if (identity.isManual ||
        !isMusicType(identity.mediaType) ||
        !isMusicType(metadata.mediaType)) {
      throw const FormatException('Referência de filme inválida');
    }
  }
  final CatalogIdentity identity;
  final MediaMetadata metadata;
}

class MusicCatalogPage {
  MusicCatalogPage(Iterable<MusicCatalogItem> items, this.nextCursor)
    : items = List.unmodifiable(items);
  final List<MusicCatalogItem> items;
  final String? nextCursor;
}

abstract class MusicCatalog {
  bool get available;
  Future<MusicCatalogPage> search(
    MediaType type,
    String query, {
    String? cursor,
  });
  Future<MusicCatalogItem> details(CatalogIdentity identity);
  void close() {}

  static MusicCatalog configured() {
    const endpoint = String.fromEnvironment('MUSIC_CATALOG_URL');
    const provider = String.fromEnvironment('MUSIC_CATALOG_PROVIDER');
    if (endpoint.isEmpty || provider.isEmpty) return UnavailableMusicCatalog();
    try {
      return HttpMusicCatalog(Uri.parse(endpoint), provider);
    } catch (_) {
      // Configuração inválida nunca envia dados a outro destino.
      return UnavailableMusicCatalog();
    }
  }
}

class UnavailableMusicCatalog extends MusicCatalog {
  @override
  bool get available => false;
  @override
  Future<MusicCatalogPage> search(
    MediaType type,
    String query, {
    String? cursor,
  }) async => throw const CatalogConfigurationException(mediaName: 'música');
  @override
  Future<MusicCatalogItem> details(CatalogIdentity identity) async =>
      throw const CatalogConfigurationException(mediaName: 'música');
}

/// Contrato de um intermediário normalizado, sem token de fornecedor no app.
/// Não implementa um backend nem escolhe fornecedor musical ou licença/cache.
class HttpMusicCatalog extends MusicCatalog {
  HttpMusicCatalog(
    this.endpoint,
    this.provider, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        timeout <= Duration.zero) {
      if (_ownsClient) _client.close();
      throw const CatalogConfigurationException(mediaName: 'música');
    }
    try {
      CatalogIdentity.external(MediaType.track, provider, 'validation');
    } catch (_) {
      if (_ownsClient) _client.close();
      rethrow;
    }
  }
  final Uri endpoint;
  final String provider;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  @override
  bool get available => true;

  Future<Map<String, dynamic>> _get(
    MediaType type,
    List<String> segments, [
    Map<String, String>? query,
  ]) async {
    final uri = endpoint.replace(
      pathSegments: [
        ...endpoint.pathSegments.where((part) => part.isNotEmpty),
        'music',
        type == MediaType.track ? 'tracks' : 'albums',
        ...segments,
      ],
      queryParameters: query,
    );
    // Recusa redirecionamento: o destino configurado é a única origem aprovada.
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await (() async => http.Response.fromStream(
      await _client.send(request),
    ))().timeout(timeout);
    if (response.statusCode == 429) throw const CatalogQuotaException(429);
    if (response.statusCode != 200) {
      throw CatalogRequestException(response.statusCode, mediaName: 'música');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || data['provider'] != provider) {
      throw const FormatException('Fornecedor/resposta incompatível');
    }
    return data;
  }

  MusicCatalogItem _normalize(MediaType type, dynamic input) {
    if (input is! Map<String, dynamic> ||
        input['id'] is! String ||
        input['title'] is! String ||
        (input['title'] as String).trim().isEmpty ||
        (input['title'] as String).length > 300) {
      throw const FormatException('Música incompleto');
    }
    final artists = input['artists'];
    if (artists is! List ||
        artists.isEmpty ||
        artists.any((a) => a is! String || a.trim().isEmpty) ||
        artists.join(', ').length > 300) {
      throw const FormatException('Artistas ausentes ou inválidos');
    }
    String? text(String key) =>
        input[key] is String && (input[key] as String).trim().isNotEmpty
        ? (input[key] as String).trim()
        : null;
    final year = input['releaseYear'];
    final cover = input['coverUrl'];
    final uri = cover is String ? Uri.tryParse(cover) : null;
    return MusicCatalogItem(
      CatalogIdentity.external(type, provider, input['id']),
      MediaMetadata(type, {
        'title': (input['title'] as String).trim(),
        'artists': artists.map((a) => (a as String).trim()).toList(),
        if (type == MediaType.album) ...{
          'releaseYear': year is int && year >= 1 && year <= 9999 ? year : null,
          'edition': text('edition'),
        } else ...{
          'albumTitle': text('albumTitle'),
          'version': text('version'),
          'durationMs': input['durationMs'] is int && input['durationMs'] >= 0
              ? input['durationMs']
              : null,
        },
        'coverUrl':
            uri != null &&
                uri.scheme == 'https' &&
                uri.host.isNotEmpty &&
                uri.userInfo.isEmpty
            ? cover
            : null,
      }),
    );
  }

  @override
  Future<MusicCatalogPage> search(
    MediaType type,
    String query, {
    String? cursor,
  }) async {
    if (!isMusicType(type)) {
      throw const FormatException('Tipo musical inválido');
    }
    query = query.trim();
    if (query.isEmpty) return MusicCatalogPage([], null);
    if (query.length > 300 ||
        (cursor != null && (cursor.isEmpty || cursor.length > 1000))) {
      throw const FormatException('Consulta/cursor inválido');
    }
    final data = await _get(
      type,
      ['search'],
      {'q': query, 'language': 'pt-BR', 'cursor': ?cursor},
    );
    final rows = data['items'];
    final next = data['nextCursor'];
    if (rows is! List ||
        rows.length > 100 ||
        (next != null &&
            (next is! String || next.isEmpty || next.length > 1000))) {
      throw const FormatException('Página inválida');
    }
    final unique = <String, MusicCatalogItem>{};
    for (final row in rows) {
      try {
        final movie = _normalize(type, row);
        unique.putIfAbsent(movie.identity.key, () => movie);
      } on FormatException {
        /* Item parcial sem identidade/título é descartado. */
      }
    }
    return MusicCatalogPage(
      unique.values,
      rows.isEmpty ? null : next as String?,
    );
  }

  @override
  Future<MusicCatalogItem> details(CatalogIdentity identity) async {
    if (identity.isManual ||
        !isMusicType(identity.mediaType) ||
        identity.provider != provider) {
      throw const FormatException('Fornecedor incompatível');
    }
    final item = _normalize(
      identity.mediaType,
      (await _get(identity.mediaType, [identity.externalId!]))['item'],
    );
    if (item.identity.key != identity.key) {
      throw const FormatException('Referência de detalhes divergente');
    }
    return item;
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}
