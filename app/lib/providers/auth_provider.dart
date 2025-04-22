import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { user, admin }

class User {
  final String id;
  final String name;
  final String walletAddress;
  final UserRole role;

  User({
    required this.id,
    required this.name,
    required this.walletAddress,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      walletAddress: json['walletAddress'],
      role: json['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'walletAddress': walletAddress,
      'role': role == UserRole.admin ? 'admin' : 'user',
    };
  }
}

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  Future<void> initialize() async {
    final userJson = await _secureStorage.read(key: 'user');
    if (userJson != null) {
      try {
        // In a real app, you would deserialize the JSON string to a Map
        // For demo purposes, we'll create a dummy user
        _currentUser = User(
          id: '1',
          name: 'Demo User',
          walletAddress: '0x1234567890abcdef',
          role: UserRole.user,
        );
        _isAuthenticated = true;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Error initializing auth: $e');
        }
      }
    }
  }

  Future<bool> login(String walletAddress, String signature) async {
    try {
      // In a real app, you would verify the signature on the server
      // For demo purposes, we'll just create a dummy user
      _currentUser = User(
        id: '1',
        name: 'Demo User',
        walletAddress: walletAddress,
        role: walletAddress.endsWith('admin') ? UserRole.admin : UserRole.user,
      );
      
      // Save user data securely
      await _secureStorage.write(
        key: 'user',
        value: 'dummy-encrypted-user-data',
      );
      
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: 'user');
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
    }
  }
}
