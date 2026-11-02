/// Destination details are sourced from the customer's order, not the courier's
/// location. Maps itself handles requesting the courier's current location.
class CourierNavigationTarget {
  final double? latitude;
  final double? longitude;
  final int? accuracyMeters;
  final Uri? savedMapUrl;
  final String area;
  final String landmark;

  const CourierNavigationTarget({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.savedMapUrl,
    this.area = '',
    this.landmark = '',
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasUsablePlace => savedMapUrl != null || area.isNotEmpty || landmark.isNotEmpty;
  bool get hasDestination => hasCoordinates || hasUsablePlace;
  bool get needsConfirmation => !hasCoordinates || (accuracyMeters != null && accuracyMeters! > 100);
  String get qualityLabel {
    if (hasCoordinates) {
      if (accuracyMeters != null && accuracyMeters! > 100) {
        return 'GPS تقريبي (±$accuracyMeters م)';
      }
      if (accuracyMeters != null && accuracyMeters! > 0) {
        return 'GPS ±$accuracyMeters م';
      }
      return 'موقع GPS محدد';
    }
    if (savedMapUrl != null) return 'رابط موقع من الطالب';
    if (area.isNotEmpty || landmark.isNotEmpty) return 'عنوان تقريبي فقط';
    return 'الموقع غير محدد';
  }

  Uri? get navigationUrl {
    if (hasCoordinates) {
      return Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });
    }
    if (savedMapUrl != null) return savedMapUrl;
    if (!hasUsablePlace) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': [
        if (landmark.isNotEmpty) landmark,
        if (area.isNotEmpty) area,
        'كركوك',
        'العراق',
      ].join('، '),
    });
  }

  /// Waze Universal Link: opens the installed app on mobile, or its website.
  /// Keep the pin from the customer's order; do not collect courier GPS here.
  Uri? get wazeUrl {
    if (hasCoordinates) {
      return Uri.https('waze.com', '/ul', {
        'll': '$latitude,$longitude',
        'navigate': 'yes',
        'utm_source': 'alin_business',
      });
    }
    // A saved Google Maps short-link cannot safely be translated to Waze.
    // Search the human-readable destination only when it exists.
    if (area.isEmpty && landmark.isEmpty) return null;
    return Uri.https('waze.com', '/ul', {
      'q': [
        if (landmark.isNotEmpty) landmark,
        if (area.isNotEmpty) area,
        'كركوك',
        'العراق',
      ].join('، '),
      'utm_source': 'alin_business',
    });
  }

  String? get coordinatesForCopy =>
      hasCoordinates ? '$latitude,$longitude' : null;

  static CourierNavigationTarget fromOrder(Map<String, dynamic> order) {
    final rows = <Map<String, dynamic>>[order];
    for (final item in (order['_items'] as List? ?? const [])) {
      if (item is Map) rows.add(Map<String, dynamic>.from(item));
    }
    double? parsePart(dynamic value, {required double max}) {
      if (value == null || '$value'.trim().isEmpty) return null;
      final number = double.tryParse('$value');
      if (number == null || !number.isFinite || number.abs() > max) return null;
      return number;
    }

    String value(dynamic data) => data == null ? '' : '$data'.trim();
    final area = rows.map((row) => value(row['delivery_area']))
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final landmark = rows.map((row) => value(row['delivery_landmark']))
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    // A checkout group can contain several rows; the anchor may not hold
    // the student's pin. Pick the most accurate valid point from any row.
    CourierNavigationTarget? best;
    for (final row in rows) {
      final lat = parsePart(row['delivery_latitude'], max: 90);
      final lng = parsePart(row['delivery_longitude'], max: 180);
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      final accuracy = num.tryParse(value(row['delivery_location_accuracy']))?.round();
      final accuracyMeters = accuracy != null && accuracy > 0 ? accuracy : null;
      final candidate = CourierNavigationTarget(
        latitude: lat, longitude: lng,
        accuracyMeters: accuracyMeters, area: area, landmark: landmark,
      );
      if (best == null ||
          (candidate.accuracyMeters ?? 999999) < (best.accuracyMeters ?? 999999)) {
        best = candidate;
      }
    }
    if (best != null) return best;

    for (final row in rows) {
      final raw = value(row['delivery_location_url']);
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty &&
          _isTrustedMapHost(uri.host)) {
        return CourierNavigationTarget(savedMapUrl: uri, area: area, landmark: landmark);
      }
    }
    return CourierNavigationTarget(area: area, landmark: landmark);
  }

  static bool _isTrustedMapHost(String host) {
    final h = host.toLowerCase();
    return h == 'maps.app.goo.gl' ||
        h == 'maps.google.com' || h == 'google.com' ||
        h.endsWith('.google.com') || h == 'openstreetmap.org' ||
        h.endsWith('.openstreetmap.org');
  }
}
