// Somente leitura, contra o intermediário local já iniciado.
const assert = require('node:assert/strict');
async function main() {
  for (const [type, query] of [['tracks', 'Águas de Março Elis Regina'], ['albums', 'Clube da Esquina Milton Nascimento']]) {
    const url = new URL(`http://127.0.0.1:17370/music/${type}/search`);
    url.searchParams.set('q', query);
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    assert.equal(response.status, 200, `Busca ${type}: HTTP ${response.status}`);
    const page = await response.json();
    assert.equal(page.provider, 'musicbrainz');
    assert.ok(page.items.length > 0, `Busca sem resultados: ${type}`);
    const selected = page.items[0];
    const details = await fetch(`http://127.0.0.1:17370/music/${type}/${selected.id}`,
      { signal: AbortSignal.timeout(15000) });
    assert.equal(details.status, 200, `Detalhes ${type}: HTTP ${details.status}`);
    const result = await details.json();
    assert.equal(result.item.id, selected.id);
    assert.ok(result.item.artists.length > 0);
    console.log(JSON.stringify({ type, results: page.items.length, pagination: !!page.nextCursor,
      id: selected.id, title: result.item.title, artists: result.item.artists,
      version: result.item.version, edition: result.item.edition }));
    if (page.nextCursor) {
      url.searchParams.set('cursor', page.nextCursor);
      const next = await fetch(url, { signal: AbortSignal.timeout(15000) });
      assert.equal(next.status, 200, `Próxima página ${type}: HTTP ${next.status}`);
      console.log(JSON.stringify({ type, nextPageResults: (await next.json()).items.length }));
    }
  }
}
main().catch(() => { console.error('Ensaio não concluído: rede, indisponibilidade ou contrato divergente. Tente novamente depois.'); process.exitCode = 1; });
