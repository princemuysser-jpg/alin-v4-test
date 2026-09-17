from pathlib import Path

path = Path('flutter_business/lib/screens/admin_desktop_dashboard_screen.dart')
text = path.read_text(encoding='utf-8')

if "label: const Text('إضافة حساب')" in text and "Future<void> _createAccount()" in text:
    print('Flutter desktop admin account creation is already present.')
    raise SystemExit(0)

old_header = """    Row(\n      children: [\n        Expanded(child: _sectionHeader('الحسابات (${visibleAccounts.length})')),\n        DropdownButton<String>(\n"""
new_header = """    Row(\n      children: [\n        Expanded(child: _sectionHeader('الحسابات (${visibleAccounts.length})')),\n        if (widget.account.role == 'admin') ...[\n          FilledButton.icon(\n            onPressed: _createAccount,\n            icon: const Icon(Icons.person_add_alt_1_rounded),\n            label: const Text('إضافة حساب'),\n          ),\n          const SizedBox(width: 12),\n        ],\n        DropdownButton<String>(\n"""
if old_header not in text:
    raise SystemExit('Could not find desktop accounts header anchor.')
text = text.replace(old_header, new_header, 1)

finance_marker = "  Widget _financePage() => _page([\n"
if finance_marker not in text:
    raise SystemExit('Could not find finance page insertion anchor.')

methods = r'''  Future<void> _createAccount() async {
    if (widget.account.role != 'admin') return;
    final result = await _accountDialog();
    if (result == null) return;
    try {
      await widget.repository.adminCreateAccount(result);
      await load();
      _snack('تم إنشاء الحساب بنجاح');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _accountDialog() async {
    final name = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final phone = TextEditingController();
    final area = TextEditingController();
    String role = 'printer';
    bool obscurePassword = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'نوع الحساب',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'printer', child: Text('مطبعة')),
                      DropdownMenuItem(value: 'teacher', child: Text('مدرس')),
                      DropdownMenuItem(value: 'library', child: Text('مكتبة')),
                      DropdownMenuItem(value: 'courier', child: Text('مندوب')),
                      DropdownMenuItem(value: 'accountant', child: Text('حسابات')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => role = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدخول',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      helperText: '12 حرفاً على الأقل وتحتوي حروفاً وأرقاماً',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: role == 'courier'
                          ? 'الهاتف (مطلوب للمندوب)'
                          : 'الهاتف (اختياري)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: area,
                    decoration: InputDecoration(
                      labelText: role == 'courier'
                          ? 'المنطقة (مطلوبة للمندوب)'
                          : 'المنطقة (اختياري)',
                      prefixIcon: const Icon(Icons.location_on_outlined),
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
            FilledButton.icon(
              onPressed: () {
                final cleanName = name.text.trim();
                final cleanUsername = username.text.trim();
                final cleanPassword = password.text;
                final hasLetter = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(cleanPassword);
                final hasNumber = RegExp(r'[0-9]').hasMatch(cleanPassword);
                if (cleanName.isEmpty || cleanUsername.isEmpty || cleanPassword.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('أكمل الاسم واسم الدخول وكلمة المرور')),
                  );
                  return;
                }
                if (cleanPassword.length < 12 || !hasLetter || !hasNumber) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً'),
                    ),
                  );
                  return;
                }
                if (role == 'courier' && phone.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('أدخل رقم هاتف المندوب')),
                  );
                  return;
                }
                if (role == 'courier' && area.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('أدخل منطقة عمل المندوب')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, <String, dynamic>{
                  'role': role,
                  'name': cleanName,
                  'username': cleanUsername,
                  'password': cleanPassword,
                  'phone': phone.text.trim(),
                  'area': area.text.trim(),
                  if (role == 'courier') 'areas': [area.text.trim()],
                  'status': 'active',
                });
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ الحساب'),
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
    return result;
  }

'''

text = text.replace(finance_marker, methods + finance_marker, 1)
path.write_text(text, encoding='utf-8')
print('Added Flutter desktop admin account creation with printer support.')
