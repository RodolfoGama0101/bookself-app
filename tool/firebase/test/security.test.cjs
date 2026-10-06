const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, runTransaction, onSnapshot, collection, query, where, getDocs, serverTimestamp, Timestamp, setLogLevel} = require('firebase/firestore');
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

const {randomBytes} = require('node:crypto');
async function issue(database, sender, code = randomBytes(16).toString('hex')) {
  const own=(await getDoc(doc(database,'users',sender))).data();
  const batch = writeBatch(database);
  batch.set(doc(database, 'partner_invites', code), {version:1, senderUid:sender, senderEpoch:own.coupleEpoch ?? 0, senderName:own.name, senderPhotoUrl:own.photoUrl ?? null,
    recipientUid:null, recipientEpoch:null, recipientName:null, recipientPhotoUrl:null, status:'pending', createdAt:serverTimestamp(), decidedAt:null});
  batch.set(doc(database, 'partner_invite_slots', sender), {code, issuedAt:serverTimestamp()});
  await batch.commit(); return code;
}
async function lookup(database, code, recipient) {
  await setDoc(doc(database,'partner_invite_lookups',recipient), {code,requestedAt:serverTimestamp()});
}
async function claim(database, code, recipient) {
  await lookup(database,code,recipient);
  const own=(await getDoc(doc(database,'users',recipient))).data();
  return updateDoc(doc(database, 'partner_invites', code), {recipientUid:recipient, recipientEpoch:own?.coupleEpoch ?? 0, recipientName:'Pessoa fictícia', recipientPhotoUrl:null});
}
async function accept(database, code, sender, recipient) {
  const raw=(await getDoc(doc(database,'partner_invites',code))).data();
  const batch=writeBatch(database);
  batch.update(doc(database,'partner_invites',code), {status:'accepted', decidedAt:serverTimestamp()});
  batch.update(doc(database,'users',sender), {partnerUid:recipient, relationshipId:code, coupleEpoch:raw.senderEpoch+1});
  batch.update(doc(database,'users',recipient), {partnerUid:sender, relationshipId:code, coupleEpoch:raw.recipientEpoch+1});
  const slot=await getDoc(doc(database, 'partner_invite_slots', recipient));
  if (slot.exists()) {
    const outgoing=await getDoc(doc(database, 'partner_invites', slot.data().code));
    if (outgoing.data().status === 'pending') batch.update(outgoing.ref, {status:'cancelled', decidedAt:serverTimestamp()});
  }
  return batch.commit();
}
async function pair(database, a, b, linking = true) {
  if (linking) {
    // Avança somente o relógio da fixture de cooldown para re-vínculos do teste.
    await env.withSecurityRulesDisabled(async context => {
      const ref=doc(context.firestore(),'partner_invite_slots',a);
      if ((await getDoc(ref)).exists()) await updateDoc(ref, {issuedAt:stamp});
    });
    const code=await issue(database,a);
    await env.withSecurityRulesDisabled(async context => {
      const ref=doc(context.firestore(),'partner_invite_lookups',b);
      if ((await getDoc(ref)).exists()) await updateDoc(ref,{requestedAt:stamp});
    });
    await claim(db(b),code,b);
    return accept(db(b),code,a,b);
  }
  const batch = writeBatch(database);
  batch.update(doc(database, 'users', a), {partnerUid:null, relationshipId:null});
  batch.update(doc(database, 'users', b), {partnerUid:null, relationshipId:null});
  return batch.commit();
}
async function publish(database, group, id) {
   const data = (await getDoc(doc(database, group, id))).data();
   delete data.isShared;
   return setDoc(doc(database, 'shared_'+group, id), data);
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
      batch.set(doc(database, 'partner_profiles', uid), {name: profile(uid).name, photoUrl: null});
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
test('parceiro recíproco lê perfil mínimo/estante/Bíblia sem ler o documento privado', async () => {
  await assertSucceeds(pair(db('a'), 'a', 'b'));
  await publish(db('b'),'books','b-book'); await publish(db('b'),'bible_progress','b_gênesis');
  for (const [group, id] of [['partner_profiles','b'], ['shared_books','b-book'], ['shared_bible_progress','b_gênesis']]) {
    await assertSucceeds(getDoc(doc(db('a'), group, id)));
    await assertFails(deleteDoc(doc(db('a'), group, id)));
  }
  await assertFails(getDoc(doc(db('a'), 'users', 'b')));
  assert.deepEqual((await getDoc(doc(db('a'), 'partner_profiles', 'b'))).data(), {name: 'Pessoa fictícia', photoUrl: null});
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
    await assertFails(getDocs(query(collection(database, group), where('userId', 'in', ['a','b']))));
    await publish(db('b'),group,group==='books'?'b-book':'b_gênesis');
    await assertSucceeds(getDocs(query(collection(database, 'shared_'+group), where('userId', '==', 'b'))));
    await assertFails(getDocs(collection(database,'shared_'+group)));
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
test('aceite não exige leitura privada do remetente e mantém vínculo recíproco', async () => {
  await assertFails(getDoc(doc(db('a'), 'users', 'b')));
  await assertSucceeds(pair(db('a'), 'a', 'b'));
  assert.deepEqual(await state(), {a:'b', b:'a', c:null, d:null});
  await assertSucceeds(pair(db('a'), 'a', 'b', false));
  assert.deepEqual(await state(), {a:null, b:null, c:null, d:null});
});
test('vínculo/desvínculo unilateral, auto-vínculo e conta ausente são rejeitados', async () => {
  await assertFails(updateDoc(doc(db('a'), 'users', 'a'), {partnerUid:'b'}));
  await assertFails(updateDoc(doc(db('a'), 'users', 'a'), {partnerUid:'a'}));
  const missingCode=await issue(db('a'),'a');
  await assertFails(claim(db('missing'),missingCode,'missing'));
  await updateDoc(doc(db('a'),'partner_invites',missingCode),{status:'cancelled',decidedAt:serverTimestamp()});
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
  for (const [group, id] of [['users','b'], ['partner_profiles','b'], ['books','b-book'], ['bible_progress','b_gênesis']]) {
    await assertFails(getDoc(doc(db('a'), group, id)));
    await assertSucceeds(getDoc(doc(db('b'), group, id)));
  }
  await assertFails(getDocs(query(collection(db('a'), 'books'), where('userId','in',['a','b']))));
  await pair(db('a'), 'a', 'c');
  await assertFails(getDoc(doc(db('c'), 'books', 'b-book')));
  await assertFails(getDoc(doc(db('c'), 'partner_profiles', 'b')));
  await assertFails(getDoc(doc(db('c'), 'users', 'a')));
  await assertSucceeds(getDoc(doc(db('c'), 'partner_profiles', 'a')));
});

test('perfil mínimo não é público nem listável e só o dono escreve', async () => {
  const unauthenticated = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauthenticated, 'partner_profiles', 'a')));
  await assertFails(getDoc(doc(db('c'), 'partner_profiles', 'a')));
  await assertFails(getDocs(collection(db('a'), 'partner_profiles')));
  await pair(db('a'), 'a', 'b');
  await assertFails(updateDoc(doc(db('b'), 'partner_profiles', 'a'), {name: 'Alteração alheia'}));
  await assertFails(deleteDoc(doc(db('a'), 'partner_profiles', 'a')));
});

test('perfil mínimo rejeita campos privados e exige apresentação do próprio perfil', async () => {
  const reference = doc(db('a'), 'partner_profiles', 'a');
  for (const patch of [{email:'a@example.com'}, {uid:'a'}, {partnerUid:'b'}, {createdAt:stamp}, {favorites:[]}, {name:'Inventado'}, {photoUrl:3}, {name:''}]) {
    await assertFails(setDoc(reference, {name: 'Pessoa fictícia', photoUrl: null, ...patch}));
  }
  await assertFails(setDoc(doc(db('missing'), 'partner_profiles', 'missing'), {name:'Sem perfil', photoUrl:null}));
  await assertSucceeds(setDoc(reference, {name: 'Pessoa fictícia', photoUrl: null}));
});

test('cadastro e nome/foto são publicados atomicamente; rejeição não deixa escrita parcial', async () => {
  const database = db('new');
  const batch = writeBatch(database);
  batch.set(doc(database, 'users', 'new'), profile('new'));
  batch.set(doc(database, 'partner_profiles', 'new'), {name: 'Pessoa fictícia', photoUrl:null});
  await assertSucceeds(batch.commit());
  const own = doc(database, 'users', 'new');
  const shared = doc(database, 'partner_profiles', 'new');
  const update = writeBatch(database);
  update.update(own, {name: 'Nome atualizado', photoUrl:'foto-ficticia'});
  update.set(shared, {name: 'Nome atualizado', photoUrl:'foto-ficticia'});
  await assertSucceeds(update.commit());
  const invalid = writeBatch(database);
  invalid.update(own, {name:'Não salvar'});
  invalid.set(shared, {name:'Não salvar', photoUrl:'foto-ficticia', email:'new@example.com'});
  await assertFails(invalid.commit());
  assert.equal((await getDoc(own)).data().name, 'Nome atualizado');
  assert.equal((await getDoc(shared)).data().name, 'Nome atualizado');
});

test('edições concorrentes de nome/foto preservam campos privados e a projeção atual', async () => {
  const database = db('a');
  const own = doc(database, 'users', 'a');
  const shared = doc(database, 'partner_profiles', 'a');
  const edit = patch => runTransaction(database, async transaction => {
    const before = (await transaction.get(own)).data();
    await transaction.get(shared);
    transaction.update(own, patch);
    transaction.update(shared, patch);
  });
  await Promise.all([edit({name:'Novo nome'}), edit({photoUrl:'nova-foto'})]);
  const current = (await getDoc(own)).data();
  assert.equal(current.name, 'Novo nome');
  assert.equal(current.photoUrl, 'nova-foto');
  assert.equal(current.email, 'a@example.com');
  assert.deepEqual((await getDoc(shared)).data(), {name:current.name, photoUrl:current.photoUrl});
});

test('perfil mínimo contaminado por campo privado é negado ao parceiro e reparável pelo dono', async () => {
  await pair(db('a'), 'a', 'b');
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'partner_profiles', 'b'), {email:'b@example.com'}));
  await assertFails(getDoc(doc(db('a'), 'partner_profiles', 'b')));
  await assertSucceeds(setDoc(doc(db('b'), 'partner_profiles', 'b'), {name:'Pessoa fictícia', photoUrl:null}));
  await assertSucceeds(getDoc(doc(db('a'), 'partner_profiles', 'b')));
});

test('perfil legado sem projeção mantém dados pessoais e não permite fallback privado', async () => {
  await env.withSecurityRulesDisabled(context => deleteDoc(doc(context.firestore(), 'partner_profiles', 'b')));
  await pair(db('a'), 'a', 'b');
  assert.equal((await assertSucceeds(getDoc(doc(db('a'), 'partner_profiles', 'b')))).exists(), false);
  await assertFails(getDoc(doc(db('a'), 'users', 'b')));
  const before = (await getDoc(doc(db('b'), 'users', 'b'))).data();
  await assertSucceeds(setDoc(doc(db('b'), 'partner_profiles', 'b'), {name:before.name, photoUrl:before.photoUrl}));
  assert.deepEqual((await getDoc(doc(db('b'), 'users', 'b'))).data(), before);
  await publish(db('b'),'books','b-book'); await publish(db('b'),'bible_progress','b_gênesis');
  await assertSucceeds(getDoc(doc(db('a'), 'shared_books', 'b-book')));
  await assertSucceeds(getDoc(doc(db('a'), 'shared_bible_progress', 'b_gênesis')));
});

test('assinatura do perfil mínimo perde autorização depois do desvínculo', async () => {
  await pair(db('a'), 'a', 'b');
  let ready;
  let revoked;
  const initial = new Promise(resolve => { ready = resolve; });
  const denied = new Promise(resolve => { revoked = resolve; });
  const unsubscribe = onSnapshot(doc(db('a'), 'partner_profiles', 'b'), snapshot => {
    if (!snapshot.metadata.fromCache) ready();
  }, error => revoked(error.code));
  let timeout;
  try {
    const deadline = new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('Assinatura não revogada')), 10000); });
    await Promise.race([initial, deadline]);
    await pair(db('b'), 'a', 'b', false);
    const owner = db('b');
    const edit = writeBatch(owner);
    edit.update(doc(owner, 'users', 'b'), {name: 'Nome após término'});
    edit.update(doc(owner, 'partner_profiles', 'b'), {name: 'Nome após término'});
    await edit.commit();
    assert.equal(await Promise.race([denied, deadline]), 'permission-denied');
  } finally {
    clearTimeout(timeout);
    unsubscribe();
  }
});

test('convite sem aceite não compartilha registros; vínculo direto por UID é negado', async () => {
  const code=await issue(db('a'),'a');
  const ownDatabase=db('a');
  const direct=writeBatch(ownDatabase);
  direct.update(doc(ownDatabase,'users','a'),{partnerUid:'b'});
  direct.update(doc(ownDatabase,'users','b'),{partnerUid:'a'});
  await assertFails(direct.commit());
  await claim(db('b'),code,'b');
  for(const group of ['users','partner_profiles','books','bible_progress']) {
    const id=group==='books'?'a-book':group==='bible_progress'?'a_gênesis':'a';
    await assertFails(getDoc(doc(db('b'),group,id)));
  }
  await assertFails(accept(db('a'),code,'a','b'));
  await assertSucceeds(accept(db('b'),code,'a','b'));
  assert.deepEqual(await state(),{a:'b',b:'a',c:null,d:null});
});

test('descoberta requer código opaco, consulta individual limitada e autenticação',async()=>{
  const code=await issue(db('a'),'a');
  const ref=doc(db('b'),'partner_invites',code);
  await assertFails(getDoc(ref));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'partner_invites',code)));
  await lookup(db('b'),code,'b');
  const invitation=(await assertSucceeds(getDoc(ref))).data();
  assert.deepEqual(Object.keys(invitation).sort(), ['version','senderUid','senderEpoch','senderName','senderPhotoUrl','recipientUid','recipientEpoch','recipientName','recipientPhotoUrl','status','createdAt','decidedAt'].sort());
  assert.equal(invitation.email,undefined);
  await assertFails(lookup(db('b'),randomBytes(16).toString('hex'),'b'));
  await assertFails(getDocs(collection(db('b'),'partner_invites')));
  await assertFails(getDoc(doc(db('c'),'partner_invite_lookups','b')));
  await assertFails(getDoc(doc(db('c'),'partner_invite_slots','a')));
  await assertFails(issue(db('c'),'c','a'));
});

test('primeira reserva fixa destinatário; auto-reserva e terceiro não decidem nem adulteram convite',async()=>{
  const code=await issue(db('a'),'a');
  await assertFails(claim(db('a'),code,'a'));
  await claim(db('b'),code,'b');
  await assertFails(claim(db('c'),code,'c'));
  await assertFails(getDoc(doc(db('c'),'partner_invites',code)));
  for(const patch of [{recipientUid:'c'},{senderUid:'c'},{senderName:'Outro'},{createdAt:serverTimestamp()},{email:'private@example.com'},{status:'accepted',decidedAt:serverTimestamp()}]) {
    await assertFails(updateDoc(doc(db('b'),'partner_invites',code),patch));
  }
  await assertFails(updateDoc(doc(db('c'),'partner_invites',code),{status:'declined',decidedAt:serverTimestamp()}));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
});

test('um convite enviado ativo por conta e intervalo de criação são exigidos no servidor',async()=>{
  const code=await issue(db('a'),'a');
  await assertFails(issue(db('a'),'a'));
  await updateDoc(doc(db('a'),'partner_invites',code),{status:'cancelled',decidedAt:serverTimestamp()});
  await assertFails(issue(db('a'),'a'));
  await assertFails(updateDoc(doc(db('a'),'partner_invite_slots','a'),{issuedAt:stamp}));
  await assertFails(deleteDoc(doc(db('a'),'partner_invite_slots','a')));
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),'partner_invite_slots','a'),{issuedAt:stamp}));
  const next=await assertSucceeds(issue(db('a'),'a'));
  assert.notEqual(next,code);
});

for(const terminal of ['declined','cancelled']) test(`${terminal} é terminal, sem acesso e sem reutilização`,async()=>{
  const code=await issue(db('a'),'a');
  await claim(db('b'),code,'b');
  const actor=terminal==='declined'?'b':'a';
  await assertSucceeds(updateDoc(doc(db(actor),'partner_invites',code),{status:terminal,decidedAt:serverTimestamp()}));
  await assertFails(accept(db('b'),code,'a','b'));
  await assertFails(updateDoc(doc(db(actor),'partner_invites',code),{status:'pending',decidedAt:null}));
  await assertFails(getDoc(doc(db('b'),'books','a-book')));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
});

test('expiração do servidor impede descoberta/reserva/aceite e não apaga registros pessoais',async()=>{
  const code=await issue(db('a'),'a');
  await claim(db('b'),code,'b');
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),'partner_invites',code),{createdAt:stamp}));
  await assertFails(accept(db('b'),code,'a','b'));
  await assertFails(claim(db('c'),code,'c'));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
  await assertSucceeds(getDoc(doc(db('a'),'books','a-book')));
});

test('aceite e cancelamento concorrentes têm uma única transição vencedora',async()=>{
  const code=await issue(db('a'),'a');await claim(db('b'),code,'b');
  const results=await Promise.allSettled([
    accept(db('b'),code,'a','b'),
    updateDoc(doc(db('a'),'partner_invites',code),{status:'cancelled',decidedAt:serverTimestamp()}),
  ]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const invite=(await getDoc(doc(db('a'),'partner_invites',code))).data();
  const links=await state();assertReciprocal(links);
  assert.equal(links.a,invite.status==='accepted'?'b':null);
});

test('dois aceites disputando a conta e respostas antigas não recriam vínculo',async()=>{
  const first=await issue(db('a'),'a');const second=await issue(db('c'),'c');
  await claim(db('b'),first,'b');
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),'partner_invite_lookups','b'),{requestedAt:stamp}));
  await claim(db('b'),second,'b');
  const results=await Promise.allSettled([accept(db('b'),first,'a','b'),accept(db('b'),second,'c','b')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const links=await state(); assertReciprocal(links);
  const sender=links.b;const consumed=sender==='a'?first:second;
  await pair(db('b'),sender,'b',false);
  await assertFails(accept(db('b'),consumed,sender,'b'));
  const losing=sender==='a'?second:first;const loser=sender==='a'?'c':'a';
  await assertFails(accept(db('b'),losing,loser,'b'));
  assert.equal((await getDoc(doc(db('b'),'books','b-book'))).exists(),true);
});

test('aceite encerra o convite enviado do destinatário na mesma operação',async()=>{
  const incoming=await issue(db('a'),'a');const outgoing=await issue(db('b'),'b');
  await claim(db('c'),outgoing,'c'); await claim(db('b'),incoming,'b');
  const ownDatabase=db('b');
  const incomplete=writeBatch(ownDatabase);
  incomplete.update(doc(ownDatabase,'partner_invites',incoming),{status:'accepted',decidedAt:serverTimestamp()});
  incomplete.update(doc(ownDatabase,'users','a'),{partnerUid:'b',relationshipId:incoming});
  incomplete.update(doc(ownDatabase,'users','b'),{partnerUid:'a',relationshipId:incoming});
  await assertFails(incomplete.commit());
  await assertSucceeds(accept(db('b'),incoming,'a','b'));
  assert.equal((await getDoc(doc(db('b'),'partner_invites',outgoing))).data().status,'cancelled');
  await pair(db('b'),'a','b',false);
  await assertFails(accept(db('c'),outgoing,'b','c'));
});

test('duas reservas simultâneas fixam somente um destinatário e não ativam vínculo',async()=>{
  const code=await issue(db('a'),'a');
  const results=await Promise.allSettled([claim(db('b'),code,'b'),claim(db('c'),code,'c')]);
  assert.equal(results.filter(result=>result.status==='fulfilled').length,1);
  const invitation=(await getDoc(doc(db('a'),'partner_invites',code))).data();
  assert.ok(['b','c'].includes(invitation.recipientUid));
  assert.equal(invitation.status,'pending');
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
  const loser=invitation.recipientUid==='b'?'c':'b';
  await assertFails(accept(db(loser),code,'a',invitation.recipientUid));
});

async function hide(database, group, id, value = false) {
  const batch = writeBatch(database);
  const ref = doc(database, group, id);
  if (group === 'bible_progress') batch.update(ref, {isShared:value,updatedAt:serverTimestamp()});
  else batch.update(ref, {isShared:value,activityAt:null});
  if (value) {
    const data = (await getDoc(ref)).data(); delete data.isShared;
    if (group === 'bible_progress') data.updatedAt = serverTimestamp(); else data.activityAt=null;
    batch.set(doc(database, 'shared_'+group, id),data);
  } else batch.delete(doc(database, 'shared_'+group, id));
  return batch.commit();
}

test('ocultar livro retira consulta, detalhes e contagens sem apagar registro pessoal', async () => {
  await pair(db('a'),'a','b'); await publish(db('a'),'books','a-book');
  await assertSucceeds(getDoc(doc(db('b'),'shared_books','a-book')));
  await assertFails(getDoc(doc(db('b'),'books','a-book')));
  await assertFails(updateDoc(doc(db('a'),'books','a-book'),{isShared:false}));
  await assertSucceeds(hide(db('a'),'books','a-book'));
  await assertFails(getDoc(doc(db('b'),'shared_books','a-book')));
  assert.equal((await getDocs(query(collection(db('b'),'shared_books'),where('userId','==','a')))).size,0);
  const own=(await getDoc(doc(db('a'),'books','a-book'))).data();
  assert.equal(own.title,'Livro fictício'); assert.equal(own.isShared,false);
  await assertFails(publish(db('a'),'books','a-book'));
  await assertSucceeds(hide(db('a'),'books','a-book',true));
  assert.equal((await getDoc(doc(db('b'),'shared_books','a-book'))).data().activityAt,null);
});

test('ocultação bíblica preserva capítulos e sobrevive ao ex e ao novo parceiro', async () => {
  await pair(db('a'),'a','b'); await publish(db('a'),'bible_progress','a_gênesis');
  await assertSucceeds(hide(db('a'),'bible_progress','a_gênesis'));
  assert.deepEqual((await getDoc(doc(db('a'),'bible_progress','a_gênesis'))).data().readChapters,[1]);
  await pair(db('a'),'a','b',false); await pair(db('a'),'a','c');
  await assertFails(getDoc(doc(db('b'),'shared_bible_progress','a_gênesis')));
  await assertFails(getDoc(doc(db('c'),'bible_progress','a_gênesis')));
  assert.equal((await getDocs(query(collection(db('c'),'shared_bible_progress'),where('userId','==','a')))).size,0);
  await assertSucceeds(hide(db('a'),'bible_progress','a_gênesis',true));
  await assertSucceeds(getDoc(doc(db('c'),'shared_bible_progress','a_gênesis')));
  await assertFails(getDoc(doc(db('b'),'shared_bible_progress','a_gênesis')));
});

test('projeção não aceita campos privados, visibilidade forjada ou edição alheia', async () => {
  await pair(db('a'),'a','b'); const own=book('a');
  await assertFails(setDoc(doc(db('a'),'shared_books','a-book'), {...own,opinion:'Privada'}));
  await assertFails(setDoc(doc(db('a'),'shared_books','a-book'), {...own,favorite:true}));
  await assertFails(setDoc(doc(db('a'),'shared_books','a-book'), {...own,title:'Forjado'}));
  await assertFails(setDoc(doc(db('c'),'shared_books','a-book'), own));
  await publish(db('a'),'books','a-book');
  await assertFails(updateDoc(doc(db('b'),'shared_books','a-book'),{title:'Alheio'}));
  await assertFails(getDoc(doc(db('c'),'shared_books','a-book')));
  await assertFails(deleteDoc(doc(db('a'),'books','a-book')));
});

test('publicação concorrente com ocultação não reexpõe o registro', async () => {
  await pair(db('a'),'a','b'); await publish(db('a'),'books','a-book');
  await Promise.allSettled([publish(db('a'),'books','a-book'),hide(db('a'),'books','a-book')]);
  assert.equal((await getDoc(doc(db('a'),'books','a-book'))).data().isShared,false);
  assert.equal((await getDocs(query(collection(db('b'),'shared_books'),where('userId','==','a')))).size,0);
});

test('desvínculo revoga projeções compartilhadas e não transfere acesso a outra relação', async () => {
  await pair(db('a'),'a','b'); await publish(db('b'),'books','b-book'); await publish(db('b'),'bible_progress','b_gênesis');
  await pair(db('a'),'a','b',false); await pair(db('a'),'a','c');
  for (const uid of ['a','c','d']) {
    await assertFails(getDoc(doc(db(uid),'shared_books','b-book')));
    await assertFails(getDoc(doc(db(uid),'shared_bible_progress','b_gênesis')));
    await assertFails(getDocs(query(collection(db(uid),'shared_books'),where('userId','==','b'))));
  }
  assert.equal((await getDoc(doc(db('b'),'books','b-book'))).exists(),true);
  assert.deepEqual((await getDoc(doc(db('b'),'bible_progress','b_gênesis'))).data().readChapters,[1]);
});

async function block(database,a,b) {
  const own=(await getDoc(doc(database,'users',a))).data();
  const batch=writeBatch(database);
  batch.set(doc(database,'partner_blocks',a,'targets',b),{name:'Pessoa fictícia',createdAt:serverTimestamp()});
  batch.update(doc(database,'users',a),{partnerUid:null,relationshipId:null,coupleEpoch:(own.coupleEpoch??0)+1});
  batch.update(doc(database,'users',b),{partnerUid:null,relationshipId:null});
  return batch.commit();
}

test('bloquear encerra vínculo, revoga conteúdo e impede convites em ambas as direções', async () => {
  await pair(db('a'),'a','b'); await publish(db('b'),'books','b-book');
  await assertSucceeds(block(db('a'),'a','b'));
  assert.equal((await state()).a,null); assert.equal((await state()).b,null);
  await assertFails(getDoc(doc(db('a'),'shared_books','b-book')));
  await assertFails(getDocs(collection(db('b'),'partner_blocks','a','targets')));
  await assertFails(deleteDoc(doc(db('b'),'partner_blocks','a','targets','b')));
  const code=await issue(db('b'),'b');
  await assertFails(claim(db('a'),code,'a'));
  await assertFails(getDoc(doc(db('a'),'partner_invites',code)));
  await assertSucceeds(deleteDoc(doc(db('a'),'partner_blocks','a','targets','b')));
  assert.equal((await state()).a,null);
});

test('bloqueio unilateral sem término e bloqueio por terceiro são negados', async () => {
  await pair(db('a'),'a','b');
  await assertFails(setDoc(doc(db('a'),'partner_blocks','a','targets','b'),{name:'Pessoa',createdAt:serverTimestamp()}));
  await assertFails(block(db('c'),'a','b'));
  assert.deepEqual(await state(),{a:'b',b:'a',c:null,d:null});
});

test('novo livro transacional publica atividade do servidor sem consulta privada alheia', async () => {
  const database=db('a');const id='new-transactional';
  await assertSucceeds(runTransaction(database,async tx=>{
    const own=doc(database,'books',id);assert.equal((await tx.get(own)).exists(),false);
    const data={...book('a'),isShared:true,activityAt:serverTimestamp()};tx.set(own,data);
    const shared={...data};delete shared.isShared;tx.set(doc(database,'shared_books',id),shared);
  }));
  assert.ok((await getDoc(doc(database,'books',id))).data().activityAt instanceof Timestamp);
});

test('campos privados legados sobrevivem à ocultação sem contaminar projeção', async () => {
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),'books','a-book'),{opinion:'Privada',favorite:true}));
  const database=db('a');
  await assertSucceeds(setDoc(doc(database,'shared_books','a-book'),book('a')));
  await assertSucceeds(hide(database,'books','a-book'));
  const data=(await getDoc(doc(database,'books','a-book'))).data();
  assert.equal(data.opinion,'Privada');assert.equal(data.favorite,true);
  await assertFails(updateDoc(doc(database,'books','a-book'),{opinion:'Alteração fora do contrato'}));
});

test('bloqueio e término concorrentes não deixam vínculo unilateral', async () => {
  await pair(db('a'),'a','b');
  await Promise.allSettled([block(db('a'),'a','b'),pair(db('b'),'a','b',false)]);
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
  assert.equal((await getDoc(doc(db('a'),'books','a-book'))).exists(),true);
});
