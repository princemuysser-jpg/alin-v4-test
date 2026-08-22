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
  final Future<bool> Function()? notificationPermissionPrimer;
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
    this.notificationPermissionPrimer,
  });

  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // If notification permission is still not granted, show Alin's short benefit
      // message first. The primer returns on every fresh launch while permission
      // remains denied, and disappears permanently once Android reports granted.
      var granted = false;
      try {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {}

      if (!granted) {
        var requestNow = true;
        try {
          requestNow = await notificationPermissionPrimer?.call() ?? true;
        } catch (_) {}

        if (requestNow) {
          // Use one Android permission path only, so the user never sees two
          // permission dialogs in the same launch.
          try {
            await _channel.invokeMethod<bool>('requestPermission');
          } catch (_) {
            // Fallback only if the native MethodChannel is unavailable.
            try {
              await FirebaseMessaging.instance.requestPermission(
                alert: true,
                badge: true,
                sound: true,
              );
            } catch (_) {}
          }
        }
      }
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
