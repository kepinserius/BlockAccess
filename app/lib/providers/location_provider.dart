import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  double distanceTo(LocationData other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }
}

class GeoFence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final String? doorId;
  final bool isActive;

  GeoFence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.doorId,
    this.isActive = true,
  });

  factory GeoFence.fromJson(Map<String, dynamic> json) {
    return GeoFence(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: json['radius'],
      doorId: json['doorId'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'doorId': doorId,
      'isActive': isActive,
    };
  }

  bool isInside(LocationData location) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      location.latitude,
      location.longitude,
    );
    return distance <= radius;
  }
}

class LocationProvider with ChangeNotifier {
  LocationData? _currentLocation;
  List<GeoFence> _geoFences = [];
  bool _isTracking = false;
  bool _hasPermission = false;
  LocationPermission? _permissionStatus;

  LocationData? get currentLocation => _currentLocation;
  List<GeoFence> get geoFences => _geoFences;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  LocationPermission? get permissionStatus => _permissionStatus;

  Future<void> initialize() async {
    await _checkPermission();
    await _loadGeoFences();
    
    if (_hasPermission) {
      await getCurrentLocation();
    }
  }

  Future<void> _checkPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _hasPermission = false;
        _permissionStatus = null;
        notifyListeners();
        return;
      }

      _permissionStatus = await Geolocator.checkPermission();
      if (_permissionStatus == LocationPermission.denied) {
        _permissionStatus = await Geolocator.requestPermission();
        if (_permissionStatus == LocationPermission.denied) {
          _hasPermission = false;
          notifyListeners();
          return;
        }
      }

      if (_permissionStatus == LocationPermission.deniedForever) {
        _hasPermission = false;
        notifyListeners();
        return;
      }

      _hasPermission = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking location permission: $e');
      }
      _hasPermission = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    await _checkPermission();
    if (_hasPermission) {
      await getCurrentLocation();
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      if (!_hasPermission) {
        await _checkPermission();
        if (!_hasPermission) return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
    }
  }

  Future<void> startTracking() async {
    if (!_hasPermission) {
      await _checkPermission();
      if (!_hasPermission) return;
    }

    _isTracking = true;
    notifyListeners();

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // minimum distance (in meters) before updates
      ),
    ).listen((Position position) {
      _currentLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      _checkGeoFences();
      notifyListeners();
    });
  }

  void stopTracking() {
    _isTracking = false;
    notifyListeners();
  }

  Future<void> _loadGeoFences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geoFencesJson = prefs.getString('geoFences');
      if (geoFencesJson != null) {
        final List<dynamic> geoFencesList = jsonDecode(geoFencesJson);
        _geoFences = geoFencesList
            .map((json) => GeoFence.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading geo-fences: $e');
      }
    }
  }

  Future<void> _saveGeoFences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'geoFences',
        jsonEncode(_geoFences.map((gf) => gf.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving geo-fences: $e');
      }
    }
  }

  Future<void> addGeoFence({
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
    String? doorId,
  }) async {
    final geoFence = GeoFence(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      doorId: doorId,
    );

    _geoFences.add(geoFence);
    await _saveGeoFences();
    notifyListeners();
  }

  Future<void> updateGeoFence(GeoFence updatedGeoFence) async {
    final index = _geoFences.indexWhere((gf) => gf.id == updatedGeoFence.id);
    if (index != -1) {
      _geoFences[index] = updatedGeoFence;
      await _saveGeoFences();
      notifyListeners();
    }
  }

  Future<void> deleteGeoFence(String geoFenceId) async {
    _geoFences.removeWhere((gf) => gf.id == geoFenceId);
    await _saveGeoFences();
    notifyListeners();
  }

  void _checkGeoFences() {
    if (_currentLocation == null) return;

    for (final geoFence in _geoFences) {
      if (geoFence.isActive && geoFence.isInside(_currentLocation!)) {
        // Trigger event when user enters a geo-fence
        // This could be used to automatically unlock doors when user is near
      }
    }
  }

  List<GeoFence> getNearbyGeoFences({double maxDistance = 100.0}) {
    if (_currentLocation == null) return [];

    return _geoFences.where((geoFence) {
      final distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        geoFence.latitude,
        geoFence.longitude,
      );
      return distance <= maxDistance;
    }).toList();
  }
}
