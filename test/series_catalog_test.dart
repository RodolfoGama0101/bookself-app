import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/series_catalog.dart';
import 'package:bookself_app/utils/error_handler.dart';

void main() {
  final endpoint = Uri.parse('https://example.test/catalog');
  final identity = CatalogIdentity.external(
    MediaType.series,
    'example_video',
    'a/b?é',
  );
  http.Response page(List<Object?> rows, {Object? next}) => http.Response(
    jsonEncode({
      'provider': 'example_video',
      'items': rows,
      'nextCursor': next,
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  test('configuração ausente mantém manual sem acesso à rede', () async {
    final catalog = SeriesCatalog.configured();
    expect(catalog.available, isFalse);
    expect(
      ErrorHandler.getFriendlyErrorMessage(
        const CatalogConfigurationException(mediaName: 'séries'),
      ),
      contains('busca de séries'),
    );
    await expectLater(
      catalog.search('Série'),
      throwsA(isA<CatalogConfigurationException>()),
    );
  });
  for (final address in [
    'http://example.test',
    'https://user:pass@example.test',
    'https://example.test?token=x',
    'https://example.test#x',
  ]) {
    test('recusa destino inseguro $address', () {
      expect(
        () => HttpSeriesCatalog(Uri.parse(address), 'example_video'),
        throwsA(isA<CatalogConfigurationException>()),
      );
    });
  }
  test(
    'normaliza opcionais, descarta incompletos e deduplica sem perder identidade',
    () async {
      final catalog = HttpSeriesCatalog(
        endpoint,
        'example_video',
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'q': 'ação',
            'language': 'pt-BR',
            'cursor': 'next/é',
          });
          expect(request.followRedirects, isFalse);
          return page([
            {
              'id': 'a/b?é',
              'title': ' Série ',
              'releaseYear': '2020',
              'coverUrl': 'http://example.test/poster',
            },
            {'id': 'a/b?é', 'title': 'Duplicado'},
            {'id': 'missing'},
            {
              'id': 'other',
              'title': 'Outro',
              'releaseYear': 2020,
              'coverUrl': 'https://example.test/poster',
            },
          ], next: 'page2');
        }),
      );
      final result = await catalog.search(' ação ', cursor: 'next/é');
      expect(result.items, hasLength(2));
      expect(result.items.first.identity.key, identity.key);
      expect(result.items.first.metadata.toMap()['coverUrl'], isNull);
      expect(result.items.first.metadata.toMap()['releaseYear'], isNull);
      expect(result.items.last.metadata.toMap()['releaseYear'], 2020);
      expect(result.nextCursor, 'page2');
    },
  );
  test('detalhes codificam ID e rejeitam troca da referência', () async {
    final catalog = HttpSeriesCatalog(
      endpoint,
      'example_video',
      client: MockClient((request) async {
        expect(request.url.pathSegments, ['catalog', 'series', 'a/b?é']);
        return http.Response(
          jsonEncode({
            'provider': 'example_video',
            'item': {'id': 'other', 'title': 'Outro'},
          }),
          200,
        );
      }),
    );
    await expectLater(catalog.details(identity), throwsFormatException);
  });
  test(
    'página vazia termina mesmo com cursor; consulta vazia não envia',
    () async {
      var requests = 0;
      final catalog = HttpSeriesCatalog(
        endpoint,
        'example_video',
        client: MockClient((_) async {
          requests++;
          return page([], next: 'again');
        }),
      );
      expect((await catalog.search(' ')).items, isEmpty);
      expect(requests, 0);
      expect((await catalog.search('série')).nextCursor, isNull);
    },
  );
  for (final status in [302, 429, 503]) {
    test('HTTP $status permanece falha sem falso sucesso', () async {
      final catalog = HttpSeriesCatalog(
        endpoint,
        'example_video',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        catalog.search('série'),
        throwsA(
          status == 429
              ? isA<CatalogQuotaException>()
              : isA<CatalogRequestException>(),
        ),
      );
    });
  }
  test('timeout inclui leitura e não mantém resultado anterior', () async {
    final catalog = HttpSeriesCatalog(
      endpoint,
      'example_video',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      catalog.search('série'),
      throwsA(isA<TimeoutException>()),
    );
  });
  test('recusa envelope de outro fornecedor e cursor inválido', () async {
    final catalog = HttpSeriesCatalog(
      endpoint,
      'example_video',
      client: MockClient(
        (_) async => http.Response('{"provider":"other","items":[]}', 200),
      ),
    );
    await expectLater(catalog.search('série'), throwsFormatException);
    await expectLater(
      catalog.search('série', cursor: ''),
      throwsFormatException,
    );
  });
}
