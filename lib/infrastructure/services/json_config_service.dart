import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/interfaces/config_provider.dart';

class JsonConfigService implements ConfigProvider {
  final _log = Logger('JsonConfigService');
  Map<String, dynamic> _config = {};

  @override
  Future<void> load() async {
    try {
      // 1. Determine Config Path
      final dir = await getApplicationDocumentsDirectory();
      // Use a subfolder on Desktop to keep things tidy
      final configDir = (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
          ? Directory('${dir.path}/OpenPhotoFrame')
          : dir;
          
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      final configFile = File('${configDir.path}/config.json');

      // 2. Load or Create
      if (await configFile.exists()) {
        _log.info("Loading user config from ${configFile.path}");
        final jsonString = await configFile.readAsString();
        _config = json.decode(jsonString);
      } else {
        _log.info("No user config found. Creating default at ${configFile.path}");
        final jsonString = await rootBundle.loadString('assets/config.json');
        _config = json.decode(jsonString);
        
        // Write default config to disk so user can edit it
        await configFile.writeAsString(jsonString);
      }

      _log.info("Config loaded successfully. Active source: $activeSourceType");
    } catch (e) {
      _log.severe("Failed to load config", e);
      rethrow;
    }
  }

  @override
  String get activeSourceType => _config['active_source'] ?? 'unknown';

  @override
  Map<String, dynamic> getSourceConfig(String type) {
    final sources = _config['sources'] as Map<String, dynamic>?;
    return sources?[type] ?? {};
  }
}
