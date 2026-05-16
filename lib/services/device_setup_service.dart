import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Step 1: Request standard Android battery optimization permission (shows a system pop-up)
  static Future<void> requestBatteryOptimization() async {
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      debugPrint('DeviceSetup: Battery opt request failed: $e');
    }
  }

  /// Step 2: Open manufacturer-specific settings page via native platform channel
  static Future<void> openManufacturerSettings(String manufacturer) async {
    try {
      String method;

      if (manufacturer.contains('xiaomi') ||
          manufacturer.contains('redmi') ||
          manufacturer.contains('poco')) {
        method = 'openAutoStart';
      } else if (manufacturer.contains('oppo') ||
          manufacturer.contains('realme')) {
        method = 'openAppDetails';
      } else if (manufacturer.contains('oneplus')) {
        method = 'openOnePlusSettings';
      } else if (manufacturer.contains('huawei') ||
          manufacturer.contains('honor')) {
        method = 'openPowerManager';
      } else if (manufacturer.contains('samsung')) {
        method = 'openBatterySettings';
      } else if (manufacturer.contains('vivo')) {
        method = 'openAppDetails';
      } else {
        method = 'openBatterySettings';
      }

      final result = await _channel.invokeMethod<bool>(method);
      if (result != true) {
        debugPrint('DeviceSetup: Native intent returned false, fallback not needed (handled natively).');
      }
    } catch (e) {
      debugPrint('DeviceSetup: Platform channel failed: $e');
      // If platform channel fails entirely, try permission_handler fallback
      try {
        await openAppSettings();
      } catch (_) {}
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
            'MIUI aggressively kills background apps. Enable Autostart for Snapi so it can detect screenshots 24/7.',
        'color': const Color(0xFFFF6900),
        'tip': '💡 Also lock Snapi in Recent Apps by swiping down on it.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open Autostart Settings',
        'settingsIcon': CupertinoIcons.rocket_fill,
      };
    } else if (manufacturer.contains('oneplus')) {
      return {
        'brand': 'OnePlus',
        'description':
            'OxygenOS may freeze Snapi in the background. Disable battery optimization for reliable screenshot detection.',
        'color': const Color(0xFFEB0029),
        'tip': '💡 Set Snapi\'s battery usage to "Unrestricted" for best results.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open Battery Settings',
        'settingsIcon': CupertinoIcons.battery_100,
      };
    } else if (manufacturer.contains('oppo') ||
        manufacturer.contains('realme')) {
      return {
        'brand': 'Oppo / Realme',
        'description':
            'ColorOS restricts background activity. Allow Snapi to auto-start for uninterrupted screenshot detection.',
        'color': const Color(0xFF1DB954),
        'tip': '💡 Make sure Snapi is excluded from Power Saving Mode.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open Startup Settings',
        'settingsIcon': CupertinoIcons.rocket_fill,
      };
    } else if (manufacturer.contains('vivo')) {
      return {
        'brand': 'Vivo',
        'description':
            'Enable background running for Snapi in iManager for reliable detection.',
        'color': const Color(0xFF415FFF),
        'tip': '💡 Add Snapi to the Whitelist in iManager for best results.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open App Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    } else if (manufacturer.contains('huawei') ||
        manufacturer.contains('honor')) {
      return {
        'brand': 'Huawei / Honor',
        'description':
            'EMUI may restrict Snapi. Enable "Protected App" and Auto-launch for reliable background detection.',
        'color': const Color(0xFFE40520),
        'tip': '💡 Enable Auto-launch and Background activity in Manager.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open Power Manager',
        'settingsIcon': CupertinoIcons.shield_fill,
      };
    } else if (manufacturer.contains('samsung')) {
      return {
        'brand': 'Samsung',
        'description':
            'Set Snapi\'s battery usage to "Unrestricted" so it can detect screenshots reliably in the background.',
        'color': const Color(0xFF1428A0),
        'tip': '💡 Ensure Snapi is not in your Sleeping apps list.',
        'hasSettingsButton': true,
        'settingsLabel': 'Open Battery Settings',
        'settingsIcon': CupertinoIcons.battery_100,
      };
    } else {
      return {
        'brand': 'Your Device',
        'description':
            'Allow Snapi to run in the background so it can detect screenshots reliably.',
        'color': CupertinoColors.activeBlue,
        'tip': '💡 Avoid strict Battery Saver mode when you need screenshot alerts.',
        'hasSettingsButton': false,
        'settingsLabel': 'Open Settings',
        'settingsIcon': CupertinoIcons.settings,
      };
    }
  }
}
