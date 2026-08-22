import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static bool _checkedThisLaunch = false;

  static Future<void> maybePrompt(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;

    if (!_boolValue(settings['android_update_enabled'])) return;

    final latest = '${settings['android_latest_version'] ?? ''}'.trim();
    if (latest.isEmpty) return;

    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final current = packageInfo.version.trim();
    if (_compareVersions(current, latest) >= 0) return;

    final minimum = '${settings['android_min_version'] ?? ''}'.trim();
    final force = _boolValue(settings['android_force_update']) ||
        (minimum.isNotEmpty && _compareVersions(current, minimum) < 0);
    final message = '${settings['android_update_message'] ?? ''}'.trim();
    final configuredUrl = '${settings['android_update_url'] ?? ''}'.trim();
    final updateUrl = configuredUrl.isNotEmpty
        ? configuredUrl
        : 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('تحديث جديد لمنصة آلين')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.isEmpty
                    ? 'يتوفر إصدار أحدث من منصة آلين. حدّث التطبيق للحصول على آخر التحسينات والميزات.'
                    : message,
              ),
              const SizedBox(height: 10),
              Text(
                'الإصدار الجديد: $latest',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('لاحقًا'),
              ),
            FilledButton.icon(
              onPressed: () {
                unawaited(_openUpdate(updateUrl));
                if (!force) Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openUpdate(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _compareVersions(String left, String right) {
    List<int> parts(String value) => value
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .take(4)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    final a = parts(left);
    final b = parts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
