import 'dart:convert';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/music_catalog.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/services/partner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/profile_firestore_fake.dart';
import 'package:bookself_app/services/music_listen_service.dart';

void main() {
  for (final external in [false, true]) {
    test(
      'QA-03: jornada de música ${external ? 'com catálogo simulado' : 'manual sem API'} e casal preserva estados após término',
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
          if (!request.url.path.endsWith('/music/tracks/fixture')) {
            expect(request.url.queryParameters['language'], 'pt-BR');
          }
          const item = {
            'id': 'fixture',
            'title': 'Música de ensaio',
            'artists': ['Artista'],
          };
          return http.Response(
            jsonEncode({
              'provider': 'fixture_music',
              if (request.url.path.endsWith('/music/tracks/fixture'))
                'item': item
              else
                'items': [item],
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        addTearDown(client.close);
        final catalog = external
            ? HttpMusicCatalog(
                Uri.parse('https://example.test/catalog'),
                'fixture_music',
                client: client,
              )
            : UnavailableMusicCatalog();
        final musics = MusicLibraryService(
          repository: FirestoreMediaLibraryRepository(firestore: db),
          catalog: catalog,
        );
        final couple = CoupleWorkspaceService(firestore: db);
        final listens = MusicListenService(firestore: db);
        MusicCatalogItem? details;
        if (external) {
          final found = await catalog.search(MediaType.track, 'Música');
          details = await catalog.details(found.items.single.identity);
        } else {
          expect(catalog.available, false);
        }
        final metadata =
            details?.metadata ??
            MediaMetadata(MediaType.track, {
              'title': 'Música de ensaio',
              'artists': ['Artista'],
            });
        final prepared = musics.prepare(
          'a',
          metadata,
          identity: details?.identity,
        );
        var own = await musics.save(prepared);
        final partner = await musics.save(
          musics.prepare('b', metadata, identity: details?.identity),
        );
        expect(own.entry.ownerId, 'a');
        expect(partner.entry.ownerId, 'b');
        expect(own.cover, isEmpty);
        expect(own.artists, 'Artista');
        final included = own.entry.createdAt;
        final listenId = listens.newId('a');
        await listens.save('a', own.entry.id, listenId, '2020-02-29');
        await listens.save('a', own.entry.id, listenId, '2020-02-29');
        own = await musics.favorite(own, true);
        expect((await musics.save(prepared)).entry.favorite, true);
        expect(
          (await musics.read('b', partner.entry.id)).entry.favorite,
          false,
        );
        await couple.createList('a', 'relation', 'list', 'Músicas para nós');
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
        expect(shared.containsKey('favorite'), false);
        expect(shared.containsKey('listenedOn'), false);
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
        expect((await musics.read('a', own.entry.id)).entry.favorite, true);
        expect(
          (await musics.read('b', partner.entry.id)).entry.favorite,
          false,
        );
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
        own = await musics.favorite(own, false);
        expect(own.entry.favorite, false);
        expect(own.entry.createdAt, included);
        expect(
          db.documents.keys.where((p) => p.contains('/listens/')),
          hasLength(1),
        );
        expect(
          (await musics.read('b', partner.entry.id)).entry.favorite,
          false,
        );
        expect(
          db.documents.keys.where((p) => p.contains('/entries/')),
          hasLength(2),
        );
      },
    );
  }
}
