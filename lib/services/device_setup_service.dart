import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart' as auto_start;

class DeviceSetupService {
  static const _prefSetupDone = 'device_setup_guide_done';
  static const _prefSetupSkipped = 'device_setup_skipped';
  static const _channel = MethodChannel('com.snapi/device_settings');

  /// Returns the phone manufacturer in lowercase
  static Future<String> getManufacturer() async {
    if (!Platform.isAndroid) return 'unknown';
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.manufacturer.toLowerCase();
    } catch (_) {
      return 'unknown';
    }
  }

  /// Check if setup guide has been shown before
  static Future<bool> needsSetupGuide() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefSetupDone) ?? false);
  }

  /// Mark setup as fully completed
  static Future<void> markSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSetupDone, true);
    await prefs.setBool(_prefSetupSkipped, false); // clear skip flag
  }

  /// Mark setup as skipped (show reminder on home screen)
  static Future<void> markSetupSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSetupDone, true); // don't show again
    await prefs.setBool(_prefSetupSkipped, true); // but mark as skipped
  }

  /// Check if the user skipped setup (for home screen reminder)
  static Future<bool> wasSetupSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefSetupSkipped) ?? false;
  }

  /// Clear the skipped flag (after user completes from reminder)
  static Future<void> clearSkippedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSetupSkipped, false);
  }

  /// Check if battery optimization is already disabled/ignored
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Step 1: Request standard Android battery optimization permission
  static Future<void> requestBatteryOptimization() async {
    try {
      await auto_start.disableBatteryOptimization();
      // Fallback
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      debugPrint('DeviceSetup: Battery opt request failed: $e');
    }
  }

  /// Step 2: Open specific App Settings page or Auto Start page
  static Future<void> openManufacturerSettings(String manufacturer) async {
    try {
      // First try to open the exact Auto Start settings page using the package
      bool success = await auto_start.getAutoStartPermission();
      
      // If it fails (some devices don't have a dedicated page), fallback to App Settings
      if (!success) {
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('DeviceSetup: Failed to open settings: $e');
      await openAppSettings();
    }
  }

  /// Returns device-specific guide content
  static Map<String, dynamic> getGuideForDevice(String manufacturer) {
    if (manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco')) {
      return {
        'brand': 'Xiaomi / Redmi / Poco',
        'description':
            '1. Tap on "Battery saver"\n2. Select "No restrictions"\n3. Turn on "Autostart"',
        'color': const Color(0xFFFF6900),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('oneplus')) {
      return {
        'brand': 'OnePlus',
        'description':
            '1. Tap on "Battery usage"\n2. Enable "Allow background activity"',
        'color': const Color(0xFFEB0029),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('oppo') ||
        manufacturer.contains('realme')) {
      return {
        'brand': 'Oppo / Realme',
        'description':
            '1. Tap on "Battery usage"\n2. Enable "Allow background activity"\n3. Turn on "Auto-launch"',
        'color': const Color(0xFF1DB954),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('vivo')) {
      return {
        'brand': 'Vivo',
        'description':
            '1. Tap on "Battery"\n2. Allow high background power consumption',
        'color': const Color(0xFF415FFF),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('huawei') ||
        manufacturer.contains('honor')) {
      return {
        'brand': 'Huawei / Honor',
        'description':
            '1. Tap on "Power usage details"\n2. Tap "App launch"\n3. Manage manually and enable all',
        'color': const Color(0xFFE40520),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('samsung')) {
      return {
        'brand': 'Samsung',
        'description':
            '1. Tap on "Battery"\n2. Enable "Allow background activity"',
        'color': const Color(0xFF1428A0),
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else {
      return {
        'brand': 'Your Device',
        'description':
            '1. Tap on "Battery" or "App battery usage"\n2. Enable "Allow background activity"',
        'color': CupertinoColors.activeBlue,
        'tip': '',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    }
  }
}
