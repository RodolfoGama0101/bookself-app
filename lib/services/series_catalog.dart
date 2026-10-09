import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../data/models/media_model.dart';
import '../utils/error_handler.dart';
import '../data/models/series_record.dart';

class SeriesCatalogItem {
  SeriesCatalogItem(
    this.identity,
    this.metadata, {
    this.episodes = const [],
    this.complete = false,
    this.ended = false,
  }) {
    if (identity.isManual ||
        identity.mediaType != MediaType.series ||
        metadata.mediaType != MediaType.series) {
      throw const FormatException('Referência de série inválida');
    }
  }
  final CatalogIdentity identity;
  final MediaMetadata metadata;
  final List<SeriesEpisode> episodes;
  final bool complete, ended;
}

class SeriesCatalogPage {
  SeriesCatalogPage(Iterable<SeriesCatalogItem> items, this.nextCursor)
    : items = List.unmodifiable(items);
  final List<SeriesCatalogItem> items;
  final String? nextCursor;
}

abstract class SeriesCatalog {
  bool get available;
  Future<SeriesCatalogPage> search(String query, {String? cursor});
  Future<SeriesCatalogItem> details(CatalogIdentity identity);
  void close() {}

  static SeriesCatalog configured() {
    const endpoint = String.fromEnvironment('SERIES_CATALOG_URL');
    const provider = String.fromEnvironment('SERIES_CATALOG_PROVIDER');
    if (endpoint.isEmpty || provider.isEmpty) return UnavailableSeriesCatalog();
    try {
      return HttpSeriesCatalog(Uri.parse(endpoint), provider);
    } catch (_) {
      // Configuração inválida nunca envia dados a outro destino.
      return UnavailableSeriesCatalog();
    }
  }
}

class UnavailableSeriesCatalog extends SeriesCatalog {
  @override
  bool get available => false;
  @override
  Future<SeriesCatalogPage> search(String query, {String? cursor}) async =>
      throw const CatalogConfigurationException(mediaName: 'séries');
  @override
  Future<SeriesCatalogItem> details(CatalogIdentity identity) async =>
      throw const CatalogConfigurationException(mediaName: 'séries');
}

/// Contrato de um intermediário normalizado, sem token de fornecedor no app.
/// Não implementa/contrata um backend nem decide TMDB ou licença/cache.
class HttpSeriesCatalog extends SeriesCatalog {
  HttpSeriesCatalog(
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
      throw const CatalogConfigurationException(mediaName: 'séries');
    }
    try {
      CatalogIdentity.external(MediaType.series, provider, 'validation');
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
    List<String> segments, [
    Map<String, String>? query,
  ]) async {
    final uri = endpoint.replace(
      pathSegments: [
        ...endpoint.pathSegments.where((part) => part.isNotEmpty),
        'series',
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
      throw CatalogRequestException(response.statusCode, mediaName: 'séries');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || data['provider'] != provider) {
      throw const FormatException('Fornecedor/resposta incompatível');
    }
    return data;
  }

  SeriesCatalogItem _normalize(dynamic input, {bool detailed = false}) {
    if (input is! Map<String, dynamic> ||
        input['id'] is! String ||
        input['title'] is! String ||
        (input['title'] as String).trim().isEmpty ||
        (input['title'] as String).length > 300) {
      throw const FormatException('Série incompleto');
    }
    final year = input['releaseYear'];
    final cover = input['coverUrl'];
    final uri = cover is String ? Uri.tryParse(cover) : null;
    final episodes = <SeriesEpisode>[];
    if (detailed && input['episodes'] != null) {
      if (input['episodes'] is! List ||
          (input['episodes'] as List).length > 500) {
        throw const FormatException('Lista inválida');
      }
      final ids = <String>{};
      for (final row in input['episodes']) {
        final e = SeriesEpisode(
          id: row['id'] as String,
          season: row['season'] as int,
          number: row['number'] as int,
          availableOn: row['availableOn'] as String?,
          available: row['available'] == true,
        );
        if (!ids.add(e.id)) throw const FormatException('Identidade repetida');
        episodes.add(e);
      }
    }
    return SeriesCatalogItem(
      CatalogIdentity.external(MediaType.series, provider, input['id']),
      MediaMetadata(MediaType.series, {
        'title': (input['title'] as String).trim(),
        'releaseYear': year is int && year >= 1 && year <= 9999 ? year : null,
        'coverUrl':
            uri != null &&
                uri.scheme == 'https' &&
                uri.host.isNotEmpty &&
                uri.userInfo.isEmpty
            ? cover
            : null,
      }),
      episodes: List.unmodifiable(episodes),
      complete:
          detailed && input['complete'] == true && input['episodes'] is List,
      ended: detailed && input['ended'] == true,
    );
  }

  @override
  Future<SeriesCatalogPage> search(String query, {String? cursor}) async {
    query = query.trim();
    if (query.isEmpty) return SeriesCatalogPage([], null);
    if (query.length > 300 ||
        (cursor != null && (cursor.isEmpty || cursor.length > 1000))) {
      throw const FormatException('Consulta/cursor inválido');
    }
    final data = await _get(
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
    final unique = <String, SeriesCatalogItem>{};
    for (final row in rows) {
      try {
        final series = _normalize(row);
        unique.putIfAbsent(series.identity.key, () => series);
      } on FormatException {
        /* Item parcial sem identidade/título é descartado. */
      }
    }
    return SeriesCatalogPage(
      unique.values,
      rows.isEmpty ? null : next as String?,
    );
  }

  @override
  Future<SeriesCatalogItem> details(CatalogIdentity identity) async {
    if (identity.isManual ||
        identity.mediaType != MediaType.series ||
        identity.provider != provider) {
      throw const FormatException('Fornecedor incompatível');
    }
    final item = _normalize(
      (await _get([identity.externalId!]))['item'],
      detailed: true,
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
