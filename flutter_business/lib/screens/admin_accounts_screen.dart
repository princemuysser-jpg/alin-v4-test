import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';

class AdminAccountsScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const AdminAccountsScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  bool loading = true;
  String? error;
  String filter = 'all';
  List<Map<String, dynamic>> accounts = [];

  bool get isSuperAdmin => widget.account.adminLevel == 'super_admin';

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
      final rows = await widget.repository.adminAccounts();
      if (!mounted) return;
      setState(() => accounts = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get visibleAccounts {
    final alive = accounts.where((row) => row['deleted_at'] == null).toList();
    if (filter == 'all') return alive;
    return alive.where((row) => '${row['role']}' == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _createAccount,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة حساب'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 14),
                      _filters(),
                      const SizedBox(height: 14),
                      if (visibleAccounts.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(child: Text('لا توجد حسابات ضمن هذا القسم')),
                          ),
                        )
                      else
                        ...visibleAccounts.map(_accountCard),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard() {
    final alive = accounts.where((row) => row['deleted_at'] == null).toList();
    final active = alive.where((row) => '${row['status']}' == 'active').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              child: Icon(Icons.manage_accounts_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حسابات آلين للأعمال',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text('الإجمالي: ${alive.length} • الفعّالة: $active'),
                  if (isSuperAdmin)
                    const Text(
                      'صلاحية المدير الأعلى: يمكنك إنشاء حساب مدير جديد.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    final items = <(String, String)>[
      ('all', 'الكل'),
      if (isSuperAdmin) ('admin', 'المديرون'),
      ('teacher', 'المدرسون'),
      ('library', 'المكتبات'),
      ('courier', 'المندوبون'),
      ('printer', 'المطابع'),
      ('accountant', 'الحسابات'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(item.$2),
                  selected: filter == item.$1,
                  onSelected: (_) => setState(() => filter = item.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final role = '${account['role'] ?? ''}';
    final active = '${account['status']}' == 'active';
    final canEdit = role != 'admin' || isSuperAdmin;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_roleIcon(role))),
        title: Text(
          '${account['name'] ?? 'بدون اسم'}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_roleLabel(role)} • ${account['username'] ?? ''}\n'
          '${account['phone'] ?? ''}${('${account['area'] ?? ''}').trim().isEmpty ? '' : ' • ${account['area']}'}'
          '${role == 'admin' && '${account['admin_level'] ?? ''}'.isNotEmpty ? '\nالصلاحية: ${account['admin_level']}' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(active ? 'فعال' : 'غير فعال')),
            if (canEdit)
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _editAccount(account),
                icon: const Icon(Icons.edit_rounded),
              ),
          ],
        ),
        onTap: canEdit ? () => _editAccount(account) : null,
      ),
    );
  }

  Future<void> _createAccount() async {
    final payload = await _accountDialog();
    if (payload == null) return;
    try {
      await widget.repository.adminCreateAccount(payload);
      await load();
      _snack('تم إنشاء الحساب بنجاح');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editAccount(Map<String, dynamic> account) async {
    if ('${account['role']}' == 'admin' && !isSuperAdmin) {
      _snack('تعديل حساب المدير يتطلب صلاحية المدير الأعلى');
      return;
    }
    final payload = await _accountDialog(existing: account);
    if (payload == null) return;
    try {
      await widget.repository.adminUpdateAccount('${account['id']}', payload);
      await load();
      _snack('تم تحديث الحساب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _accountDialog({
    Map<String, dynamic>? existing,
  }) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final username = TextEditingController(text: '${existing?['username'] ?? ''}');
    final password = TextEditingController();
    final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
    final area = TextEditingController(text: '${existing?['area'] ?? ''}');
    final landmark = TextEditingController(text: '${existing?['landmark'] ?? ''}');
    final notes = TextEditingController(text: '${existing?['notes'] ?? ''}');

    final allowedRoles = <String>[
      if (isSuperAdmin) 'admin',
      'teacher',
      'library',
      'courier',
      'printer',
      'accountant',
    ];
    String role = '${existing?['role'] ?? 'teacher'}';
    if (!allowedRoles.contains(role)) role = 'teacher';
    String status = '${existing?['status'] ?? 'active'}';
    if (!const ['active', 'inactive', 'pending'].contains(status)) status = 'active';
    bool obscure = true;
    String? validation;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'إضافة حساب' : 'تعديل الحساب'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'الاسم *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'اسم الدخول *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'كلمة المرور *'
                          : 'كلمة مرور جديدة (اختياري)',
                      helperText: '12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً',
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'نوع الحساب *'),
                    items: allowedRoles
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_roleLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setLocal(() => role = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: role == 'courier' ? 'الهاتف *' : 'الهاتف',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: area,
                    decoration: InputDecoration(
                      labelText: role == 'courier' ? 'المنطقة *' : 'المنطقة',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: landmark,
                    decoration: const InputDecoration(labelText: 'أقرب نقطة دالة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('فعال')),
                      DropdownMenuItem(value: 'inactive', child: Text('غير فعال')),
                      DropdownMenuItem(value: 'pending', child: Text('معلّق')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => status = value);
                    },
                  ),
                  if (validation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        validation!,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final cleanName = name.text.trim();
                final cleanUsername = username.text.trim();
                final cleanPassword = password.text;
                final cleanPhone = phone.text.trim();
                final cleanArea = area.text.trim();

                String? message;
                if (cleanName.isEmpty || cleanUsername.isEmpty) {
                  message = 'أكمل الاسم واسم الدخول';
                } else if (existing == null && cleanPassword.isEmpty) {
                  message = 'أدخل كلمة المرور';
                } else if (cleanPassword.isNotEmpty && !_strongPassword(cleanPassword)) {
                  message = 'كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً';
                } else if (role == 'courier' && cleanPhone.isEmpty) {
                  message = 'أدخل رقم هاتف المندوب';
                } else if (role == 'courier' && cleanArea.isEmpty) {
                  message = 'أدخل منطقة عمل المندوب';
                } else if (role == 'admin' && !isSuperAdmin) {
                  message = 'إنشاء مدير جديد يتطلب صلاحية المدير الأعلى';
                }

                if (message != null) {
                  setLocal(() => validation = message);
                  return;
                }

                final payload = <String, dynamic>{
                  'name': cleanName,
                  'username': cleanUsername,
                  'role': role,
                  'phone': cleanPhone,
                  'area': cleanArea,
                  'landmark': landmark.text.trim(),
                  'notes': notes.text.trim(),
                  'status': status,
                };
                if (role == 'courier' && cleanArea.isNotEmpty) {
                  payload['areas'] = [cleanArea];
                }
                if (cleanPassword.isNotEmpty) payload['password'] = cleanPassword;
                Navigator.pop(context, payload);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    username.dispose();
    password.dispose();
    phone.dispose();
    area.dispose();
    landmark.dispose();
    notes.dispose();
    return result;
  }

  bool _strongPassword(String value) {
    return value.length >= 12 && RegExp(r'[0-9]').hasMatch(value) && RegExp(r'[A-Za-z؀-ۿ]').hasMatch(value);
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? 'حدث خطأ', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  IconData _roleIcon(String role) => switch (role) {
        'admin' => Icons.admin_panel_settings_rounded,
        'teacher' => Icons.school_rounded,
        'library' => Icons.local_library_rounded,
        'courier' => Icons.delivery_dining_rounded,
        'printer' => Icons.print_rounded,
        'accountant' => Icons.account_balance_wallet_rounded,
        _ => Icons.person_rounded,
      };

  String _roleLabel(String role) => switch (role) {
        'admin' => 'مدير',
        'teacher' => 'مدرس',
        'library' => 'مكتبة',
        'courier' => 'مندوب',
        'printer' => 'مطبعة',
        'accountant' => 'حسابات',
        _ => role,
      };
}
