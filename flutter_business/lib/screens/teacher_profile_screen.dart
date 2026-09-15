import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_brand.dart';

class TeacherProfileScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const TeacherProfileScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic> profile = {};
  Map<String, dynamic> summary = {};

  final phone = TextEditingController();
  final area = TextEditingController();
  final specialty = TextEditingController();
  final bio = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  Uint8List? newAvatarBytes;
  String? newAvatarName;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    phone.dispose();
    area.dispose();
    specialty.dispose();
    bio.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      Map<String, dynamic> account = {};
      try {
        final raw = await widget.repository.client
            .from('accounts')
            .select('id,name,username,phone,area,specialty,bio,avatar_path,status')
            .eq('id', widget.account.id)
            .maybeSingle();
        if (raw != null) account = Map<String, dynamic>.from(raw);
      } catch (_) {
        account = {
          'id': widget.account.id,
          'name': widget.account.name,
          'username': widget.account.username,
          'phone': widget.account.phone,
          'area': widget.account.area,
        };
      }

      Map<String, dynamic> totals = {};
      try {
        totals = await widget.repository.dashboardSummary(widget.account);
      } catch (_) {}

      int bookletCount = 0;
      int orderCount = 0;
      num soldCopies = 0;
      try {
        final rawBooks = await widget.repository.client
            .from('booklets')
            .select('id')
            .eq('teacher_id', widget.account.id)
            .isFilter('deleted_at', null);
        final books = (rawBooks as List).whereType<Map>().toList();
        bookletCount = books.length;
        final ids = books.map((e) => '${e['id']}').where((e) => e.isNotEmpty).toList();
        if (ids.isNotEmpty) {
          final rawOrders = await widget.repository.client
              .from('orders')
              .select('id,qty,item_id,kind')
              .eq('kind', 'booklet')
              .inFilter('item_id', ids)
              .limit(2000);
          final rows = (rawOrders as List).whereType<Map>().toList();
          orderCount = rows.length;
          soldCopies = rows.fold<num>(0, (sum, row) => sum + n(row['qty']));
        }
      } catch (_) {}

      totals = {
        ...totals,
        '_booklets': bookletCount,
        '_orders': orderCount,
        '_sold': soldCopies,
      };

      if (!mounted) return;
      profile = account;
      summary = totals;
      phone.text = '${account['phone'] ?? widget.account.phone}';
      area.text = '${account['area'] ?? widget.account.area}';
      specialty.text = '${account['specialty'] ?? ''}';
      bio.text = '${account['bio'] ?? ''}';
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _snack('تعذر قراءة الصورة');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('حجم الصورة يجب ألا يتجاوز 5MB');
      return;
    }
    setState(() {
      newAvatarBytes = bytes;
      newAvatarName = file.name;
    });
  }

  String _imageContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _safeExt(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  Future<String> _uploadAvatar() async {
    final bytes = newAvatarBytes;
    final name = newAvatarName;
    if (bytes == null || name == null) return '${profile['avatar_path'] ?? ''}';
    final path = 'teachers/${widget.account.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.${_safeExt(name)}';
    await widget.repository.client.storage.from('alin-private').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: _imageContentType(name),
          ),
        );
    return path;
  }

  Future<void> saveProfile() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final avatarPath = await _uploadAvatar();
      final raw = await widget.repository.client.rpc('alin_teacher_update_profile', params: {
        'p_phone': phone.text.trim(),
        'p_area': area.text.trim(),
        'p_specialty': specialty.text.trim(),
        'p_bio': bio.text.trim(),
        'p_avatar_path': avatarPath,
      });
      if (raw is Map && raw['ok'] != true) {
        throw Exception('${raw['error'] ?? 'تعذر حفظ الملف الشخصي'}');
      }
      newAvatarBytes = null;
      newAvatarName = null;
      await load();
      _snack('تم حفظ الملف الشخصي');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changePassword() async {
    if (saving) return;
    final p = password.text;
    final p2 = confirmPassword.text;
    if (p.length < 12 || !RegExp(r'[0-9]').hasMatch(p) || !RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(p)) {
      _snack('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
      return;
    }
    if (p != p2) {
      _snack('كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.client.auth.updateUser(UserAttributes(password: p));
      password.clear();
      confirmPassword.clear();
      _snack('تم تغيير كلمة المرور');
    } catch (e) {
      _snack('$e'.replaceFirst('AuthException: ', '').replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 900;
                    final profileCard = _profileCard();
                    final summaryCard = _summaryCard();
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _hero(),
                        const SizedBox(height: 14),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: profileCard),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: summaryCard),
                            ],
                          )
                        else ...[
                          profileCard,
                          const SizedBox(height: 12),
                          summaryCard,
                        ],
                      ],
                    );
                  },
                ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: BusinessBrand.heroGradient, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: .16),
            child: newAvatarBytes != null
                ? ClipOval(child: Image.memory(newAvatarBytes!, width: 68, height: 68, fit: BoxFit.cover))
                : Text(
                    (widget.account.name.trim().isEmpty ? 'م' : widget.account.name.trim().characters.first),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${profile['name'] ?? widget.account.name}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(specialty.text.trim().isEmpty ? 'مدرس في منصة آلين' : specialty.text.trim(), style: const TextStyle(color: Colors.white70)),
          ])),
          const Chip(label: Text('الحساب فعال')),
        ]),
      );

  Widget _profileCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('البيانات الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextFormField(initialValue: '${profile['name'] ?? widget.account.name}', enabled: false, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 10),
            TextFormField(initialValue: '${profile['username'] ?? widget.account.username}', enabled: false, decoration: const InputDecoration(labelText: 'اسم الدخول')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 10),
            TextField(controller: area, decoration: const InputDecoration(labelText: 'المنطقة')),
            const SizedBox(height: 10),
            TextField(controller: specialty, decoration: const InputDecoration(labelText: 'الاختصاص', hintText: 'مثال: مدرس رياضيات')),
            const SizedBox(height: 10),
            TextField(controller: bio, maxLines: 4, decoration: const InputDecoration(labelText: 'نبذة قصيرة')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving ? null : pickAvatar,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(newAvatarName == null ? 'اختيار صورة شخصية' : newAvatarName!, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: saving ? null : saveProfile, icon: const Icon(Icons.save_rounded), label: const Text('حفظ التعديلات')),
          ]),
        ),
      );

  Widget _summaryCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ملخص الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _stat('الملازم', '${n(summary['_booklets']).round()}'),
            _stat('الطلبات', '${n(summary['_orders']).round()}'),
            _stat('النسخ المباعة', '${n(summary['_sold']).round()}'),
            const Divider(height: 28),
            const Text('الأمان', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
            const SizedBox(height: 10),
            TextField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: saving ? null : changePassword, icon: const Icon(Icons.lock_reset_rounded), label: const Text('تغيير كلمة المرور')),
            const SizedBox(height: 12),
            const Text('اسم المدرس وربط الملازم يبقى من صلاحية الإدارة، بينما تستطيع تعديل بيانات التواصل والصورة وكلمة المرور.', style: TextStyle(fontSize: 12, color: BusinessBrand.muted)),
          ]),
        ),
      );

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: BusinessBrand.navy))]),
      );
}
