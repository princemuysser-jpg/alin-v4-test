import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/business_dashboard_insights.dart';
import 'business_brand.dart';

/// Advanced command center, showing recent activity and actionable queue.
/// All counts come from the live grouped checkout snapshot received by caller.
class BusinessCommandCenter extends StatelessWidget {
  final List<Map<String, dynamic>> groupedOrders;
  final int newOrders;
  final int processingOrders;
  final int readyOrders;
  final int unreadNotifications;
  final VoidCallback onNewOrders;
  final VoidCallback onProcessing;
  final VoidCallback onReadyOrders;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;

  const BusinessCommandCenter({
    super.key,
    required this.groupedOrders,
    required this.newOrders,
    required this.processingOrders,
    required this.readyOrders,
    required this.unreadNotifications,
    required this.onNewOrders,
    required this.onProcessing,
    required this.onReadyOrders,
    required this.onNotifications,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = BusinessDashboardInsights.ordersByDay(groupedOrders, today: now);
    final total = values.fold<int>(0, (a, b) => a + b);
    final maximum = math.max(1, values.reduce(math.max));
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 930;
        final activity = _activityCard(now, values, total, maximum);
        final followUp = _followUpCard();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مركز المتابعة', style: TextStyle(
                        color: BusinessBrand.ink,
                        fontSize: 19, fontWeight: FontWeight.w900,
                      )),
                      SizedBox(height: 4),
                      Text('نشاط الطلبات وأهم الإجراءات التي تحتاج انتباهك',
                        style: TextStyle(color: BusinessBrand.muted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تحديث لوحة المتابعة',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: BusinessBrand.navy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: activity),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: followUp),
                ],
              )
            else ...[
              activity,
              const SizedBox(height: 14),
              followUp,
            ],
          ],
        );
      },
    );
  }

  Widget _activityCard(DateTime now, List<int> values, int total, int maximum) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BusinessBrand.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39, height: 39,
                decoration: BoxDecoration(color: BusinessBrand.softTeal,
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.show_chart_rounded, color: BusinessBrand.teal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('حركة الطلبات', style: TextStyle(
                  fontWeight: FontWeight.w900, color: BusinessBrand.ink, fontSize: 15,
                )),
              ),
              Text('$total', style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 23, color: BusinessBrand.navy)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('آخر 7 أيام • الطلبات ضمن آخر 600 سجل محمّل',
            style: TextStyle(color: BusinessBrand.muted, fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final value = values[i];
                final fraction = value / maximum;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$value', style: const TextStyle(
                          fontSize: 10, color: BusinessBrand.muted,
                          fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: math.max(.045, fraction),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == 6 ? BusinessBrand.teal : BusinessBrand.softBlue,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(BusinessDashboardInsights.dayLabel(now, i),
                            style: const TextStyle(color: BusinessBrand.muted,
                              fontSize: 10.5)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 13),
          const Text('مؤشر تشغيلي من عينة الطلبات، وليس تقرير المبيعات الكامل',
            style: TextStyle(color: BusinessBrand.muted, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _followUpCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BusinessBrand.panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.radar_rounded, color: BusinessBrand.teal),
            SizedBox(width: 9),
            Expanded(child: Text('يحتاج متابعة', style: TextStyle(
              color: BusinessBrand.ink, fontSize: 15, fontWeight: FontWeight.w900))),
          ],
        ),
        const SizedBox(height: 4),
        const Text('اضغط على البند للانتقال مباشرةً إلى العمل',
          style: TextStyle(fontSize: 11, color: BusinessBrand.muted)),
        const SizedBox(height: 12),
        _action('طلبات جديدة', '$newOrders', Icons.new_releases_outlined,
          BusinessBrand.teal, onNewOrders),
        _action('قيد التنفيذ والطباعة', '$processingOrders', Icons.print_outlined,
          BusinessBrand.warning, onProcessing),
        _action('طلبات جاهزة', '$readyOrders', Icons.inventory_2_outlined,
          const Color(0xFF397ACA), onReadyOrders),
        _action('إشعارات غير مقروءة', '$unreadNotifications',
          Icons.notifications_outlined, BusinessBrand.danger, onNotifications),
      ],
    ),
  );

  Widget _action(String label, String count, IconData icon, Color accent,
    VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: accent),
                const SizedBox(width: 10),
                Expanded(child: Text(label, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: BusinessBrand.ink,
                    fontSize: 12, fontWeight: FontWeight.w700))),
                Text(count, style: TextStyle(color: accent,
                  fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_left_rounded, color: BusinessBrand.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
