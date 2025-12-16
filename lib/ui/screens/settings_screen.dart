import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/interfaces/config_provider.dart';
import '../../infrastructure/services/photo_service.dart';
import '../../infrastructure/services/nextcloud_sync_service.dart';
import '../../infrastructure/services/autostart_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _slideDurationMinutes;
  late double _transitionDurationSeconds;
  late String _syncType;
  late TextEditingController _nextcloudUrlController;
  late int _syncIntervalMinutes;
  late bool _deleteOrphanedFiles;
  late bool _autostartOnBoot;
  
  bool _isSyncing = false;
  String? _syncStatus;
  
  bool _isTestingConnection = false;
  String? _connectionTestResult;
  bool? _connectionTestSuccess;
  
  // Track original values to detect changes
  late String _originalSyncType;
  late String _originalNextcloudUrl;
  
  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigProvider>();
    _slideDurationMinutes = (config.slideDurationSeconds / 60).round().clamp(1, 15);
    _transitionDurationSeconds = (config.transitionDurationMs / 1000.0).clamp(0.5, 5.0);
    _syncType = config.activeSourceType.isEmpty ? 'none' : config.activeSourceType;
    _syncIntervalMinutes = config.syncIntervalMinutes;
    _deleteOrphanedFiles = config.deleteOrphanedFiles;
    _autostartOnBoot = config.autostartOnBoot;
    
    final nextcloudConfig = config.getSourceConfig('nextcloud_link');
    _nextcloudUrlController = TextEditingController(
      text: nextcloudConfig['url'] ?? '',
    );
    
    // Store original values for comparison on save
    _originalSyncType = _syncType;
    _originalNextcloudUrl = nextcloudConfig['url'] ?? '';
  }
  
  @override
  void dispose() {
    _nextcloudUrlController.dispose();
    super.dispose();
  }
  
  Future<void> _saveSettings() async {
    final config = context.read<ConfigProvider>();
    
    // Detect if sync configuration changed
    final newNextcloudUrl = _nextcloudUrlController.text.trim();
    final syncConfigChanged = _syncType != _originalSyncType ||
        (_syncType == 'nextcloud_link' && newNextcloudUrl != _originalNextcloudUrl);
    final newSyncSourceConfigured = syncConfigChanged && 
        _syncType == 'nextcloud_link' && 
        newNextcloudUrl.isNotEmpty;
    
    config.slideDurationSeconds = _slideDurationMinutes * 60;
    config.transitionDurationMs = (_transitionDurationSeconds * 1000).round();
    config.activeSourceType = _syncType == 'none' ? '' : _syncType;
    config.syncIntervalMinutes = _syncIntervalMinutes;
    config.deleteOrphanedFiles = _deleteOrphanedFiles;
    config.autostartOnBoot = _autostartOnBoot;
    
    // Sync autostart setting to SharedPreferences for BootReceiver
    await AutostartService.setEnabled(_autostartOnBoot);
    
    if (_syncType == 'nextcloud_link') {
      config.setSourceConfig('nextcloud_link', {
        'url': newNextcloudUrl,
      });
    }
    
    await config.save();
    
    // If a new sync source was configured, trigger an immediate sync
    // This runs in the background (fire-and-forget) so the user can continue
    if (newSyncSourceConfigured) {
      final photoService = context.read<PhotoService>();
      // Don't await - let it run in the background
      photoService.triggerSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _saveSettings();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === SLIDESHOW SETTINGS ===
          _buildSectionHeader('Slideshow'),
          const SizedBox(height: 8),
          
          // Slide Duration
          _buildSliderSetting(
            icon: Icons.timer,
            title: 'Slide Duration',
            value: _slideDurationMinutes.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            unit: 'min',
            onChanged: (value) {
              setState(() => _slideDurationMinutes = value.round());
            },
          ),
          
          const SizedBox(height: 16),
          
          // Transition Duration (0.5 - 5 seconds, 0.5s steps)
          _buildSliderSetting(
            icon: Icons.blur_on,
            title: 'Transition Duration',
            value: _transitionDurationSeconds,
            min: 0.5,
            max: 5.0,
            divisions: 9,  // 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0
            unit: 'sec',
            formatValue: (v) => v.toStringAsFixed(1),
            onChanged: (value) {
              setState(() => _transitionDurationSeconds = value);
            },
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // === SYNC SETTINGS ===
          _buildSectionHeader('Sync'),
          const SizedBox(height: 8),
          
          // Sync Type Selection
          _buildSyncTypeSelector(),
          
          // Nextcloud URL (only visible if nextcloud selected)
          if (_syncType == 'nextcloud_link') ...[
            const SizedBox(height: 16),
            _buildNextcloudSettings(),
          ],
          
          // Sync options (only visible if sync enabled)
          if (_syncType != 'none') ...[
            const SizedBox(height: 16),
            
            // Sync Interval Slider
            _buildSyncIntervalSlider(),
            
            const SizedBox(height: 8),
            
            // Delete orphaned files checkbox
            CheckboxListTile(
              title: const Text('Delete orphaned files'),
              subtitle: const Text('Remove local files that are no longer on server'),
              value: _deleteOrphanedFiles,
              onChanged: (value) {
                setState(() => _deleteOrphanedFiles = value ?? true);
              },
            ),
            
            const SizedBox(height: 16),
            _buildSyncNowButton(),
            
            const SizedBox(height: 8),
            _buildLastSyncInfo(),
          ],
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // === ANDROID SETTINGS (only on Android) ===
          if (Platform.isAndroid) ...[
            _buildSectionHeader('Android'),
            const SizedBox(height: 8),
            
            SwitchListTile(
              title: const Text('Start on Boot'),
              subtitle: const Text('Automatically start app when device boots'),
              secondary: const Icon(Icons.power_settings_new),
              value: _autostartOnBoot,
              onChanged: (value) {
                setState(() => _autostartOnBoot = value);
              },
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ],
          
          // === ABOUT ===
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Open Photo Frame v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Open Photo Frame',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024',
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildSliderSetting({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    String Function(double)? formatValue,
  }) {
    final displayValue = formatValue != null ? formatValue(value) : '${value.round()}';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Text(
              '$displayValue $unit',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildSyncTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<String>(
          title: const Text('No Sync'),
          subtitle: const Text('Use only local photos'),
          value: 'none',
          groupValue: _syncType,
          onChanged: (value) {
            setState(() => _syncType = value!);
          },
        ),
        RadioListTile<String>(
          title: const Text('Nextcloud'),
          subtitle: const Text('Sync from Nextcloud public share link'),
          value: 'nextcloud_link',
          groupValue: _syncType,
          onChanged: (value) {
            setState(() => _syncType = value!);
          },
        ),
      ],
    );
  }
  
  Widget _buildNextcloudSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nextcloudUrlController,
            decoration: const InputDecoration(
              labelText: 'Nextcloud Public Share URL',
              hintText: 'https://cloud.example.com/s/abc123',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              // Reset test result when URL changes
              if (_connectionTestResult != null) {
                setState(() {
                  _connectionTestResult = null;
                  _connectionTestSuccess = null;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isTestingConnection ? null : _testConnection,
            icon: _isTestingConnection
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find, size: 18),
            label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
          ),
          if (_connectionTestResult != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _connectionTestSuccess! ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _connectionTestSuccess! ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionTestResult!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _connectionTestSuccess! ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionTestSuccess = null;
    });
    
    final error = await NextcloudSyncService.testConnection(
      _nextcloudUrlController.text.trim(),
    );
    
    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _connectionTestSuccess = error == null;
        _connectionTestResult = error ?? 'Connection successful!';
      });
    }
  }
  
  Widget _buildSyncIntervalSlider() {
    // Values: 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
    final displayValue = _syncIntervalMinutes == 0 
        ? 'Disabled' 
        : '$_syncIntervalMinutes min';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 12),
            const Expanded(child: Text('Auto-Sync Interval')),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _syncIntervalMinutes.toDouble(),
          min: 0,
          max: 60,
          divisions: 12, // 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
          onChanged: (value) {
            // Snap to 5-minute steps
            final snapped = (value / 5).round() * 5;
            setState(() => _syncIntervalMinutes = snapped);
          },
        ),
      ],
    );
  }
  
  Widget _buildSyncNowButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _triggerSync,
            icon: _isSyncing 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
          ),
          if (_syncStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _syncStatus!,
              style: TextStyle(
                color: _syncStatus!.contains('Error') 
                    ? Colors.red 
                    : Colors.green,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLastSyncInfo() {
    final config = context.read<ConfigProvider>();
    final lastSync = config.lastSuccessfulSync;
    
    String text;
    if (lastSync == null) {
      text = 'Never synced';
    } else {
      final now = DateTime.now();
      final diff = now.difference(lastSync);
      
      if (diff.inMinutes < 1) {
        text = 'Last sync: Just now';
      } else if (diff.inMinutes < 60) {
        text = 'Last sync: ${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        text = 'Last sync: ${diff.inHours} hours ago';
      } else {
        // Format as date
        text = 'Last sync: ${lastSync.day}.${lastSync.month}.${lastSync.year} '
               '${lastSync.hour.toString().padLeft(2, '0')}:'
               '${lastSync.minute.toString().padLeft(2, '0')}';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  Future<void> _triggerSync() async {
    // First save the current settings
    await _saveSettings();
    
    setState(() {
      _isSyncing = true;
      _syncStatus = null;
    });
    
    try {
      final photoService = context.read<PhotoService>();
      
      // Use centralized sync via PhotoService
      // This handles cancellation of running syncs and uses current config
      await photoService.triggerSync();
      
      if (mounted) {
        setState(() {
          _syncStatus = 'Sync completed successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncStatus = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
