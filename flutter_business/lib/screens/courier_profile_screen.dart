import 'package:flutter/material.dart';

import '../data/business_courier_repository.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_brand.dart';

class CourierProfileScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const CourierProfileScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<CourierProfileScreen> createState() => _CourierProfileScreenState();
}

class _CourierProfileScreenState extends State<CourierProfileScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic> profile = {};
  String availability = 'available';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.courierProfile();
      if (!mounted) return;
      setState(() {
        profile = value;
        availability = '${value['availability'] ?? 'available'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveAvailability() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.repository.courierSetAvailability(availability);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ حالة العمل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<String> get areas {
    final values = <String>{};
    final main = '${profile['area'] ?? ''}'.trim();
    if (main.isNotEmpty) values.add(main);
    final raw = profile['areas'];
    if (raw is List) {
      for (final item in raw) {
        final value = '$item'.trim();
        if (value.isNotEmpty) values.add(value);
      }
    }
    return values.toList();
  }

  String get phone => '${profile['phone'] ?? widget.account.phone ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth >= 900 ? 760.0 : constraints.maxWidth;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: maxWidth,
                            child: Column(
                              children: [
                                _hero(),
                                const SizedBox(height: 14),
                                _details(),
                                const SizedBox(height: 14),
                                _statusCard(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: BusinessBrand.heroGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 31,
              backgroundColor: Colors.white.withValues(alpha: .16),
              child: Text(
                widget.account.name.isEmpty ? 'م' : widget.account.name.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile['name'] ?? widget.account.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(phone.isEmpty ? 'بدون رقم هاتف' : phone, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            _statusBadge(),
          ],
        ),
      );

  Widget _details() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بيانات المندوب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _line(Icons.person_rounded, 'الاسم', '${profile['name'] ?? widget.account.name}'),
              _line(Icons.phone_rounded, 'الهاتف', phone.isEmpty ? 'غير محدد' : phone),
              const SizedBox(height: 12),
              const Text('مناطق العمل', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (areas.isEmpty)
                const Text('غير محددة', style: TextStyle(color: BusinessBrand.muted))
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: areas
                      .map((area) => Chip(
                            avatar: const Icon(Icons.location_on_rounded, size: 17),
                            label: Text(area),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      );

  Widget _statusCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('حالة العمل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'حدد حالتك مثل صفحة المندوب في الويب القديم.',
                style: TextStyle(color: BusinessBrand.muted),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'available', label: Text('متاح'), icon: Icon(Icons.check_circle_rounded)),
                  ButtonSegment(value: 'busy', label: Text('مشغول'), icon: Icon(Icons.schedule_rounded)),
                  ButtonSegment(value: 'offline', label: Text('خارج الخدمة'), icon: Icon(Icons.pause_circle_rounded)),
                ],
                selected: {availability},
                onSelectionChanged: saving ? null : (value) => setState(() => availability = value.first),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: saving ? null : saveAvailability,
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('حفظ الحالة'),
              ),
            ],
          ),
        ),
      );

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: BusinessBrand.navy, size: 21),
            const SizedBox(width: 9),
            SizedBox(width: 75, child: Text(label, style: const TextStyle(color: BusinessBrand.muted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );

  Widget _statusBadge() {
    final label = switch (availability) {
      'available' => 'متاح',
      'busy' => 'مشغول',
      'offline' => 'خارج الخدمة',
      _ => availability,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}
