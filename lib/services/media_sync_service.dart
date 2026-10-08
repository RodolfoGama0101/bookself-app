import 'package:flutter/foundation.dart';

import '../data/models/media_model.dart';
import 'media_library_repository.dart';

enum MediaSyncStatus { idle, pending, confirmed, failed, conflict }

/// Uma intenção por instância, sem fila offline. Descarte/troca de conta invalidam
/// resultados antigos; o repositório continua responsável pela confirmação.
class MediaSyncService extends ChangeNotifier {
  MediaSyncService(this.repository);
  final MediaLibraryRepository repository;
  MediaSyncStatus status = MediaSyncStatus.idle;
  LibraryEntry? entry;
  Object? error;
  String? _owner;
  Future<LibraryEntry> Function()? _retry;
  bool _disposed = false;
  int _generation = 0;

  void selectOwner(String? ownerId) {
    if (_disposed) return;
    if (ownerId != null) requireDocumentId(ownerId);
    if (_owner == ownerId) return;
    _generation++;
    _owner = ownerId;
    _retry = null;
    entry = null;
    error = null;
    status = MediaSyncStatus.idle;
    notifyListeners();
  }

  Future<void> save(CatalogItem catalog) async {
    _requireOwner(catalog.ownerId);
    await _run(() => repository.save(catalog));
  }

  Future<void> update({
    required MediaState? state,
    required bool favorite,
  }) async {
    final current = entry;
    if (current == null) throw StateError('Entrada não carregada');
    _requireOwner(current.ownerId);
    await _run(
      () => repository.updatePersonal(
        current.ownerId,
        current.id,
        expectedRevision: current.revision,
        state: state,
        favorite: favorite,
      ),
    );
  }

  /// Conflito exige recarregar e nova intenção explícita, sem retry de edição
  /// antiga. Em falha de rede, repetir mantém catálogo/ID/revisão capturados.
  Future<void> retry() async {
    if (status != MediaSyncStatus.failed || _retry == null) {
      throw StateError('Não há operação repetível');
    }
    await _run(_retry!);
  }

  Future<void> reload(String entryId) async {
    final owner = _owner;
    if (owner == null) throw StateError('Conta não selecionada');
    requireDocumentId(entryId);
    await _run(() async {
      final found = await repository.readEntry(owner, entryId);
      if (found == null) throw StateError('Entrada ausente');
      return found;
    });
  }

  void _requireOwner(String owner) {
    if (_disposed || _owner != owner) throw StateError('Sessão incompatível');
  }

  Future<void> _run(Future<LibraryEntry> Function() action) async {
    if (_disposed || status == MediaSyncStatus.pending) {
      throw StateError('Operação indisponível');
    }
    final generation = _generation;
    _retry = action;
    error = null;
    status = MediaSyncStatus.pending;
    notifyListeners();
    try {
      final confirmed = await action();
      if (_disposed || generation != _generation) return;
      if (confirmed.ownerId != _owner) {
        throw const FormatException('Dono divergente');
      }
      entry = confirmed;
      status = MediaSyncStatus.confirmed;
      _retry = null;
    } on MediaRevisionConflict catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
      status = MediaSyncStatus.conflict;
      _retry = null;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
      status = MediaSyncStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retry = null;
    entry = null;
    error = null;
    super.dispose();
  }
}
