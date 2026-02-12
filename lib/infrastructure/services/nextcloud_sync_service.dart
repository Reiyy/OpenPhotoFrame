import 'dart:io';
import 'package:logging/logging.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../domain/interfaces/sync_provider.dart';
import '../../domain/interfaces/storage_provider.dart';

/// 关闭 HTTPS 证书校验
class _NoCheckHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class WebDavSyncService implements SyncProvider {
  final String webDavUrl;
  final String remotePath;
  final StorageProvider _storageProvider;
  final _log = Logger('WebDavSyncService');

  WebDavSyncService({
    required this.webDavUrl,
    required StorageProvider storageProvider,
    this.remotePath = '/',
  }) : _storageProvider = storageProvider {
    // 关闭证书校验
    HttpOverrides.global = _NoCheckHttpOverrides();
  }

  @override
  String get id => 'webdav';

  /// 测试连接
  /// 成功返回 null，失败返回错误字符串
  static Future<String?> testConnection(String url) async {
    final log = Logger('WebDavSyncService');

    if (url.isEmpty) {
      return 'URL is empty';
    }

    try {
      final uri = Uri.parse(url);

      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return 'Invalid URL scheme (must be http or https)';
      }

      if (uri.host.isEmpty) {
        return 'Invalid URL (no host)';
      }

      HttpOverrides.global = _NoCheckHttpOverrides();

      final client = webdav.newClient(
        url,
        user: '',
        password: '',
        debug: false,
      );

      await client.readDir('/');

      log.info("Connection test successful");
      return null;

    } on FormatException catch (e) {
      return 'Invalid URL format: ${e.message}';
    } catch (e) {
      log.warning("Connection test failed: $e");

      if (e.toString().contains('SocketException')) {
        return 'Could not connect (check URL/network)';
      }

      return 'Connection failed: $e';
    }
  }

  @override
  Future<void> sync({bool deleteOrphanedFiles = false}) async {
    _log.info("Starting WebDAV Sync from $webDavUrl");

    final client = webdav.newClient(
      webDavUrl,
      user: '',
      password: '',
      debug: false,
    );

    try {
      final localDir = await _storageProvider.getPhotoDirectory();
      _log.info("Syncing to local directory: ${localDir.path}");

      _log.info("Listing remote files...");
      final files = await client.readDir(remotePath);

      final remoteFileNames = <String>{};

      for (var file in files) {
        if (file.isDir == true) continue;

        final name = file.name ?? '';
        if (!_isImage(name)) continue;

        remoteFileNames.add(name);

        final localFile = File('${localDir.path}/$name');

        bool needsDownload = false;

        if (!await localFile.exists()) {
          needsDownload = true;
        }

        if (needsDownload) {
          _log.info("Downloading $name...");

          final partFile = File('${localFile.path}.part');

          await client.read2File(file.path ?? name, partFile.path);

          if (file.mTime != null) {
            try {
              await partFile.setLastModified(file.mTime!);
            } catch (e) {
              _log.warning("Could not set modification time for $name: $e");
            }
          }

          await partFile.rename(localFile.path);
        }
      }

      if (deleteOrphanedFiles) {
        _log.info("Checking for orphaned local files...");

        final localFiles = await localDir.list().toList();

        for (var entity in localFiles) {
          if (entity is! File) continue;

          final fileName = entity.path.split('/').last;

          if (!_isImage(fileName) || fileName.endsWith('.part')) continue;

          if (!remoteFileNames.contains(fileName)) {
            _log.info("Deleting orphaned file: $fileName");

            try {
              await entity.delete();
            } catch (e) {
              _log.warning("Failed to delete orphaned file $fileName: $e");
            }
          }
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
