const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../../web/firebase_emulator.js'), 'utf8');
const options = { projectId: 'demo-bookself', apiKey: 'demo-key' };
const origin = 'http://127.0.0.1:9099';

function fixture() {
  const context = vm.createContext({ URL });
  const imports = [];
  const events = [];
  const instance = {};
  const core = {
    initializeApp: (config, name) => ({ options: config, name }),
  };
  const auth = {
    debugErrorMap: {}, indexedDBLocalPersistence: {},
    browserLocalPersistence: {}, browserSessionPersistence: {},
    browserPopupRedirectResolver: {},
    initializeAuth: (app, dependencies) => {
      assert.equal(app.name, 'demo-bookself');
      assert.equal(dependencies.persistence.length, 3);
      // Reproduz a restauração assíncrona iniciada pelo SDK real.
      Promise.resolve().then(() => {
        events.push(instance.emulatorConfig ? 'restore-local' : 'restore-remote');
      });
      return instance;
    },
    connectAuthEmulator: (value, target) => {
      assert.equal(target, origin);
      value.emulatorConfig = { host: '127.0.0.1', port: 9099, protocol: 'http' };
      events.push('connect');
    },
  };
  const script = new vm.Script(source, {
    importModuleDynamically: async (specifier) => {
      imports.push(specifier);
      const exports = specifier.endsWith('/firebase-app.js') ? core :
        specifier.endsWith('/firebase-auth.js') ? auth : {};
      const module = new vm.SyntheticModule(Object.keys(exports), function () {
        for (const [key, value] of Object.entries(exports)) this.setExport(key, value);
      }, { context });
      await module.link(() => {});
      await module.evaluate();
      return module;
    },
  });
  script.runInContext(context);
  return { context, imports, events, instance,
    prepare: context.bookselfPrepareDemoFirebase };
}

test('carregar o helper não inicializa Firebase ou chama a rede', () => {
  const { context, imports } = fixture();
  assert.equal(imports.length, 0);
  assert.equal(context.firebase_core, undefined);
});

test('projeto que não é demo é rejeitado antes de importar SDKs', async () => {
  const { prepare, imports } = fixture();
  await assert.rejects(prepare('12.13.0', { projectId: 'real-project' }, origin));
  assert.equal(imports.length, 0);
});

test('destinos remotos, protocolos e URLs com extras são rejeitados', async () => {
  const { prepare, imports } = fixture();
  for (const target of [
    'http://example.com:9099', 'https://127.0.0.1:9099',
    'http://127.0.0.1', 'http://user:secret@127.0.0.1:9099',
    'http://127.0.0.1:9099/path', 'http://127.0.0.1:9099/?x=1',
    'http://127.0.0.1:9099/#x',
  ]) {
    await assert.rejects(prepare('12.13.0', options, target));
  }
  assert.equal(imports.length, 0);
});

test('override incompatível não mistura versões dos SDKs', async () => {
  const { prepare, context, imports } = fixture();
  context.flutterfire_web_sdk_version = '0.0.0';
  await assert.rejects(prepare('12.13.0', options, origin));
  assert.equal(imports.length, 0);
});

test('sessão persistida só é restaurada depois da conexão local', async () => {
  const { prepare, events, imports } = fixture();
  await prepare('12.13.0', options, origin);
  assert.deepEqual(events, ['connect', 'restore-local']);
  assert.equal(imports.length, 3);
  assert.ok(imports.every(url => url.startsWith('https://www.gstatic.com/firebasejs/12.13.0/')));
});

test('nova tentativa preserva a conexão existente e rejeita outro destino', async () => {
  const { prepare, events } = fixture();
  await prepare('12.13.0', options, origin);
  await prepare('12.13.0', options, origin);
  assert.equal(events.filter(event => event === 'connect').length, 1);
  assert.ok(!events.includes('restore-remote'));
  await assert.rejects(prepare('12.13.0', options, 'http://localhost:9199'));
});
