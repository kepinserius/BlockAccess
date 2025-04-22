import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/share_access_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/access_history_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/access_provider.dart';
import 'providers/blockchain_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/location_provider.dart';
import 'providers/settings_provider.dart';

import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase: $e');
    // Continue without Firebase for now
  }
  
  runApp(const BlockAccessApp());
}

class BlockAccessApp extends StatelessWidget {
  const BlockAccessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccessProvider()),
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          
          return MaterialApp(
            title: 'BlockAccess',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: ThemeData.dark().copyWith(
              useMaterial3: true,
              colorScheme: ColorScheme.dark(
                primary: AppTheme.primaryColor,
                secondary: AppTheme.secondaryColor,
                surface: const Color(0xFF1E1E1E),
                background: const Color(0xFF121212),
                error: AppTheme.errorColor,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(
                ThemeData.dark().textTheme,
              ),
            ),
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/qr_scanner': (context) => const QRScannerScreen(),
              '/admin': (context) => const AdminScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/notifications': (context) => const NotificationScreen(),
              '/share_access': (context) => const ShareAccessScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/access_history': (context) => const AccessHistoryScreen(),
            },
          );
        },
      ),
    );
  }
}
