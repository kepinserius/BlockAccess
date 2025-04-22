import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Notification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? doorId;
  final String? userId;
  final bool isRead;
  final NotificationType type;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.doorId,
    this.userId,
    this.isRead = false,
    required this.type,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      timestamp: DateTime.parse(json['timestamp']),
      doorId: json['doorId'],
      userId: json['userId'],
      isRead: json['isRead'] ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.general,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'doorId': doorId,
      'userId': userId,
      'isRead': isRead,
      'type': type.toString().split('.').last,
    };
  }

  Notification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    String? doorId,
    String? userId,
    bool? isRead,
    NotificationType? type,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      doorId: doorId ?? this.doorId,
      userId: userId ?? this.userId,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}

enum NotificationType {
  accessGranted,
  accessRevoked,
  accessAttempt,
  systemUpdate,
  general,
}

class NotificationProvider with ChangeNotifier {
  final List<Notification> _notifications = [];
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  List<Notification> get notifications => _notifications;
  List<Notification> get unreadNotifications =>
      _notifications.where((notification) => !notification.isRead).toList();
  int get unreadCount => unreadNotifications.length;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle iOS notification
      },
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload != null) {
          // Navigate to specific screen based on payload
        }
      },
    );

    // Load saved notifications
    await _loadNotifications();
    _isInitialized = true;
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('notifications');
      if (notificationsJson != null) {
        final List<dynamic> notificationsList = jsonDecode(notificationsJson);
        _notifications.clear();
        _notifications.addAll(
          notificationsList
              .map((json) => Notification.fromJson(json))
              .toList(),
        );
        // Sort by timestamp (newest first)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notifications: $e');
      }
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notifications',
        jsonEncode(_notifications.map((n) => n.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notifications: $e');
      }
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    String? doorId,
    String? userId,
    required NotificationType type,
    bool showLocalNotification = true,
  }) async {
    final notification = Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      doorId: doorId,
      userId: userId,
      isRead: false,
      type: type,
    );

    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();

    if (showLocalNotification) {
      await _showLocalNotification(notification);
    }
  }

  Future<void> _showLocalNotification(Notification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'block_access_channel',
      'BlockAccess Notifications',
      channelDescription: 'Notifications from BlockAccess app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      int.parse(notification.id),
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(notification.toJson()),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final index =
        _notifications.indexWhere((notification) => notification.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((notification) => notification.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }
}
