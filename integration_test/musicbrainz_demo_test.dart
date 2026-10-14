import 'dart:math';

import 'package:bookself_app/main.dart' as app;
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/firebase_environment.dart';
import 'package:bookself_app/services/music_library_service.dart';
import 'package:bookself_app/ui/screens/main_navigation.dart';
import 'package:bookself_app/ui/screens/music_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'android_demo_test.dart' show waitFor, tapText, fill, destination, show;

// Rede pública somente para metadados; escritas somente no Firebase demo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('MusicBrainz: busca, detalhes e biblioteca Android demo', (
    tester,
  ) async {
    const environment = FirebaseEnvironment.fromDefines;
    if (!environment.useEmulators ||
        !const bool.fromEnvironment('RUN_MUSICBRAINZ_DEMO_TESTS') ||
        const String.fromEnvironment('MUSIC_CATALOG_PROVIDER') !=
            'musicbrainz') {
      fail('Exige opt-in musical, fornecedor MusicBrainz e Firebase emulado.');
    }
    environment.validate();
    app.main();
    await waitFor(tester, () => find.byType(MaterialApp).evaluate().isNotEmpty);
    await waitFor(
      tester,
      () =>
          find.byType(MainNavigation).evaluate().isNotEmpty ||
          find.text('Entrar').evaluate().isNotEmpty,
    );
    final auth = FirebaseEnvironment.auth;
    expect(auth.app.options.projectId, FirebaseEnvironment.demoProjectId);
    if (auth.currentUser != null) await auth.signOut();
    await waitFor(tester, () => find.text('Entrar').evaluate().isNotEmpty);
    await tapText(tester, 'Não tem conta? Cadastre-se');
    await fill(tester, 'Seu Nome', 'Catálogo musical demo');
    await fill(
      tester,
      'E-mail',
      'musicbrainz-${DateTime.now().microsecondsSinceEpoch}@example.test',
    );
    await fill(
      tester,
      'Senha',
      List.generate(
        24,
        (_) => Random.secure().nextInt(36).toRadixString(36),
      ).join(),
    );
    await tapText(tester, 'Criar Conta');
    await waitFor(
      tester,
      () => find.byType(MainNavigation).evaluate().isNotEmpty,
    );
    final owner = auth.currentUser!.uid;
    final music = MusicLibraryService();
    addTearDown(music.close);
    expect(music.catalog.available, isTrue);
    await destination(tester, 'Biblioteca');
    await tapText(tester, 'Música');
    for (final type in [MediaType.track, MediaType.album]) {
      if (type == MediaType.album) await tapText(tester, 'Álbuns');
      await tapText(tester, 'Adicionar seleção');
      await fill(
        tester,
        'Buscar música no catálogo',
        type == MediaType.track
            ? 'Águas de Março Elis Regina'
            : 'Clube da Esquina Milton Nascimento',
      );
      await tapText(tester, 'Buscar músicas');
      await waitFor(tester, () => find.byType(ListTile).evaluate().isNotEmpty);
      final first = find.byType(ListTile).first;
      await show(tester, first);
      await tester.tap(first);
      await waitFor(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await show(tester, find.text('Referência: musicbrainz'));
      await tapText(tester, 'Salvar música');
      await waitFor(
        tester,
        () => find.byType(MusicAddScreen).evaluate().isEmpty,
      );
      final saved = (await music.page(owner, type: type)).items.single;
      expect(saved.catalog.identity.isManual, isFalse);
      expect(saved.catalog.identity.provider, 'musicbrainz');
      expect(saved.catalog.identity.mediaType, type);
      expect(saved.artists, isNotEmpty);
      expect(saved.entry.favorite, isFalse);
      expect(saved.catalog.metadata.toMap()['coverUrl'], isNull);
      if (type == MediaType.album) {
        expect(saved.catalog.metadata.toMap()['edition'], isNotEmpty);
      }
      tester.printToConsole(
        'MusicBrainz: ${type.name} salvo e relido no demo.',
      );
    }
    await auth.signOut();
  });
}
