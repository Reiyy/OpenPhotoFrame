import 'dart:io';
import 'package:logging/logging.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../domain/interfaces/sync_provider.dart';
import '../../domain/interfaces/storage_provider.dart';

class NextcloudSyncService implements SyncProvider {
  final String webDavUrl;
  final String user;
  final String password;
  final String remotePath;
  final StorageProvider _storageProvider;
  final _log = Logger('NextcloudSyncService');

  NextcloudSyncService({
    required this.webDavUrl,
    required this.user,
    required this.password,
    required StorageProvider storageProvider,
    this.remotePath = '/',
  }) : _storageProvider = storageProvider;

  /// Factory for Public Share Links
  /// Link format: https://cloud.example.com/s/TOKEN
  factory NextcloudSyncService.fromPublicLink(String link, StorageProvider storageProvider) {
    final uri = Uri.parse(link);
    // Extract token from last segment
    final token = uri.pathSegments.last;
    // Construct WebDAV URL: https://cloud.example.com/public.php/webdav
    final baseUrl = "${uri.scheme}://${uri.host}/public.php/webdav";
    
    return NextcloudSyncService(
      webDavUrl: baseUrl,
      user: token,
      password: '', // Public links usually have no password or it's handled differently
      storageProvider: storageProvider,
    );
  }

  @override
  String get id => 'nextcloud_public';

  @override
  Future<void> sync() async {
    _log.info("Starting Sync from $webDavUrl");

    // 1. Setup Client
    final client = webdav.newClient(
      webDavUrl,
      user: user,
      password: password,
      debug: false,
    );

    try {
      // 2. Get Local Directory via Provider
      final localDir = await _storageProvider.getPhotoDirectory();
      _log.info("Syncing to local directory: ${localDir.path}");

      // 3. List Remote Files
      // Note: public.php/webdav usually maps the root '/' to the shared folder
      _log.info("Listing remote files...");
      final files = await client.readDir(remotePath);

      for (var file in files) {
        // Skip directories and non-image files
        if (file.isDir == true) continue;
        final name = file.name ?? '';
        if (!_isImage(name)) continue;

        final localFile = File('${localDir.path}/$name');

        // 4. Check if we need to download
        // Simple check: File exists?
        // Better check: File size or modification time
        bool needsDownload = false;
        if (!await localFile.exists()) {
          needsDownload = true;
        } else {
          // Optional: Check size if available
          // if (file.size != await localFile.length()) needsDownload = true;
        }

        if (needsDownload) {
          _log.info("Downloading $name...");
          
          // Atomic Write: Download to .part file, then rename
          final partFile = File('${localFile.path}.part');
          await client.read2File(file.path ?? name, partFile.path);
          
          // 5. Sync Date (Crucial for our Freshness Algorithm)
          if (file.mTime != null) {
            try {
              await partFile.setLastModified(file.mTime!);
            } catch (e) {
              _log.warning("Could not set modification time for $name: $e");
            }
          }
          
          // Rename to final file (triggers FileWatcher)
          await partFile.rename(localFile.path);
        }
      }
      _log.info("Sync completed.");

    } catch (e) {
      _log.severe("Sync failed", e);
      rethrow;
    }
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || 
           lower.endsWith('.jpeg') || 
           lower.endsWith('.png') || 
           lower.endsWith('.webp');
  }
}
