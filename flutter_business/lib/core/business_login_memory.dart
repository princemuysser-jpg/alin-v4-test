import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembered credentials are opt-in. Never put a password in SharedPreferences.
///
/// Mobile passwords are encrypted by the OS-backed secure storage plugin.
/// On web, rely on the browser password manager/autofill; only the username
/// and the user's opt-in choice are saved here.
class BusinessLoginRecall {
  final bool remember;
  final String username;
  final String password;

  const BusinessLoginRecall({
    this.remember = false,
    this.username = '',
    this.password = '',
  });
}

class BusinessLoginMemory {
  static const _rememberKey = 'alin_business_remember_login_v2';
  static const _usernameKey = 'alin_business_saved_username_v2';
  static const _passwordKey = 'alin_business_saved_password_v2';
  static const _secure = FlutterSecureStorage();

  static Future<BusinessLoginRecall> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) {
      return const BusinessLoginRecall();
    }
    final name = prefs.getString(_usernameKey) ?? '';
    String savedPassword = '';
    if (!kIsWeb) {
      try {
        savedPassword = await _secure.read(key: _passwordKey) ?? '';
      } catch (_) {
        // A device key may be unavailable after reinstall/restore.
        // Keep the remembered name and request the password normally.
      }
    }
    return BusinessLoginRecall(
      remember: true,
      username: name,
      password: savedPassword,
    );
  }

  static Future<void> save({
    required String username,
    required String password,
    required bool remember,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      // Only mark credentials remembered after secure storage succeeds.
      if (!kIsWeb) {
        await _secure.write(key: _passwordKey, value: password);
      }
      await prefs.setString(_usernameKey, username.trim());
      await prefs.setBool(_rememberKey, true);
    } else {
      // Do not retain stale credentials on opt-out or user switching.
      await prefs.setBool(_rememberKey, false);
      await prefs.remove(_usernameKey);
      if (!kIsWeb) {
        await _secure.delete(key: _passwordKey);
      }
    }
  }
}
