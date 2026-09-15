import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminCouponsScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminCouponsScreen({super.key, required this.repository});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  List<Map<String, dynamic>> coupons = [];
  bool loading = true;
  bool busy = false;
  String? error;
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

  int used(Map<String, dynamic> row) =>
      n(row['used_count'] ?? row['usage_count']).round();
  int limit(Map<String, dynamic> row) =>
      n(row['max_uses'] ?? row['usage_limit']).round();

  bool active(Map<String, dynamic> row) {
    if ('${row['status'] ?? 'active'}'.toLowerCase() != 'active') return false;
    final expires = DateTime.tryParse('${row['expires_at'] ?? ''}')?.toLocal();
    return expires == null || !expires.isBefore(DateTime.now());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await widget.repository.client
          .from('coupons')
          .select('*')
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() => coupons = (raw as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return coupons;
    return coupons.where((row) {
      final haystack =
          '${row['code'] ?? ''} ${row['applies_to'] ?? ''} ${row['status'] ?? ''}'
              .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: '${row?['code'] ?? ''}');
    final value = TextEditingController(
      text: row == null ? '' : '${n(row['discount_value']).round()}',
    );
    final maxUses = TextEditingController(
      text: row == null ? '0' : '${limit(row)}',
    );
    String type = '${row?['discount_type'] ?? 'percent'}';
    String applies = '${row?['applies_to'] ?? 'all'}';
    String status = '${row?['status'] ?? 'active'}';
    DateTime? expiry = DateTime.tryParse(
      '${row?['expires_at'] ?? ''}',
    )?.toLocal();

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(row == null ? 'إضافة كوبون' : 'تعديل الكوبون'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'كود الخصم',
                      hintText: 'ALIN20',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          decoration: const InputDecoration(
                            labelText: 'نوع الخصم',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percent',
                              child: Text('نسبة مئوية'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Text('مبلغ ثابت'),
                            ),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => type = v ?? 'percent'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: value,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'قيمة الخصم',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxUses,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الاستخدامات',
                      helperText: '0 = بدون حد',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: applies,
                    decoration: const InputDecoration(labelText: 'يطبق على'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('كل المتجر')),
                      DropdownMenuItem(
                        value: 'booklet',
                        child: Text('الملازم'),
                      ),
                      DropdownMenuItem(
                        value: 'stationery',
                        child: Text('القرطاسية'),
                      ),
                      DropdownMenuItem(value: 'gift', child: Text('الهدايا')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => applies = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'disabled', child: Text('متوقف')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => status = v ?? 'active'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الانتهاء'),
                    subtitle: Text(
                      expiry == null
                          ? 'غير محدد'
                          : '${expiry!.year}/${expiry!.month.toString().padLeft(2, '0')}/${expiry!.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (expiry != null)
                          IconButton(
                            tooltip: 'إلغاء التاريخ',
                            onPressed: () =>
                                setDialogState(() => expiry = null),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                        IconButton(
                          tooltip: 'اختيار التاريخ',
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              initialDate:
                                  expiry ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (selected != null)
                              setDialogState(() => expiry = selected);
                          },
                          icon: const Icon(Icons.calendar_month_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = code.text.trim().toUpperCase();
                final discount = num.tryParse(value.text.trim()) ?? 0;
                final max = int.tryParse(maxUses.text.trim()) ?? 0;
                if (normalized.length < 2 || discount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أكمل كود وقيمة الخصم')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'code': normalized,
                  'discount_type': type,
                  'discount_value': discount,
                  'max_uses': max < 0 ? 0 : max,
                  'applies_to': applies,
                  'status': status,
                  'expires_at': expiry == null
                      ? null
                      : DateTime(
                          expiry!.year,
                          expiry!.month,
                          expiry!.day,
                          23,
                          59,
                          59,
                        ).toUtc().toIso8601String(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    code.dispose();
    value.dispose();
    maxUses.dispose();
    if (payload == null || busy) return;

    setState(() => busy = true);
    try {
      final duplicate = coupons.any(
        (coupon) =>
            '${coupon['code'] ?? ''}'.trim().toUpperCase() ==
                '${payload['code']}' &&
            '${coupon['id']}' != '${row?['id']}',
      );
      if (duplicate) throw Exception('هذا كود الخصم موجود مسبقاً');

      if (row == null) {
        await widget.repository.client.from('coupons').insert({
          'id': 'CP${DateTime.now().millisecondsSinceEpoch}',
          'used_count': 0,
          'usage_count': 0,
          ...payload,
        });
      } else {
        await widget.repository.client
            .from('coupons')
            .update(payload)
            .eq('id', row['id']);
      }
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الكوبون')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final next = '${row['status'] ?? 'active'}' == 'active'
          ? 'disabled'
          : 'active';
      await widget.repository.client
          .from('coupons')
          .update({'status': next})
          .eq('id', row['id']);
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الكوبون'),
        content: Text('حذف الكوبون ${row['code']}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes != true || busy) return;
    setState(() => busy = true);
    try {
      await widget.repository.client
          .from('coupons')
          .delete()
          .eq('id', row['id']);
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = coupons.where(active).length;
    final usedCount = coupons.fold<int>(0, (sum, row) => sum + used(row));
    final expired = coupons.where((row) {
      final date = DateTime.tryParse('${row['expires_at'] ?? ''}')?.toLocal();
      return date != null && date.isBefore(DateTime.now());
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض والكوبونات'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة كوبون'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final count = c.maxWidth >= 1000 ? 4 : 2;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: count,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: c.maxWidth >= 1000 ? 2.5 : 1.6,
                        children: [
                          _metric(
                            'إجمالي الكوبونات',
                            '${coupons.length}',
                            Icons.confirmation_number_rounded,
                          ),
                          _metric(
                            'نشطة',
                            '$activeCount',
                            Icons.check_circle_rounded,
                          ),
                          _metric(
                            'مرات الاستخدام',
                            '$usedCount',
                            Icons.shopping_cart_checkout_rounded,
                          ),
                          _metric(
                            'منتهية',
                            '$expired',
                            Icons.event_busy_rounded,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'بحث بالكود',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('لا توجد كوبونات')),
                      ),
                    )
                  else
                    ...visible.map(_couponCard),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BusinessBrand.border),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: BusinessBrand.softBlue,
          child: Icon(icon, color: BusinessBrand.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: BusinessBrand.navy,
                ),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _couponCard(Map<String, dynamic> row) {
    final isActive = active(row);
    final max = limit(row);
    final discount = '${row['discount_type']}' == 'fixed'
        ? money(row['discount_value'])
        : '${n(row['discount_value']).toStringAsFixed(n(row['discount_value']) % 1 == 0 ? 0 : 1)}%';
    final expiry = DateTime.tryParse('${row['expires_at'] ?? ''}')?.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row['code'] ?? '—'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: BusinessBrand.navy,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    size: 17,
                  ),
                  label: Text(isActive ? 'نشط' : 'متوقف/منتهي'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$discount خصم • ${_appliesLabel('${row['applies_to'] ?? 'all'}')}',
            ),
            const SizedBox(height: 5),
            Text(
              'الاستخدام ${used(row)}/${max == 0 ? '∞' : max} • الانتهاء ${expiry == null ? 'غير محدد' : '${expiry.year}/${expiry.month}/${expiry.day}'}',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => edit(row),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => toggle(row),
                  icon: Icon(
                    '${row['status'] ?? 'active'}' == 'active'
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    '${row['status'] ?? 'active'}' == 'active'
                        ? 'إيقاف'
                        : 'تشغيل',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => remove(row),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _appliesLabel(String value) => switch (value) {
    'booklet' => 'الملازم',
    'stationery' => 'القرطاسية',
    'gift' => 'الهدايا',
    _ => 'كل المتجر',
  };
}
