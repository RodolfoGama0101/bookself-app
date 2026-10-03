import 'package:bookself_app/services/book_service.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final status in [403, 429, 503]) {
    test('busca HTTP $status preserva apenas status para a tradução', () async {
      final client = MockClient(
        (_) async => http.Response('PRIVATE_FIXTURE', status),
      );
      addTearDown(client.close);
      final service = BookService(httpClient: client);
      await expectLater(
        service.searchGoogleBooks('Consulta de teste'),
        throwsA(
          isA<CatalogRequestException>().having(
            (error) => error.statusCode,
            'statusCode',
            status,
          ),
        ),
      );
    });
  }

  test(
    'busca propaga falha de conexão tipada sem converter para erro bruto',
    () async {
      final client = MockClient(
        (_) async => throw http.ClientException('PRIVATE_FIXTURE'),
      );
      addTearDown(client.close);
      final service = BookService(httpClient: client);
      try {
        await service.searchGoogleBooks('Consulta de teste');
        fail('A busca deveria falhar');
      } catch (error) {
        expect(error, isA<http.ClientException>());
        expect(
          ErrorHandler.getFriendlyErrorMessage(error),
          ErrorHandler.networkMessage,
        );
      }
    },
  );

  test(
    'resposta inválida pode ser traduzida sem revelar corpo da resposta',
    () async {
      final client = MockClient(
        (_) async => http.Response('PRIVATE_FIXTURE', 200),
      );
      addTearDown(client.close);
      final service = BookService(httpClient: client);
      try {
        await service.searchGoogleBooks('Consulta de teste');
        fail('A busca deveria falhar');
      } catch (error) {
        expect(error, isA<FormatException>());
        expect(
          ErrorHandler.getFriendlyErrorMessage(error),
          contains('ler os dados'),
        );
      }
    },
  );

  test(
    'sucesso mantém interpretação dos livros e busca vazia não faz requisição',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          '{"items":[{"id":"catalog-id","volumeInfo":{"title":"Livro de teste","authors":["Autor"]}}]}',
          200,
        );
      });
      addTearDown(client.close);
      final service = BookService(httpClient: client);
      expect(await service.searchGoogleBooks('  '), isEmpty);
      expect(requests, 0);
      final books = await service.searchGoogleBooks('Consulta de teste');
      expect(requests, 1);
      expect(books.single.title, 'Livro de teste');
      expect(books.single.id, 'catalog-id');
      expect(books.single.authors, ['Autor']);
    },
  );
}
