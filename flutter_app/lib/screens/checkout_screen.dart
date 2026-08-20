import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_scope.dart';
import '../core/alin_config.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const MethodChannel _nativeLocationChannel = MethodChannel('com.alin.platform/native_location');
  final name = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();
  final coupon = TextEditingController();
  final landmark = TextEditingController();
  String fulfillmentType = 'pickup';
  LibraryModel? library;
  DeliveryAreaModel? area;
  _DeliveryLocation? deliveryPosition;
  bool locationBusy = false;
  String? locationError;
  Map<String, dynamic>? cartQuote;
  bool quoteRequested = false;
  bool busy = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final student = AppScope.of(context).student;
    if (student != null) {
      if (name.text.isEmpty) name.text = student.name;
      if (phone.text.isEmpty) phone.text = student.phone;
    }
    if (coupon.text.isEmpty) {
      final pending = AppScope.of(context).takePendingCoupon();
      if (pending != null && pending.isNotEmpty) coupon.text = pending;
    }
    final hasPhysical = AppScope.of(context).cart.any((line) => line.item.isProduct);
    if (hasPhysical && fulfillmentType == 'pickup') fulfillmentType = 'home_delivery';
    if (!quoteRequested && coupon.text.isNotEmpty) {
      quoteRequested = true;
      Future.microtask(_loadQuote);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    coupon.dispose();
    landmark.dispose();
    super.dispose();
  }


  Future<void> _loadQuote() async {
    try {
      final result = await AppScope.of(context).quoteCart(couponCode: coupon.text.trim());
      if (!mounted) return;
      setState(() => cartQuote = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  num _quoteNumber(String key, num fallback) {
    final value = cartQuote?[key];
    if (value is num) return value;
    return num.tryParse('$value') ?? fallback;
  }

  Future<Position?> _tryCurrentPosition(LocationSettings settings) async {
    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<_DeliveryLocation?> _raceFreshLocation() async {
    final completer = Completer<_DeliveryLocation?>();
    var finished = 0;
    const sourceCount = 4;

    void settle(_DeliveryLocation? value) {
      if (value != null && !completer.isCompleted) {
        completer.complete(value);
      }
      finished++;
      if (finished >= sourceCount && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    Future<void> runGoogleFused() async {
      try {
        settle(await _tryGoogleFusedLocation());
      } catch (_) {
        settle(null);
      }
    }

    Future<void> runNative() async {
      try {
        settle(await _tryNativeQuickLocation());
      } catch (_) {
        settle(null);
      }
    }

    Future<void> runFlutterLocation() async {
      try {
        final position = await _tryCurrentPosition(
          const LocationSettings(accuracy: LocationAccuracy.high),
        );
        settle(position == null ? null : _DeliveryLocation.fromPosition(position));
      } catch (_) {
        settle(null);
      }
    }

    Future<void> runWebEngineLocation() async {
      try {
        settle(await _tryHiddenWebLocation());
      } catch (_) {
        settle(null);
      }
    }

    unawaited(runGoogleFused());
    unawaited(runNative());
    unawaited(runFlutterLocation());
    unawaited(runWebEngineLocation());

    return completer.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => null,
    );
  }

  bool _usableCachedPosition(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= const Duration(seconds: 30) && position.accuracy <= 2000;
  }

  Future<_DeliveryLocation?> _tryGoogleFusedLocation() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _nativeLocationChannel.invokeMethod<dynamic>('getGoogleFusedLocation');
      if (raw is! Map) return null;
      final latitude = num.tryParse('${raw['latitude']}')?.toDouble();
      final longitude = num.tryParse('${raw['longitude']}')?.toDouble();
      final accuracy = num.tryParse('${raw['accuracy']}')?.toDouble() ?? 0;
      if (latitude == null || longitude == null) return null;
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
      return _DeliveryLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_DeliveryLocation?> _tryNativeQuickLocation() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _nativeLocationChannel.invokeMethod<dynamic>('getQuickLocation');
      if (raw is! Map) return null;
      final latitude = num.tryParse('${raw['latitude']}')?.toDouble();
      final longitude = num.tryParse('${raw['longitude']}')?.toDouble();
      final accuracy = num.tryParse('${raw['accuracy']}')?.toDouble() ?? 0;
      if (latitude == null || longitude == null) return null;
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
      return _DeliveryLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_DeliveryLocation?> _tryHiddenWebLocation() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _nativeLocationChannel.invokeMethod<dynamic>('getWebLocation');
      if (raw is! Map) return null;
      final latitude = num.tryParse('${raw['latitude']}')?.toDouble();
      final longitude = num.tryParse('${raw['longitude']}')?.toDouble();
      final accuracy = num.tryParse('${raw['accuracy']}')?.toDouble() ?? 0;
      if (latitude == null || longitude == null) return null;
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
      return _DeliveryLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _locationDiagnostics() async {
    if (defaultTargetPlatform != TargetPlatform.android) return '';
    try {
      final raw = await _nativeLocationChannel.invokeMethod<dynamic>('getLocationDiagnostics');
      if (raw is! Map) return '';
      final fine = raw['fine'];
      final coarse = raw['coarse'];
      final gms = raw['gms'];
      final googleAccuracy = raw['google_accuracy'];
      final locationEnabled = raw['location_enabled'];
      final providers = '${raw['providers'] ?? ''}';
      return 'FINE=$fine COARSE=$coarse GMS=$gms ACC=$googleAccuracy LOC=$locationEnabled ${providers.isEmpty ? '' : 'PROV=$providers'}'.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> captureLocation() async {
    if (locationBusy) return;
    setState(() {
      locationBusy = true;
      locationError = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('فعّل خدمة الموقع من الجهاز حتى نحدد موقع التوصيل');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('لازم تسمح للتطبيق باستخدام الموقع للتوصيل');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('صلاحية الموقع مرفوضة نهائياً. فعّلها من إعدادات التطبيق');
      }

      _DeliveryLocation? selected;

      // Accept a very recent fix immediately. Otherwise race Google Play Services
      // Fused Location, Android system providers, Flutter geolocation, and the hidden
      // WebView fallback. Nothing opens outside the app; the first valid coordinates win.
      try {
        final cached = await Geolocator.getLastKnownPosition();
        if (cached != null && _usableCachedPosition(cached)) {
          selected = _DeliveryLocation.fromPosition(cached);
        }
      } catch (_) {}

      selected ??= await _raceFreshLocation();

      if (selected == null) {
        final diagnostic = await _locationDiagnostics();
        throw Exception(
          diagnostic.isEmpty
              ? 'تعذر تحديد موقعك. تأكد من تشغيل خدمة الموقع واسمح للتطبيق بالموقع ثم حاول مرة ثانية'
              : 'تعذر تحديد موقعك. تشخيص الجهاز: $diagnostic',
        );
      }

      if (!mounted) return;
      setState(() {
        deliveryPosition = selected;
        locationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final raw = '$e'.replaceFirst('Exception: ', '');
      setState(() => locationError = raw.isEmpty ? 'تعذر تحديد الموقع. اضغط تحديث الموقع وحاول مرة ثانية.' : raw);
    } finally {
      if (mounted) setState(() => locationBusy = false);
    }
  }

  Future<void> submit() async {
    final c = AppScope.of(context);
    final customerName = c.student?.name ?? name.text.trim();
    final customerPhone = c.student?.phone ?? phone.text.trim();
    if (customerName.length < 2) return _setError('اكتب اسم الطالب بصورة صحيحة');
    if (!RegExp(r'^\+?[0-9٠-٩]{7,15}$').hasMatch(customerPhone.replaceAll(' ', ''))) return _setError('اكتب رقم هاتف صحيح');

    final hasPhysical = c.cart.any((line) => line.item.isProduct);
    if (hasPhysical && fulfillmentType == 'pickup') {
      fulfillmentType = 'home_delivery';
    }

    Map<String, dynamic> fulfillment;
    if (fulfillmentType == 'pickup') {
      if (library == null) return _setError('اختر مكتبة الاستلام');
      fulfillment = {
        'fulfillment_type': 'pickup',
        'library_id': library!.id,
        'pickup_library_id': library!.id,
        'library_name': library!.name,
        'pickup_library_name': library!.name,
      };
    } else {
      if (area == null) return _setError('اختر منطقة التوصيل');
      if (deliveryPosition == null) return _setError('حدد موقعك GPS حتى يعرف المندوب مكان التوصيل');
      fulfillment = {
        'fulfillment_type': 'home_delivery',
        'delivery_area': area!.name,
        'delivery_landmark': landmark.text.trim(),
        'delivery_latitude': deliveryPosition!.latitude,
        'delivery_longitude': deliveryPosition!.longitude,
        'delivery_location_accuracy': deliveryPosition!.accuracy.round(),
      };
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await c.placeOrder(
        name: customerName,
        phone: customerPhone,
        notes: notes.text,
        fulfillment: fulfillment,
        couponCode: coupon.text,
      );
      if (!mounted) return;
      final number = '${result['order_number'] ?? result['order_id'] ?? 'تم إنشاء الطلب'}';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
          title: const Text('تم إرسال طلبك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('احتفظ برقم الطلب حتى تگدر تتابعه.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: SelectableText(number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AlinTheme.navy))),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'نسخ رقم الطلب',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: number));
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الطلب')));
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تم'))],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _setError('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _setError(String value) {
    if (!mounted) return;
    setState(() => error = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final data = c.bootstrap;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final hasPhysical = c.cart.any((line) => line.item.isProduct);
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الطلب')),
      body: ListView(
        padding: EdgeInsets.all(tablet ? 28 : 16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'البيانات',
                    child: Column(
                      children: [
                        TextField(controller: name, readOnly: c.student != null, decoration: const InputDecoration(labelText: 'الاسم *')),
                        const SizedBox(height: 12),
                        TextField(controller: phone, readOnly: c.student != null, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف *')),
                        if (c.student != null) ...[
                          const SizedBox(height: 8),
                          Text('الطلب مربوط بحساب ${c.student!.name}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'طريقة الاستلام',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'pickup', icon: Icon(Icons.store_mall_directory_outlined), label: Text('استلام من مكتبة')),
                            ButtonSegment(value: 'home_delivery', icon: Icon(Icons.delivery_dining), label: Text('توصيل')),
                          ],
                          selected: {fulfillmentType},
                          onSelectionChanged: busy ? null : (value) {
                            final next = value.first;
                            if (hasPhysical && next == 'pickup') return;
                            setState(() {
                              fulfillmentType = next;
                              if (next == 'pickup') locationError = null;
                            });
                          },
                        ),
                        if (hasPhysical) ...[
                          const SizedBox(height: 8),
                          const Text('القرطاسية والهدايا متاحة بالتوصيل فقط.', style: TextStyle(color: AlinTheme.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 14),
                        if (fulfillmentType == 'pickup')
                          DropdownButtonFormField<LibraryModel>(
                            initialValue: library,
                            decoration: const InputDecoration(labelText: 'اختر المكتبة'),
                            items: data.libraries
                                .where((e) => e.isOpen)
                                .map((e) => DropdownMenuItem(value: e, child: Text('${e.name}${e.area.isEmpty ? '' : ' — ${e.area}'}', overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: busy ? null : (value) => setState(() => library = value),
                          )
                        else ...[
                          DropdownButtonFormField<DeliveryAreaModel>(
                            initialValue: area,
                            decoration: const InputDecoration(labelText: 'منطقة التوصيل *'),
                            items: data.deliveryAreas.map((e) => DropdownMenuItem(value: e, child: Text(e.deliveryFee > 0 ? '${e.name} — ${e.deliveryFee.toStringAsFixed(0)} د.ع' : e.name))).toList(),
                            onChanged: busy ? null : (value) => setState(() => area = value),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: busy || locationBusy ? null : captureLocation,
                            icon: locationBusy
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(deliveryPosition == null ? Icons.my_location_rounded : Icons.location_on_rounded),
                            label: Text(locationBusy ? 'جاري تحديد موقعك...' : (deliveryPosition == null ? 'تحديد موقعي *' : 'تحديث الموقع')),
                          ),
                          if (deliveryPosition != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('✓ تم تحديد موقع التوصيل', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  SelectableText('Latitude: ${deliveryPosition!.latitude.toStringAsFixed(7)}'),
                                  SelectableText('Longitude: ${deliveryPosition!.longitude.toStringAsFixed(7)}'),
                                  if (deliveryPosition!.accuracy > 0)
                                    Text('الدقة التقريبية: ${deliveryPosition!.accuracy.round()} متر', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                          if (locationError != null) ...[
                            const SizedBox(height: 8),
                            Text(locationError!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 12),
                          TextField(controller: landmark, maxLength: 300, decoration: const InputDecoration(labelText: 'أقرب نقطة دالة — اختياري')),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'إضافات',
                    child: Column(
                      children: [
                        TextField(controller: coupon, readOnly: coupon.text.isNotEmpty, decoration: const InputDecoration(labelText: 'كود الخصم')),
                        if (coupon.text.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          const Align(alignment: Alignment.centerRight, child: Text('تم تطبيق الكود من السلة.', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700))),
                        ],
                        const SizedBox(height: 12),
                        TextField(controller: notes, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'ملاحظات الطلب — اختياري')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final subtotal = _quoteNumber('subtotal', c.cartTotal);
                      final discount = _quoteNumber('discount', 0);
                      final afterDiscount = _quoteNumber('total', c.cartTotal);
                      final deliveryFee = fulfillmentType == 'home_delivery' ? (area?.deliveryFee ?? 0) : 0;
                      final finalTotal = afterDiscount + deliveryFee;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              if (discount > 0) ...[
                                _CheckoutPriceLine(title: 'قبل الخصم', value: subtotal),
                                _CheckoutPriceLine(title: 'الخصم', value: -discount, green: true),
                                if (deliveryFee > 0) _CheckoutPriceLine(title: 'التوصيل', value: deliveryFee),
                                const Divider(),
                              ],
                              Row(
                                children: [
                                  Expanded(child: Text(discount > 0 ? 'الإجمالي بعد الخصم' : (deliveryFee > 0 ? 'الإجمالي مع التوصيل' : 'إجمالي السلة'), style: const TextStyle(fontWeight: FontWeight.w800))),
                                  Text('${finalTotal.toStringAsFixed(0)} ${AlinConfig.currency}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                      child: Text(error!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: busy ? null : submit,
                    icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
                    label: Text(busy ? 'جارٍ إرسال الطلب...' : 'تأكيد الطلب'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DeliveryLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  const _DeliveryLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory _DeliveryLocation.fromPosition(Position position) => _DeliveryLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
}

class _CheckoutPriceLine extends StatelessWidget {
  final String title;
  final num value;
  final bool green;
  const _CheckoutPriceLine({required this.title, required this.value, this.green = false});

  @override
  Widget build(BuildContext context) {
    final prefix = value < 0 ? '- ' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$prefix${value.abs().toStringAsFixed(0)} ${AlinConfig.currency}', style: TextStyle(fontWeight: FontWeight.w900, color: green ? Colors.green.shade700 : null)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}
