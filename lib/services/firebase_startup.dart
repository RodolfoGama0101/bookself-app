/// Retoma somente etapas concluídas, sem abrir serviços antes da configuração.
/// A instância é mantida entre tentativas para evitar recriar o app nomeado.
class FirebaseStartupCoordinator<T extends Object> {
  FirebaseStartupCoordinator({
    required this.validate,
    required this.prepareWeb,
    required this.initializeApp,
    required this.configureFirestore,
    required this.configureAuth,
    required this.useEmulators,
  });

  final void Function() validate;
  final Future<bool> Function() prepareWeb;
  final Future<T> Function() initializeApp;
  final Future<void> Function(T app) configureFirestore;
  final Future<void> Function(T app) configureAuth;
  final bool useEmulators;

  bool _webPrepared = false;
  bool _webAuthConfigured = false;
  bool _firestoreConfigured = false;
  bool _authConfigured = false;
  T? _app;
  Future<void>? _inFlight;
  bool _ready = false;

  Future<void> initialize() {
    if (_ready) return Future.value();
    return _inFlight ??= _initialize().whenComplete(() => _inFlight = null);
  }

  Future<void> _initialize() async {
    validate();
    if (!_webPrepared) {
      _webAuthConfigured = await prepareWeb();
      _webPrepared = true;
    }
    final app = _app ??= await initializeApp();
    if (useEmulators) {
      if (!_firestoreConfigured) {
        await configureFirestore(app);
        _firestoreConfigured = true;
      }
      if (!_webAuthConfigured && !_authConfigured) {
        await configureAuth(app);
        _authConfigured = true;
      }
    }
    _ready = true;
  }
}
