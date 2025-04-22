import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  String _appVersion = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _getAppVersion();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      setState(() {
        _canCheckBiometrics = canCheckBiometrics;
        _availableBiometrics = availableBiometrics;
      });
    } catch (e) {
      setState(() {
        _canCheckBiometrics = false;
        _availableBiometrics = [];
      });
    }
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _resetSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.resetToDefaults();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance Section
                  FadeAnimation(
                    delay: 0.1,
                    child: _buildSectionHeader('Appearance'),
                  ),
                  SlideAnimation(
                    delay: 0.2,
                    direction: SlideDirection.fromLeft,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Dark Mode
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            subtitle: const Text('Enable dark color theme'),
                            secondary: const Icon(Icons.dark_mode),
                            value: settingsProvider.isDarkMode,
                            onChanged: (value) async {
                              await settingsProvider.setDarkMode(value);
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                          
                          const Divider(),
                          
                          // Language
                          ListTile(
                            leading: const Icon(Icons.language),
                            title: const Text('Language'),
                            subtitle: Text(_getLanguageName(settingsProvider.language)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              _showLanguageDialog(context, settingsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Security Section
                  FadeAnimation(
                    delay: 0.3,
                    child: _buildSectionHeader('Security'),
                  ),
                  SlideAnimation(
                    delay: 0.4,
                    direction: SlideDirection.fromRight,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Biometric Authentication
                          SwitchListTile(
                            title: const Text('Biometric Authentication'),
                            subtitle: Text(_canCheckBiometrics
                                ? 'Use ${_getBiometricTypeName()} to unlock the app'
                                : 'Biometrics not available on this device'),
                            secondary: const Icon(Icons.fingerprint),
                            value: settingsProvider.useBiometrics && _canCheckBiometrics,
                            onChanged: _canCheckBiometrics
                                ? (value) async {
                                    await settingsProvider.setUseBiometrics(value);
                                  }
                                : null,
                            activeColor: AppTheme.primaryColor,
                          ),
                          
                          const Divider(),
                          
                          // Auto Lock Timeout
                          ListTile(
                            leading: const Icon(Icons.lock_clock),
                            title: const Text('Auto Lock'),
                            subtitle: Text('Lock after ${settingsProvider.autoLockTimeout} minutes of inactivity'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              _showAutoLockDialog(context, settingsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Notifications Section
                  FadeAnimation(
                    delay: 0.5,
                    child: _buildSectionHeader('Notifications'),
                  ),
                  SlideAnimation(
                    delay: 0.6,
                    direction: SlideDirection.fromLeft,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive notifications about access events'),
                        secondary: const Icon(Icons.notifications),
                        value: settingsProvider.enableNotifications,
                        onChanged: (value) async {
                          await settingsProvider.setEnableNotifications(value);
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Location Section
                  FadeAnimation(
                    delay: 0.7,
                    child: _buildSectionHeader('Location'),
                  ),
                  SlideAnimation(
                    delay: 0.8,
                    direction: SlideDirection.fromRight,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Location-Based Access'),
                        subtitle: const Text('Automatically unlock doors when nearby'),
                        secondary: const Icon(Icons.location_on),
                        value: settingsProvider.locationBasedAccess,
                        onChanged: (value) async {
                          await settingsProvider.setLocationBasedAccess(value);
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // About Section
                  FadeAnimation(
                    delay: 0.9,
                    child: _buildSectionHeader('About'),
                  ),
                  SlideAnimation(
                    delay: 1.0,
                    direction: SlideDirection.fromBottom,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info),
                            title: const Text('App Version'),
                            subtitle: Text(_appVersion),
                          ),
                          
                          const Divider(),
                          
                          ListTile(
                            leading: const Icon(Icons.privacy_tip),
                            title: const Text('Privacy Policy'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Navigate to privacy policy
                            },
                          ),
                          
                          const Divider(),
                          
                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('Terms of Service'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Navigate to terms of service
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Reset Settings Button
                  SlideAnimation(
                    delay: 1.1,
                    direction: SlideDirection.fromBottom,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _showResetConfirmationDialog,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset to Default Settings'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'id':
        return 'Bahasa Indonesia';
      default:
        return 'English';
    }
  }

  String _getBiometricTypeName() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else {
      return 'Biometrics';
    }
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, settingsProvider, 'en', 'English'),
            _buildLanguageOption(context, settingsProvider, 'es', 'Español'),
            _buildLanguageOption(context, settingsProvider, 'fr', 'Français'),
            _buildLanguageOption(context, settingsProvider, 'de', 'Deutsch'),
            _buildLanguageOption(context, settingsProvider, 'id', 'Bahasa Indonesia'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    SettingsProvider settingsProvider,
    String languageCode,
    String languageName,
  ) {
    return ListTile(
      title: Text(languageName),
      trailing: settingsProvider.language == languageCode
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : null,
      onTap: () async {
        await settingsProvider.setLanguage(languageCode);
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showAutoLockDialog(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeoutOption(context, settingsProvider, 1, '1 minute'),
            _buildTimeoutOption(context, settingsProvider, 5, '5 minutes'),
            _buildTimeoutOption(context, settingsProvider, 15, '15 minutes'),
            _buildTimeoutOption(context, settingsProvider, 30, '30 minutes'),
            _buildTimeoutOption(context, settingsProvider, 60, '1 hour'),
            _buildTimeoutOption(context, settingsProvider, 0, 'Never'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutOption(
    BuildContext context,
    SettingsProvider settingsProvider,
    int minutes,
    String label,
  ) {
    return ListTile(
      title: Text(label),
      trailing: settingsProvider.autoLockTimeout == minutes
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : null,
      onTap: () async {
        await settingsProvider.setAutoLockTimeout(minutes);
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
