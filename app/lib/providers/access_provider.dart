import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AccessRight {
  final String id;
  final String userId;
  final String doorId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;

  AccessRight({
    required this.id,
    required this.userId,
    required this.doorId,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory AccessRight.fromJson(Map<String, dynamic> json) {
    return AccessRight(
      id: json['id'],
      userId: json['userId'],
      doorId: json['doorId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isActive: json['isActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'doorId': doorId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isActive': isActive,
    };
  }

  bool isValid() {
    final now = DateTime.now();
    return isActive && now.isAfter(startTime) && now.isBefore(endTime);
  }
}

class Door {
  final String id;
  final String name;
  final String location;
  final String deviceId;

  Door({
    required this.id,
    required this.name,
    required this.location,
    required this.deviceId,
  });

  factory Door.fromJson(Map<String, dynamic> json) {
    return Door(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      deviceId: json['deviceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'deviceId': deviceId,
    };
  }
}

class AccessLog {
  final String id;
  final String userId;
  final String doorId;
  final DateTime timestamp;
  final bool wasSuccessful;
  final String? transactionHash;

  AccessLog({
    required this.id,
    required this.userId,
    required this.doorId,
    required this.timestamp,
    required this.wasSuccessful,
    this.transactionHash,
  });

  factory AccessLog.fromJson(Map<String, dynamic> json) {
    return AccessLog(
      id: json['id'],
      userId: json['userId'],
      doorId: json['doorId'],
      timestamp: DateTime.parse(json['timestamp']),
      wasSuccessful: json['wasSuccessful'],
      transactionHash: json['transactionHash'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'doorId': doorId,
      'timestamp': timestamp.toIso8601String(),
      'wasSuccessful': wasSuccessful,
      'transactionHash': transactionHash,
    };
  }
}

class AccessProvider with ChangeNotifier {
  List<Door> _doors = [];
  List<AccessRight> _accessRights = [];
  List<AccessLog> _accessLogs = [];
  bool _isLoading = false;

  List<Door> get doors => _doors;
  List<AccessRight> get accessRights => _accessRights;
  List<AccessLog> get accessLogs => _accessLogs;
  bool get isLoading => _isLoading;

  // Initialize with some demo data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCachedData();
      // In a real app, you would fetch data from the blockchain
      await Future.delayed(const Duration(seconds: 1));
      
      // Demo data
      _doors = [
        Door(id: '1', name: 'Main Entrance', location: 'Building A', deviceId: 'esp32-001'),
        Door(id: '2', name: 'Conference Room', location: 'Building A', deviceId: 'esp32-002'),
        Door(id: '3', name: 'Lab Access', location: 'Building B', deviceId: 'esp32-003'),
      ];

      final now = DateTime.now();
      _accessRights = [
        AccessRight(
          id: '1',
          userId: '1',
          doorId: '1',
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now.add(const Duration(days: 30)),
          isActive: true,
        ),
        AccessRight(
          id: '2',
          userId: '1',
          doorId: '2',
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now.add(const Duration(days: 30)),
          isActive: true,
        ),
      ];

      _accessLogs = [
        AccessLog(
          id: '1',
          userId: '1',
          doorId: '1',
          timestamp: now.subtract(const Duration(hours: 2)),
          wasSuccessful: true,
          transactionHash: '0x1234567890abcdef',
        ),
      ];

      // Cache the data for offline mode
      await _cacheData();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing access data: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doorsJson = prefs.getString('doors');
      final accessRightsJson = prefs.getString('accessRights');
      final accessLogsJson = prefs.getString('accessLogs');

      if (doorsJson != null) {
        final List<dynamic> doorsList = jsonDecode(doorsJson);
        _doors = doorsList.map((json) => Door.fromJson(json)).toList();
      }

      if (accessRightsJson != null) {
        final List<dynamic> rightsList = jsonDecode(accessRightsJson);
        _accessRights = rightsList.map((json) => AccessRight.fromJson(json)).toList();
      }

      if (accessLogsJson != null) {
        final List<dynamic> logsList = jsonDecode(accessLogsJson);
        _accessLogs = logsList.map((json) => AccessLog.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached data: $e');
      }
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doors', jsonEncode(_doors.map((d) => d.toJson()).toList()));
      await prefs.setString('accessRights', jsonEncode(_accessRights.map((r) => r.toJson()).toList()));
      await prefs.setString('accessLogs', jsonEncode(_accessLogs.map((l) => l.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) {
        print('Error caching data: $e');
      }
    }
  }

  Future<bool> checkAccess(String userId, String doorId) async {
    try {
      // Check if user has access to this door
      final accessRight = _accessRights.firstWhere(
        (right) => right.userId == userId && right.doorId == doorId,
        orElse: () => AccessRight(
          id: '',
          userId: '',
          doorId: '',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          isActive: false,
        ),
      );

      final hasAccess = accessRight.isValid();
      
      // Log the access attempt
      final log = AccessLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        doorId: doorId,
        timestamp: DateTime.now(),
        wasSuccessful: hasAccess,
      );
      
      _accessLogs.add(log);
      await _cacheData();
      notifyListeners();
      
      return hasAccess;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking access: $e');
      }
      return false;
    }
  }

  Future<bool> grantAccess(String userId, String doorId, DateTime startTime, DateTime endTime) async {
    try {
      final newAccessRight = AccessRight(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        doorId: doorId,
        startTime: startTime,
        endTime: endTime,
        isActive: true,
      );
      
      _accessRights.add(newAccessRight);
      await _cacheData();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error granting access: $e');
      }
      return false;
    }
  }

  Future<bool> revokeAccess(String accessRightId) async {
    try {
      final index = _accessRights.indexWhere((right) => right.id == accessRightId);
      if (index != -1) {
        _accessRights[index] = AccessRight(
          id: _accessRights[index].id,
          userId: _accessRights[index].userId,
          doorId: _accessRights[index].doorId,
          startTime: _accessRights[index].startTime,
          endTime: _accessRights[index].endTime,
          isActive: false,
        );
        
        await _cacheData();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error revoking access: $e');
      }
      return false;
    }
  }
}
