import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../data/models/media_model.dart';
import '../utils/error_handler.dart';

class MovieCatalogItem {
  MovieCatalogItem(this.identity, this.metadata) {
    if (identity.isManual ||
        identity.mediaType != MediaType.movie ||
        metadata.mediaType != MediaType.movie) {
      throw const FormatException('Referência de filme inválida');
    }
  }
  final CatalogIdentity identity;
  final MediaMetadata metadata;
}

class MovieCatalogPage {
  MovieCatalogPage(Iterable<MovieCatalogItem> items, this.nextCursor)
    : items = List.unmodifiable(items);
  final List<MovieCatalogItem> items;
  final String? nextCursor;
}

abstract class MovieCatalog {
  bool get available;
  Future<MovieCatalogPage> search(String query, {String? cursor});
  Future<MovieCatalogItem> details(CatalogIdentity identity);
  void close() {}

  static MovieCatalog configured() {
    const endpoint = String.fromEnvironment('MOVIE_CATALOG_URL');
    const provider = String.fromEnvironment('MOVIE_CATALOG_PROVIDER');
    if (endpoint.isEmpty || provider.isEmpty) return UnavailableMovieCatalog();
    try {
      return HttpMovieCatalog(Uri.parse(endpoint), provider);
    } catch (_) {
      // Configuração inválida nunca envia dados a outro destino.
      return UnavailableMovieCatalog();
    }
  }
}

class UnavailableMovieCatalog extends MovieCatalog {
  @override
  bool get available => false;
  @override
  Future<MovieCatalogPage> search(String query, {String? cursor}) async =>
      throw const CatalogConfigurationException(mediaName: 'filmes');
  @override
  Future<MovieCatalogItem> details(CatalogIdentity identity) async =>
      throw const CatalogConfigurationException(mediaName: 'filmes');
}

/// Contrato de um intermediário normalizado, sem token de fornecedor no app.
/// Não implementa/contrata um backend nem decide TMDB ou licença/cache.
class HttpMovieCatalog extends MovieCatalog {
  HttpMovieCatalog(
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
      throw const CatalogConfigurationException(mediaName: 'filmes');
    }
    try {
      CatalogIdentity.external(MediaType.movie, provider, 'validation');
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
        'movies',
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
      throw CatalogRequestException(response.statusCode, mediaName: 'filmes');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || data['provider'] != provider) {
      throw const FormatException('Fornecedor/resposta incompatível');
    }
    return data;
  }

  MovieCatalogItem _normalize(dynamic input) {
    if (input is! Map<String, dynamic> ||
        input['id'] is! String ||
        input['title'] is! String ||
        (input['title'] as String).trim().isEmpty ||
        (input['title'] as String).length > 300) {
      throw const FormatException('Filme incompleto');
    }
    final year = input['releaseYear'];
    final cover = input['coverUrl'];
    final uri = cover is String ? Uri.tryParse(cover) : null;
    return MovieCatalogItem(
      CatalogIdentity.external(MediaType.movie, provider, input['id']),
      MediaMetadata(MediaType.movie, {
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
    );
  }

  @override
  Future<MovieCatalogPage> search(String query, {String? cursor}) async {
    query = query.trim();
    if (query.isEmpty) return MovieCatalogPage([], null);
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
    final unique = <String, MovieCatalogItem>{};
    for (final row in rows) {
      try {
        final movie = _normalize(row);
        unique.putIfAbsent(movie.identity.key, () => movie);
      } on FormatException {
        /* Item parcial sem identidade/título é descartado. */
      }
    }
    return MovieCatalogPage(
      unique.values,
      rows.isEmpty ? null : next as String?,
    );
  }

  @override
  Future<MovieCatalogItem> details(CatalogIdentity identity) async {
    if (identity.isManual ||
        identity.mediaType != MediaType.movie ||
        identity.provider != provider) {
      throw const FormatException('Fornecedor incompatível');
    }
    final item = _normalize((await _get([identity.externalId!]))['item']);
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
