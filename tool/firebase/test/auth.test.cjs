const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signOut, signInWithEmailAndPassword} = require('firebase/auth');
const {getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, deleteDoc, Timestamp, terminate, setLogLevel} = require('firebase/firestore');
setLogLevel('silent');

test('Auth real do emulador cria sessão e Firestore autoriza perfil do dono', async () => {
  assert.equal(process.env.GCLOUD_PROJECT, 'demo-bookself');
  assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
  const app = initializeApp({projectId:'demo-bookself', apiKey:'demo-key', appId:'demo-app'}, 'auth-smoke');
  const auth = getAuth(app); const database = getFirestore(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings:true});
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  connectFirestoreEmulator(database, host, Number(port));
  const email = `fixture-${Date.now()}@example.com`; const password = 'fixture-only-123';
  try {
    const credential = await createUserWithEmailAndPassword(auth, email, password);
    const reference = doc(database, 'users', credential.user.uid);
    await setDoc(reference, {uid:credential.user.uid, name:'Pessoa fictícia', email,
      createdAt:Timestamp.now(), partnerUid:null, photoUrl:null});
    assert.equal((await getDoc(reference)).data().uid, credential.user.uid);
    await signOut(auth);
    await assert.rejects(getDoc(reference), error => error.code === 'permission-denied');
    await signInWithEmailAndPassword(auth, email, password);
    assert.equal((await getDoc(reference)).data().uid, auth.currentUser.uid);
    await assert.rejects(deleteDoc(reference), error => error.code === 'permission-denied');
  } finally {
    await signOut(auth);
    await terminate(database);
    await deleteApp(app);
  }
});
