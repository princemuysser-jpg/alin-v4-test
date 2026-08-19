import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceStore {
  static const _deviceKey = 'alin_flutter_device_v1';
  static const _studentProfileKey = 'alin_flutter_student_profile_v2';
  static const _studentTokenKey = 'alin_flutter_student_token_v2';
  static const _legacyStudentKey = 'alin_flutter_student_session_v1';
  static const _cartKey = 'alin_flutter_cart_v1';
  static const _favoritesKey = 'alin_flutter_favorites_v1';
  static const _readNotificationsKey = 'alin_flutter_read_notifications_v1';

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;

  DeviceStore(
    this.prefs, {
    FlutterSecureStorage? secureStorage,
  }) : secure = secureStorage ?? const FlutterSecureStorage();

  String deviceId() {
    final existing = prefs.getString(_deviceKey);
    if (existing != null && existing.length >= 16) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final value = base64Url.encode(bytes).replaceAll('=', '');
    prefs.setString(_deviceKey, value);
    return value;
  }

  Future<Map<String, dynamic>?> readStudentSession() async {
    try {
      var token = await secure.read(key: _studentTokenKey);
      var profileRaw = prefs.getString(_studentProfileKey);

      // One-time migration from the first Flutter prototype.
      if ((token == null || token.isEmpty || profileRaw == null) && prefs.containsKey(_legacyStudentKey)) {
        final legacyRaw = prefs.getString(_legacyStudentKey);
        final legacy = legacyRaw == null ? null : jsonDecode(legacyRaw);
        if (legacy is Map && legacy['student'] is Map && '${legacy['token'] ?? ''}'.isNotEmpty) {
          token = '${legacy['token']}';
          profileRaw = jsonEncode(Map<String, dynamic>.from(legacy['student'] as Map));
          await secure.write(key: _studentTokenKey, value: token);
          await prefs.setString(_studentProfileKey, profileRaw);
        }
        await prefs.remove(_legacyStudentKey);
      }

      if (token == null || token.isEmpty || profileRaw == null || profileRaw.isEmpty) return null;
      final profile = jsonDecode(profileRaw);
      if (profile is! Map) return null;
      return {
        'student': Map<String, dynamic>.from(profile),
        'token': token,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> writeStudentSession(Map<String, dynamic>? value) async {
    if (value == null) {
      await secure.delete(key: _studentTokenKey);
      await prefs.remove(_studentProfileKey);
      await prefs.remove(_legacyStudentKey);
      return;
    }
    final token = '${value['token'] ?? ''}';
    final student = value['student'];
    if (token.isEmpty || student is! Map) return;
    await secure.write(key: _studentTokenKey, value: token);
    await prefs.setString(_studentProfileKey, jsonEncode(Map<String, dynamic>.from(student)));
  }

  List<Map<String, dynamic>> readCart() => _readList(_cartKey);
  Future<void> writeCart(List<Map<String, dynamic>> value) => prefs.setString(_cartKey, jsonEncode(value));

  Set<String> readFavorites() => _readStringSet(_favoritesKey);
  Future<void> writeFavorites(Set<String> value) => prefs.setString(_favoritesKey, jsonEncode(value.toList()));

  Set<String> readReadNotifications() => _readStringSet(_readNotificationsKey);
  Future<void> writeReadNotifications(Set<String> value) =>
      prefs.setString(_readNotificationsKey, jsonEncode(value.toList()));

  List<Map<String, dynamic>> _readList(String key) {
    try {
      final raw = prefs.getString(key);
      final value = raw == null ? const [] : jsonDecode(raw);
      if (value is List) {
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Set<String> _readStringSet(String key) {
    try {
      final raw = prefs.getString(key);
      final value = raw == null ? const [] : jsonDecode(raw);
      if (value is List) return value.map((e) => e.toString()).toSet();
    } catch (_) {}
    return <String>{};
  }
}
