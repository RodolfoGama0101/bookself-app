import 'package:bookself_app/data/models/music_record.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/ui/screens/music_library_screen.dart';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/ui/screens/music_couple_screen.dart';
import 'dart:async';
import 'package:bookself_app/services/music_listen_service.dart';
import 'package:bookself_app/ui/screens/music_listen_screen.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/media_library_repository.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/ui/screens/music_add_screen.dart';
import 'package:bookself_app/ui/screens/music_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class RetryListen extends MusicListenService {
  final gate = Completer<void>();
  final ids = <String>[];
  @override
  String newId(String owner) => 'stable-listen';
  @override
  Future<void> save(String owner, String entry, String id, String date) async {
    ids.add(id);
    if (ids.length == 1) throw StateError('Falha simulada');
    await gate.future;
  }
}

class MusicJoint extends CoupleWorkspaceService {
  final gate = Completer<void>();
  final selections = <CoupleSelection>[];
  @override
  String newId() => 'selection';
  @override
  Stream<List<CoupleRecord>> records(
    String relation,
    String collection, {
    String? listId,
  }) => Stream.value([
    CoupleRecord('list', {'title': 'Nossa lista'}),
  ]);
  @override
  Future<void> addItem(
    String uid,
    String relation,
    String listId,
    String id,
    CoupleSelection selection,
  ) {
    selections.add(selection);
    return gate.future;
  }

  @override
  Future<void> propose(
    String uid,
    String relation,
    String id,
    CoupleSelection selection,
    DateTime date, {
    CoupleRecord? previous,
  }) {
    selections.add(selection);
    return gate.future;
  }
}

class PagedMusic extends MusicLibraryService {
  PagedMusic(MediaLibraryRepository repository, this.rows)
    : super(repository: repository);
  final List<MusicRecord> rows;
  @override
  Future<LibraryPage<MusicRecord>> page(
    String owner, {
    required MediaType type,
    LibraryCursor? after,
  }) async => LibraryPage(
    rows.where((r) => r.entry.ownerId == owner && r.entry.mediaType == type),
    null,
  );
  @override
  Future<int> count(String owner, MediaType type) async => rows
      .where((r) => r.entry.ownerId == owner && r.entry.mediaType == type)
      .length;
}

void main() {
  setUpAll(useBundledTestFonts);
  testWidgets('biblioteca combina artista/favorito e separa faixas de álbuns', (
    tester,
  ) async {
    final auth = JointAuth();
    final db = ProfileFirestoreFake();
    final repository = FirestoreMediaLibraryRepository(firestore: db);
    final library = MusicLibraryService(repository: repository);
    Future<MusicRecord> item(MediaType type, String title) => library.save(
      library.prepare(
        'a',
        MediaMetadata(type, {
          'title': title,
          'artists': ['Artista'],
        }),
      ),
    );
    final favorite = await library.favorite(
      await item(MediaType.track, 'Faixa favorita'),
      true,
    );
    final other = await item(MediaType.track, 'Outra faixa');
    final album = await item(MediaType.album, 'Álbum pessoal');
    final service = PagedMusic(repository, [favorite, other, album]);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: MusicLibraryScreen(service: service, onBooks: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Faixa favorita'), findsOneWidget);
    expect(find.text('Outra faixa'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Outra faixa'), findsNothing);
    expect(find.text('Carregadas: 2 · Total: 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Artista');
    await tester.pumpAndSettle();
    expect(find.text('Faixa favorita'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Álbuns'));
    await tester.pumpAndSettle();
    expect(find.text('Álbum pessoal'), findsOneWidget);
    expect(find.text('Faixa favorita'), findsNothing);
    auth.change();
    await tester.pumpAndSettle();
    expect(find.text('Álbum pessoal'), findsNothing);
    expect(tester.takeException(), null);
  });
  for (final experience in [false, true]) {
    testWidgets(
      'seleção musical exige consentimento e aguarda gravação: experiência=$experience',
      (tester) async {
        final auth = JointAuth();
        final db = ProfileFirestoreFake();
        final library = MusicLibraryService(
          repository: FirestoreMediaLibraryRepository(firestore: db),
        );
        final type = experience ? MediaType.album : MediaType.track;
        final music = await library.save(
          library.prepare(
            'a',
            MediaMetadata(type, {
              'title': 'Obra',
              'artists': ['Artista'],
            }),
          ),
        );
        final service = MusicJoint();
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: MaterialApp(
              home: MusicCoupleScreen(
                music: music,
                relation: 'relation',
                experience: experience,
                service: service,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          null,
        );
        if (experience) {
          await tester.tap(find.text('Escolher data do momento musical'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirmar'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Nossa lista'));
          await tester.pump();
        }
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(service.selections.single.type, type);
        expect(service.selections.single.subtitle, 'Artista');
        expect(
          service.selections.single.toMap().containsKey('favorite'),
          false,
        );
        expect(find.text('Confirmando…'), findsOneWidget);
        auth.change();
        service.gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('O vínculo mudou'), findsOneWidget);
        expect(db.documents.keys.any((p) => p.contains('/listens/')), false);
        expect(tester.takeException(), null);
      },
    );
  }
  testWidgets(
    'escuta exige data, retry conserva intenção e retorno após troca é ignorado',
    (tester) async {
      final auth = JointAuth();
      final db = ProfileFirestoreFake();
      final library = MusicLibraryService(
        repository: FirestoreMediaLibraryRepository(firestore: db),
      );
      final music = await library.save(
        library.prepare(
          'a',
          MediaMetadata(MediaType.track, {
            'title': 'Faixa',
            'artists': ['Artista'],
          }),
        ),
      );
      final service = RetryListen();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: MusicListenScreen(music: music, service: service),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar escuta'),
            )
            .onPressed,
        null,
      );
      await tester.tap(find.text('Escolher data da escuta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar escuta'));
      await tester.pumpAndSettle();
      expect(service.ids, ['stable-listen']);
      expect(find.textContaining('conserva esta escuta'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(service.ids, ['stable-listen', 'stable-listen']);
      expect(find.text('Confirmando escuta…'), findsOneWidget);
      auth.change();
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sua conta mudou'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
  testWidgets('manual exige artistas e mostra versão em 320 px/texto 2×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = JointAuth();
    final db = ProfileFirestoreFake();
    final service = MusicLibraryService(
      repository: FirestoreMediaLibraryRepository(firestore: db),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MusicAddScreen(
            owner: 'a',
            service: service,
            type: MediaType.track,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('indisponível'), findsOneWidget);
    final save = find.text('Salvar música');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Informe os artistas.'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Informe os artistas.'), findsOneWidget);
    expect(db.writes, 0);
    expect(
      find.widgetWithText(TextFormField, 'Versão (opcional)'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
    final record = await service.save(
      service.prepare(
        'a',
        MediaMetadata(MediaType.track, {
          'title': 'Obra',
          'artists': ['Artista'],
          'version': 'Ao vivo',
          'albumTitle': 'Álbum',
        }),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: MusicDetailsScreen(music: record, service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Versão/edição: Ao vivo'), findsOneWidget);
    expect(find.text('Álbum: Álbum'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
