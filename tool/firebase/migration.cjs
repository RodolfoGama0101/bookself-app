// Ensaio offline: não importa SDK, credenciais ou destinos remotos.
const {createHash} = require('node:crypto');
const fs = require('node:fs');

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  }
  return value;
}
const copy = value => JSON.parse(JSON.stringify(value));
const digest = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
function validateJson(value) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return;
  if (typeof value === 'number' && Number.isFinite(value)) return;
  if (Array.isArray(value)) { value.forEach(validateJson); return; }
  if (value && typeof value === 'object' &&
      [Object.prototype, null].includes(Object.getPrototypeOf(value))) {
    Object.values(value).forEach(validateJson); return;
  }
  throw new Error('Valor não representável no snapshot JSON');
}
function validateSnapshot(snapshot) {
  validateJson(snapshot);
  if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) throw new Error('Snapshot inválido');
  for (const [path, data] of Object.entries(snapshot)) {
    if (!/^[^/]+\/[^/]+(?:\/[^/]+\/[^/]+)*$/.test(path) ||
        !data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Documento inválido');
  }
}
function backup(snapshot) {
  validateSnapshot(snapshot);
  const documents = copy(snapshot);
  return {formatVersion: 1, sourceDigest: digest(documents), documents};
}
function verifyBackup(saved) {
  if (saved?.formatVersion !== 1) throw new Error('Versão de backup incompatível');
  validateSnapshot(saved.documents);
  if (digest(saved.documents) !== saved.sourceDigest) throw new Error('Backup divergente');
}
function plan(saved) {
  verifyBackup(saved);
  const imports = {}, conflicts = [], references = new Map();
  let books = 0, users = 0, bible = 0, relationships = 0;
  for (const [path, data] of Object.entries(saved.documents).sort(([a], [b]) => a.localeCompare(b))) {
    const [collection, id] = path.split('/');
    if (collection === 'bible_progress') bible++;
    if (collection === 'users') {
      users++;
      if (data.uid !== id) conflicts.push({sourcePath: path, reason: 'uid_path_mismatch'});
      if (data.partnerUid != null) {
        const other = saved.documents[`users/${data.partnerUid}`];
        if (other?.partnerUid !== id) conflicts.push({sourcePath: path, reason: 'non_reciprocal_relationship'});
        else if (id < data.partnerUid) relationships++;
      }
    }
    if (collection !== 'books') continue;
    books++;
    if (typeof data.userId !== 'string' || !saved.documents[`users/${data.userId}`]) {
      conflicts.push({sourcePath: path, reason: 'missing_owner'});
    }
    const external = typeof data.googleBooksId === 'string' && data.googleBooksId.length > 0;
    const identity = external
      ? [1, 'book', 'external', 'google_books', data.googleBooksId]
      : [1, 'book', 'manual', data.userId ?? null, id];
    const referenceKey = JSON.stringify([data.userId ?? null, ...identity]);
    if (references.has(referenceKey)) {
      conflicts.push({sourcePath: path, reason: 'duplicate_reference', otherPath: references.get(referenceKey)});
    } else references.set(referenceKey, path);
    // Área de preparação distinta do contrato ativo. Não presumir createdAt,
    // converter datas com fuso desconhecido ou decidir sobrevivente de duplicatas.
    imports[`migration_imports/${digest(path)}`] = {
      schemaVersion: 1, migrationVersion: 1, sourcePath: path,
      sourceDigest: digest(data), ownerId: data.userId ?? null,
      originalId: id, identity, createdAt: null,
      legacyRef: {collection: 'books', id, creationUnknown: true},
      original: copy(data),
    };
  }
  return {migrationVersion: 1, sourceDigest: saved.sourceDigest, imports, conflicts,
    counts: {documents: Object.keys(saved.documents).length, books, users, bible, relationships}};
}
function validatePlan(saved, prepared) {
  if (digest(plan(saved)) !== digest(prepared)) throw new Error('Plano divergente do backup');
}
function apply(saved, prepared, current) {
  validatePlan(saved, prepared);
  const result = copy(current);
  for (const [path, source] of Object.entries(saved.documents)) {
    if (digest(current[path] ?? null) !== digest(source)) throw new Error('Origem mudou; refazer backup e plano');
  }
  for (const [path, data] of Object.entries(prepared.imports)) {
    if (result[path] && digest(result[path]) !== digest(data)) throw new Error('Destino ocupado ou alterado');
    result[path] = copy(data);
  }
  return result;
}
function rollback(saved, prepared, current) {
  validatePlan(saved, prepared);
  const result = copy(current);
  // Validar tudo antes de remover; nunca apagar alteração posterior.
  for (const [path, data] of Object.entries(prepared.imports)) {
    if (result[path] && digest(result[path]) !== digest(data)) throw new Error('Destino mudou; recuperação requer revisão');
  }
  for (const path of Object.keys(prepared.imports)) delete result[path];
  return result;
}
function rehearse(snapshot) {
  const saved = backup(snapshot), prepared = plan(saved);
  const imported = apply(saved, prepared, snapshot);
  if (digest(apply(saved, prepared, imported)) !== digest(imported)) throw new Error('Ensaio não idempotente');
  const restored = rollback(saved, prepared, imported);
  if (digest(restored) !== digest(snapshot)) throw new Error('Recuperação divergente');
  return {saved, prepared, summary: {...prepared.counts, conflicts: prepared.conflicts.length, verified: true}};
}
module.exports = {digest, backup, verifyBackup, plan, validatePlan, apply, rollback, rehearse};
if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    if (args.length !== 1 && !(args.length === 3 && args[1] === '--archive' && args[2].endsWith('.local.json'))) {
      throw new Error('Use node migration.cjs <snapshot-local.json> [--archive <backup.local.json>]');
    }
    const result = rehearse(JSON.parse(fs.readFileSync(process.argv[2], 'utf8')));
    if (args.length === 3) {
      // Arquivo exclusivo: nunca substituir backup existente. O sufixo local
      // e o local recomendado em config/ mantêm conteúdo privado fora do Git.
      fs.writeFileSync(args[2], JSON.stringify({backup: result.saved, plan: result.prepared}), {flag:'wx', mode:0o600});
    }
    // Só contagens: IDs, nomes, conteúdo e datas não vão para o terminal.
    console.info(JSON.stringify(result.summary));
  } catch (_) { console.error('Ensaio recusado; confira snapshot, versão e integridade.'); process.exitCode = 1; }
}
