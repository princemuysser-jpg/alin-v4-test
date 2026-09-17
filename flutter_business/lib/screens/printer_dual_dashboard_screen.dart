import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import 'library_dashboard_screen.dart';
import 'printer_dashboard_screen.dart';

class PrinterDualDashboardScreen extends StatelessWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const PrinterDualDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  Future<void> _open(
    BuildContext context,
    Widget page,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظام المطبعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              account.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 850;
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 48 : 16,
                vertical: 20,
              ),
              children: [
                Container(
                  padding: EdgeInsets.all(desktop ? 28 : 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF143B68), Color(0xFF255B91)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً ${account.name}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: desktop ? 26 : 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'حساب المطبعة يحتوي نظامين مستقلين. اختر النظام الذي تريد العمل عليه.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (desktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _bookSupplyCard(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _bookletCard(context)),
                    ],
                  )
                else ...[
                  _bookSupplyCard(context),
                  const SizedBox(height: 14),
                  _bookletCard(context),
                ],
                const SizedBox(height: 20),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'حساب توريد الكتب مستقل عن حساب الملازم. تسويات مورد الكتب لا تختلط بأرباح وذمة طلبات الملازم.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bookSupplyCard(BuildContext context) {
    return _systemCard(
      context,
      icon: Icons.menu_book_rounded,
      title: 'نظام توريد الكتب',
      subtitle: 'توريد الكتب، مستحقات المورد، الذمة، التسويات والوصولات.',
      button: 'فتح توريد الكتب',
      onTap: () => _open(
        context,
        PrinterDashboardScreen(
          repository: repository,
          account: account,
          onLogout: onLogout,
        ),
      ),
    );
  }

  Widget _bookletCard(BuildContext context) {
    return _systemCard(
      context,
      icon: Icons.print_rounded,
      title: 'نظام الملازم والطباعة',
      subtitle: 'يظهر اسم المطبعة مع المكتبات، وتستقبل طلبات الملازم وتجهزها وتطبعها وتسلمها، مع حساب ملازم مستقل.',
      button: 'فتح نظام الملازم',
      onTap: () => _open(
        context,
        LibraryDashboardScreen(
          repository: repository,
          account: account,
          onLogout: onLogout,
        ),
      ),
    );
  }

  Widget _systemCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String button,
    required VoidCallback onTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              child: Icon(icon, size: 29),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
