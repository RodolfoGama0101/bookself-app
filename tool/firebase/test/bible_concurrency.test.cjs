const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {
  deleteDoc, doc, getDocFromServer, onSnapshot, runTransaction,
  serverTimestamp, setDoc,
} = require('firebase/firestore');

// Exercita o mesmo formato e algoritmo transacional do BibleService pelo SDK
// JS. A execução da implementação Dart e da tela é coberta separadamente.
test('concorrência preserva capítulos e leitura do servidor reconcilia',
  {timeout: 60000}, async () => {
    assert.equal(process.env.GCLOUD_PROJECT, 'demo-bookself');
    assert.match(process.env.FIRESTORE_EMULATOR_HOST || '',
      /^(127\.0\.0\.1|localhost):\d+$/);
    const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
    const environment = await initializeTestEnvironment({
      projectId: 'demo-bookself',
      firestore: {host, port: Number(port)},
    });
    const userId = `fixture-${randomUUID()}`;
    const firstDb = environment.authenticatedContext(userId).firestore();
    const secondDb = environment.authenticatedContext(userId).firestore();
    const first = doc(firstDb, 'bible_progress', `${userId}_rute`);
    const second = doc(secondDb, 'bible_progress', `${userId}_rute`);
    const data = chapters => ({
      userId, bookName: 'Rute', readChapters: chapters,
      updatedAt: serverTimestamp(),
    });
    let release;
    const pause = new Promise(resolve => { release = resolve; });
    let observedRead;
    const firstRead = new Promise(resolve => { observedRead = resolve; });
    let pending;
    try {
      await setDoc(first, data([]));
      let attempts = 0;
      pending = runTransaction(firstDb, async transaction => {
        const snapshot = await transaction.get(first);
        attempts++;
        if (attempts === 1) {
          observedRead();
          await pause;
        }
        const chapters = [...(snapshot.data()?.readChapters || [])];
        if (!chapters.includes(1)) chapters.push(1);
        chapters.sort((a, b) => a - b);
        transaction.set(first, data(chapters));
        return chapters;
      });
      await Promise.race([
        firstRead,
        pending.then(() => { throw new Error('Transação encerrou antes da leitura.'); }),
      ]);
      await runTransaction(secondDb, async transaction => {
        const snapshot = await transaction.get(second);
        const chapters = [...(snapshot.data()?.readChapters || [])];
        if (!chapters.includes(2)) chapters.push(2);
        chapters.sort((a, b) => a - b);
        transaction.set(second, data(chapters));
      });
      release();
      assert.deepEqual(await pending, [1, 2]);
      assert.ok(attempts >= 2, 'o conflito deve repetir a transação');

      let unsubscribe;
      const confirmed = await new Promise((resolve, reject) => {
        unsubscribe = onSnapshot(first, {includeMetadataChanges: true}, snap => {
          if (!snap.metadata.fromCache && !snap.metadata.hasPendingWrites) {
            resolve(snap.data().readChapters);
          }
        }, reject);
      }).finally(() => unsubscribe?.());
      assert.deepEqual(confirmed, [1, 2]);

      await setDoc(second, data([1, 2, 3]));
      const latest = await getDocFromServer(first);
      assert.equal(latest.metadata.fromCache, false);
      assert.equal(latest.metadata.hasPendingWrites, false);
      assert.deepEqual(latest.data().readChapters, [1, 2, 3]);
    } finally {
      release();
      if (pending) await pending.catch(() => {});
      await deleteDoc(first).catch(() => {});
      await environment.cleanup();
    }
  });
