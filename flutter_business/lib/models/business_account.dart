class BusinessAccount {
  final String id;
  final String role;
  final String name;
  final String username;
  final String status;
  final String authUserId;
  final String area;
  final String phone;
  final String landmark;
  final String adminLevel;

  const BusinessAccount({
    required this.id,
    required this.role,
    required this.name,
    required this.username,
    required this.status,
    required this.authUserId,
    this.area = '',
    this.phone = '',
    this.landmark = '',
    this.adminLevel = 'operator',
  });

  factory BusinessAccount.fromMap(Map<String, dynamic> map) {
    final rawRole = '${map['role'] ?? ''}'.toLowerCase();
    return BusinessAccount(
      id: '${map['id'] ?? ''}',
      role: rawRole == 'delegate' ? 'courier' : rawRole,
      name: '${map['name'] ?? ''}',
      username: '${map['username'] ?? ''}',
      status: '${map['status'] ?? ''}',
      authUserId: '${map['auth_user_id'] ?? ''}',
      area: '${map['area'] ?? ''}',
      phone: '${map['phone'] ?? ''}',
      landmark: '${map['landmark'] ?? ''}',
      adminLevel: '${map['admin_level'] ?? 'operator'}',
    );
  }

  String get roleLabel => switch (role) {
        'admin' => 'الإدارة',
        'accountant' => 'الحسابات',
        'teacher' => 'المدرس',
        'library' => 'المكتبة',
        'printer' => 'المطبعة',
        'courier' => 'المندوب',
        _ => role,
      };

  bool get isBusinessRole => const {
        'admin',
        'accountant',
        'teacher',
        'library',
        'printer',
        'courier',
      }.contains(role);
}
