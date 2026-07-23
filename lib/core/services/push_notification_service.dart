import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/router/app_router.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';

// Background messaging handler (must be a top-level function annotated with @pragma)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase (needed if not initialized)
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling background message: ${message.messageId}");
    print("Background data: ${message.data}");
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  return service;
});

class PushNotificationService {
  final Ref _ref;
  FirebaseMessaging? _fcmInstance;
  FirebaseMessaging get _fcm => _fcmInstance ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  PushNotificationService(this._ref);

  Future<void> init() async {
    if (kIsWeb) {
      print('🔔 FCM: Web is not supported. Skipping push notification initialization.');
      return;
    }
    print('🔔 FCM: Starting PushNotificationService initialization...');
    if (_initialized) {
      print('🔔 FCM: Already initialized, skipping.');
      return;
    }

    try {
      // 0. Initialize Firebase
      print('🔔 FCM: Initializing Firebase...');
      await Firebase.initializeApp();
      print('🔔 FCM: Firebase initialized successfully.');

      // 1. Initialize Firebase Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Initialize Local Notifications Plugin FIRST
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(
                jsonDecode(details.payload!),
              );
              _handleNotificationTap(data);
            } catch (e) {
              if (kDebugMode) print("Error parsing notification tap payload: $e");
            }
          }
        },
      );

      // 3. Setup Foreground Notification channel details (Android)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Request Permissions (iOS & Android 13+)
      print('🔔 FCM: Requesting notification permissions...');
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('🔔 FCM: Permission authorizationStatus = ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('🔔 FCM: Push notifications authorized by user');

        // Setup iOS foreground notification options
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Get FCM Token
        print('🔔 FCM: Fetching FCM token...');
        final token = await _fcm.getToken();
        print('🔔 FCM: Token fetched: ${token != null ? token.substring(0, 15) : 'null'}...');
        if (token != null) {
          await uploadToken(token);
        } else {
          print('⚠️ FCM: Token is null, cannot upload!');
        }

        // Listen for token updates
        _fcm.onTokenRefresh.listen((newToken) {
          print('🔔 FCM: Token refreshed: ${newToken.substring(0, 15)}...');
          uploadToken(newToken);
        });
      } else {
        print('❌ FCM: Push notifications denied by user');
      }

      // 5. Handle messages when the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) print("Foreground message received: ${message.messageId}");

        final RemoteNotification? notification = message.notification;

        if (notification != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      // 6. Handle notification click when app is opened from a terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

      // 7. Handle notification click when app is in background state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      _initialized = true;
    } catch (e) {
      if (kDebugMode) print("Error initializing PushNotificationService: $e");
    }
  }

  /// Upload the FCM registration token to our backend database
  Future<void> uploadToken(String token) async {
    print('🔔 FCM: uploadToken called with token length = ${token.length}');
    try {
      final deviceType = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      final api = _ref.read(apiServiceProvider);

      print('🔔 FCM: Sending POST to users/devices with token = ${token.substring(0, 15)}...');
      final response = await api.post('users/devices', data: {
        'fcmToken': token,
        'deviceType': deviceType,
      });

      print("🚀 FCM: Token uploaded to backend successfully! Response: $response");
    } catch (e) {
      print("⚠️ FCM: Failed to upload FCM token to backend: $e");
    }
  }

  /// Delete the FCM token from the backend database (for logout cleanups)
  Future<void> deleteToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final api = _ref.read(apiServiceProvider);
        await api.delete('users/devices?fcmToken=$token');
      }

      _initialized = false; // Reset initialization state so next login re-registers token
      if (kDebugMode) {
        print("🗑️ FCM Token deleted from backend: $token");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Failed to delete FCM token from backend: $e");
      }
    }
  }

  /// Routing logic on notification click
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) print("Notification Tapped! Payload: $data");

    final router = _ref.read(routerProvider);
    final type = data['type'] as String?;
    final referenceId = data['referenceId'] as String?;

    if (type == null) {
      router.push(AppRoutes.notifications);
      return;
    }

    switch (type) {
      case 'group_invitation':
        router.push(AppRoutes.groupInvitations);
        break;
      case 'invitation_accepted':
      case 'settlement_created':
      case 'settlement_completed':
      case 'settlement_rejected':
      case 'expense_created':
      case 'group_locked':
      case 'group_unlocked':
      case 'reports_ready':
      case 'settlement_pending':
      case 'group_balance':
        final groupId = data['groupId'] as String? ?? referenceId;
        if (groupId != null && groupId.isNotEmpty) {
          // Navigate to group detail page
          router.push('/groups/$groupId');
        } else {
          router.push(AppRoutes.notifications);
        }
        break;
      default:
        router.push(AppRoutes.notifications);
        break;
    }
  }
}
