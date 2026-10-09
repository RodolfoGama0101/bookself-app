import 'dart:convert';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/movie_catalog.dart';
import 'package:bookself_app/services/movie_library_service.dart';
import 'package:bookself_app/services/partner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  for (final external in [false, true]) {
    test(
      'QA-03: jornada de filme ${external ? 'com catálogo simulado' : 'manual sem API'} e casal preserva estados após término',
      () async {
        final db = ProfileFirestoreFake();
        addTearDown(db.close);
        db.documents.addAll({
          'a': {
            'name': 'Pessoa A',
            'partnerUid': 'b',
            'relationshipId': 'relation',
          },
          'b': {
            'name': 'Pessoa B',
            'partnerUid': 'a',
            'relationshipId': 'relation',
          },
          'partner_invites/relation': {
            'status': 'accepted',
            'senderUid': 'a',
            'recipientUid': 'b',
          },
        });
        final client = MockClient((request) async {
          if (!request.url.path.endsWith('/movies/fixture')) {
            expect(request.url.queryParameters['language'], 'pt-BR');
          }
          const item = {'id': 'fixture', 'title': 'Filme de ensaio'};
          return http.Response(
            jsonEncode({
              'provider': 'fixture_video',
              if (request.url.path.endsWith('/movies/fixture'))
                'item': item
              else
                'items': [item],
              'nextCursor': null,
            }),
            200,
          );
        });
        addTearDown(client.close);
        final catalog = external
            ? HttpMovieCatalog(
                Uri.parse('https://example.test/catalog'),
                'fixture_video',
                client: client,
              )
            : UnavailableMovieCatalog();
        final movies = MovieLibraryService(
          repository: FirestoreMediaLibraryRepository(firestore: db),
          catalog: catalog,
        );
        final couple = CoupleWorkspaceService(firestore: db);
        MovieCatalogItem? details;
        if (external) {
          final found = await catalog.search('Filme');
          details = await catalog.details(found.items.single.identity);
        } else {
          expect(catalog.available, false);
        }
        final metadata =
            details?.metadata ??
            MediaMetadata(MediaType.movie, {'title': 'Filme de ensaio'});
        final prepared = movies.prepare(
          'a',
          metadata,
          identity: details?.identity,
        );
        var own = await movies.save(prepared);
        final partner = await movies.save(
          movies.prepare('b', metadata, identity: details?.identity),
        );
        expect(own.entry.ownerId, 'a');
        expect(partner.entry.ownerId, 'b');
        expect(own.cover, isEmpty);
        expect(own.year, isNull);
        final included = own.entry.createdAt;
        own = await movies.update(own, watched: true, date: '2020-02-29');
        expect((await movies.save(prepared)).watchedOn, '2020-02-29');
        expect((await movies.read('b', partner.entry.id)).watched, false);
        await couple.createList('a', 'relation', 'list', 'Filmes para nós');
        await couple.addItem(
          'a',
          'relation',
          'list',
          'selection',
          own.selection,
        );
        final shared =
            db.documents['couple_relationships/relation/lists/list/items/selection']!['selection']
                as Map;
        expect(shared.containsKey('state'), false);
        expect(shared.containsKey('watchedOn'), false);
        await couple.propose(
          'a',
          'relation',
          'session',
          own.selection,
          DateTime(2020, 2, 29),
        );
        const path = 'couple_relationships/relation/experiences/session';
        CoupleRecord session() => CoupleRecord('session', db.documents[path]!);
        expect(session().confirmed, false);
        await couple.respond('b', 'relation', session(), 'confirmed');
        expect(session().confirmed, true);
        final old = session();
        await couple.propose(
          'a',
          'relation',
          'session',
          own.selection,
          DateTime(2020, 3, 1),
          previous: old,
        );
        expect(session().confirmed, false);
        await expectLater(
          couple.respond('b', 'relation', old, 'confirmed'),
          throwsA(isA<CoupleConflict>()),
        );
        await couple.respond('b', 'relation', session(), 'confirmed');
        expect(session().confirmed, true);
        expect((await movies.read('a', own.entry.id)).watchedOn, '2020-02-29');
        expect((await movies.read('b', partner.entry.id)).watched, false);
        await PartnerService(
          firestore: db,
        ).unlink('a', 'b', relationshipId: 'relation');
        expect(db.documents['a']!['partnerUid'], isNull);
        expect(db.documents['b']!['partnerUid'], isNull);
        await expectLater(
          couple.addItem('b', 'relation', 'list', 'late', partner.selection),
          throwsStateError,
        );
        await couple.respond('b', 'relation', session(), 'withdrawn');
        expect(session().confirmed, false);
        own = await movies.update(own, watched: false);
        expect(own.watchedOn, isNull);
        expect(own.entry.createdAt, included);
        expect((await movies.read('b', partner.entry.id)).watched, false);
        expect(
          db.documents.keys.where((p) => p.contains('/entries/')),
          hasLength(2),
        );
      },
    );
  }
}
