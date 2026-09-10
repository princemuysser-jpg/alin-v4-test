import 'package:flutter/material.dart';

import '../data/admin_growth_repository.dart';
import '../data/business_repository.dart';

class AdminGrowthControlsScreen extends StatefulWidget {
  final BusinessRepository repository;
  const AdminGrowthControlsScreen({super.key, required this.repository});

  @override
  State<AdminGrowthControlsScreen> createState() => _AdminGrowthControlsScreenState();
}

class _AdminGrowthControlsScreenState extends State<AdminGrowthControlsScreen> {
  bool loading = true;
  bool savingOrdering = false;
  bool ordersEnabled = true;
  String pauseReason = '';
  int days = 30;
  String mode = 'all';
  String search = '';
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> customers = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  void snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.repository.adminOrderingSettings(),
        widget.repository.adminStudentCustomers(days: days, mode: mode, search: search),
      ]);
      final orderSettings = Map<String, dynamic>.from(values[0] as Map);
      final customerData = Map<String, dynamic>.from(values[1] as Map);
      if (!mounted) return;
      setState(() {
        ordersEnabled = orderSettings['enabled'] == true;
        pauseReason = '${orderSettings['reason'] ?? ''}';
        stats = customerData['stats'] is Map ? Map<String, dynamic>.from(customerData['stats'] as Map) : {};
        customers = customerData['rows'] is List
            ? (customerData['rows'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
      });
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleOrdering() async {
    final next = !ordersEnabled;
    String? reason = pauseReason;
    if (!next) {
      final controller = TextEditingController(text: pauseReason.isEmpty ? 'الطلبات متوقفة مؤقتاً. يرجى المحاولة لاحقاً.' : pauseReason);
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إيقاف الطلبات مؤقتاً'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'سبب الإيقاف'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('إيقاف')),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.trim().isEmpty) return;
    }

    setState(() => savingOrdering = true);
    try {
      final result = await widget.repository.adminSetOrderingEnabled(enabled: next, reason: reason);
      if (!mounted) return;
      setState(() {
        ordersEnabled = result['enabled'] == true;
        pauseReason = '${result['reason'] ?? pauseReason}';
      });
      snack(ordersEnabled ? 'تم فتح الطلبات' : 'تم إيقاف الطلبات مؤقتاً');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => savingOrdering = false);
    }
  }

  Future<void> createOffer(Map<String, dynamic> student) async {
    final value = TextEditingController(text: '10');
    final title = TextEditingController(text: 'عرض خاص لك 🎁');
    final message = TextEditingController(text: 'عندك خصم خاص من منصة آلين.');
    String type = 'percent';
    String applies = 'all';
    int validDays = 3;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('عرض خاص — ${student['name'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'نوع الخصم'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
                  DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت')),
                ],
                onChanged: (v) { if (v != null) setLocal(() => type = v); },
              ),
              const SizedBox(height: 8),
              TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قيمة الخصم')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: applies,
                decoration: const InputDecoration(labelText: 'ينطبق على'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'booklet', child: Text('الملازم')),
                  DropdownMenuItem(value: 'stationery', child: Text('القرطاسية')),
                  DropdownMenuItem(value: 'gift', child: Text('الهدايا')),
                ],
                onChanged: (v) { if (v != null) setLocal(() => applies = v); },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: validDays,
                decoration: const InputDecoration(labelText: 'مدة العرض'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('يوم')),
                  DropdownMenuItem(value: 3, child: Text('3 أيام')),
                  DropdownMenuItem(value: 7, child: Text('7 أيام')),
                  DropdownMenuItem(value: 14, child: Text('14 يوم')),
                  DropdownMenuItem(value: 30, child: Text('30 يوم')),
                ],
                onChanged: (v) { if (v != null) setLocal(() => validDays = v); },
              ),
              const SizedBox(height: 8),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان العرض')),
              const SizedBox(height: 8),
              TextField(controller: message, maxLines: 3, decoration: const InputDecoration(labelText: 'نص العرض')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final amount = num.tryParse(value.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(dialogContext, {
                  'discount_type': type,
                  'discount_value': amount,
                  'days': validDays,
                  'applies': applies,
                  'title': title.text.trim(),
                  'message': message.text.trim(),
                });
              },
              child: const Text('إرسال العرض'),
            ),
          ],
        ),
      ),
    );

    value.dispose();
    title.dispose();
    message.dispose();
    if (payload == null) return;

    try {
      final result = await widget.repository.adminCreateStudentOffer(
        studentId: '${student['id']}',
        discountType: '${payload['discount_type']}',
        discountValue: payload['discount_value'] as num,
        daysValid: payload['days'] as int,
        appliesTo: '${payload['applies']}',
        title: '${payload['title']}',
        message: '${payload['message']}',
      );
      final coupon = result['coupon'] is Map ? Map<String, dynamic>.from(result['coupon'] as Map) : <String, dynamic>{};
      snack('تم إنشاء العرض — الكود ${coupon['code'] ?? ''}');
      await load();
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget statCard(String title, dynamic value, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [Icon(icon), const SizedBox(height: 6), Text('${value ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text(title)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات والعملاء والعروض')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Icon(ordersEnabled ? Icons.storefront_rounded : Icons.pause_circle_rounded),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ordersEnabled ? 'الطلبات مفتوحة حالياً' : 'الطلبات متوقفة مؤقتاً', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                        ]),
                        if (!ordersEnabled && pauseReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(pauseReason),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: savingOrdering ? null : toggleOrdering,
                          icon: Icon(ordersEnabled ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          label: Text(ordersEnabled ? 'إيقاف الطلبات مؤقتاً' : 'فتح الطلبات'),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    statCard('المسجلين', stats['registered'], Icons.people_alt_rounded),
                    statCard('النشطين', stats['active'], Icons.check_circle_rounded),
                    statCard('غير النشطين', stats['inactive'], Icons.person_off_rounded),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ChoiceChip(label: const Text('الكل'), selected: mode == 'all', onSelected: (_) { setState(() => mode = 'all'); load(); }),
                    ChoiceChip(label: const Text('النشطين'), selected: mode == 'active', onSelected: (_) { setState(() => mode = 'active'); load(); }),
                    ChoiceChip(label: const Text('غير النشطين'), selected: mode == 'inactive', onSelected: (_) { setState(() => mode = 'inactive'); load(); }),
                    DropdownButton<int>(
                      value: days,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 أيام')),
                        DropdownMenuItem(value: 30, child: Text('30 يوم')),
                        DropdownMenuItem(value: 90, child: Text('90 يوم')),
                      ],
                      onChanged: (v) { if (v != null) { setState(() => days = v); load(); } },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SearchBar(
                    hintText: 'بحث بالاسم أو الهاتف',
                    leading: const Icon(Icons.search_rounded),
                    onSubmitted: (v) { search = v.trim(); load(); },
                    trailing: [IconButton(onPressed: () { search = ''; load(); }, icon: const Icon(Icons.refresh_rounded))],
                  ),
                  const SizedBox(height: 12),
                  if (customers.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا يوجد عملاء بهذا الفلتر'))))
                  else
                    ...customers.map((c) {
                      final active = c['is_active'] == true;
                      final offer = '${c['active_offer_code'] ?? ''}'.trim();
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(active ? Icons.person_rounded : Icons.person_outline_rounded)),
                          title: Text('${c['name'] ?? 'طالب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('${c['phone'] ?? ''}\n${active ? 'نشط' : 'غير نشط منذ ${c['days_inactive'] ?? 0} يوم'}${offer.isNotEmpty ? ' • عرض فعال: $offer' : ''}'),
                          isThreeLine: true,
                          trailing: FilledButton.tonal(
                            onPressed: () => createOffer(c),
                            child: const Text('عرض خاص'),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
