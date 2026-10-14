// Intermediário local de desenvolvimento. Não expor em rede/produção.
const http = require('node:http');
const { createHash } = require('node:crypto');
const { setTimeout: delay } = require('node:timers/promises');
const USER_AGENT = 'BookselfApp/1.0 (https://github.com/RodolfoGama0101/bookself-app)';
const MBID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '10.0.2.2']);
const PAGE_SIZE = 25;
class CatalogError extends Error {
  constructor(status, retryAfter) {
    super(`Catálogo indisponível (${status})`);
    this.status = status;
    this.retryAfter = retryAfter;
  }
}
const text = value => typeof value === 'string' && value.trim() && value.trim().length <= 300
  ? value.trim() : null;
function normalize(type, raw) {
  if (!raw || !MBID.test(raw.id) || !text(raw.title)) return null;
  const credits = raw['artist-credit'];
  if (!Array.isArray(credits) || !credits.length) return null;
  const artists = credits.map(credit => text(credit?.name) || text(credit?.artist?.name));
  if (artists.some(artist => !artist) || artists.join('; ').length > 300) return null;
  const item = { id: raw.id, title: text(raw.title), artists };
  if (type === 'tracks') {
    if (text(raw.disambiguation)) item.version = text(raw.disambiguation);
    if (Number.isSafeInteger(raw.length) && raw.length >= 0) item.durationMs = raw.length;
    // Gravação pode pertencer a muitas edições; não escolher álbum arbitrário.
  } else {
    if (raw['release-group']?.['primary-type'] !== 'Album') return null;
    const year = /^(\d{4})(?:-|$)/.exec(raw.date || '');
    if (year && Number(year[1]) > 0) item.releaseYear = Number(year[1]);
    const formats = [...new Set((Array.isArray(raw.media) ? raw.media : [])
      .map(medium => text(medium?.format)).filter(Boolean))];
    const edition = [text(raw.disambiguation), text(raw.date), text(raw.country), ...formats]
      .filter(Boolean).join(' · ');
    if (text(edition)) item.edition = edition;
  }
  return item;
}
function createCatalog({ fetchImpl = fetch, now = Date.now, sleep = delay,
  interval = 1100, timeout = 10000, capacity = 100 } = {}) {
  const cache = new Map(), inflight = new Map();
  let nextStart = 0, gate = Promise.resolve(), queued = 0, cooldown = 0;
  async function upstream(entity, id, params) {
    if (cooldown > now()) throw new CatalogError(429, Math.ceil((cooldown - now()) / 1000));
    if (queued >= 4) throw new CatalogError(429, 2);
    queued++;
    const signal = AbortSignal.timeout(timeout);
    const turn = gate.then(async () => {
      try {
        while (now() < nextStart) {
          await sleep(nextStart - now(), undefined, { signal });
        }
        if (cooldown > now()) throw new CatalogError(429, Math.ceil((cooldown - now()) / 1000));
        signal.throwIfAborted();
        nextStart = now() + interval;
      } finally { queued--; }
    });
    gate = turn.catch(() => {});
    try {
      await turn;
      const url = new URL(`https://musicbrainz.org/ws/2/${entity}${id ? `/${id}` : ''}`);
      url.search = new URLSearchParams({ fmt: 'json', ...params });
      const response = await fetchImpl(url, { redirect: 'error', signal,
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' } });
      if (!response.ok) {
        if (response.status === 429 || response.status === 503) {
          const header = response.headers.get('retry-after');
          const seconds = /^\d+$/.test(header || '') ? Number(header)
            : Math.ceil((Date.parse(header) - now()) / 1000);
          const retry = Math.max(2, Number.isFinite(seconds) ? seconds : 5);
          cooldown = Math.max(cooldown, now() + retry * 1000);
          throw new CatalogError(response.status, retry);
        }
        throw new CatalogError(response.status === 404 ? 404 : 502);
      }
      // Limita também respostas chunked; não guardar o documento externo bruto.
      let size = 0;
      const chunks = [];
      for await (const chunk of response.body) {
        size += chunk.length;
        if (size > 2 * 1024 * 1024) throw new CatalogError(502);
        chunks.push(chunk);
      }
      return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch (error) {
      if (error instanceof CatalogError) throw error;
      throw new CatalogError(signal.aborted ? 504 : 502);
    }
  }
  async function cached(key, ttl, load) {
    const hit = cache.get(key);
    if (hit && hit.until > now()) return structuredClone(hit.value);
    cache.delete(key);
    if (!inflight.has(key)) {
      if (inflight.size >= 8) throw new CatalogError(429, 2);
      inflight.set(key, (async () => {
        const value = await load();
        if (cache.size >= capacity) cache.delete(cache.keys().next().value);
        cache.set(key, { until: now() + ttl, value });
        return value;
      })().finally(() => inflight.delete(key)));
    }
    return structuredClone(await inflight.get(key));
  }
  return {
    async get(type, action, params = new URLSearchParams()) {
      if (!['tracks', 'albums'].includes(type)) throw new CatalogError(404);
      const entity = type === 'tracks' ? 'recording' : 'release';
      if (action !== 'search') {
        if (!MBID.test(action)) throw new CatalogError(400);
        return cached(`${type}/${action}`, 3600000, async () => {
          const raw = await upstream(entity, action, {
            inc: type === 'albums' ? 'artist-credits+release-groups' : 'artist-credits',
          });
          const item = normalize(type, raw);
          if (!item || item.id !== action) throw new CatalogError(502);
          return { provider: 'musicbrainz', item };
        });
      }
      const query = text(params.get('q'));
      if (!query) throw new CatalogError(400);
      const queryHash = createHash('sha256').update(query).digest('hex');
      let offset = 0;
      if (params.has('cursor')) {
        try {
          const cursor = JSON.parse(Buffer.from(params.get('cursor'), 'base64url'));
          if (cursor.q !== queryHash || cursor.type !== type || !Number.isSafeInteger(cursor.offset)
            || cursor.offset < PAGE_SIZE || cursor.offset > 10000 || cursor.offset % PAGE_SIZE) throw new Error();
          offset = cursor.offset;
        } catch { throw new CatalogError(400); }
      }
      return cached(JSON.stringify([type, query, offset]), 60000, async () => {
        // Texto livre: operadores digitados não alteram o filtro de álbuns.
        const escaped = query.replace(/([+\-!(){}\[\]^"~*?:\\/|&])/g, '\\$1')
          .split(/\s+/).map(token => `(${entity}:"${token}" OR artist:"${token}")`).join(' AND ');
        const raw = await upstream(entity, null, {
          query: type === 'albums' ? `(${escaped}) AND primarytype:album` : escaped,
          limit: String(PAGE_SIZE), offset: String(offset),
        });
        const rows = raw[type === 'tracks' ? 'recordings' : 'releases'];
        if (!Array.isArray(rows) || rows.length > PAGE_SIZE || !Number.isSafeInteger(raw.count)
          || raw.count < 0) throw new CatalogError(502);
        const items = [...new Map(rows.map(row => normalize(type, row))
          .filter(Boolean).map(item => [item.id, item])).values()];
        const next = offset + PAGE_SIZE;
        return { provider: 'musicbrainz', items,
          nextCursor: rows.length && next < raw.count && next <= 10000
            ? Buffer.from(JSON.stringify({ type, q: queryHash, offset: next })).toString('base64url') : null };
      });
    },
  };
}
function createServer(catalog = createCatalog()) {
  return http.createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
      const base = new URL(`http://${req.headers.host}`);
      if (!LOCAL_HOSTS.has(base.hostname) || base.username || base.password) throw new CatalogError(403);
      if (req.headers.origin) {
        let origin;
        try { origin = new URL(req.headers.origin); }
        catch { throw new CatalogError(403); }
        if (origin.protocol !== 'http:' || !['localhost', '127.0.0.1'].includes(origin.hostname)
          || origin.username || origin.password || origin.origin !== req.headers.origin) throw new CatalogError(403);
        res.setHeader('Access-Control-Allow-Origin', origin.origin);
        res.setHeader('Vary', 'Origin');
      }
      if (req.method !== 'GET') throw new CatalogError(405);
      if (req.url.length > 3000) throw new CatalogError(400);
      const url = new URL(req.url, base);
      if (url.origin !== base.origin) throw new CatalogError(403);
      const match = /^\/music\/(tracks|albums)\/([^/]+)$/.exec(url.pathname);
      if (!match) throw new CatalogError(404);
      if ([...url.searchParams.keys()].some(key => !['q', 'cursor', 'language'].includes(key))
        || [...url.searchParams.keys()].some(key => url.searchParams.getAll(key).length !== 1)
        || (url.searchParams.get('cursor') || '').length > 1000) throw new CatalogError(400);
      const data = await catalog.get(match[1], match[2], url.searchParams);
      res.writeHead(200).end(JSON.stringify(data));
    } catch (error) {
      const status = error instanceof CatalogError ? error.status : 400;
      if (error.retryAfter) res.setHeader('Retry-After', String(error.retryAfter));
      res.writeHead(status).end(JSON.stringify({ error: 'Catálogo indisponível. Use o cadastro manual ou tente novamente.' }));
    }
  });
}
if (require.main === module) {
  const port = Number(process.env.MUSIC_CATALOG_PORT || 17370);
  if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Porta inválida');
  const server = createServer();
  server.on('error', () => { console.error('Não foi possível iniciar o catálogo local. Confira a porta.'); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`MusicBrainz local: http://127.0.0.1:${port}`));
}
module.exports = { createCatalog, createServer, normalize, CatalogError, USER_AGENT };
