import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/music_catalog.dart';
import 'package:bookself_app/utils/error_handler.dart';

void main() {
  test('não combina identidade de faixa com metadados de álbum', () {
    expect(
      () => MusicCatalogItem(
        CatalogIdentity.external(MediaType.track, 'example', 'id'),
        MediaMetadata(MediaType.album, {
          'title': 'Obra',
          'artists': ['Artista'],
        }),
      ),
      throwsFormatException,
    );
  });
  test('timeout cancela espera sem inventar resultado', () async {
    final catalog = HttpMusicCatalog(
      Uri.parse('https://example.test'),
      'example',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      catalog.search(MediaType.track, 'obra'),
      throwsA(isA<TimeoutException>()),
    );
  });
  test('fornecedor divergente e cursor inválido são recusados', () async {
    var requests = 0;
    final catalog = HttpMusicCatalog(
      Uri.parse('https://example.test'),
      'example',
      client: MockClient((_) async {
        requests++;
        return http.Response('{"provider":"other","items":[]}', 200);
      }),
    );
    await expectLater(
      catalog.search(MediaType.album, 'obra', cursor: ''),
      throwsFormatException,
    );
    expect(requests, 0);
    await expectLater(
      catalog.search(MediaType.album, 'obra'),
      throwsFormatException,
    );
  });
  test('catálogo ausente preserva cadastro manual', () async {
    final catalog = MusicCatalog.configured();
    expect(catalog.available, false);
    await expectLater(
      catalog.search(MediaType.track, 'obra'),
      throwsA(isA<CatalogConfigurationException>()),
    );
  });
  for (final type in [MediaType.track, MediaType.album]) {
    test('normaliza $type sem confundir versões ou tipos', () async {
      final catalog = HttpMusicCatalog(
        Uri.parse('https://example.test/v1'),
        'example_music',
        client: MockClient((request) async {
          expect(request.followRedirects, false);
          expect(request.url.pathSegments, [
            'v1',
            'music',
            type == MediaType.track ? 'tracks' : 'albums',
            'search',
          ]);
          expect(request.url.queryParameters['q'], 'obra');
          return http.Response(
            jsonEncode({
              'provider': 'example_music',
              'nextCursor': 'next',
              'items': [
                {
                  'id': 'v1',
                  'title': ' Obra ',
                  'artists': [' Artista '],
                  'version': 'Ao vivo',
                  'edition': 'Deluxe',
                  'coverUrl': 'http://unsafe.test',
                },
                {
                  'id': 'v1',
                  'title': 'Duplicada',
                  'artists': ['Artista'],
                },
                {
                  'id': 'v2',
                  'title': 'Obra',
                  'artists': ['Artista'],
                },
                {'id': 'bad', 'title': 'Sem artista'},
                {
                  'id': 'bad2',
                  'title': 'Inválida',
                  'artists': [''],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final page = await catalog.search(type, ' obra ');
      expect(page.items, hasLength(2));
      expect(page.items.first.metadata.toMap()['artists'], ['Artista']);
      expect(page.items.first.metadata.toMap()['coverUrl'], null);
      expect(page.items.first.identity.mediaType, type);
      expect(
        page.items.first.identity.key,
        isNot(page.items.last.identity.key),
      );
      expect(page.nextCursor, 'next');
    });
  }
  test(
    'detalhes rejeitam identidade divergente e fornecedor inesperado',
    () async {
      final identity = CatalogIdentity.external(
        MediaType.track,
        'example_music',
        'a/b',
      );
      final catalog = HttpMusicCatalog(
        Uri.parse('https://example.test'),
        'example_music',
        client: MockClient((request) async {
          expect(request.url.pathSegments.last, 'a/b');
          return http.Response(
            jsonEncode({
              'provider': 'example_music',
              'item': {
                'id': 'other',
                'title': 'Obra',
                'artists': ['Artista'],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await expectLater(catalog.details(identity), throwsFormatException);
      await expectLater(
        catalog.search(MediaType.movie, 'obra'),
        throwsFormatException,
      );
    },
  );
  for (final status in [302, 429, 503]) {
    test('falha HTTP $status não anuncia resultado', () async {
      final catalog = HttpMusicCatalog(
        Uri.parse('https://example.test'),
        'example_music',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        catalog.search(MediaType.album, 'obra'),
        throwsA(
          status == 429
              ? isA<CatalogQuotaException>()
              : isA<CatalogRequestException>(),
        ),
      );
    });
  }
}
