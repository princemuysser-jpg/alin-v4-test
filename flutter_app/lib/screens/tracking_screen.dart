import 'dart:convert';
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
  dynamic result;
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
      setState(() => result = data);
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
                Text(c.tr('تتبع الطلب', ku: 'بەدواداچوونی داواکاری', en: 'Track order'), style: TextStyle(fontSize: tablet ? 26 : 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 5),
                Text(c.tr('اكتب رقم الطلب حتى تعرف حالته الحالية.', ku: 'ژمارەی داواکاری بنووسە بۆ زانینی دۆخەکەی.', en: 'Enter the order number to check its status.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                TextField(
                  controller: input,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => search(),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.receipt_long_outlined), hintText: 'مثال: ALIN-0001'),
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
                  _TrackingResult(data: result),
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
  final dynamic data;
  const _TrackingResult({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      final number = '${map['order_number'] ?? map['id'] ?? ''}';
      final status = '${map['status'] ?? map['order_status'] ?? 'قيد المتابعة'}';
      final item = '${map['item_name'] ?? map['title'] ?? ''}';
      final total = '${map['total'] ?? map['total_amount'] ?? ''}';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Icon(Icons.check_circle_outline, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(number.isEmpty ? 'تم العثور على الطلب' : number, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)))]),
              const Divider(height: 28),
              _line('الحالة', status),
              if (item.isNotEmpty) _line('الطلب', item),
              if (total.isNotEmpty) _line('المبلغ', '$total د.ع'),
            ],
          ),
        ),
      );
    }
    return _MessageCard(icon: Icons.info_outline, color: AlinTheme.navy, text: const JsonEncoder.withIndent('  ').convert(data));
  }

  Widget _line(String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(title, style: const TextStyle(color: AlinTheme.muted))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );
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
