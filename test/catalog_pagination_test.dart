import 'dart:async';
import 'dart:convert';

import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  BookService service(Object response, {int status = 200}) {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(response), status),
    );
    addTearDown(client.close);
    return BookService(httpClient: client, apiKey: 'fixture-key');
  }

  test('configuração ausente e consulta vazia não enviam requisição', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final books = BookService(httpClient: client, apiKey: '');
    expect((await books.searchGoogleBooksPage('  ')).books, isEmpty);
    await expectLater(
      books.searchGoogleBooksPage('livro'),
      throwsA(isA<CatalogConfigurationException>()),
    );
    expect(calls, 0);
    expect(
      ErrorHandler.getFriendlyErrorMessage(
        const CatalogConfigurationException(),
      ),
      contains('manualmente'),
    );
  });

  test(
    'termos especiais e posição são codificados sem alterar a consulta',
    () async {
      late Uri received;
      final client = MockClient((request) async {
        received = request.url;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final books = BookService(httpClient: client, apiKey: 'fixture-key');
      await books.searchGoogleBooksPage(
        '  ação & amor + paz  ',
        startIndex: 20,
      );
      expect(received.scheme, 'https');
      expect(received.host, 'www.googleapis.com');
      expect(received.queryParameters, {
        'q': 'ação & amor + paz',
        'maxResults': '20',
        'startIndex': '20',
        'key': 'fixture-key',
      });
      await expectLater(
        books.searchGoogleBooksPage('livro', startIndex: -1),
        throwsRangeError,
      );
    },
  );

  test('requisição pendente termina com timeout traduzível', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    final books = BookService(
      httpClient: client,
      apiKey: 'fixture-key',
      requestTimeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      books.searchGoogleBooksPage('livro'),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete(http.Response('{}', 200));
    expect(
      ErrorHandler.getFriendlyErrorMessage(TimeoutException('PRIVATE_FIXTURE')),
      isNot(contains('PRIVATE_FIXTURE')),
    );
  });

  test(
    'resultados incompletos usam fallback e itens sem identidade são ignorados',
    () async {
      final page = await service({
        'totalItems': 20,
        'items': [
          {
            'id': 'valid',
            'volumeInfo': {
              'title': 4,
              'authors': [' Autor ', 3, ' '],
              'imageLinks': {'smallThumbnail': 'https://example.com/cover'},
            },
          },
          {'id': 'empty-metadata', 'volumeInfo': <String, Object>{}},
          {
            'volumeInfo': {'title': 'Sem ID'},
          },
          {'id': '', 'volumeInfo': <String, Object>{}},
          {'id': 'broken', 'volumeInfo': []},
          3,
        ],
      }).searchGoogleBooksPage('livro');
      expect(page.books.map((book) => book.googleBooksId), [
        'valid',
        'empty-metadata',
      ]);
      expect(page.books.first.title, 'Sem título');
      expect(page.books.first.authors, ['Autor']);
      expect(page.books.first.coverUrl, 'https://example.com/cover');
      expect(page.books.last.authors, ['Autor desconhecido']);
      expect(page.books.last.publishedDate, 'Data desconhecida');
      expect(page.skippedCount, 4);
      expect(page.nextStartIndex, 6);
      final personal = page.books.first.copyWith(
        id: 'personal-id',
        userId: 'owner',
      );
      expect(personal.toMap()['googleBooksId'], 'valid');
      expect(personal.id, isNot(personal.googleBooksId));
    },
  );

  test(
    'página curta avança por itens recebidos e página vazia encerra total estimado',
    () async {
      final partial = await service({
        'totalItems': 100,
        'items': [
          {'id': 'one', 'volumeInfo': <String, Object>{}},
        ],
      }).searchGoogleBooksPage('livro', startIndex: 20);
      expect(partial.nextStartIndex, 21);
      final empty = await service({
        'totalItems': 100,
      }).searchGoogleBooksPage('livro', startIndex: 21);
      expect(empty.books, isEmpty);
      expect(empty.nextStartIndex, isNull);
      final full = await service({
        'items': List.generate(
          20,
          (i) => {'id': '$i', 'volumeInfo': <String, Object>{}},
        ),
      }).searchGoogleBooksPage('livro');
      expect(full.nextStartIndex, 20);
    },
  );

  for (final payload in [
    [],
    'PRIVATE_FIXTURE',
    {'items': 3},
  ]) {
    test('resposta estruturalmente inválida é rejeitada', () async {
      await expectLater(
        service(payload).searchGoogleBooksPage('livro'),
        throwsFormatException,
      );
    });
  }

  test('403 de quota difere de proibição e omite detalhes externos', () async {
    final quota = service({
      'error': {
        'message': 'PRIVATE_FIXTURE',
        'errors': [
          {'reason': 'dailyLimitExceeded'},
        ],
      },
    }, status: 403);
    await expectLater(
      quota.searchGoogleBooksPage('livro'),
      throwsA(isA<CatalogQuotaException>()),
    );
    final denied = service({
      'error': {
        'errors': [
          {'reason': 'accessNotConfigured'},
        ],
      },
    }, status: 403);
    try {
      await denied.searchGoogleBooksPage('livro');
      fail('A proibição deveria falhar');
    } catch (error) {
      expect(error, isA<CatalogRequestException>());
      expect(error, isNot(isA<CatalogQuotaException>()));
    }
    expect(
      ErrorHandler.getFriendlyErrorMessage(const CatalogQuotaException(403)),
      contains('limite'),
    );
  });
}
