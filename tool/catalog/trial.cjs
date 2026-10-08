// Ensaio somente de leitura. Não integra o aplicativo nem grava respostas/segredos.
const fs = require('node:fs');
const path = require('node:path');
const { setTimeout: delay } = require('node:timers/promises');
const agent = 'BookselfCatalogTrial/1.0 (https://github.com/RodolfoGama0101/bookself-app)';
let lastCall = 0;

async function request(url, { token, method = 'GET', archiveMetadata = false, hops = 0 } = {}) {
  await delay(Math.max(0, 1100 - (Date.now() - lastCall)));
  lastCall = Date.now();
  const response = await fetch(url, {
    method, redirect: archiveMetadata ? 'manual' : 'error', signal: AbortSignal.timeout(15000),
    headers: { 'User-Agent': agent, Accept: 'application/json',
      Origin: 'http://localhost:7357', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });
  if (archiveMetadata && [301, 302, 303, 307, 308].includes(response.status)) {
    const target = new URL(response.headers.get('location'), url);
    if (token || hops >= 3 || target.protocol !== 'https:' ||
        target.username || target.password ||
        !(target.hostname === 'archive.org' || target.hostname.endsWith('.archive.org')) ||
        !target.pathname.endsWith('/index.json')) {
      throw new Error('Redirecionamento de metadados inválido');
    }
    return request(target, { archiveMetadata: true, hops: hops + 1 });
  }
  const summary = { status: response.status,
    cors: response.headers.get('access-control-allow-origin'),
    contentType: response.headers.get('content-type') };
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return { summary, data: method === 'HEAD' ? null : await response.json() };
}

async function musicbrainz(read = request) {
  const results = [];
  let album;
  for (const [entity, query] of [
    ['recording', 'recording:"Águas de Março" AND artist:"Elis Regina"'],
    ['recording', 'recording:"Tempo Perdido" AND artist:"Legião Urbana"'],
    ['release-group', 'releasegroup:"Clube da Esquina" AND artist:"Milton Nascimento"'],
    ['release-group', 'releasegroup:"Abbey Road" AND artist:"The Beatles"'],
  ]) {
    const url = new URL(`https://musicbrainz.org/ws/2/${entity}`);
    url.search = new URLSearchParams({ query, fmt: 'json', limit: '5' });
    let response;
    try { response = await read(url); }
    catch (error) {
      results.push({ entity, query, outcome: safeError(error) });
      continue;
    }
    const { summary, data } = response;
    const rows = data[entity === 'recording' ? 'recordings' : 'release-groups'];
    if (!Array.isArray(rows)) throw new Error('Resposta inválida');
    results.push({ entity, query, ...summary, total: data.count,
      matches: rows.map(r => ({ id: r.id, title: r.title,
        artist: r['artist-credit']?.map(a => a.name || a.artist?.name || '').join(' / '),
        version: r.disambiguation || '', duration: r.length ?? null })) });
    if (entity === 'release-group' && !album) {
      album = rows.find(r => r.title === 'Clube da Esquina')?.id ?? rows[0]?.id;
    }
  }
  if (album) {
    try {
      const { summary, data } = await read(`https://musicbrainz.org/ws/2/release-group/${album}?fmt=json&inc=releases+artist-credits`);
      const release = data.releases?.find(r => r.status === 'Official') ?? data.releases?.[0];
      results.push({ entity: 'release-group-details', ...summary, id: data.id,
        title: data.title, editions: data.releases?.length ?? 0 });
      if (release) {
        const details = await read(`https://musicbrainz.org/ws/2/release/${release.id}?fmt=json&inc=recordings+artist-credits`);
        results.push({ entity: 'release-details', ...details.summary, id: details.data.id,
          title: details.data.title, date: details.data.date ?? null,
          tracks: details.data.media?.flatMap(m => m.tracks || []).length ?? 0,
          coverAvailable: details.data['cover-art-archive']?.front ?? false });
        // Metadados da capa somente. Não baixa arquivos de imagem.
        try {
          const cover = await read(`https://coverartarchive.org/release/${release.id}`, { archiveMetadata: true });
          results.push({ entity: 'cover-metadata', ...cover.summary,
            images: cover.data.images?.length ?? 0 });
        } catch (error) {
          results.push({ entity: 'cover-metadata', outcome: safeError(error) });
        }
      }
    } catch (error) {
      results.push({ entity: 'album-details', outcome: safeError(error) });
    }
  }
  return results;
}

async function tmdb(configFile) {
  const directory = path.resolve(__dirname, '../../config');
  const resolved = path.resolve(configFile || '');
  if (path.dirname(resolved) !== directory || !resolved.endsWith('.local.json')) {
    throw new Error('Use config/tmdb.local.json ignorado pelo Git');
  }
  const token = JSON.parse(fs.readFileSync(resolved, 'utf8')).TMDB_READ_ACCESS_TOKEN;
  if (typeof token !== 'string' || !token.trim() || /[\r\n]/.test(token)) {
    throw new Error('Credencial de desenvolvimento ausente');
  }
  const results = [];
  const base = 'https://api.themoviedb.org/3';
  const configuration = await request(`${base}/configuration`, { token });
  results.push({ entity: 'configuration', ...configuration.summary });
  for (const [entity, query] of [['movie', 'Central do Brasil'], ['tv', 'Cidade Invisível']]) {
    const params = new URLSearchParams({ query, language: 'pt-BR', include_adult: 'false', page: '1' });
    const search = await request(`${base}/search/${entity}?${params}`, { token });
    results.push({ entity: `${entity}-search`, ...search.summary, total: search.data.total_results,
      matches: search.data.results?.slice(0, 5).map(r => ({ id: r.id, title: r.title ?? r.name })) });
    const selected = search.data.results?.[0];
    if (!selected) throw new Error('Busca sem resultado: investigar cobertura');
    const details = await request(`${base}/${entity}/${selected.id}?language=pt-BR`, { token });
    results.push({ entity: `${entity}-details`, ...details.summary, id: details.data.id,
      title: details.data.title ?? details.data.name, overviewPresent: !!details.data.overview,
      date: details.data.release_date ?? details.data.first_air_date ?? null });
    if (details.data.poster_path) {
      const images = configuration.data.images;
      if (images.secure_base_url !== 'https://image.tmdb.org/t/p/' ||
          !images.poster_sizes.includes('w500') ||
          !/^\/[A-Za-z0-9._-]+$/.test(details.data.poster_path)) {
        throw new Error('Configuração de imagem inesperada');
      }
      const image = await request(`${images.secure_base_url}w500${details.data.poster_path}`, { method: 'HEAD' });
      results.push({ entity: `${entity}-poster-head`, ...image.summary });
    } else results.push({ entity: `${entity}-poster-head`, outcome: 'sem capa' });
    if (entity === 'tv') {
      const season = details.data.seasons?.find(s => s.season_number > 0);
      if (!season) throw new Error('Temporada ausente');
      const episodes = await request(`${base}/tv/${selected.id}/season/${season.season_number}?language=pt-BR`, { token });
      results.push({ entity: 'season-details', ...episodes.summary,
        season: season.season_number, episodes: episodes.data.episodes?.map(e => ({
          id: e.id, number: e.episode_number, name: e.name, date: e.air_date ?? null })) });
    }
  }
  return results;
}

function safeError(error) {
  const message = error?.message;
  return /^HTTP \d{3}$/.test(message) ? message : 'Falha de rede, configuração ou resposta; sem detalhes sensíveis';
}

if (require.main === module) {
  const provider = process.argv[2];
  (provider === 'musicbrainz' ? musicbrainz() : provider === 'tmdb' ? tmdb(process.argv[3]) :
    Promise.reject(new Error('Fornecedor inválido')))
    .then(results => {
      const partial = results.some(r => r.outcome && r.outcome !== 'sem capa');
      console.log(JSON.stringify({ provider, checkedAt: new Date().toISOString(),
        status: partial ? 'partial' : 'complete', results }, null, 2));
      if (partial) process.exitCode = 2;
    })
    .catch(error => { console.error(safeError(error)); process.exitCode = 1; });
}
module.exports = { musicbrainz, tmdb, safeError, request };
