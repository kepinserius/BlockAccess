import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _useBiometrics = false;
  bool _enableNotifications = true;
  bool _locationBasedAccess = false;
  String _language = 'en';
  int _autoLockTimeout = 5; // minutes
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get useBiometrics => _useBiometrics;
  bool get enableNotifications => _enableNotifications;
  bool get locationBasedAccess => _locationBasedAccess;
  String get language => _language;
  int get autoLockTimeout => _autoLockTimeout;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _useBiometrics = prefs.getBool('useBiometrics') ?? false;
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _locationBasedAccess = prefs.getBool('locationBasedAccess') ?? false;
      _language = prefs.getString('language') ?? 'en';
      _autoLockTimeout = prefs.getInt('autoLockTimeout') ?? 5;
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing settings: $e');
      }
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    
    _isDarkMode = value;
    await _saveSetting('isDarkMode', value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setUseBiometrics(bool value) async {
    if (_useBiometrics == value) return;
    
    _useBiometrics = value;
    await _saveSetting('useBiometrics', value);
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool value) async {
    if (_enableNotifications == value) return;
    
    _enableNotifications = value;
    await _saveSetting('enableNotifications', value);
    notifyListeners();
  }

  Future<void> setLocationBasedAccess(bool value) async {
    if (_locationBasedAccess == value) return;
    
    _locationBasedAccess = value;
    await _saveSetting('locationBasedAccess', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    if (_language == value) return;
    
    _language = value;
    await _saveSetting('language', value);
    notifyListeners();
  }

  Future<void> setAutoLockTimeout(int minutes) async {
    if (_autoLockTimeout == minutes) return;
    
    _autoLockTimeout = minutes;
    await _saveSetting('autoLockTimeout', minutes);
    notifyListeners();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving setting $key: $e');
      }
    }
  }

  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('isDarkMode');
      await prefs.remove('useBiometrics');
      await prefs.remove('enableNotifications');
      await prefs.remove('locationBasedAccess');
      await prefs.remove('language');
      await prefs.remove('autoLockTimeout');
      
      _isDarkMode = false;
      _useBiometrics = false;
      _enableNotifications = true;
      _locationBasedAccess = false;
      _language = 'en';
      _autoLockTimeout = 5;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting settings: $e');
      }
    }
  }
}
