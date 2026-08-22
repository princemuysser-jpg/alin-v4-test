import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_store.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('com.alin.platform/native_notifications');

  final SupabaseClient client;
  final DeviceStore store;
  final String? Function() studentTokenProvider;
  final Future<void> Function()? onNotificationReceived;
  RealtimeChannel? _realtime;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _started = false;
  final Set<String> _recentIds = <String>{};

  NativeNotificationService({
    required this.client,
    required this.store,
    required this.studentTokenProvider,
    this.onNotificationReceived,
  });

  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Permission is intentionally NOT requested here. The store UI owns the
      // permission prompt so nothing appears over the splash screen.
      await _registerCurrentToken();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_handleFcmMessage(message));
      });
    }

    _realtime = client
        .channel('alin_flutter_public_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) => unawaited(_handleRealtimeInsert(payload.newRecord)),
        )
        .subscribe();
  }


  Future<bool> notificationPermissionGranted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final nativeGranted = await _channel.invokeMethod<bool>('permissionGranted');
      if (nativeGranted != null) return nativeGranted;
    } catch (_) {}
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (await notificationPermissionGranted()) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      if (granted == true) {
        await _registerCurrentToken();
        return true;
      }
      return notificationPermissionGranted();
    } catch (_) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) await _registerCurrentToken();
        return granted;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    try {
      final studentToken = studentTokenProvider();
      await client.rpc('alin_register_fcm_token', params: {
        'p_token': token,
        'p_device': store.deviceId(),
        'p_student_token': studentToken,
        'p_student_device': studentToken == null ? null : store.deviceId(),
        'p_platform': 'android',
      });
    } catch (_) {}
  }

  Future<void> _handleFcmMessage(RemoteMessage message) async {
    final id = '${message.data['notification_id'] ?? message.messageId ?? ''}'.trim();
    if (id.isNotEmpty) _remember(id);
    final title = (message.notification?.title ?? '${message.data['title'] ?? 'منصة آلين'}').trim();
    final body = (message.notification?.body ?? '${message.data['message'] ?? message.data['body'] ?? ''}').trim();
    if (body.isNotEmpty) {
      try {
        await _channel.invokeMethod<void>('showNotification', {'title': title.isEmpty ? 'منصة آلين' : title, 'message': body});
      } catch (_) {}
    }
    try { await onNotificationReceived?.call(); } catch (_) {}
  }

  Future<void> _handleRealtimeInsert(Map<String, dynamic> row) async {
    final status = '${row['status'] ?? ''}'.trim().toLowerCase();
    final role = '${row['role'] ?? ''}'.trim().toLowerCase();
    final accountId = '${row['account_id'] ?? ''}'.trim();
    final id = '${row['id'] ?? ''}'.trim();
    final title = '${row['title'] ?? 'منصة آلين'}'.trim();
    final message = '${row['message'] ?? ''}'.trim();
    final expiresRaw = '${row['expires_at'] ?? ''}'.trim();
    if (status != 'active' || accountId.isNotEmpty || (role != 'all' && role != 'student')) return;
    if (message.isEmpty || (id.isNotEmpty && _recentIds.contains(id))) return;
    if (expiresRaw.isNotEmpty) {
      final expires = DateTime.tryParse(expiresRaw)?.toUtc();
      if (expires != null && expires.isBefore(DateTime.now().toUtc())) return;
    }
    if (id.isNotEmpty) _remember(id);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try { await _channel.invokeMethod<void>('showNotification', {'title': title.isEmpty ? 'منصة آلين' : title, 'message': message}); } catch (_) {}
    }
    try { await onNotificationReceived?.call(); } catch (_) {}
  }

  void _remember(String id) {
    _recentIds.add(id);
    if (_recentIds.length > 80) _recentIds.remove(_recentIds.first);
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    final realtime = _realtime;
    _realtime = null;
    _started = false;
    if (realtime != null) {
      try { await client.removeChannel(realtime); } catch (_) {}
    }
  }
}
