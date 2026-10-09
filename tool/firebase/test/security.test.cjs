const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, runTransaction, onSnapshot, collection, query, where, getDocs, serverTimestamp, Timestamp, setLogLevel} = require('firebase/firestore');
const {orderBy, documentId, startAfter, limit, getCountFromServer} = require('firebase/firestore');
const migration = require('../migration.cjs');
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

const jointSelection = {mediaType:'movie',title:'Filme fictício',subtitle:'',source:'manual',reference:null,episode:null};
test('QA-03: disputa de estado de filme, revisão de sessão e novo vínculo preservam isolamento', async () => {
  const rid = await jointRelation();
  const identity = {kind:'external',provider:'fixture_video',externalId:'fixture'};
  await assertSucceeds(mediaBatch(db('a'),'a','catalog','entry','movie',identity).commit());
  await assertSucceeds(mediaBatch(db('b'),'b','catalog','entry','movie',identity).commit());
  const own = doc(db('a'),'libraries/a/entries/entry');
  const before = (await getDoc(own)).data();
  const results = await Promise.allSettled([
    updateDoc(own,{state:{status:'watched',watchedOn:'2020-02-29'},revision:2,updatedAt:serverTimestamp()}),
    updateDoc(own,{state:{status:'watched',watchedOn:'2020-03-01'},revision:2,updatedAt:serverTimestamp()}),
  ]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await getDoc(own)).data().createdAt.toMillis(),before.createdAt.toMillis());
  const partner = doc(db('b'),'libraries/b/entries/entry');
  assert.equal((await getDoc(partner)).data().state.status,'planned');
  const selection = {...jointSelection,source:'library',reference:mediaKey('movie',identity)};
  await assertSucceeds(jointWrite(db('a'),rid,'experience',{...jointExperience(),selection}));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
  const original = (await getDoc(doc(db('a'),jointPath(rid)))).data();
  const corrected = {...original,occurredOn:'2020-03-02',revision:2,version:3,updatedAt:serverTimestamp(),
    responses:{...original.responses,a:{revision:2,decision:'confirmed',respondedAt:serverTimestamp()}}};
  await assertSucceeds(jointWrite(db('a'),rid,'experience',corrected));
  await assert.rejects(jointRespond(db('b'),'b',rid,'confirmed',2),/revision conflict/);
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed',3));
  const privateState = (await getDoc(own)).data().state;
  await pair(db('a'),'a','b',false);
  await assertFails(jointRespond(db('b'),'b',rid,'confirmed'));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'withdrawn'));
  await pair(db('a'),'a','c');
  for (const actor of [db('b'),db('c'),env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(actor,'libraries/a/entries/entry')));
    await assertFails(getDocs(collection(actor,'libraries/a/catalog')));
  }
  await assertFails(getDoc(doc(db('c'),jointPath(rid))));
  assert.deepEqual((await getDoc(own)).data().state,privateState);
  assert.equal((await getDoc(partner)).data().state.status,'planned');
});
test('MOVIE-02/03: filme pessoal, seleção mínima e sessão consentida após desvínculo',async()=>{
  const rid=await jointRelation();
  const identity={kind:'manual',ownerId:'a',manualId:'movie'};
  await assertSucceeds(mediaBatch(db('a'),'a','movie-catalog','movie-entry','movie',identity).commit());
  await assertSucceeds(mediaBatch(db('b'),'b','movie-catalog','movie-entry','movie',{...identity,ownerId:'b'}).commit());
  const own=doc(db('a'),'libraries/a/entries/movie-entry');
  await assertSucceeds(updateDoc(own,{state:{status:'watched',watchedOn:'2020-01-01'},revision:2,updatedAt:serverTimestamp()}));
  for(const uid of ['b','c']) {
    await assertFails(getDoc(doc(db(uid),'libraries/a/entries/movie-entry')));
    await assertFails(updateDoc(doc(db(uid),'libraries/a/entries/movie-entry'),{state:{status:'planned',watchedOn:null},revision:3,updatedAt:serverTimestamp()}));
  }
  const selection={...jointSelection,source:'library',reference:mediaKey('movie',identity)};
  const base=`couple_relationships/${rid}/lists/movies`;
  await assertSucceeds(setDoc(doc(db('a'),base),{schemaVersion:1,title:'Filmes para nós',authorId:'a',version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  const item={schemaVersion:1,selection,authorId:'a',version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),removed:false,removedBy:null};
  await assertSucceeds(setDoc(doc(db('a'),`${base}/items/movie`),item));
  await assertSucceeds(getDoc(doc(db('b'),`${base}/items/movie`)));
  await assertFails(setDoc(doc(db('a'),`${base}/items/private`),{...item,selection:{...selection,watchedOn:'2020-01-01'}}));
  await assertSucceeds(jointWrite(db('a'),rid,'experience',{...jointExperience(),selection}));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
  assert.equal((await getDoc(own)).data().state.status,'watched');
  assert.equal((await getDoc(doc(db('b'),'libraries/b/entries/movie-entry'))).data().state.status,'planned');
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDoc(doc(db('b'),jointPath(rid))));
  await assertSucceeds(getDoc(doc(db('b'),`${base}/items/movie`)));
  await assertFails(setDoc(doc(db('b'),`${base}/items/late`),{...item,authorId:'b'}));
  await assertFails(jointRespond(db('b'),'b',rid,'confirmed'));
  await assertFails(getDoc(doc(db('b'),'libraries/a/entries/movie-entry')));
  await pair(db('a'),'a','c');
  await assertFails(getDoc(doc(db('c'),jointPath(rid))));
  await assertFails(getDoc(doc(db('c'),`${base}/items/movie`)));
  await assertSucceeds(getDoc(own));
});
const jointPath = (rid,id='experience') => `couple_relationships/${rid}/experiences/${id}`;
async function jointRelation() {
  await pair(db('a'),'a','b');
  return (await getDoc(doc(db('a'),'users','a'))).data().relationshipId;
}
function jointExperience() {
  return {schemaVersion:1,authorId:'a',participantIds:['a','b'],selection:jointSelection,
    occurredOn:'2020-01-01',revision:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),
    responses:{a:{revision:1,decision:'confirmed',respondedAt:serverTimestamp()}}};
}
async function jointWrite(database,rid,id,data,audit=true) {
  const batch=writeBatch(database), target=jointPath(rid,id);
  batch.set(doc(database,target),data);
  if(audit) batch.set(doc(database,`${target}/history/${data.version}`),data);
  batch.set(doc(database,`couple_relationships/${rid}/activity/${id}`),jointActivity(data));
  return batch.commit();
}
async function jointRespond(database,uid,rid,decision,expected) {
  return runTransaction(database,async tx=>{
    const ref=doc(database,jointPath(rid));
    const data=(await tx.get(ref)).data();
    if(expected !== undefined && data.version!==expected) throw new Error('revision conflict');
    const next={...data,version:data.version+1,updatedAt:serverTimestamp(),responses:{...data.responses,
      [uid]:{revision:data.revision,decision,respondedAt:serverTimestamp()}}};
    tx.set(ref,next); tx.set(doc(database,`${jointPath(rid)}/history/${next.version}`),next);
    tx.set(doc(database,`couple_relationships/${rid}/activity/experience`),jointActivity(next));
  });
}
test('COUPLE-05: autoria, dupla confirmação por revisão e auditoria obrigatória',async()=>{
  const rid=await jointRelation();
  await assertFails(jointWrite(db('a'),rid,'experience',jointExperience(),false));
  await assertSucceeds(jointWrite(db('a'),rid,'experience',jointExperience()));
  await assertFails(jointRespond(db('b'),'a',rid,'confirmed'));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
  let data=(await getDoc(doc(db('a'),jointPath(rid)))).data();
  assert.equal(data.responses.b.revision,1);
  const revised={...data,version:3,revision:2,occurredOn:'2020-02-01',updatedAt:serverTimestamp(),
    responses:{...data.responses,a:{revision:2,decision:'confirmed',respondedAt:serverTimestamp()}}};
  await assertFails(jointWrite(db('b'),rid,'experience',revised));
  await assertSucceeds(jointWrite(db('a'),rid,'experience',revised));
  data=(await getDoc(doc(db('b'),jointPath(rid)))).data();
  assert.equal(data.responses.b.revision,1); assert.equal(data.revision,2);
  await assert.rejects(jointRespond(db('b'),'b',rid,'confirmed',2),/revision conflict/);
  await assertSucceeds(jointRespond(db('b'),'b',rid,'declined',3));
  assert.equal((await getDocs(collection(db('a'),`${jointPath(rid)}/history`))).size,4);
  await assertFails(updateDoc(doc(db('a'),`${jointPath(rid)}/history/1`),{occurredOn:'2020-03-01'}));
  assert.equal((await getDoc(doc(db('a'),'books','a-book'))).data().status,'Lendo');
});
test('COUPLE-05: terceiro, campos privados, concorrência e histórico após término/novo vínculo',async()=>{
  const rid=await jointRelation();
  for(const database of [db('c'),env.unauthenticatedContext().firestore()]) {
    await assertFails(jointWrite(database,rid,'experience',jointExperience()));
    await assertFails(getDocs(collection(database,`couple_relationships/${rid}/experiences`)));
  }
  await assertFails(jointWrite(db('a'),rid,'experience',{...jointExperience(),selection:{...jointSelection,favorite:true}}));
  await assertSucceeds(jointWrite(db('a'),rid,'experience',jointExperience()));
  const attempts=await Promise.allSettled([jointRespond(db('a'),'a',rid,'withdrawn',1),jointRespond(db('b'),'b',rid,'confirmed',1)]);
  assert.equal(attempts.filter(r=>r.status==='fulfilled').length,1);
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDoc(doc(db('b'),jointPath(rid))));
  await assertFails(jointRespond(db('b'),'b',rid,'confirmed'));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'withdrawn'));
  await pair(db('a'),'a','c');
  await assertFails(getDoc(doc(db('c'),jointPath(rid))));
  await assertFails(jointWrite(db('a'),rid,'new',jointExperience()));
});
test('COUPLE-06: inclusão/remoção concorrentes, origem imutável e histórico privado',async()=>{
  const rid=await jointRelation(), base=`couple_relationships/${rid}/lists/list`;
  const list={schemaVersion:1,title:'Próximos momentos',authorId:'a',version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('a'),base),list));
  const item=uid=>({schemaVersion:1,selection:jointSelection,authorId:uid,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),removed:false,removedBy:null});
  await Promise.all([assertSucceeds(setDoc(doc(db('a'),`${base}/items/one`),item('a'))),assertSucceeds(setDoc(doc(db('b'),`${base}/items/two`),item('b')))]);
  await assertFails(updateDoc(doc(db('b'),`${base}/items/one`),{authorId:'b'}));
  const remove=uid=>updateDoc(doc(db(uid),`${base}/items/one`),{removed:true,removedBy:uid,version:2,updatedAt:serverTimestamp()});
  const results=await Promise.allSettled([remove('a'),remove('b')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await getDoc(doc(db('a'),`${base}/items/one`))).data().authorId,'a');
  for(const uid of ['a','b']) await assertSucceeds(setDoc(doc(db('a'),`users/${uid}/couple_history/${rid}`),{relationshipId:rid,createdAt:serverTimestamp()}));
  await assertFails(getDocs(collection(db('c'),'users/a/couple_history')));
  await assertFails(setDoc(doc(db('a'),`${base}/items/secret`),{...item('a'),selection:{...jointSelection,personalState:'Lido'}}));
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDocs(collection(db('b'),`${base}/items`)));
  await assertFails(setDoc(doc(db('b'),`${base}/items/late`),item('b')));
  await assertFails(updateDoc(doc(db('b'),`${base}/items/two`),{removed:true,removedBy:'b',version:2,updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(db('c'),base)));
});

test('DATA-02: biblioteca privada isolada inclusive do parceiro, ex e terceiro', async()=>{
  await assertSucceeds(mediaSave(db('a'),'a','c1','e1'));
  await pair(db('a'),'a','b');
  for(const database of [db('b'),db('c'),env.unauthenticatedContext().firestore()]) {
    for(const path of [['catalog','c1'],['entries','e1'],['reference_slots',mediaKey('book',mediaIdentity)]]) {
      await assertFails(getDoc(doc(database,'libraries','a',...path)));
      await assertFails(getDocs(collection(database,'libraries','a',path[0])));
    }
    await assertFails(updateDoc(doc(database,'libraries','a','entries','e1'),{state:{status:'reading',finishedOn:null},updatedAt:serverTimestamp(),revision:2}));
    await assertFails(mediaBatch(database,'a','other','other','movie').commit());
  }
  await pair(db('a'),'a','b',false);
  await assertFails(getDoc(doc(db('b'),'libraries','a','entries','e1')));
  await assertSucceeds(getDocs(collection(db('a'),'libraries','a','entries')));
});

test('DATA-04: paginação privada ordenada por data/ID e contagens completas por mídia',async()=>{
  const database=db('a'), batch=writeBatch(database);
  for(let i=0;i<7;i++) {
    const type=i===6?'movie':'book',identity={...mediaIdentity,externalId:`work-${i}`};
    const values=mediaDocuments('a',`c${i}`,type,identity);
    batch.set(doc(database,'libraries','a','catalog',`c${i}`),values.catalog);
    batch.set(doc(database,'libraries','a','entries',`e${i}`),values.entry);
    batch.set(doc(database,'libraries','a','reference_slots',values.catalog.catalogKey),{schemaVersion:1,catalogId:`c${i}`,entryId:`e${i}`});
  }
  await assertSucceeds(batch.commit());
  const entries=collection(database,'libraries','a','entries');
  const base=query(entries,orderBy('createdAt','desc'),orderBy(documentId(),'desc'));
  const first=await getDocs(query(base,limit(3)));
  assert.deepEqual(first.docs.map(d=>d.id),['e6','e5','e4']);
  const last=first.docs[1];
  const next=await getDocs(query(base,startAfter(last.data().createdAt,last.id),limit(3)));
  assert.deepEqual(next.docs.map(d=>d.id),['e4','e3','e2']);
  assert.equal((await getCountFromServer(query(entries,where('mediaType','==','book'),where('state.status','==','planned')))).data().count,6);
  for(const unauthorized of [db('b'),db('c'),env.unauthenticatedContext().firestore()]) {
    const target=collection(unauthorized,'libraries','a','entries');
    await assertFails(getDocs(query(target,orderBy('createdAt','desc'),orderBy(documentId(),'desc'),limit(3))));
    await assertFails(getCountFromServer(target));
  }
});

test('DATA-04: feed limitado e métricas do parceiro são revogados após término',async()=>{
  await pair(db('a'),'a','b');
  const current=Timestamp.now();
  await env.withSecurityRulesDisabled(async context=>{
    const database=context.firestore(), batch=writeBatch(database);
    for(let i=0;i<5;i++) {
      const data={...book('a'),status:'Lido',finishedDate:stamp,activityAt:current};
      batch.set(doc(database,'books',`page-${i}`),data);
      batch.set(doc(database,'shared_books',`page-${i}`),data);
    }
    await batch.commit();
  });
  const target=collection(db('b'),'shared_books');
  const feed=query(target,where('userId','==','a'),where('activityAt','>=',stamp),orderBy('activityAt','desc'),orderBy(documentId(),'desc'));
  const first=await assertSucceeds(getDocs(query(feed,limit(3))));
  assert.equal(first.size,3);
  const last=first.docs[1];
  assert.equal((await getDocs(query(feed,startAfter(last.data().activityAt,last.id),limit(3)))).size,3);
  const metric=query(target,where('userId','==','a'),where('status','==','Lido'),where('finishedDate','>=',stamp),where('finishedDate','<',current));
  assert.equal((await assertSucceeds(getCountFromServer(metric))).data().count,5);
  await assertFails(getDocs(query(collection(db('c'),'shared_books'),where('userId','==','a'),limit(3))));
  await pair(db('a'),'a','b',false);
  await assertFails(getDocs(query(feed,startAfter(last.data().activityAt,last.id),limit(3))));
  await assertFails(getCountFromServer(metric));
});

test('DATA-03: área de ensaio preserva legado e nega clientes antigo, parceiro e terceiro',async()=>{
  await pair(db('a'),'a','b');
  await env.withSecurityRulesDisabled(async context=>{
    const database=context.firestore(), sources={};
    for(const name of ['users','books','bible_progress','partner_invites','shared_books']) {
      for(const row of (await getDocs(collection(database,name))).docs) sources[`${name}/${row.id}`]=row.data();
    }
    const encode=value=>value instanceof Timestamp?{$timestamp:[value.seconds,value.nanoseconds]}:
      Array.isArray(value)?value.map(encode):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)])):value;
    const snapshot=encode(sources),{saved,prepared}=migration.rehearse(snapshot);
    const batch=writeBatch(database);
    for(const [path,data] of Object.entries(prepared.imports)) batch.set(doc(database,path),data);
    await batch.commit();
    for(const [path,data] of Object.entries(sources)) {
      assert.deepEqual((await getDoc(doc(database,path))).data(),data);
    }
    const current={...snapshot};
    for(const row of (await getDocs(collection(database,'migration_imports'))).docs) current[`migration_imports/${row.id}`]=row.data();
    assert.deepEqual(migration.rollback(saved,prepared,current),snapshot);
    for(const client of [db('a'),db('b'),db('c'),env.unauthenticatedContext().firestore()]) {
      const path=Object.keys(prepared.imports)[0];
      await assertFails(getDoc(doc(client,path)));
      await assertFails(getDocs(collection(client,'migration_imports')));
      await assertFails(setDoc(doc(client,path),prepared.imports[path]));
    }
    const remove=writeBatch(database);
    for(const path of Object.keys(prepared.imports)) remove.delete(doc(database,path));
    await remove.commit();
    assert.equal((await getDocs(collection(database,'migration_imports'))).size,0);
  });
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDoc(doc(db('a'),'books','a-book')));
  await assertFails(getDoc(doc(db('b'),'shared_books','a-book')));
});

test('DATA-02: mesma obra em duas contas mantém estado e datas independentes', async()=>{
  await assertSucceeds(mediaSave(db('a'),'a','c1','e1'));
  await assertSucceeds(mediaSave(db('b'),'b','c2','e2'));
  const original=(await getDoc(doc(db('a'),'libraries','a','entries','e1'))).data();
  await assertSucceeds(updateDoc(doc(db('a'),'libraries','a','entries','e1'),{
    state:{status:'completed',finishedOn:'2026-10-08'},updatedAt:serverTimestamp(),revision:2}));
  assert.equal((await getDoc(doc(db('b'),'libraries','b','entries','e2'))).data().state.status,'planned');
  assert((await getDoc(doc(db('a'),'libraries','a','entries','e1'))).data().createdAt.isEqual(original.createdAt));
  assert.equal(await mediaSave(db('a'),'a','retry','retry'),'e1');
  assert.equal((await getDoc(doc(db('a'),'libraries','a','entries','e1'))).data().revision,2);
});

test('DATA-02: concorrência resolve um slot, catálogo e entrada', async()=>{
  const [first,second]=await Promise.all([mediaSave(db('a'),'a','c1','e1'),mediaSave(db('a'),'a','c2','e2')]);
  assert.equal(first,second);
  for(const path of ['catalog','entries','reference_slots']) {
    assert.equal((await getDocs(collection(db('a'),'libraries','a',path))).size,1);
  }
  const database=db('a'), ref=doc(database,'libraries','a','entries',first);
  const change=status=>runTransaction(database,async tx=>{
    const saved=(await tx.get(ref)).data();
    if(saved.revision!==1) throw new Error('revision-conflict');
    tx.update(ref,{state:{status,finishedOn:null},revision:2,updatedAt:serverTimestamp()});
  });
  const results=await Promise.allSettled([change('reading'),change('completed')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await getDoc(ref)).data().revision,2);
});

test('DATA-02: cinco mídias, fornecedores, edições e manuais sem colisão', async()=>{
  let counter=0;
  for(const type of ['book','movie','series','track','album']) {
    for(const identity of [mediaIdentity,{...mediaIdentity,provider:'example_video'},
      {...mediaIdentity,externalId:'edition'}, {kind:'manual',ownerId:'a',manualId:`m-${type}`}]) {
      const id=String(++counter);
      await assertSucceeds(mediaBatch(db('a'),'a',`c${id}`,`e${id}`,type,identity).commit());
    }
  }
  assert.equal((await getDocs(collection(db('a'),'libraries','a','entries'))).size,20);
  await assertSucceeds(updateDoc(doc(db('a'),'libraries','a','entries','e13'),{favorite:true,revision:2,updatedAt:serverTimestamp()}));
  await assertFails(getDocs(collection(db('b'),'libraries','a','listens')));
});

test('DATA-02: versões, autoria, referência atômica e campos incompatíveis são rejeitados', async()=>{
  for(const changes of [
    {catalog:{schemaVersion:2}}, {entry:{schemaVersion:2}}, {slot:{schemaVersion:2}},
    {catalog:{ownerId:'b'}}, {entry:{ownerId:'b'}}, {slot:{catalogId:'absent'}},
    {entry:{catalogId:'absent'}}, {entry:{mediaType:'movie'}}, {entry:{isShared:true}},
    {entry:{favorite:true}}, {entry:{legacyRef:{id:'legacy'}}}, {entry:{privateExtra:'secret'}},
    {entry:{createdAt:stamp}}, {entry:{revision:2}}, {entry:{state:{status:'planned',finishedOn:'2020-01-01'}}},
    {catalog:{metadata:{title:'Obra',authors:[],unknown:'secret'}}},
    {catalog:{identity:{kind:'manual',ownerId:'b',manualId:'m'}}},
  ]) {
    await assertFails(mediaBatch(db('a'),'a','c1','e1','book',mediaIdentity,changes).commit());
  }
  await assertFails(setDoc(doc(db('a'),'libraries','a','catalog','c1'),mediaDocuments('a','c1').catalog));
  await assertFails(setDoc(doc(db('a'),'libraries','a','entries','e1'),mediaDocuments('a','c1').entry));
  await assertFails(setDoc(doc(db('a'),'libraries','a','reference_slots',mediaKey('book',mediaIdentity)),{schemaVersion:1,catalogId:'c1',entryId:'e1'}));
  assert.equal((await getDocs(collection(db('a'),'libraries','a','entries'))).size,0);
});

test('DATA-02: imutabilidade, revisão e datas/estados impedem perda de autoria', async()=>{
  await mediaSave(db('a'),'a','c1','e1');
  const ref=doc(db('a'),'libraries','a','entries','e1');
  for(const fields of [{ownerId:'b'}, {catalogId:'other'}, {createdAt:stamp}, {schemaVersion:2},
    {revision:1}, {isShared:true}, {state:{status:'Lido'}}, {favorite:true},
    {state:{status:'planned',finishedOn:'2020-01-01'}}, {state:{status:'completed',finishedOn:'2020-13-01'}}]) {
    await assertFails(updateDoc(ref,{revision:2,updatedAt:serverTimestamp(),...fields}));
  }
  await assertSucceeds(updateDoc(ref,{state:{status:'completed',finishedOn:null},revision:2,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{state:{status:'reading',finishedOn:null},revision:2,updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(ref));
  await assertFails(updateDoc(doc(db('a'),'libraries','a','catalog','c1'),{metadata:{title:'Other',authors:[]}}));
  await assertFails(deleteDoc(doc(db('a'),'libraries','a','reference_slots',mediaKey('book',mediaIdentity))));
  await assertFails(mediaBatch(db('a'),'a','c2','e2').commit());
});

// Contraparte de persistência do repositório DATA-02, somente dados fictícios.
const mediaKey = (type, identity) => Buffer.from(JSON.stringify(identity.kind === 'manual'
  ? [1,type,'manual',identity.ownerId,identity.manualId]
  : [1,type,'external',identity.provider,identity.externalId])).toString('base64url');
const mediaIdentity = {kind:'external', provider:'google_books', externalId:'work'};
const mediaInitial = type => type === 'book' ? {status:'planned',finishedOn:null}
  : type === 'movie' ? {status:'planned',watchedOn:null}
  : type === 'series' ? {status:'in_progress'} : null;
function mediaDocuments(owner, catalogId, type='book', identity=mediaIdentity) {
  return {
    catalog:{schemaVersion:1,ownerId:owner,mediaType:type,identity,catalogKey:mediaKey(type,identity),fetchedAt:null,
      metadata:{title:'Obra fictícia',coverUrl:null,...(type==='book'?{authors:[],publishedDate:null}
        : type==='track'?{artists:['Artista'],albumTitle:null,version:null,durationMs:null}
        : type==='album'?{artists:['Artista'],releaseYear:null,edition:null}
        : type==='series'?{releaseYear:null,productionStatus:null}:{releaseYear:null})}},
    entry:{schemaVersion:1,ownerId:owner,catalogId,mediaType:type,state:mediaInitial(type),favorite:false,
      isShared:false,legacyRef:null,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),revision:1},
  };
}
function mediaBatch(database, owner, catalogId, entryId, type='book', identity=mediaIdentity, changes={}) {
  const data=mediaDocuments(owner,catalogId,type,identity), batch=writeBatch(database);
  batch.set(doc(database,'libraries',owner,'catalog',catalogId),{...data.catalog,...changes.catalog});
  batch.set(doc(database,'libraries',owner,'entries',entryId),{...data.entry,...changes.entry});
  batch.set(doc(database,'libraries',owner,'reference_slots',data.catalog.catalogKey),{schemaVersion:1,catalogId,entryId,...changes.slot});
  return batch;
}
async function mediaSave(database, owner, catalogId, entryId) {
  const data=mediaDocuments(owner,catalogId), slot=doc(database,'libraries',owner,'reference_slots',data.catalog.catalogKey);
  return runTransaction(database,async tx=>{
    const existing=await tx.get(slot);
    if(existing.exists()) {
      const saved=await tx.get(doc(database,'libraries',owner,'entries',existing.data().entryId));
      const source=await tx.get(doc(database,'libraries',owner,'catalog',existing.data().catalogId));
      assert.equal(source.data().catalogKey,data.catalog.catalogKey);
      assert.equal(saved.data().catalogId,source.id);
      return saved.id;
    }
    const catalog=doc(database,'libraries',owner,'catalog',catalogId), entry=doc(database,'libraries',owner,'entries',entryId);
    assert.equal((await tx.get(catalog)).exists(),false);
    assert.equal((await tx.get(entry)).exists(),false);
    tx.set(catalog,data.catalog);tx.set(entry,data.entry);tx.set(slot,{schemaVersion:1,catalogId,entryId});
    return entryId;
  });
}

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

async function remember(database, code) {
  const invitation=(await getDoc(doc(database,'partner_invites',code))).data();
  const batch=writeBatch(database);
  batch.set(doc(database,'partner_contacts',invitation.senderUid,'targets',invitation.recipientUid),{name:invitation.recipientName,invitationCode:code});
  batch.set(doc(database,'partner_contacts',invitation.recipientUid,'targets',invitation.senderUid),{name:invitation.senderName,invitationCode:code});
  return batch.commit();
}
async function blockKnown(database, uid, other) {
  return runTransaction(database,async tx=>{
    const ownRef=doc(database,'users',uid);
    const contactRef=doc(database,'partner_contacts',uid,'targets',other);
    const blockRef=doc(database,'partner_blocks',uid,'targets',other);
    const own=(await tx.get(ownRef)).data();
    const contact=(await tx.get(contactRef)).data();
    if ((await tx.get(blockRef)).exists()) return;
    tx.set(blockRef,{name:contact?.name ?? 'Forjado',createdAt:serverTimestamp()});
    tx.update(ownRef,{coupleEpoch:(own.coupleEpoch??0)+1,lastBlockedUid:other});
  });
}
test('contatos de convite reservado são privados e não autorizam perfil ou biblioteca',async()=>{
  const code=await issue(db('a'),'a');await claim(db('b'),code,'b');
  await assertSucceeds(remember(db('b'),code));
  assert.equal((await getDocs(collection(db('a'),'partner_contacts','a','targets'))).size,1);
  await assertFails(getDocs(collection(db('c'),'partner_contacts','a','targets')));
  await assertFails(remember(db('c'),code));
  await assertFails(setDoc(doc(db('a'),'partner_contacts','a','targets','c'),{name:'Pessoa fictícia',invitationCode:code}));
  await assertFails(setDoc(doc(db('a'),'partner_contacts','a','targets','b'),{name:'Forjado',invitationCode:code}));
  await assertFails(getDoc(doc(db('b'),'users','a')));
  await assertFails(getDoc(doc(db('b'),'books','a-book')));
});
test('código sem reserva, dados extras e contato criado por terceiro são negados',async()=>{
  const code=await issue(db('a'),'a');
  await assertFails(setDoc(doc(db('a'),'partner_contacts','a','targets','b'),{name:'Pessoa fictícia',invitationCode:code}));
  await claim(db('b'),code,'b');await remember(db('b'),code);
  await assertFails(updateDoc(doc(db('b'),'partner_contacts','b','targets','a'),{email:'private@example.com'}));
  await assertFails(blockKnown(db('c'),'a','b'));
  await assertFails(blockKnown(db('a'),'a','c'));
  await assertFails(updateDoc(doc(db('a'),'users','a'),{coupleEpoch:1,lastBlockedUid:'b'}));
});
test('após recusa ambos bloqueiam independentemente e desbloqueio não revive convite',async()=>{
  const code=await issue(db('a'),'a');await claim(db('b'),code,'b');await remember(db('b'),code);
  await updateDoc(doc(db('b'),'partner_invites',code),{status:'declined',decidedAt:serverTimestamp()});
  await assertSucceeds(blockKnown(db('a'),'a','b'));
  await assertSucceeds(blockKnown(db('b'),'b','a'));
  await assertSucceeds(deleteDoc(doc(db('a'),'partner_blocks','a','targets','b')));
  await assertFails(deleteDoc(doc(db('a'),'partner_blocks','b','targets','a')));
  await assertFails(accept(db('b'),code,'a','b'));
  const next=await issue(db('b'),'b');
  await assertFails(claim(db('a'),next,'a'));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
});
test('bloquear após término preserva novo parceiro e registros pessoais',async()=>{
  await pair(db('a'),'a','b');
  const code=(await getDoc(doc(db('a'),'partner_invite_slots','a'))).data().code;
  await remember(db('a'),code);await pair(db('a'),'a','b',false);
  await pair(db('a'),'a','c');
  await assertSucceeds(blockKnown(db('a'),'a','b'));
  assert.deepEqual(await state(),{a:'c',b:null,c:'a',d:null});
  assert.equal((await getDoc(doc(db('a'),'books','a-book'))).data().title,'Livro fictício');
  await assertFails(getDoc(doc(db('b'),'shared_books','a-book')));
});
test('contatos legados podem ser registrados junto ao término sem leitura privada alheia',async()=>{
  await env.withSecurityRulesDisabled(async context=>{
    await updateDoc(doc(context.firestore(),'users','a'),{partnerUid:'b'});
    await updateDoc(doc(context.firestore(),'users','b'),{partnerUid:'a'});
  });
  const database=db('b');const batch=writeBatch(database);
  for (const [uid,other] of [['a','b'],['b','a']]) {
    batch.set(doc(database,'partner_contacts',uid,'targets',other),{name:'Pessoa fictícia',invitationCode:null});
    batch.update(doc(database,'users',uid),{partnerUid:null,relationshipId:null});
  }
  await assertSucceeds(batch.commit());
  await assertSucceeds(blockKnown(db('a'),'a','b'));
});
test('bloqueio e aceite simultâneos não deixam relação ativa com pessoa bloqueada',async()=>{
  const code=await issue(db('a'),'a');await claim(db('b'),code,'b');await remember(db('b'),code);
  await Promise.allSettled([blockKnown(db('a'),'a','b'),accept(db('b'),code,'a','b')]);
  const links=await state();assertReciprocal(links);
  const blocked=(await getDoc(doc(db('a'),'partner_blocks','a','targets','b'))).exists();
  assert.equal(blocked,links.a===null);
});
test('desbloquear não permite aceite de convites pendentes anteriores',async()=>{
  const code=await issue(db('a'),'a');await claim(db('b'),code,'b');await remember(db('b'),code);
  await blockKnown(db('b'),'b','a');
  await deleteDoc(doc(db('b'),'partner_blocks','b','targets','a'));
  await assertFails(accept(db('b'),code,'a','b'));
  await assertFails(updateDoc(doc(db('a'),'partner_invites',code),{recipientEpoch:1}));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
});
test('reserva e contatos dos dois participantes podem ser gravados atomicamente',async()=>{
  const code=await issue(db('a'),'a');await lookup(db('b'),code,'b');
  const database=db('b');
  await assertSucceeds(runTransaction(database,async tx=>{
    const own=(await tx.get(doc(database,'users','b'))).data();
    const ref=doc(database,'partner_invites',code);
    const invitation=(await tx.get(ref)).data();
    tx.update(ref,{recipientUid:'b',recipientEpoch:own.coupleEpoch??0,recipientName:own.name,recipientPhotoUrl:null});
    tx.set(doc(database,'partner_contacts','a','targets','b'),{name:own.name,invitationCode:code});
    tx.set(doc(database,'partner_contacts','b','targets','a'),{name:invitation.senderName,invitationCode:code});
  }));
  await assertSucceeds(blockKnown(db('b'),'b','a'));
});
test('bloqueio ativo registra contatos junto à revogação sem ler perfil privado do parceiro',async()=>{
  await pair(db('a'),'a','b');const database=db('a');
  await assertSucceeds(runTransaction(database,async tx=>{
    const own=(await tx.get(doc(database,'users','a'))).data();
    const a=(await tx.get(doc(database,'partner_profiles','a'))).data();
    const b=(await tx.get(doc(database,'partner_profiles','b'))).data();
    tx.set(doc(database,'partner_contacts','a','targets','b'),{name:b.name,invitationCode:null});
    tx.set(doc(database,'partner_contacts','b','targets','a'),{name:a.name,invitationCode:null});
    tx.set(doc(database,'partner_blocks','a','targets','b'),{name:b.name,createdAt:serverTimestamp()});
    tx.update(doc(database,'users','a'),{partnerUid:null,relationshipId:null,coupleEpoch:(own.coupleEpoch??0)+1});
    tx.update(doc(database,'users','b'),{partnerUid:null,relationshipId:null});
  }));
  await assertSucceeds(blockKnown(db('b'),'b','a'));
  assert.deepEqual(await state(),{a:null,b:null,c:null,d:null});
});
test('término conserva contato mínimo mesmo com apresentação do parceiro contaminada',async()=>{
  await pair(db('a'),'a','b');
  await env.withSecurityRulesDisabled(context=>updateDoc(doc(context.firestore(),'partner_profiles','b'),{email:'private@example.com'}));
  await assertFails(getDoc(doc(db('a'),'partner_profiles','b')));
  const database=db('a');
  await assertSucceeds(runTransaction(database,async tx=>{
    const own=(await tx.get(doc(database,'users','a'))).data();
    const contact=(await tx.get(doc(database,'partner_contacts','a','targets','b'))).data();
    tx.set(doc(database,'partner_contacts','a','targets','b'),{name:contact?.name??'Pessoa conhecida',invitationCode:null});
    tx.set(doc(database,'partner_contacts','b','targets','a'),{name:own.name,invitationCode:null});
    tx.update(doc(database,'users','a'),{partnerUid:null,relationshipId:null});
    tx.update(doc(database,'users','b'),{partnerUid:null,relationshipId:null});
  }));
  await assertSucceeds(blockKnown(db('a'),'a','b'));
});

function saveActivity(database, id, status, {createOnly=false, external=null}={}) {
  const own=doc(database,'books',id), event=doc(collection(own,'activity'));
  return runTransaction(database,async tx=>{
    const snapshot=await tx.get(own), current=snapshot.exists()?snapshot.data():null;
    if(createOnly && current) return id;
    const data={...(current||book('a')),status,createdAt:current?current.createdAt??null:serverTimestamp(),updatedAt:serverTimestamp()};
    if(external) data.googleBooksId=external;
    const action=current?'status_changed':'added';
    Object.assign(data,{activityAt:serverTimestamp(),latestActivityAt:serverTimestamp(),activityEventId:event.id,activityStatus:status,activityAction:action});
    tx.set(own,data);
    tx.set(event,{userId:'a',bookId:id,action,beforeStatus:current?.status??null,status,occurredAt:serverTimestamp()});
    const shared={...data}; for(const key of ['isShared','createdAt','updatedAt','latestActivityAt','activityEventId']) delete shared[key];
    tx.set(doc(database,'shared_books',id),shared);
    return id;
  }).catch(async error=>{
    if(createOnly) {
      const existing=await getDoc(own);
      if(existing.exists() && existing.data().userId==='a' && existing.data().googleBooksId===external) return id;
    }
    throw error;
  });
}

test('DATA-06: atividades atômicas/imutáveis e inclusão preservada, sem histórico forjado',async()=>{
  const database=db('a'),id='history';
  await assertSucceeds(saveActivity(database,id,'Lendo'));
  const initial=(await getDoc(doc(database,'books',id))).data();
  await assertSucceeds(saveActivity(database,id,'Quero Ler'));
  const current=(await getDoc(doc(database,'books',id))).data();
  assert.deepEqual(current.addedAt,initial.addedAt);
  assert.deepEqual(current.createdAt,initial.createdAt);
  const history=await getDocs(collection(database,'books',id,'activity'));
  assert.equal(history.size,2);
  for(const row of history.docs) {
    await assertFails(updateDoc(row.ref,{status:'Lido'}));
    await assertFails(deleteDoc(row.ref));
    for(const unauthorized of [db('b'),db('c'),env.unauthenticatedContext().firestore()])
      await assertFails(getDoc(doc(unauthorized,'books',id,'activity',row.id)));
  }
  await assertFails(updateDoc(doc(database,'books',id),{addedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(database,'books',id),{createdAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(database,'books',id),{status:'Lendo'}));
  await assertFails(setDoc(doc(database,'books',id,'activity','forged'),{userId:'a',bookId:id,action:'status_changed',beforeStatus:'Lendo',status:'Lido',occurredAt:serverTimestamp()}));
  for(const unauthorized of [db('b'),db('c')])
    await assertFails(getDocs(collection(unauthorized,'books',id,'activity')));
});

test('BOOK-01: concorrência na referência canônica conserva uma inclusão e seu progresso',async()=>{
  const database=db('a'),id='catalog_'+Buffer.from(JSON.stringify([1,'a','book','google_books','volume'])).toString('base64url');
  await Promise.all([saveActivity(database,id,'Lendo',{createOnly:true,external:'volume'}),saveActivity(database,id,'Quero Ler',{createOnly:true,external:'volume'})]);
  const initial=(await getDoc(doc(database,'books',id))).data();
  await assertSucceeds(saveActivity(database,id,'Lido'));
  await assertSucceeds(saveActivity(database,id,'Quero Ler',{createOnly:true,external:'volume'}));
  assert.equal((await getDoc(doc(database,'books',id))).data().status,'Lido');
  assert.equal((await getDocs(query(collection(database,'books'),where('userId','==','a'),where('googleBooksId','==','volume')))).size,1);
  assert.equal((await getDocs(collection(database,'books',id,'activity'))).size,2);
  assert.ok(initial.createdAt instanceof Timestamp);
});

test('DATA-06/BOOK-02: metadados, ocultação e término não alteram histórico nem expõem eventos privados',async()=>{
  const database=db('a'), id='history';
  await pair(database,'a','b');
  await saveActivity(database,id,'Lendo');
  const old=(await getDoc(doc(database,'books',id))).data();
  const batch=writeBatch(database), metadata={...old,title:'Título corrigido',updatedAt:serverTimestamp()};
  batch.set(doc(database,'books',id),metadata);
  const shared={...metadata}; for(const key of ['isShared','createdAt','updatedAt','latestActivityAt','activityEventId']) delete shared[key];
  batch.set(doc(database,'shared_books',id),shared);
  await assertSucceeds(batch.commit());
  assert.equal((await getDocs(collection(database,'books',id,'activity'))).size,1);
  await assertSucceeds(getDoc(doc(db('b'),'shared_books',id)));
  const hidden=writeBatch(database); hidden.update(doc(database,'books',id),{isShared:false,activityAt:null}); hidden.delete(doc(database,'shared_books',id));
  await assertSucceeds(hidden.commit());
  assert.equal((await getDocs(collection(database,'books',id,'activity'))).size,1);
  await assertFails(getDoc(doc(db('b'),'books',id,'activity',old.activityEventId)));
  await pair(database,'a','b',false);
  await assertFails(getDoc(doc(db('b'),'books',id,'activity',old.activityEventId)));
  assert.deepEqual((await getDoc(doc(database,'books',id))).data().latestActivityAt,old.latestActivityAt);
});

const listenData = (entryId='music', listenedOn='2020-02-29') => ({schemaVersion:1,ownerId:'a',entryId,listenedOn,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),revision:1});
test('MUSIC-02: escutas são privadas e imutáveis, inclusive após término', async () => {
  const rid=await jointRelation();
  await mediaBatch(db('a'),'a','music','music','track').commit();
  const own=doc(db('a'),'libraries/a/listens/listen');
  await assertSucceeds(setDoc(own,listenData()));
  await assertSucceeds(getDoc(own));
  for(const uid of ['b','c']) {
    await assertFails(getDoc(doc(db(uid),'libraries/a/listens/listen')));
    await assertFails(getDocs(collection(db(uid),'libraries/a/listens')));
    await assertFails(setDoc(doc(db(uid),'libraries/a/listens/forged'),listenData()));
  }
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'libraries/a/listens/listen')));
  await assertFails(updateDoc(own,{listenedOn:'2020-03-01'}));
  await assertFails(deleteDoc(own));
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDoc(own));
  await assertFails(getDoc(doc(db('b'),'libraries/a/listens/listen')));
});
test('MUSIC-02: data civil, referência e campos adulterados são recusados', async () => {
  await mediaBatch(db('a'),'a','music','music','album').commit();
  await mediaBatch(db('a'),'a','movie','movie','movie').commit();
  let i=0;
  for(const change of [
    {listenedOn:'2020-02-31'}, {listenedOn:'2021-02-29'}, {listenedOn:'9999-01-01'},
    {listenedOn:'0000-01-01'}, {listenedOn:null}, {entryId:'missing'}, {entryId:'movie'},
    {ownerId:'b'}, {revision:2}, {schemaVersion:2}, {favorite:true}, {createdAt:stamp},
  ]) await assertFails(setDoc(doc(db('a'),'libraries/a/listens/bad'+i++),{...listenData(),...change}));
});
test('MUSIC-02: retry concorrente gera uma escuta, nova intenção repete a data', async () => {
  await mediaBatch(db('a'),'a','music','music','album').commit();
  const database=db('a'), ref=doc(database,'libraries/a/listens/same');
  const save=()=>runTransaction(database,async tx=>{if(!(await tx.get(ref)).exists())tx.set(ref,listenData());});
  await Promise.all([save(),save()]);
  await assertSucceeds(setDoc(doc(db('a'),'libraries/a/listens/other'),listenData()));
  const rows=await getDocs(query(collection(db('a'),'libraries/a/listens'),where('entryId','==','music'),orderBy('createdAt','desc'),orderBy(documentId(),'desc'),limit(21)));
  assert.equal(rows.size,2);
  assert.equal((await getDoc(doc(db('a'),'libraries/a/entries/music'))).data().revision,1);
});
test('MUSIC-02: disputa de favorito não sobrescreve outra sessão nem cria escutas', async () => {
  await mediaBatch(db('a'),'a','music','music','track').commit();
  const own=doc(db('a'),'libraries/a/entries/music');
  const results=await Promise.allSettled([1,2].map(()=>updateDoc(own,{favorite:true,revision:2,updatedAt:serverTimestamp()})));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal((await getDocs(collection(db('a'),'libraries/a/listens'))).size,0);
  await assertFails(updateDoc(doc(db('b'),'libraries/a/entries/music'),{favorite:false,revision:3,updatedAt:serverTimestamp()}));
});

for (const type of ['track','album']) test('MUSIC-03: ' + type + ' compartilha seleção mínima sem favorito/escuta e preserva histórico', async () => {
  const rid=await jointRelation();
  const identity={kind:'external',provider:'fixture_music',externalId:'record'};
  for(const uid of ['a','b']) await mediaBatch(db(uid),uid,'music','music',type,identity).commit();
  const own=doc(db('a'),'libraries/a/entries/music');
  await updateDoc(own,{favorite:true,revision:2,updatedAt:serverTimestamp()});
  await setDoc(doc(db('a'),'libraries/a/listens/own'),listenData());
  const selection={mediaType:type,title:'Obra',subtitle:'Artista',source:'library',reference:mediaKey(type,identity),episode:null};
  const base='couple_relationships/'+rid+'/lists/music';
  await assertSucceeds(setDoc(doc(db('a'),base),{schemaVersion:1,title:'Descobertas musicais',authorId:'a',version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  const item={schemaVersion:1,selection,authorId:'a',version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),removed:false,removedBy:null};
  await assertSucceeds(setDoc(doc(db('a'),base+'/items/a'),item));
  await assertSucceeds(setDoc(doc(db('b'),base+'/items/b'),{...item,authorId:'b'}));
  await assertSucceeds(getDoc(doc(db('b'),base+'/items/a')));
  for(const privateField of ['favorite','listenedOn']) await assertFails(setDoc(doc(db('a'),base+'/items/bad'),{...item,selection:{...selection,[privateField]:true}}));
  await assertFails(getDoc(doc(db('c'),base+'/items/a')));
  await assertSucceeds(jointWrite(db('a'),rid,'experience',{...jointExperience(),selection}));
  assert.equal(Object.keys((await getDoc(doc(db('a'),jointPath(rid)))).data().responses).length,1);
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
  assert.equal((await getDoc(own)).data().favorite,true);
  assert.equal((await getDoc(doc(db('b'),'libraries/b/entries/music'))).data().favorite,false);
  assert.equal((await getDocs(collection(db('b'),'libraries/b/listens'))).size,0);
  await pair(db('a'),'a','b',false);
  await assertSucceeds(getDoc(doc(db('b'),base+'/items/a')));
  await assertFails(setDoc(doc(db('b'),base+'/items/late'),{...item,authorId:'b'}));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'withdrawn'));
  await pair(db('a'),'a','c');
  await assertFails(getDoc(doc(db('c'),base+'/items/a')));
  for(const uid of ['b','c']) await assertFails(getDoc(doc(db(uid),'libraries/a/listens/own')));
  await assertSucceeds(getDoc(doc(db('a'),'libraries/a/listens/own')));
});

const seriesConfig = {schemaVersion:1,complete:false,ended:false,paused:false,revision:1,updatedAt:serverTimestamp()};
const seriesEpisode = {schemaVersion:1,season:1,number:1,availableOn:null,available:true,watched:false,revision:1,updatedAt:serverTimestamp()};
test('SERIES-02: episódios privados, calendário, novos episódios e disputa por revisão', async () => {
  await mediaBatch(db('a'),'a','series','series','series').commit();
  const root='libraries/a/series/series';
  await assertSucceeds(setDoc(doc(db('a'),root),seriesConfig));
  await assertSucceeds(seriesWrite(db('a'),root,'one',seriesEpisode));
  for(const actor of [db('b'),db('c'),env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(actor,root)));
    await assertFails(getDocs(collection(actor,root+'/episodes')));
    await assertFails(setDoc(doc(actor,root+'/episodes/other'),seriesEpisode));
  }
  for(const data of [{availableOn:'2020-02-31'}, {availableOn:'9999-01-01',watched:true}, {season:-1}, {number:0}, {title:'Spoiler'}, {revision:3}]) {
    await assertFails(seriesWrite(db('a'),root,'invalid',{...seriesEpisode,...data}));
  }
  const target=doc(db('a'),root+'/episodes/one');
  const results=await Promise.allSettled([true,false].map(watched=>seriesWrite(db('a'),root,'one',{...seriesEpisode,watched,revision:2,updatedAt:serverTimestamp()})));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const old=(await getDoc(target)).data();
  await assertSucceeds(seriesWrite(db('a'),root,'new',{...seriesEpisode,number:2}));
  assert.deepEqual((await getDoc(target)).data(),old);
  await assertSucceeds(seriesWrite(db('a'),root,'one',{...seriesEpisode,watched:false,revision:3,updatedAt:serverTimestamp()}));
  assert.equal((await getDoc(target)).data().watched,false);
  await assertFails(deleteDoc(target));
  await assertFails(setDoc(doc(db('a'),'libraries/a/series/missing'),seriesConfig));
});

function seriesWrite(database, root, id, data) {
  const batch=writeBatch(database);
  batch.set(doc(database,root+'/episodes/'+id),data);
  const parts=root.split('/');
  batch.set(doc(database,'shared_series/'+parts[1]+'/entries/'+parts[3]+'/episodes/'+id),{
    schemaVersion:1, season:data.season,number:data.number,watched:data.watched,revision:data.revision,updatedAt:data.updatedAt,
  });
  return batch.commit();
}

async function seriesVisibleWrite(database, owner, visible, revision=1) {
  const batch=writeBatch(database),root='libraries/'+owner+'/series_visibility/series';
  batch.set(doc(database,root),{schemaVersion:1,visible,revision,updatedAt:serverTimestamp()});
  const projection=doc(database,'shared_series/'+owner+'/entries/series');
  if(visible) batch.set(projection,{schemaVersion:1,title:'Obra fictícia',reference:mediaKey('series',mediaIdentity),updatedAt:serverTimestamp()});
  else batch.delete(projection);
  return batch.commit();
}
test('SERIES-03: projeção mínima, ocultação concorrente e término revogam episódios',async()=>{
  await jointRelation();
  await mediaBatch(db('a'),'a','series','series','series').commit();
  await assertSucceeds(seriesVisibleWrite(db('a'),'a',true));
  await seriesWrite(db('a'),'libraries/a/series/series','one',seriesEpisode);
  const path='shared_series/a/entries/series/episodes/one';
  const data=(await assertSucceeds(getDoc(doc(db('b'),path)))).data();
  assert.deepEqual(Object.keys(data).sort(),['schemaVersion','season','number','watched','revision','updatedAt'].sort());
  for(const actor of [db('c'),env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(actor,path)));
    await assertFails(getDocs(collection(actor,'shared_series/a/entries')));
  }
  await assertFails(updateDoc(doc(db('b'),path),{watched:true}));
  await assertFails(updateDoc(doc(db('a'),'libraries/a/series/series/episodes/one'),{watched:true,revision:2,updatedAt:serverTimestamp()}));
  await Promise.all([seriesVisibleWrite(db('a'),'a',false,2),seriesWrite(db('a'),'libraries/a/series/series','one',{...seriesEpisode,watched:true,revision:2})]);
  await assertFails(getDoc(doc(db('b'),path)));
  assert.equal((await getDocs(collection(db('b'),'shared_series/a/entries'))).size,0);
  await assertFails(setDoc(doc(db('a'),'shared_series/a/entries/series'),{schemaVersion:1,title:'Obra fictícia',reference:mediaKey('series',mediaIdentity),updatedAt:serverTimestamp()}));
  await seriesVisibleWrite(db('a'),'a',true,3);
  assert.equal((await getDoc(doc(db('b'),path))).data().watched,true);
  await pair(db('a'),'a','b',false);
  await assertFails(getDoc(doc(db('b'),path)));
  await assertFails(getDocs(collection(db('b'),'shared_series/a/entries')));
  await assertSucceeds(getDoc(doc(db('a'),'libraries/a/series/series/episodes/one')));
});
test('SERIES-03: sessões confirmadas não marcam episódios pessoais e não herdam novo vínculo',async()=>{
  const rid=await jointRelation();
  for(const owner of ['a','b']) {
    await mediaBatch(db(owner),owner,'series','series','series').commit();
    await seriesWrite(db(owner),'libraries/'+owner+'/series/series','one',seriesEpisode);
  }
  const selection={...jointSelection,mediaType:'series',episode:{id:'one',season:1,number:1}};
  await jointWrite(db('a'),rid,'experience',{...jointExperience(),selection});
  await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
  for(const owner of ['a','b']) assert.equal((await getDoc(doc(db(owner),'libraries/'+owner+'/series/series/episodes/one'))).data().watched,false);
  await assertFails(jointWrite(db('a'),rid,'spoiler',{...jointExperience(),selection:{...selection,episode:{...selection.episode,title:'Spoiler'}}}));
  await pair(db('a'),'a','b',false);
  await pair(db('a'),'a','c');
  await assertFails(getDoc(doc(db('c'),jointPath(rid))));
  await assertSucceeds(getDoc(doc(db('b'),jointPath(rid))));
  await assertFails(jointRespond(db('b'),'b',rid,'confirmed'));
  await assertSucceeds(jointRespond(db('b'),'b',rid,'withdrawn'));
});

function jointActivity(data) {
 return {schemaVersion:1,mediaType:data.selection.mediaType,selection:data.selection,confirmed:data.participantIds.every(uid=>data.responses[uid]?.decision==='confirmed'&&data.responses[uid]?.revision===data.revision),
   occurredOn:data.occurredOn,revision:data.revision,sourceVersion:data.version,createdAt:data.createdAt,updatedAt:data.updatedAt};
}

test('COUPLE-08: projeção atômica, confirmação por revisão e contagem única por experiência',async()=>{
 const rid=await jointRelation(),path='couple_relationships/'+rid+'/activity/experience';
 await jointWrite(db('a'),rid,'experience',jointExperience());
 assert.equal((await getDoc(doc(db('a'),path))).data().confirmed,false);
 await assertFails(updateDoc(doc(db('a'),path),{confirmed:true}));
 await assertFails(updateDoc(doc(db('b'),path),{selection:{...jointSelection,title:'Inventado'}}));
 await assertSucceeds(jointRespond(db('b'),'b',rid,'confirmed'));
 const count=async()=> (await getCountFromServer(query(collection(db('a'),'couple_relationships/'+rid+'/activity'),where('mediaType','==','movie'),where('confirmed','==',true)))).data().count;
 assert.equal(await count(),1);
 await jointRespond(db('b'),'b',rid,'confirmed');assert.equal(await count(),1);
 const data=(await getDoc(doc(db('a'),jointPath(rid)))).data();
 await jointWrite(db('a'),rid,'experience',{...data,revision:2,version:data.version+1,updatedAt:serverTimestamp(),responses:{...data.responses,a:{revision:2,decision:'confirmed',respondedAt:serverTimestamp()}}});
 assert.equal(await count(),0);
 await jointRespond(db('b'),'b',rid,'confirmed');assert.equal(await count(),1);
 await jointRespond(db('a'),'a',rid,'withdrawn');assert.equal(await count(),0);
 await assertFails(deleteDoc(doc(db('a'),path)));
 await assertFails(getDoc(doc(db('c'),path)));
 await assertFails(getDocs(collection(db('c'),'couple_relationships/'+rid+'/activity')));
 await pair(db('a'),'a','b',false);
 await assertFails(getDoc(doc(db('b'),path)));
 await assertFails(getCountFromServer(collection(db('a'),'couple_relationships/'+rid+'/activity')));
 await assertSucceeds(getDoc(doc(db('b'),jointPath(rid))));
});
test('COUPLE-08: páginas com empate, filtros e totais completos além da primeira página',async()=>{
 const rid=await jointRelation();
 // Fixture histórica tipada; timestamp empatado testa o desempate por ID.
 await env.withSecurityRulesDisabled(async context=>{
  const database=context.firestore(),batch=writeBatch(database);
  for(let i=0;i<27;i++) {
   const type=['book','movie','series','track','album'][i%5],id='fixture-'+String(i).padStart(2,'0');
   const data={...jointExperience(),selection:{...jointSelection,mediaType:type,subtitle:(type==='track'||type==='album')?'Artista':''},responses:{a:{revision:1,decision:'confirmed',respondedAt:stamp},b:{revision:1,decision:'confirmed',respondedAt:stamp}},createdAt:stamp,updatedAt:stamp};
   batch.set(doc(database,'couple_relationships/'+rid+'/experiences/'+id),data);
   batch.set(doc(database,'couple_relationships/'+rid+'/activity/'+id),jointActivity(data));
  }
  await batch.commit();
 });
 const base=collection(db('a'),'couple_relationships/'+rid+'/activity');
 const first=await getDocs(query(base,orderBy('updatedAt','desc'),orderBy(documentId(),'desc'),limit(20)));
 const last=first.docs.at(-1);
 const second=await getDocs(query(base,orderBy('updatedAt','desc'),orderBy(documentId(),'desc'),startAfter(last.data().updatedAt,last.id),limit(20)));
 assert.equal(new Set([...first.docs,...second.docs].map(d=>d.id)).size,27);
 const count=(await getCountFromServer(query(base,where('mediaType','==','book'),where('confirmed','==',true)))).data().count;
 assert.equal(count,6);
 const filtered=await getDocs(query(base,where('mediaType','==','track'),orderBy('updatedAt','desc'),orderBy(documentId(),'desc'),limit(21)));
 assert.equal(filtered.size,5);
});
