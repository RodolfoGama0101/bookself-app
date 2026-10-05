// Chamado somente pelo opt-in Dart de emuladores. Não inicializa no modo normal.
// FlutterFire aguarda Auth dentro de initializeApp; conectar depois é tarde
// quando há uma sessão persistida. Usamos os módulos/versão do plugin instalado.
(function (root) {
  root.bookselfPrepareDemoFirebase = async function (version, options, origin) {
    const url = new URL(origin);
    if (options.projectId !== 'demo-bookself' ||
        url.protocol !== 'http:' ||
        !['127.0.0.1', 'localhost', '10.0.2.2'].includes(url.hostname) ||
        !url.port || url.username || url.password || url.pathname !== '/' ||
        url.search || url.hash) {
      throw new Error('Configuração local dos emuladores inválida');
    }
    if (root.flutterfire_web_sdk_version &&
        root.flutterfire_web_sdk_version !== version) {
      throw new Error('Versão web do Firebase incompatível com o modo demo');
    }
    const base = `https://www.gstatic.com/firebasejs/${version}/`;
    // Ao encontrar firebase_core, FlutterFire não injeta outros módulos.
    const [core, auth, firestore] = await Promise.all([
      import(`${base}firebase-app.js`),
      import(`${base}firebase-auth.js`),
      import(`${base}firebase-firestore-pipelines.js`),
    ]);
    root.firebase_core = core;
    root.firebase_auth = auth;
    root.firebase_firestore = firestore;
    const app = core.initializeApp(options, 'demo-bookself');
    // Mesmas dependências de firebase_auth_web 6.2.1 para reutilizar a instância.
    const instance = auth.initializeAuth(app, {
      errorMap: auth.debugErrorMap,
      persistence: [auth.indexedDBLocalPersistence,
        auth.browserLocalPersistence, auth.browserSessionPersistence],
      popupRedirectResolver: auth.browserPopupRedirectResolver,
    });
    // Sem await entre initializeAuth e connectAuthEmulator.
    if (!instance.emulatorConfig) {
      auth.connectAuthEmulator(instance, origin);
    } else if (instance.emulatorConfig.host !== url.hostname ||
               instance.emulatorConfig.port !== Number(url.port) ||
               instance.emulatorConfig.protocol !== 'http') {
      throw new Error('Auth já configurado para outro emulador');
    }
  };
})(globalThis);
