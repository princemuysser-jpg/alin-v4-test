import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final input = TextEditingController();
  bool busy = false;
  Map<String, dynamic>? result;
  String? error;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final code = input.text.trim();
    if (code.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final data = await AppScope.of(context).trackOrder(code);
      if (!mounted) return;
      if (data is! Map) throw Exception('تعذر قراءة حالة الطلب');
      setState(() => result = Map<String, dynamic>.from(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return ListView(
      padding: EdgeInsets.all(tablet ? 28 : 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.tr('تتبع الطلب', ku: 'بەدواداچوونی داواکاری', en: 'Track order'),
                  style: TextStyle(fontSize: tablet ? 26 : 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 5),
                Text(
                  c.tr('اكتب رقم الطلب حتى تعرف حالته الحالية.', ku: 'ژمارەی داواکاری بنووسە بۆ زانینی دۆخەکەی.', en: 'Enter the order number to check its status.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: input,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => search(),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.receipt_long_outlined), hintText: 'مثال: AL-260820092349-01-483f'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: busy ? null : search,
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search),
                  label: Text(busy ? 'جارٍ البحث...' : 'تتبع الآن'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  _MessageCard(icon: Icons.error_outline, color: Colors.red, text: error!),
                ],
                if (result != null) ...[
                  const SizedBox(height: 18),
                  _TrackingResult(data: result!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TrackingResult({required this.data});

  String _normalizedStatus() {
    final raw = '${data['status'] ?? 'new'}'.trim().toLowerCase();
    if (raw == 'delivered') return 'completed';
    if (raw == 'out_delivery') return 'out_for_delivery';
    if (raw == 'canceled') return 'cancelled';
    return raw;
  }

  bool get _isDelivery => '${data['fulfillment_type'] ?? ''}'.trim().toLowerCase() == 'home_delivery';
  bool get _isCancelled => const {'cancelled', 'rejected'}.contains(_normalizedStatus());

  int _currentStep() {
    final status = _normalizedStatus();
    if (_isDelivery) {
      if (const {'completed'}.contains(status)) return 3;
      if (const {'picked_up', 'out_for_delivery'}.contains(status)) return 2;
      if (const {'assigned', 'accepted'}.contains(status)) return 1;
      return 0;
    }
    if (const {'completed'}.contains(status)) return 3;
    if (status == 'ready') return 2;
    if (const {'processing', 'printing'}.contains(status)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final number = '${data['order_number'] ?? ''}';
    final item = '${data['title'] ?? data['item_name'] ?? ''}';
    final steps = _isDelivery
        ? const ['تم استلام الطلب', 'تم تحديد المندوب', 'في الطريق', 'تم التسليم']
        : const ['تم استلام الطلب', 'قيد الطباعة', 'جاهز', 'تم التسليم'];

    if (_isCancelled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.shade100)),
                child: Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Text('ملغي', style: TextStyle(color: Colors.red.shade800, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AlinTheme.navy),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(number, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              ],
            ),
            if (item.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item, style: const TextStyle(color: AlinTheme.muted, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 8),
            Text(_isDelivery ? 'توصيل بواسطة مندوب' : 'استلام من مكتبة', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Divider(height: 28),
            _OrderProgress(steps: steps, currentStep: _currentStep()),
          ],
        ),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  const _OrderProgress({required this.steps, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: List.generate(steps.length, (index) {
        final done = index < currentStep;
        final active = index == currentStep;
        final reached = index <= currentStep;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? activeColor : Colors.transparent,
                      border: Border.all(color: reached ? activeColor : inactiveColor, width: 2),
                    ),
                    child: Icon(done ? Icons.check_rounded : (active ? Icons.circle : Icons.circle_outlined), size: active ? 11 : 16, color: reached ? Colors.white : inactiveColor),
                  ),
                  if (index < steps.length - 1)
                    Container(width: 2, height: 34, color: index < currentStep ? activeColor : inactiveColor),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 28),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: reached ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _MessageCard({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(text))]),
        ),
      );
}
