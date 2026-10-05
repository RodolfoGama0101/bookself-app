const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, collection, query, where, getDocs, serverTimestamp, Timestamp, setLogLevel} = require('firebase/firestore');
setLogLevel('silent');
const projectId = 'demo-bookself';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(firestoreHost || '', /^(127\.0\.0\.1|localhost):\d+$/,
  'Execute por npm test, usando somente o emulador local');
assert.equal(process.env.GCLOUD_PROJECT, projectId);
let env;
const stamp = Timestamp.fromDate(new Date('2020-01-01T00:00:00Z'));
const profile = uid => ({uid, name: 'Pessoa fictícia', email: `${uid}@example.com`, createdAt: stamp, partnerUid: null, photoUrl: null});
const book = uid => ({userId: uid, title: 'Livro fictício', authors: ['Autor'], coverUrl: '', status: 'Lendo', publishedDate: '2020', addedAt: stamp, finishedDate: null});
const progress = (uid, bookName = 'Gênesis', readChapters = [1]) => ({userId: uid, bookName, readChapters, updatedAt: serverTimestamp()});
const db = uid => env.authenticatedContext(uid, {email: `${uid}@example.com`}).firestore();

function pair(database, a, b, linking = true) {
  const batch = writeBatch(database);
  batch.update(doc(database, 'users', a), {partnerUid: linking ? b : null});
  batch.update(doc(database, 'users', b), {partnerUid: linking ? a : null});
  return batch.commit();
}
async function state() {
  const result = {};
  await env.withSecurityRulesDisabled(async context => {
    const database = context.firestore();
    for (const uid of ['a', 'b', 'c', 'd']) {
      result[uid] = (await getDoc(doc(database, 'users', uid))).data().partnerUid;
    }
  });
  return result;
}
function assertReciprocal(links) {
  for (const [uid, partner] of Object.entries(links)) {
    if (partner !== null) { assert.notEqual(partner, uid); assert.equal(links[partner], uid); }
  }
}
before(async () => {
  const [host, port] = firestoreHost.split(':');
  env = await initializeTestEnvironment({projectId, firestore: {
    host, port: Number(port), rules: fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8'),
  }});
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const database = context.firestore();
    const batch = writeBatch(database);
    for (const uid of ['a', 'b', 'c', 'd']) {
      batch.set(doc(database, 'users', uid), profile(uid));
      batch.set(doc(database, 'books', `${uid}-book`), book(uid));
      batch.set(doc(database, 'bible_progress', `${uid}_gênesis`), progress(uid));
    }
    await batch.commit();
  });
});

test('sem autenticação não lê nem escreve nas três coleções', async () => {
  const database = env.unauthenticatedContext().firestore();
  for (const [group, id] of [['users','a'], ['books','a-book'], ['bible_progress','a_gênesis']]) {
    await assertFails(getDoc(doc(database, group, id)));
    await assertFails(deleteDoc(doc(database, group, id)));
    await assertFails(setDoc(doc(database, group, 'fake'), {userId: 'a'}));
  }
});
test('dono lê seus registros; terceiro não lê perfis/livros/Bíblia', async () => {
  for (const [group, id] of [['users','a'], ['books','a-book'], ['bible_progress','a_gênesis']]) {
    await assertSucceeds(getDoc(doc(db('a'), group, id)));
    await assertFails(getDoc(doc(db('c'), group, id)));
  }
});
test('perfil ausente pode ser consultado/criado apenas pelo próprio usuário', async () => {
  await assertSucceeds(getDoc(doc(db('new'), 'users', 'new')));
  await assertSucceeds(setDoc(doc(db('new'), 'users', 'new'), profile('new')));
  await assertFails(setDoc(doc(db('a'), 'users', 'other'), profile('other')));
  await assertFails(setDoc(doc(db('forged'), 'users', 'forged'), {...profile('forged'), email: 'a@example.com'}));
  await assertFails(setDoc(doc(db('prelinked'), 'users', 'prelinked'), {...profile('prelinked'), partnerUid: 'a'}));
  await assertFails(setDoc(doc(db('extra'), 'users', 'extra'), {...profile('extra'), admin: true}));
});
test('nome/foto próprios funcionam; autoria/e-mail/data e exclusão ficam protegidos', async () => {
  const database = db('a'); const reference = doc(database, 'users', 'a');
  await assertSucceeds(updateDoc(reference, {name: 'Novo nome', photoUrl: 'data:image/png;base64,ZmljdGl0aW8='}));
  await assertSucceeds(updateDoc(reference, {photoUrl: null}));
  for (const patch of [{uid: 'c'}, {email: 'c@example.com'}, {createdAt: serverTimestamp()}, {name: ''}, {photoUrl: 2}, {admin: true}]) {
    await assertFails(updateDoc(reference, patch));
  }
  await assertFails(deleteDoc(reference));
  await assertFails(updateDoc(doc(db('c'), 'users', 'a'), {name: 'Outro nome'}));
  await assertFails(getDocs(collection(database, 'users')));
});
test('metadados legados de perfil permanecem em edição e vínculo', async () => {
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'users', 'a'), {legacy: 'preservado'}));
  await assertSucceeds(updateDoc(doc(db('a'), 'users', 'a'), {name: 'Nome corrigido'}));
  await assertSucceeds(pair(db('a'), 'a', 'b'));
  assert.equal((await getDoc(doc(db('a'), 'users', 'a'))).data().legacy, 'preservado');
});
test('parceiro recíproco lê perfil/estante/Bíblia e não escreve nos dados pessoais', async () => {
  await assertSucceeds(pair(db('a'), 'a', 'b'));
  for (const [group, id] of [['users','b'], ['books','b-book'], ['bible_progress','b_gênesis']]) {
    await assertSucceeds(getDoc(doc(db('a'), group, id)));
    await assertFails(deleteDoc(doc(db('a'), group, id)));
  }
  await assertFails(updateDoc(doc(db('a'), 'users', 'b'), {photoUrl: 'fake'}));
  await assertFails(updateDoc(doc(db('a'), 'books', 'b-book'), {status: 'Lido'}));
  await assertFails(updateDoc(doc(db('a'), 'bible_progress', 'b_gênesis'), progress('b', 'Gênesis', [2])));
});
test('ponteiro unilateral não concede acesso a parceiro', async () => {
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'users', 'a'), {partnerUid: 'b'}));
  await assertFails(getDoc(doc(db('a'), 'users', 'b')));
  await assertFails(getDoc(doc(db('a'), 'books', 'b-book')));
  await assertFails(getDoc(doc(db('a'), 'bible_progress', 'b_gênesis')));
});
test('queries filtradas pessoais/casal funcionam; globais e terceiros são negados', async () => {
  await pair(db('a'), 'a', 'b');
  const database = db('a');
  for (const group of ['books', 'bible_progress']) {
    await assertSucceeds(getDocs(query(collection(database, group), where('userId', '==', 'a'))));
    await assertSucceeds(getDocs(query(collection(database, group), where('userId', 'in', ['a','b']))));
    await assertFails(getDocs(query(collection(database, group), where('userId', '==', 'c'))));
    await assertFails(getDocs(collection(database, group)));
  }
});
test('livros permitem inclusão/edição/exclusão próprias, conclusão e limpeza', async () => {
  const reference = doc(db('a'), 'books', 'new');
  await assertSucceeds(setDoc(reference, book('a')));
  await assertSucceeds(updateDoc(reference, {status: 'Lido', finishedDate: stamp}));
  await assertSucceeds(updateDoc(reference, {status: 'Lendo', finishedDate: null}));
  await assertSucceeds(deleteDoc(reference));
});

test('referência do catálogo é opcional e não concede acesso nem colide entre donos', async () => {
  const a = doc(db('a'), 'books', 'personal-a');
  const b = doc(db('b'), 'books', 'personal-b');
  await assertSucceeds(setDoc(a, {...book('a'), googleBooksId: 'same-catalog'}));
  await assertSucceeds(setDoc(b, {...book('b'), googleBooksId: 'same-catalog'}));
  await assertFails(getDoc(doc(db('b'), 'books', 'personal-a')));
  await assertFails(updateDoc(doc(db('c'), 'books', 'personal-a'), {googleBooksId: 'changed'}));
  for (const googleBooksId of ['', 3, 'x'.repeat(201)]) {
    await assertFails(updateDoc(a, {googleBooksId}));
  }
  await assertSucceeds(updateDoc(a, {googleBooksId: null}));
  await assertSucceeds(updateDoc(doc(db('a'), 'books', 'a-book'), {title: 'Legado sem referência'}));
});
test('livros não aceitam transferir autoria, campos/tipos/estados inválidos ou futura conclusão', async () => {
  const reference = doc(db('a'), 'books', 'a-book');
  const future = Timestamp.fromDate(new Date('2099-01-01T00:00:00Z'));
  for (const patch of [{userId: 'b'}, {status: 'Assistido'}, {authors: [3]}, {title: ''}, {addedAt: 'ontem'}, {extra: true}, {status: 'Lido', finishedDate: future}, {finishedDate: stamp}]) {
    await assertFails(updateDoc(reference, patch));
  }
  await assertFails(setDoc(doc(db('a'), 'books', 'other'), book('b')));
});
test('livros lidos legados sem data/futuros continuam legíveis e podem ser corrigidos', async () => {
  const database = db('a'); const reference = doc(database, 'books', 'a-book');
  await env.withSecurityRulesDisabled(context => setDoc(doc(context.firestore(), 'books', 'a-book'),
    {...book('a'), status: 'Lido', finishedDate: Timestamp.fromDate(new Date('2099-01-01T00:00:00Z'))}));
  await assertSucceeds(getDoc(reference));
  await assertSucceeds(updateDoc(reference, {title: 'Título corrigido'}));
  await assertSucceeds(updateDoc(reference, {finishedDate: null}));
  await assertSucceeds(updateDoc(reference, {finishedDate: stamp}));
});
test('Bíblia lê ausência, marca/desmarca/lote, exige autoria e timestamp do servidor', async () => {
  const reference = doc(db('a'), 'bible_progress', 'a_1_samuel');
  await assertSucceeds(getDoc(reference));
  await assertSucceeds(setDoc(reference, progress('a', '1 Samuel', [1,31])));
  await assertSucceeds(setDoc(reference, progress('a', '1 Samuel', [])));
  await assertSucceeds(setDoc(reference, progress('a', '1 Samuel', Array.from({length:31},(_,i)=>i+1))));
  await assertFails(updateDoc(reference, {userId: 'b'}));
  await assertFails(updateDoc(reference, {bookName: 'Gênesis'}));
  await assertFails(updateDoc(reference, {updatedAt: stamp}));
});
test('Bíblia rejeita nomes/IDs/campos/capítulos inválidos e duplicatas', async () => {
  const database = db('a');
  for (const chapters of [[0], [51], [1,1], ['1'], [1.5], [-1]]) {
    await assertFails(setDoc(doc(database, 'bible_progress', 'a_gênesis'), progress('a', 'Gênesis', chapters)));
  }
  await assertFails(setDoc(doc(database, 'bible_progress', 'a_inexistente'), progress('a', 'Inexistente')));
  await assertFails(setDoc(doc(database, 'bible_progress', 'wrong-id'), progress('a')));
  await assertFails(updateDoc(doc(database, 'bible_progress', 'a_gênesis'), {extra:true}));
});
test('os 66 livros aceitam último capítulo e rejeitam ultrapassar seu limite', async () => {
  const source = fs.readFileSync(path.resolve(__dirname, '../../../lib/data/bible_data.dart'), 'utf8');
  const books = [...source.matchAll(/BibleBook\(name: '([^']+)', chapters: (\d+)/g)];
  assert.equal(books.length, 66);
  for (const [, name, chapters] of books) {
    const reference = doc(db('a'), 'bible_progress', `a_${name.replaceAll(' ', '_').toLowerCase()}`);
    await assertSucceeds(setDoc(reference, progress('a', name, [Number(chapters)])));
    await assertFails(setDoc(reference, progress('a', name, [Number(chapters)+1])));
  }
});
test('coleções desconhecidas são negadas', async () => {
  await assertFails(setDoc(doc(db('a'), 'private', 'document'), {userId:'a'}));
  await assertFails(getDoc(doc(db('a'), 'private', 'document')));
});
test('vínculo não exige leitura do destinatário e muda somente partnerUid', async () => {
  await assertFails(getDoc(doc(db('a'), 'users', 'b')));
  await assertSucceeds(pair(db('a'), 'a', 'b'));
  assert.deepEqual(await state(), {a:'b', b:'a', c:null, d:null});
  await assertSucceeds(pair(db('a'), 'a', 'b', false));
  assert.deepEqual(await state(), {a:null, b:null, c:null, d:null});
});
test('vínculo/desvínculo unilateral, auto-vínculo e conta ausente são rejeitados', async () => {
  await assertFails(updateDoc(doc(db('a'), 'users', 'a'), {partnerUid:'b'}));
  await assertFails(updateDoc(doc(db('a'), 'users', 'a'), {partnerUid:'a'}));
  await assertFails(pair(db('a'), 'a', 'missing'));
  await pair(db('a'), 'a', 'b');
  await assertFails(updateDoc(doc(db('a'), 'users', 'a'), {partnerUid:null}));
  assert.deepEqual(await state(), {a:'b', b:'a', c:null, d:null});
});
test('terceiro não cria/desfaz vínculo alheio nem modifica perfil junto ao lote', async () => {
  await assertFails(pair(db('c'), 'a', 'b'));
  await pair(db('a'), 'a', 'b');
  await assertFails(pair(db('c'), 'a', 'b', false));
  await pair(db('a'), 'a', 'b', false);
  const database = db('a'); const batch = writeBatch(database);
  batch.update(doc(database, 'users', 'a'), {partnerUid:'b'});
  batch.update(doc(database, 'users', 'b'), {partnerUid:'a', name:'Nome alheio'});
  await assertFails(batch.commit());
});
test('conta já vinculada não pode ser tomada por outro usuário', async () => {
  await pair(db('a'), 'a', 'b');
  await assertFails(pair(db('c'), 'c', 'b'));
  await assertFails(pair(db('a'), 'a', 'c'));
  assert.deepEqual(await state(), {a:'b', b:'a', c:null, d:null});
});
test('duas pessoas disputando a mesma conta produzem um único vínculo recíproco', async () => {
  const results = await Promise.allSettled([pair(db('a'), 'a', 'b'), pair(db('c'), 'c', 'b')]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const links = await state(); assertReciprocal(links);
  assert.ok(['a','c'].includes(links.b));
});
test('mesma pessoa vinculando duas contas simultaneamente mantém reciprocidade', async () => {
  const results = await Promise.allSettled([pair(db('a'), 'a', 'b'), pair(db('a'), 'a', 'c')]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assertReciprocal(await state());
});
test('desvínculo antigo não afeta novo parceiro nem par antigo já refeito', async () => {
  await pair(db('a'), 'a', 'b');
  await pair(db('a'), 'a', 'b', false);
  await pair(db('a'), 'a', 'c');
  await pair(db('b'), 'b', 'd');
  await assertFails(pair(db('a'), 'a', 'b', false));
  assert.deepEqual(await state(), {a:'c', b:'d', c:'a', d:'b'});
});
test('desvincular revoga leituras/queries do ex-parceiro e preserva registros pessoais', async () => {
  await pair(db('a'), 'a', 'b');
  await pair(db('b'), 'a', 'b', false);
  for (const [group, id] of [['users','b'], ['books','b-book'], ['bible_progress','b_gênesis']]) {
    await assertFails(getDoc(doc(db('a'), group, id)));
    await assertSucceeds(getDoc(doc(db('b'), group, id)));
  }
  await assertFails(getDocs(query(collection(db('a'), 'books'), where('userId','in',['a','b']))));
  await pair(db('a'), 'a', 'c');
  await assertFails(getDoc(doc(db('c'), 'books', 'b-book')));
});
