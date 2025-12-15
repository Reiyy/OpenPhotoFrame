import 'dart:async';
import 'package:logging/logging.dart';

import '../../domain/interfaces/playlist_strategy.dart';
import '../../domain/interfaces/sync_provider.dart';
import '../../domain/interfaces/photo_repository.dart';
import '../../domain/models/photo_entry.dart';

class PhotoService {
  final SyncProvider _syncProvider;
  final PlaylistStrategy _playlistStrategy;
  final PhotoRepository _repository;
  final _log = Logger('PhotoService');

  bool _isInitialized = false;
  
  // History management
  final List<PhotoEntry> _history = [];
  int _historyIndex = -1;

  PhotoService({
    required SyncProvider syncProvider,
    required PlaylistStrategy playlistStrategy,
    required PhotoRepository repository,
  })  : _syncProvider = syncProvider,
        _playlistStrategy = playlistStrategy,
        _repository = repository;

  Stream<void> get onPhotosChanged => _repository.onPhotosChanged;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _log.info("Initializing PhotoService...");
    
    // 1. Initialize Repository (Load local photos)
    await _repository.initialize();
    
    // 2. Start Sync in Background
    _startBackgroundSync();
    
    _isInitialized = true;
  }

  void _startBackgroundSync() {
    // Run sync periodically or once?
    // For now, run once on start, then maybe every hour.
    Future.doWhile(() async {
      try {
        await _syncProvider.sync();
        // Repository watcher will pick up changes automatically
      } catch (e) {
        _log.warning("Sync failed, retrying later...", e);
      }
      
      // Wait 1 hour before next sync
      await Future.delayed(const Duration(hours: 1));
      return true;
    });
  }

  PhotoEntry? nextPhoto() {
    // 1. If we are in the past, move forward in history
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      return _history[_historyIndex];
    }

    // 2. Otherwise, generate new photo
    final photos = _repository.photos;
    final photo = _playlistStrategy.nextPhoto(photos);
    
    if (photo != null) {
      photo.lastShown = DateTime.now();
      _history.add(photo);
      _historyIndex++;
      
      // Limit history size to prevent memory leaks (keep last 50)
      if (_history.length > 50) {
        _history.removeAt(0);
        _historyIndex--;
      }
    }
    return photo;
  }

  PhotoEntry? previousPhoto() {
    if (_historyIndex > 0) {
      _historyIndex--;
      return _history[_historyIndex];
    }
    // If we are at the start, stay there
    return _history.isNotEmpty ? _history[_historyIndex] : null;
  }
  
  void dispose() {
    _repository.dispose();
  }
}
