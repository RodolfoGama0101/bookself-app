const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createCatalog, createServer, normalize, USER_AGENT } = require('./musicbrainz-server.cjs');
const ID = '11111111-1111-4111-8111-111111111111';
const ID2 = '22222222-2222-4222-8222-222222222222';
const row = (id = ID) => ({ id, title: 'Clube da Esquina',
  'release-group': { 'primary-type': 'Album' },
  'artist-credit': [{ name: 'Milton Nascimento' }, { artist: { name: 'Lô Borges' } }] });
const json = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), { status, headers });
const params = (q = 'Clube da Esquina', cursor) => new URLSearchParams({ q, ...(cursor ? { cursor } : {}) });

test('preserva identidades de edição e gravação, créditos e opcionais sem escolher álbum', () => {
  const source = { ...row(), date: '1972', country: 'BR', media: [{ format: 'Vinyl' }],
    disambiguation: 'edição original', length: 123000, releases: [{ title: 'Não escolher' }] };
  const album = normalize('albums', source);
  assert.equal(album.releaseYear, 1972);
  assert.equal(album.edition, 'edição original · 1972 · BR · Vinyl');
  assert.deepEqual(album.artists, ['Milton Nascimento', 'Lô Borges']);
  const track = normalize('tracks', source);
  assert.equal(track.version, 'edição original');
  assert.equal(track.durationMs, 123000);
  assert.equal(track.albumTitle, undefined);
  assert.equal(track.coverUrl, undefined);
  assert.equal(normalize('tracks', { ...row(), 'artist-credit': [null] }), null);
  assert.equal(normalize('albums', { ...row(), 'release-group': { 'primary-type': 'Single' } }), null);
});

test('paginação conserva filtro/consulta, descarta parcial e não funde edições pelo título', async () => {
  const calls = [];
  const catalog = createCatalog({ interval: 0, fetchImpl: async (url, options) => {
    calls.push({ url, options });
    return json({ count: 30, releases: [row(), row(), row(ID2), { id: ID, title: 'Sem artista' }] });
  } });
  const first = await catalog.get('albums', 'search', params());
  assert.deepEqual(first.items.map(item => item.id), [ID, ID2]);
  await catalog.get('albums', 'search', params('Clube da Esquina', first.nextCursor));
  assert.equal(calls[1].url.searchParams.get('offset'), '25');
  assert.match(calls[0].url.searchParams.get('query'), /primarytype:album/);
  assert.equal(calls[0].url.origin, 'https://musicbrainz.org');
  assert.equal(calls[0].options.headers['User-Agent'], USER_AGENT);
  assert.equal(calls[0].options.redirect, 'error');
  await assert.rejects(catalog.get('tracks', 'search', params('Clube da Esquina', first.nextCursor)), { status: 400 });
  await assert.rejects(catalog.get('albums', 'search', params('Outra', first.nextCursor)), { status: 400 });
  await assert.rejects(catalog.get('albums', 'https://outra.test'), { status: 400 });
  assert.equal(calls.length, 2);
});

test('busca e detalhes compartilham intervalo; simultâneas iguais usam uma consulta', async () => {
  let time = 0;
  const starts = [];
  const catalog = createCatalog({ now: () => time, sleep: async ms => { time += ms; },
    fetchImpl: async url => {
      starts.push(time);
      return json(url.pathname.endsWith(ID) ? row() : { count: 1, recordings: [row()] });
    } });
  await Promise.all([catalog.get('tracks', 'search', params()),
    catalog.get('tracks', ID), catalog.get('tracks', 'search', params())]);
  assert.deepEqual(starts, [0, 1100]);
});

test('cache expira, tem capacidade limitada e não expõe objeto mutável', async () => {
  let time = 0, calls = 0;
  const catalog = createCatalog({ interval: 0, capacity: 2, now: () => time,
    fetchImpl: async () => { calls++; return json({ count: 1, recordings: [row()] }); } });
  const first = await catalog.get('tracks', 'search', params('um'));
  first.items[0].title = 'Alterado';
  assert.equal((await catalog.get('tracks', 'search', params('um'))).items[0].title, 'Clube da Esquina');
  assert.equal(calls, 1);
  time = 60001;
  await catalog.get('tracks', 'search', params('um'));
  await catalog.get('tracks', 'search', params('dois'));
  await catalog.get('tracks', 'search', params('três'));
  await catalog.get('tracks', 'search', params('um'));
  assert.equal(calls, 5);
});

test('cursor de consulta Unicode máxima cabe no cliente; detalhes expiram após uma hora', async () => {
  let time = 0, detailCalls = 0;
  const catalog = createCatalog({ interval: 0, now: () => time, fetchImpl: async url => {
    if (url.pathname.endsWith(ID)) {
      detailCalls++;
      assert.equal(url.pathname, `/ws/2/release/${ID}`);
      assert.equal(url.searchParams.get('inc'), 'artist-credits+release-groups');
      return json(row());
    }
    return json({ count: 30, releases: [row()] });
  } });
  const query = '音'.repeat(300);
  const page = await catalog.get('albums', 'search', params(query));
  assert.ok(page.nextCursor.length <= 1000);
  await catalog.get('albums', 'search', params(query, page.nextCursor));
  await catalog.get('albums', ID);
  time = 3599999;
  await catalog.get('albums', ID);
  assert.equal(detailCalls, 1);
  time = 3600001;
  await catalog.get('albums', ID);
  assert.equal(detailCalls, 2);
});

test('indisponibilidade respeita Retry-After, não faz retry nem guarda erro no cache', async () => {
  let time = 0, calls = 0;
  const catalog = createCatalog({ now: () => time, sleep: async ms => { time += ms; },
    fetchImpl: async () => ++calls === 1 ? json({}, 503, { 'Retry-After': '12' })
      : json({ count: 0, recordings: [] }) });
  await assert.rejects(catalog.get('tracks', 'search', params()), { status: 503, retryAfter: 12 });
  assert.equal(calls, 1);
  await assert.rejects(catalog.get('tracks', 'search', params()), { status: 429, retryAfter: 12 });
  time = 12000;
  await catalog.get('tracks', 'search', params());
  assert.equal(time, 12000);
  assert.equal(calls, 2);
});

test('timeout cobre rede; conteúdo inválido e detalhes divergentes são recusados', async () => {
  const catalog = createCatalog({ timeout: 5, fetchImpl: (_, { signal }) =>
    new Promise((resolve, reject) => signal.addEventListener('abort', () => reject(signal.reason))) });
  // Mantém o processo ativo: AbortSignal.timeout por si só não mantém o event loop.
  const keepAlive = setInterval(() => {}, 50);
  try { await assert.rejects(catalog.get('tracks', ID), { status: 504 }); }
  finally { clearInterval(keepAlive); }
  for (const response of [new Response('não é JSON'), json(row(ID2)),
    json({ count: 0 }), new Response('x'.repeat(2 * 1024 * 1024 + 1))]) {
    const bad = createCatalog({ fetchImpl: async () => response });
    await assert.rejects(bad.get('tracks', ID), { status: 502 });
  }
});

test('fila limitada recusa excesso sem multiplicar chamadas', async () => {
  let unblock;
  const wait = new Promise(resolve => { unblock = resolve; });
  let calls = 0, time = 0;
  const catalog = createCatalog({ now: () => time, sleep: async ms => { await wait; time += ms; },
    fetchImpl: async () => { calls++; return json({ count: 0, recordings: [] }); } });
  await catalog.get('tracks', 'search', params('inicial'));
  const pending = Array.from({ length: 4 }, (_, i) => catalog.get('tracks', 'search', params(`obra ${i}`)));
  await assert.rejects(catalog.get('tracks', 'search', params('excesso')), { status: 429 });
  assert.equal(calls, 1);
  unblock();
  await Promise.all(pending);
  assert.equal(calls, 5);
});

test('HTTP restringe host/origem/rota, serve Android e CORS local sem expor erros', async context => {
  let calls = 0;
  const server = createServer({ get: async () => { calls++; return { provider: 'musicbrainz', items: [] }; } });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  context.after(() => new Promise(resolve => server.close(resolve)));
  const port = server.address().port;
  const request = (path = '/music/tracks/search?q=obra', headers = {}, method = 'GET') => new Promise((resolve, reject) => {
    const req = http.request({ hostname: '127.0.0.1', port, path, headers, method }, res => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject); req.end();
  });
  const good = await request(undefined, { origin: 'http://localhost:7357', host: `10.0.2.2:${port}` });
  assert.equal(good.status, 200);
  assert.equal(good.headers['access-control-allow-origin'], 'http://localhost:7357');
  for (const headers of [{ host: 'outra.test' }, { origin: 'https://outra.test' }, { origin: 'null' }]) {
    const bad = await request(undefined, headers);
    assert.equal(bad.status, 403);
    assert.doesNotMatch(bad.body, /outra.test|stack|Error:/);
  }
  assert.equal((await request('/music/tracks/search?q=um&q=dois')).status, 400);
  assert.equal((await request('/proxy?url=https://outra.test')).status, 404);
  assert.equal((await request(undefined, {}, 'POST')).status, 405);
  assert.equal(calls, 1);
});
