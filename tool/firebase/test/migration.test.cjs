const {test} = require('node:test');
const assert = require('node:assert/strict');
const {backup, verifyBackup, plan, apply, rollback, rehearse, digest} = require('../migration.cjs');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const snapshot = () => ({
  'users/a': {uid:'a',partnerUid:'b',relationshipId:'invite',coupleEpoch:3,extra:'preserved'},
  'users/b': {uid:'b',partnerUid:'a',relationshipId:'invite',coupleEpoch:4},
  'books/first': {userId:'a',title:'Livro fictício',googleBooksId:'ref',addedAt:{$timestamp:[100,1]},finishedDate:{$timestamp:[3000000000,2]},status:'Lido',isShared:false,unknown:{keep:true}},
  'books/second': {userId:'a',title:'Duplicata fictícia',googleBooksId:'ref',finishedDate:null},
  'books/manual': {userId:'b',title:'Manual fictício'},
  'bible_progress/a_genesis': {userId:'a',bookName:'Gênesis',readChapters:[1,3]},
  'partner_invites/invite': {status:'accepted',senderUid:'a',recipientUid:'b'},
  'shared_books/first': {userId:'a',title:'Projeção fictícia'},
});
test('DATA-03: backup, ensaio repetível e recuperação preservam todos os documentos e datas',()=>{
  const original=snapshot(), before=digest(original);
  const {saved,prepared,summary}=rehearse(original);
  assert.deepEqual(summary,{documents:8,books:3,users:2,bible:1,relationships:1,conflicts:1,verified:true});
  assert.equal(digest(original),before);
  assert.equal(prepared.conflicts[0].reason,'duplicate_reference');
  assert.equal(Object.keys(prepared.imports).length,3);
  assert(Object.values(prepared.imports).every(v=>v.createdAt===null));
  assert.deepEqual(rollback(saved,prepared,apply(saved,prepared,original)),original);
});
test('DATA-03: corrupção, versão futura e plano alterado são recusados antes da escrita',()=>{
  const original=snapshot(), saved=backup(original), prepared=plan(saved);
  saved.documents['users/a'].uid='changed';
  assert.throws(()=>verifyBackup(saved));
  assert.throws(()=>verifyBackup({...backup(original),formatVersion:2}));
  prepared.imports[Object.keys(prepared.imports)[0]].ownerId='third';
  assert.throws(()=>apply(backup(original),prepared,original));
});
test('DATA-03: concorrência na origem bloqueia aplicação; rollback não apaga alteração posterior',()=>{
  const original=snapshot(), saved=backup(original), prepared=plan(saved);
  const concurrent=structuredClone(original); concurrent['users/a'].partnerUid=null;
  assert.throws(()=>apply(saved,prepared,concurrent));
  const imported=apply(saved,prepared,original), path=Object.keys(prepared.imports)[0];
  imported[path].original.title='Later change';
  const before=digest(imported);
  assert.throws(()=>rollback(saved,prepared,imported));
  assert.equal(digest(imported),before);
});
test('DATA-03: término posterior e dados novos sobrevivem à recuperação',()=>{
  const original=snapshot(), saved=backup(original), prepared=plan(saved);
  const imported=apply(saved,prepared,original);
  imported['users/a'].partnerUid=null; imported['users/b'].partnerUid=null;
  imported['books/new']={userId:'a',title:'Novo fictício'};
  const restored=rollback(saved,prepared,imported);
  assert.equal(restored['users/a'].partnerUid,null);
  assert.deepEqual(restored['books/new'],imported['books/new']);
  assert.deepEqual(restored['bible_progress/a_genesis'],original['bible_progress/a_genesis']);
});
test('DATA-03: dono ausente e vínculo unilateral ficam no relatório sem reparo',()=>{
  const original=snapshot(); original['users/b'].partnerUid=null;
  original['books/orphan']={userId:'absent',title:'Órfão fictício'};
  const {prepared}=rehearse(original);
  assert(prepared.conflicts.some(c=>c.reason==='missing_owner'));
  assert(prepared.conflicts.some(c=>c.reason==='non_reciprocal_relationship'));
});
test('DATA-03: CLI gera arquivo recuperável, não substitui backup nem imprime conteúdo',()=>{
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'bookself-migration-'));
  const input=path.join(directory,'snapshot.local.json'), output=path.join(directory,'backup.local.json');
  try {
    fs.writeFileSync(input,JSON.stringify(snapshot()));
    const args=[path.resolve(__dirname,'../migration.cjs'),input,'--archive',output];
    const result=spawnSync(process.execPath,args,{encoding:'utf8',windowsHide:true});
    assert.equal(result.status,0);
    assert.equal(JSON.parse(result.stdout).books,3);
    assert(!result.stdout.includes('Livro fictício'));
    const archive=JSON.parse(fs.readFileSync(output,'utf8'));
    verifyBackup(archive.backup);
    assert.deepEqual(rollback(archive.backup,archive.plan,apply(archive.backup,archive.plan,snapshot())),snapshot());
    assert.notEqual(spawnSync(process.execPath,args,{encoding:'utf8',windowsHide:true}).status,0);
    assert.throws(()=>backup({'books/invalid':{value:undefined}}));
    assert.throws(()=>backup({'books/invalid':{value:NaN}}));
  } finally {
    for(const file of [input,output]) if(fs.existsSync(file)) fs.unlinkSync(file);
    fs.rmdirSync(directory);
  }
});
