import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateRequirement {
  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final String message;
  final String updateUrl;
  final bool force;

  const AppUpdateRequirement({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.message,
    required this.updateUrl,
    required this.force,
  });

  String get latestLabel => latestBuild > 0 ? '$latestVersion ($latestBuild)' : latestVersion;
}

class AppUpdateService {
  static bool _checkedThisLaunch = false;

  static Future<AppUpdateRequirement?> evaluate(
    Map<String, dynamic> settings,
  ) async {
    if (kIsWeb) return null;

    final prefix = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    if (prefix == null) return null;

    dynamic setting(String suffix) {
      final platformKey = '${prefix}_$suffix';
      if (settings.containsKey(platformKey)) return settings[platformKey];
      // Backward compatibility for iOS builds that originally used android_* settings.
      if (prefix == 'ios') return settings['android_$suffix'];
      return null;
    }

    if (!_boolValue(setting('update_enabled'))) return null;

    final latestVersion = '${setting('latest_version') ?? ''}'.trim();
    if (latestVersion.isEmpty) return null;
    final latestBuild = _intValue(setting('latest_build'));

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

    final versionCompare = _compareVersions(currentVersion, latestVersion);
    final updateAvailable = versionCompare < 0 ||
        (versionCompare == 0 && latestBuild > 0 && currentBuild < latestBuild);
    if (!updateAvailable) return null;

    final minimumVersion = '${setting('min_version') ?? ''}'.trim();
    final minimumBuild = _intValue(setting('min_build'));
    var force = _boolValue(setting('force_update'));

    if (minimumVersion.isNotEmpty) {
      final minimumCompare = _compareVersions(currentVersion, minimumVersion);
      if (minimumCompare < 0 ||
          (minimumCompare == 0 && minimumBuild > 0 && currentBuild < minimumBuild)) {
        force = true;
      }
    }

    final message = '${setting('update_message') ?? ''}'.trim();
    final configuredUrl = '${setting('update_url') ?? ''}'.trim();
    final fallbackUrl = prefix == 'ios'
        ? 'https://apps.apple.com/app/id6806064802'
        : 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';

    return AppUpdateRequirement(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      message: message.isEmpty
          ? 'يتوفر إصدار أحدث من منصة آلين. يجب تحديث التطبيق للحصول على آخر التحسينات والميزات.'
          : message,
      updateUrl: configuredUrl.isNotEmpty ? configuredUrl : fallbackUrl,
      force: force,
    );
  }

  static Future<void> maybePrompt(
    BuildContext context,
    Map<String, dynamic> settings,
  ) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;

    final requirement = await evaluate(settings);
    if (requirement == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !requirement.force,
      builder: (dialogContext) => PopScope(
        canPop: !requirement.force,
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
              Text(requirement.message),
              const SizedBox(height: 10),
              Text(
                'الإصدار الجديد: ${requirement.latestLabel}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            if (!requirement.force)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('لاحقًا'),
              ),
            FilledButton.icon(
              onPressed: () {
                unawaited(openUpdate(requirement.updateUrl));
                if (!requirement.force) Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> openUpdate(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
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
