import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import 'admin_accounts_screen.dart';
import 'admin_desktop_dashboard_screen.dart';

class AdminDesktopShellScreen extends StatelessWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const AdminDesktopShellScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AdminDesktopDashboardScreen(
          repository: repository,
          account: account,
          onLogout: onLogout,
        ),
        if (account.role == 'admin')
          PositionedDirectional(
            end: 22,
            bottom: 22,
            child: SafeArea(
              child: Material(
                elevation: 7,
                borderRadius: BorderRadius.circular(18),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(190, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminAccountsScreen(
                        repository: repository,
                        account: account,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('إدارة الحسابات'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
