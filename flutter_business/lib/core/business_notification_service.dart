import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessNotificationService {
  static const _channelId = 'alin_business_orders';
  static const _channelName = 'طلبات آلين للأعمال';
  static const _deviceKey = 'alin_business_device_id_v1';

  final SupabaseClient client;
  final FlutterLocalNotificationsPlugin local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  Future<void> Function(Map<String, dynamic>)? onOpen;
  Future<void> Function()? onReceived;
  bool _started = false;

  BusinessNotificationService({
    required this.client,
    this.onOpen,
    this.onReceived,
  });

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> start() async {
    if (_started || (!_isAndroid && !_isIOS)) return;
    _started = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        await onOpen?.call({'url': payload, 'link': payload});
      },
    );

    if (_isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'تنبيهات الطلبات الجديدة وتحويلات المندوب والمكتبة',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    if (_isIOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await requestPermissionAndRegister();

    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForeground(message));
    });
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(onOpen?.call(_payload(message)));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      unawaited(onOpen?.call(_payload(initial)));
    }
  }

  Future<bool> requestPermissionAndRegister() async {
    if (!_isAndroid && !_isIOS) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return false;

      if (_isIOS) {
        for (var i = 0; i < 12; i++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!_started) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {}
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey)?.trim() ?? '';
    if (id.length >= 16) return id;
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    id = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_deviceKey, id);
    return id;
  }

  Future<void> _registerToken(String token) async {
    if (client.auth.currentSession == null) return;
    try {
      await client.rpc('alin_register_business_fcm_token', params: {
        'p_token': token,
        'p_device': await _deviceId(),
        'p_platform': _isIOS ? 'ios' : 'android',
      });
    } catch (_) {}
  }

  Map<String, dynamic> _payload(RemoteMessage message) => <String, dynamic>{
        ...message.data,
        if (message.messageId != null) 'message_id': message.messageId!,
        if (message.notification?.title != null) 'title': message.notification!.title!,
        if (message.notification?.body != null) 'message': message.notification!.body!,
      };

  Future<void> _handleForeground(RemoteMessage message) async {
    final title = (message.notification?.title ?? '${message.data['title'] ?? 'آلين للأعمال'}').trim();
    final body = (message.notification?.body ?? '${message.data['message'] ?? ''}').trim();
    final link = '${message.data['url'] ?? message.data['link'] ?? ''}'.trim();

    if (_isAndroid && body.isNotEmpty) {
      await local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title.isEmpty ? 'آلين للأعمال' : title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'تنبيهات الطلبات الجديدة وتحويلات المندوب والمكتبة',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
          ),
        ),
        payload: link,
      );
    }
    await onReceived?.call();
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _started = false;
  }
}
