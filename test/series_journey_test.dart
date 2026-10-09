import 'dart:convert';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/series_record.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/partner_service.dart';
import 'package:bookself_app/services/series_catalog.dart';
import 'package:bookself_app/services/series_library_service.dart';
import 'package:bookself_app/services/series_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/profile_firestore_fake.dart';

void main() {
  for (final external in [false, true]) {
    test(
      'QA-03: série ${external ? 'HTTP simulada' : 'manual'}, progresso, sessão corrigida e término',
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
          final detail = request.url.path == '/catalog/series/fixture';
          expect(
            request.url.path,
            detail ? '/catalog/series/fixture' : '/catalog/series/search',
          );
          if (!detail) expect(request.url.queryParameters['language'], 'pt-BR');
          const item = {
            'id': 'fixture',
            'title': 'Série de ensaio',
            'complete': true,
            'ended': false,
            'episodes': [
              {'id': 'one', 'season': 1, 'number': 1, 'available': true},
            ],
          };
          return http.Response(
            jsonEncode({
              'provider': 'fixture_video',
              if (detail) 'item': item else 'items': [item],
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        addTearDown(client.close);
        final SeriesCatalog catalog = external
            ? HttpSeriesCatalog(
                Uri.parse('https://example.test/catalog'),
                'fixture_video',
                client: client,
              )
            : UnavailableSeriesCatalog();
        final library = SeriesLibraryService(
          repository: FirestoreMediaLibraryRepository(firestore: db),
          progress: SeriesProgressService(firestore: db),
          catalog: catalog,
        );
        SeriesCatalogItem? details;
        if (external) {
          details = await catalog.details(
            (await catalog.search('Série')).items.single.identity,
          );
        }
        final metadata =
            details?.metadata ??
            MediaMetadata(MediaType.series, {'title': 'Série de ensaio'});
        final prepared = library.prepare(
          'a',
          metadata,
          identity: details?.identity,
        );
        var own = await library.save(prepared);
        final partner = await library.save(
          library.prepare('b', metadata, identity: details?.identity),
        );
        final included = own.entry.createdAt;
        final episode =
            details?.episodes.single ??
            SeriesEpisode(id: 'one', season: 1, number: 1, available: true);
        await library.progress.saveEpisode(
          'a',
          own.entry.id,
          episode,
          watched: true,
        );
        await library.progress.saveEpisode(
          'a',
          own.entry.id,
          episode,
          watched: true,
        );
        await library.progress.saveEpisode(
          'b',
          partner.entry.id,
          episode,
          watched: false,
        );
        await library.progress.configure(
          'a',
          own.entry.id,
          own.progress,
          complete: true,
          ended: false,
          paused: false,
        );
        own = await library.read('a', own.entry.id);
        expect(own.status, 'up_to_date');
        expect(
          (await library.read(
            'b',
            partner.entry.id,
          )).progress.episodes.single.watched,
          false,
        );
        await library.sharing.setVisible(own, false);
        await library.save(prepared);
        expect(await library.sharing.visible('a', own.entry.id), false);
        await library.sharing.setVisible(own, true);
        final couple = CoupleWorkspaceService(firestore: db);
        await couple.propose(
          'a',
          'relation',
          'session',
          own.selection(episode),
          DateTime(2020, 2, 29),
        );
        const path = 'couple_relationships/relation/experiences/session';
        CoupleRecord session() => CoupleRecord('session', db.documents[path]!);
        await couple.respond('b', 'relation', session(), 'confirmed');
        expect(session().confirmed, true);
        final old = session();
        await couple.propose(
          'a',
          'relation',
          'session',
          own.selection(episode),
          DateTime(2020, 3, 1),
          previous: old,
        );
        expect(session().confirmed, false);
        await expectLater(
          couple.respond('b', 'relation', old, 'confirmed'),
          throwsA(isA<CoupleConflict>()),
        );
        await couple.respond('b', 'relation', session(), 'confirmed');
        final projection =
            db.documents['couple_relationships/relation/activity/session']!;
        expect(projection['confirmed'], true);
        expect((projection['selection'] as Map).containsKey('watched'), false);
        expect(
          (await library.read(
            'b',
            partner.entry.id,
          )).progress.episodes.single.watched,
          false,
        );
        await PartnerService(
          firestore: db,
        ).unlink('a', 'b', relationshipId: 'relation');
        await expectLater(
          couple.propose(
            'a',
            'relation',
            'late',
            own.selection(),
            DateTime(2020),
          ),
          throwsStateError,
        );
        await couple.respond('b', 'relation', session(), 'withdrawn');
        expect(
          db.documents['couple_relationships/relation/activity/session']!['confirmed'],
          false,
        );
        await library.progress.configure(
          'a',
          own.entry.id,
          own.progress,
          complete: true,
          ended: true,
          paused: false,
        );
        own = await library.read('a', own.entry.id);
        expect(own.status, 'completed');
        expect(own.entry.createdAt, included);
        expect(
          (await library.read(
            'b',
            partner.entry.id,
          )).progress.episodes.single.watched,
          false,
        );
        expect(db.documents['a']!['partnerUid'], isNull);
        expect(db.documents['b']!['partnerUid'], isNull);
      },
    );
  }
}
