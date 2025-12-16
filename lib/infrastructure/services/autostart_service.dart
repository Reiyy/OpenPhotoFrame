import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage autostart settings.
/// Uses SharedPreferences because the Android BootReceiver needs to read it
/// before Flutter is initialized.
class AutostartService {
  static const String _autostartKey = 'autostart_on_boot';
  
  /// Check if autostart feature is available on the current platform.
  static bool get isAvailable => Platform.isAndroid;
  
  /// Save autostart setting to SharedPreferences.
  /// This is read by the Android BootReceiver on device boot.
  static Future<void> setEnabled(bool enabled) async {
    if (!isAvailable) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autostartKey, enabled);
  }
  
  /// Get current autostart setting from SharedPreferences.
  static Future<bool> isEnabled() async {
    if (!isAvailable) return false;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autostartKey) ?? false;
  }
}
