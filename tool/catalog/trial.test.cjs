const test = require('node:test');
const assert = require('node:assert/strict');
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
