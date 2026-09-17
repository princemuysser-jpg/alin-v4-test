import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';

class PrinterSettingsScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const PrinterSettingsScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  Map<String, dynamic> profile = {};
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  bool get isOpen =>
      profile['is_open'] != false &&
      '${profile['open_status'] ?? 'open'}' != 'closed';

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.libraryProfile(widget.account.id);
      if (!mounted) return;
      setState(() => profile = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> setBookletOpen(bool value) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.repository.librarySetOpen(value);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم فتح استقبال طلبات الملازم للمطبعة'
                : 'تم إيقاف استقبال طلبات الملازم للمطبعة',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المطبعة'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
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
                        const Icon(Icons.error_outline_rounded, size: 42),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'نظام الملازم والطباعة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'هذا الخيار يتحكم بظهور المطبعة ضمن جهات استلام وطباعة الملازم فقط، ولا يؤثر على نظام توريد الكتب.',
                              ),
                              const Divider(height: 26),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'استقبال طلبات الملازم',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  isOpen
                                      ? 'المطبعة مفتوحة وتظهر للطالب ضمن جهات الاستلام.'
                                      : 'المطبعة مغلقة مؤقتاً ولا تستقبل طلبات ملازم جديدة.',
                                ),
                                value: isOpen,
                                onChanged: saving ? null : setBookletOpen,
                              ),
                              if (saving) const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'بيانات الحساب',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _row('اسم المطبعة', profile['name'] ?? widget.account.name),
                              _row('اسم الدخول', widget.account.username),
                              _row('الهاتف', profile['phone'] ?? widget.account.phone),
                              _row('المنطقة', profile['area'] ?? widget.account.area),
                              _row('أقرب نقطة دالة', profile['landmark'] ?? widget.account.landmark),
                              _row('حالة الحساب', profile['status'] ?? widget.account.status),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الأنظمة المفعلة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _statusLine(
                                Icons.menu_book_rounded,
                                'توريد الكتب',
                                'مفعل ومستقل ماليًا',
                              ),
                              const SizedBox(height: 8),
                              _statusLine(
                                Icons.print_rounded,
                                'الملازم والطباعة',
                                isOpen ? 'مفعل ويستقبل طلبات' : 'مفعل لكن الاستقبال مغلق',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: saving ? null : widget.onLogout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF143B68), Color(0xFF255B91)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(Icons.print_rounded, color: Color(0xFF143B68), size: 31),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile['name'] ?? widget.account.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'إعدادات حساب المطبعة',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, dynamic value) {
    final text = '${value ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: const TextStyle(color: Color(0xFF667085))),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(IconData icon, String title, String subtitle) => Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Colors.green),
        ],
      );
}
