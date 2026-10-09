const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { musicbrainz, tmdb, safeError, request } = require('./trial.cjs');

test('indisponibilidade nos detalhes conserva as buscas; dados ausentes continuam opcionais', async () => {
  let calls = 0;
  const report = await musicbrainz(async url => {
    calls++;
    if (String(url).includes('/release-group/')) throw new Error('HTTP 503');
    const group = String(url).includes('release-group');
    return { summary: { status: 200, cors: '*' }, data: { count: 1,
      [group ? 'release-groups' : 'recordings']: [{ id: 'sample', title: 'Clube da Esquina' }] } };
  });
  assert.equal(calls, 5);
  assert.equal(report.length, 5);
  assert.equal(report[0].matches[0].duration, null);
  assert.equal(report[4].outcome, 'HTTP 503');
});

test('erros não revelam conteúdo, URL autenticada ou credenciais', () => {
  assert.equal(safeError(new Error('https://example.test?secret=ficticio')),
    'Falha de rede, configuração ou resposta; sem detalhes sensíveis');
  assert.equal(safeError(new Error('HTTP 401')), 'HTTP 401');
});

test('configuração fora da pasta local não inicia acesso autenticado', async () => {
  await assert.rejects(tmdb('config/tmdb.example.json'), /Use config/);
  await assert.rejects(tmdb('../other.local.json'), /Use config/);
});

test('redirect de capa não baixa imagem nem segue destino estranho', async context => {
  let calls = 0;
  context.mock.method(global, 'fetch', async () => {
    calls++;
    return new Response(null, { status: 307,
      headers: { location: 'https://example.test/image.jpg' } });
  });
  await assert.rejects(request('https://coverartarchive.org/release/sample',
    { archiveMetadata: true }), /Redirecionamento/);
  assert.equal(calls, 1);
});

test('ensaio TMDB consulta pt-BR e episódios sem enviar token ao CDN', async context => {
  const file = path.resolve(__dirname, `../../config/tmdb-trial-${randomUUID()}.local.json`);
  const calls = [];
  const json = value => new Response(JSON.stringify(value), {
    status: 200, headers: { 'content-type': 'application/json' },
  });
  context.mock.method(global, 'fetch', async (input, options) => {
    const url = new URL(String(input));
    calls.push({ url, options });
    if (url.hostname === 'image.tmdb.org') return new Response(null, { status: 200 });
    if (url.pathname.endsWith('/configuration')) return json({ images: {
      secure_base_url: 'https://image.tmdb.org/t/p/', poster_sizes: ['w500'],
    } });
    if (url.pathname.endsWith('/search/movie')) return json({ total_results: 1,
      results: [{ id: 11, title: 'Central do Brasil' }] });
    if (url.pathname.endsWith('/movie/11')) return json({ id: 11,
      title: 'Central do Brasil', overview: 'Resumo', release_date: '1998-01-01',
      poster_path: '/filme.jpg' });
    if (url.pathname.endsWith('/search/tv')) return json({ total_results: 1,
      results: [{ id: 22, name: 'Cidade Invisível' }] });
    if (url.pathname.endsWith('/tv/22')) return json({ id: 22,
      name: 'Cidade Invisível', overview: '', first_air_date: '2021-01-01',
      seasons: [{ season_number: 0 }, { season_number: 1 }] });
    if (url.pathname.endsWith('/tv/22/season/1')) return json({ episodes: [
      { id: 33, episode_number: 1, name: 'Episódio', air_date: null },
    ] });
    throw new Error(`Caminho inesperado: ${url.pathname}`);
  });
  fs.writeFileSync(file, JSON.stringify({ TMDB_READ_ACCESS_TOKEN: 'token-ficticio' }),
    { encoding: 'utf8', flag: 'wx' });
  try {
    const report = await tmdb(file);
    assert.equal(report.find(row => row.entity === 'season-details').episodes[0].id, 33);
    assert.equal(report.find(row => row.entity === 'tv-details').overviewPresent, false);
    assert.equal(calls.length, 7);
    for (const { url, options } of calls) {
      if (url.hostname === 'api.themoviedb.org') {
        assert.equal(options.headers.Authorization, 'Bearer token-ficticio');
        if (url.pathname.includes('/search/')) {
          assert.equal(url.searchParams.get('language'), 'pt-BR');
          assert.equal(url.searchParams.get('include_adult'), 'false');
        }
      } else {
        assert.equal(url.hostname, 'image.tmdb.org');
        assert.equal(options.method, 'HEAD');
        assert.equal(options.headers.Authorization, undefined);
      }
    }
  } finally {
    fs.rmSync(file, { force: true });
  }
});
