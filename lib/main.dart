import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'domain/interfaces/config_provider.dart';
import 'domain/interfaces/metadata_provider.dart';
import 'domain/interfaces/playlist_strategy.dart';
import 'domain/interfaces/sync_provider.dart';
import 'domain/interfaces/storage_provider.dart';
import 'domain/interfaces/photo_repository.dart';
import 'infrastructure/services/json_config_service.dart';
import 'infrastructure/services/file_metadata_provider.dart';
import 'infrastructure/services/nextcloud_sync_service.dart';
import 'infrastructure/services/noop_sync_service.dart';
import 'infrastructure/services/photo_service.dart';
import 'infrastructure/services/local_storage_provider.dart';
import 'infrastructure/repositories/file_system_photo_repository.dart';
import 'infrastructure/strategies/weighted_freshness_strategy.dart';
import 'ui/screens/slideshow_screen.dart';

void main() async {
  // Setup Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  // Hide Status Bar and Navigation Bar (Immersive Mode)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load Config
  final configService = JsonConfigService();
  await configService.load();

  runApp(OpenPhotoFrameApp(configProvider: configService));
}

class OpenPhotoFrameApp extends StatelessWidget {
  final ConfigProvider configProvider;

  const OpenPhotoFrameApp({super.key, required this.configProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Infrastructure Services (Singletons)
        Provider<ConfigProvider>.value(value: configProvider),
        Provider<StorageProvider>(
          create: (_) => LocalStorageProvider(),
        ),
        Provider<MetadataProvider>(
          create: (_) => FileMetadataProvider(),
        ),
        Provider<PlaylistStrategy>(
          create: (_) => WeightedFreshnessStrategy(),
        ),
        
        // Repository needs Storage and Metadata
        ProxyProvider2<StorageProvider, MetadataProvider, PhotoRepository>(
          update: (_, storage, metadata, __) => FileSystemPhotoRepository(
            storageProvider: storage,
            metadataProvider: metadata,
          ),
          dispose: (_, repo) => repo.dispose(),
        ),
        
        // SyncProvider needs StorageProvider and Config
        ProxyProvider2<StorageProvider, ConfigProvider, SyncProvider>(
          update: (_, storage, config, __) {
            final type = config.activeSourceType;
            final sourceConfig = config.getSourceConfig(type);

            if (type == 'nextcloud_link') {
              return NextcloudSyncService.fromPublicLink(
                sourceConfig['url'] ?? '',
                storage,
              );
            }
            
            return NoOpSyncService();
          },
        ),

        // 2. Application Services (Dependent on Infrastructure)
        ProxyProvider3<SyncProvider, PlaylistStrategy, PhotoRepository, PhotoService>(
          update: (_, sync, playlist, repo, __) => PhotoService(
            syncProvider: sync,
            playlistStrategy: playlist,
            repository: repo,
          ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'OpenPhotoFrame',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black, // Dark background for photos
        ),
        home: const SlideshowScreen(),
      ),
    );
  }
}
