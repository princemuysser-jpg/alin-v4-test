import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/business_finance_repository.dart';
import '../data/business_repository.dart';
import '../widgets/alin_receipt_template.dart';

class AdminPartyStatementScreen extends StatefulWidget {
  final BusinessRepository repository;
  final Map<String, dynamic> account;

  const AdminPartyStatementScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<AdminPartyStatementScreen> createState() =>
      _AdminPartyStatementScreenState();
}

class _AdminPartyStatementScreenState
    extends State<AdminPartyStatementScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> ledger = [];
  DateTime? fromDate;
  DateTime? toDate;

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

  String get role {
    final raw = '${widget.account['role'] ?? ''}'.toLowerCase();
    return raw == 'courier' ? 'delegate' : raw;
  }

  String get partyId => '${widget.account['id'] ?? ''}';

  String get partyName =>
      '${summary['party_name'] ?? widget.account['name'] ?? 'حساب مالي'}';

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
      final values = await Future.wait([
        widget.repository.financePartySummaryV2(
          role: role,
          partyId: partyId,
        ),
        widget.repository.adminLedger(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(values[0] as Map);
        ledger = (values[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get partyEntries {
    final rows = ledger.where(_belongsToParty).where((row) {
      final status = '${row['status'] ?? ''}'.toLowerCase();
      return status != 'cancelled' && status != 'reversed';
    }).toList();

    rows.retainWhere((row) => _insideDate(row['created_at']));
    rows.sort(
      (a, b) => '${b['created_at'] ?? ''}'.compareTo(
        '${a['created_at'] ?? ''}',
      ),
    );
    return rows;
  }

  List<Map<String, dynamic>> get filteredSettlements {
    final rows = ((summary['settlements'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((row) => _insideDate(row['created_at']))
        .toList();
    rows.sort(
      (a, b) => '${b['created_at'] ?? ''}'.compareTo(
        '${a['created_at'] ?? ''}',
      ),
    );
    return rows;
  }

  bool _insideDate(dynamic raw) {
    final parsed = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (parsed == null) return true;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (fromDate != null) {
      final from = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      if (day.isBefore(from)) return false;
    }
    if (toDate != null) {
      final to = DateTime(toDate!.year, toDate!.month, toDate!.day);
      if (day.isAfter(to)) return false;
    }
    return true;
  }

  bool _belongsToParty(Map<String, dynamic> row) {
    final collectorRole = _normalizedRole('${row['collector_role'] ?? ''}');
    final collectorId = '${row['collector_id'] ?? ''}';
    final collectorMatch = collectorRole == role && collectorId == partyId;

    switch (role) {
      case 'teacher':
        return '${row['teacher_id'] ?? ''}' == partyId &&
            n(row['teacher']) > 0;
      case 'library':
        return collectorMatch ||
            ('${row['library_id'] ?? ''}' == partyId &&
                n(row['library']) > 0);
      case 'delegate':
        return collectorMatch ||
            (('${row['delegate_id'] ?? ''}' == partyId ||
                    '${row['courier_id'] ?? ''}' == partyId) &&
                n(row['delegate'] ?? row['courier']) > 0);
      case 'printer':
        return collectorMatch ||
            ('${row['library_id'] ?? ''}' == partyId &&
                n(row['library']) > 0) ||
            ('${row['supplier_id'] ?? ''}' == partyId &&
                n(row['supplier']) > 0);
      default:
        return collectorMatch;
    }
  }

  String _normalizedRole(String value) {
    final lower = value.trim().toLowerCase();
    return lower == 'courier' ? 'delegate' : lower;
  }

  num _shareFor(Map<String, dynamic> row) {
    return switch (role) {
      'teacher' => n(row['teacher']),
      'library' => n(row['library']),
      'delegate' => n(row['delegate'] ?? row['courier']),
      'printer' => n(row['supplier']) > 0
          ? n(row['supplier'])
          : n(row['library']),
      _ => 0,
    };
  }

  num _debtFor(Map<String, dynamic> row) {
    final collectorRole = _normalizedRole('${row['collector_role'] ?? ''}');
    if (collectorRole == role && '${row['collector_id'] ?? ''}' == partyId) {
      return n(row['collector_debt']);
    }
    return 0;
  }

  String _roleLabel(String value) => switch (_normalizedRole(value)) {
    'teacher' => 'مدرس',
    'library' => 'مكتبة',
    'delegate' => 'مندوب',
    'printer' => 'مطبعة',
    _ => value,
  };

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (parsed == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  String _shortDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب — $partyName'),
        actions: [
          IconButton(
            tooltip: 'طباعة كشف الحساب',
            onPressed: loading || error != null ? null : _printStatement,
            icon: const Icon(Icons.print_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
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
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                children: [
                  _headerCard(),
                  const SizedBox(height: 12),
                  _filterCard(),
                  const SizedBox(height: 16),
                  _sectionTitle(
                    'حركات الطلبات',
                    '${partyEntries.length} حركة ضمن الفترة',
                    Icons.receipt_long_rounded,
                  ),
                  const SizedBox(height: 8),
                  if (partyEntries.isEmpty)
                    _empty('لا توجد حركات طلبات ضمن الفترة المحددة')
                  else
                    ...partyEntries.map(_entryCard),
                  const SizedBox(height: 16),
                  _sectionTitle(
                    'سندات التسوية',
                    '${filteredSettlements.length} سند ضمن الفترة',
                    Icons.account_balance_wallet_rounded,
                  ),
                  const SizedBox(height: 8),
                  if (filteredSettlements.isEmpty)
                    _empty('لا توجد سندات تسوية ضمن الفترة المحددة')
                  else
                    ...filteredSettlements.map(_settlementCard),
                ],
              ),
            ),
    );
  }

  Widget _headerCard() {
    final earned = n(summary['earned']);
    final settled = n(summary['settled']);
    final remaining = n(summary['remaining']);
    final debt = n(summary['debt_total']);

    final metrics = <(String, num, IconData, Color)>[
      (
        role == 'teacher' ? 'الأرباح المكتسبة' : 'الحصة المكتسبة',
        earned,
        Icons.trending_up_rounded,
        const Color(0xFF7C3AED),
      ),
      (
        'المسدد',
        settled,
        Icons.verified_rounded,
        const Color(0xFF0088FF),
      ),
      (
        'المتبقي',
        remaining,
        Icons.account_balance_wallet_rounded,
        const Color(0xFF16A34A),
      ),
      if (role != 'teacher')
        (
          'إجمالي الذمة',
          debt,
          Icons.payments_rounded,
          const Color(0xFFE11D48),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF143B68),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partyName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_roleLabel(role)} • ${summary['orders_count'] ?? 0} طلب',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760
                  ? metrics.length
                  : constraints.maxWidth >= 460
                  ? 2
                  : 1;
              final gap = 8.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            children: [
                              Icon(metric.$3, color: metric.$4, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      metric.$1,
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      money(metric.$2),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF143B68),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (role == 'printer' &&
              (n(summary['book_supply_pending']) > 0 ||
                  n(summary['book_supply_settled']) > 0)) ...[
            const SizedBox(height: 9),
            Text(
              'توريد الكتب: مستحق ${money(summary['book_supply_pending'])} • '
              'مسدد ${money(summary['book_supply_settled'])}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'الفترة:',
            style: TextStyle(
              color: Color(0xFF143B68),
              fontWeight: FontWeight.w900,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(true),
            icon: const Icon(Icons.calendar_today_rounded, size: 17),
            label: Text('من: ${_shortDate(fromDate)}'),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickDate(false),
            icon: const Icon(Icons.event_rounded, size: 17),
            label: Text('إلى: ${_shortDate(toDate)}'),
          ),
          if (fromDate != null || toDate != null)
            TextButton.icon(
              onPressed: () => setState(() {
                fromDate = null;
                toDate = null;
              }),
              icon: const Icon(Icons.close_rounded),
              label: const Text('مسح الفترة'),
            ),
          FilledButton.icon(
            onPressed: _printStatement,
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة كشف PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (fromDate ?? DateTime.now())
        : (toDate ?? DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isFrom) {
        fromDate = value;
        if (toDate != null && value.isAfter(toDate!)) toDate = value;
      } else {
        toDate = value;
        if (fromDate != null && value.isBefore(fromDate!)) fromDate = value;
      }
    });
  }

  Widget _entryCard(Map<String, dynamic> row) {
    final share = _shareFor(row);
    final debt = _debtFor(row);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF143B68),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب #${row['order_number'] ?? row['order_id'] ?? '—'}',
                  style: const TextStyle(
                    color: Color(0xFF143B68),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row['title'] ?? 'طلب'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _date(row['created_at']),
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _amountChip(
                      'قيمة الطلب',
                      n(row['total']),
                      const Color(0xFF143B68),
                    ),
                    if (share > 0)
                      _amountChip(
                        role == 'printer' && n(row['supplier']) > 0
                            ? 'توريد'
                            : 'الحصة',
                        share,
                        const Color(0xFF7C3AED),
                      ),
                    if (debt > 0)
                      _amountChip(
                        'الذمة',
                        debt,
                        const Color(0xFFE11D48),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountChip(String label, num value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      child: Text(
        '$label: ${money(value)}',
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _settlementCard(Map<String, dynamic> settlement) {
    final reversed =
        '${settlement['status'] ?? ''}' == 'reversed' ||
        '${settlement['status'] ?? ''}' == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: reversed
              ? const Color(0xFFFFCCD7)
              : const Color(0xFFDDE8F3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            reversed ? Icons.undo_rounded : Icons.receipt_long_rounded,
            color: reversed
                ? const Color(0xFFE11D48)
                : const Color(0xFF143B68),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: InkWell(
              onTap: () => showAlinSettlementReceipt(
                context,
                settlement,
                partyName: partyName,
                partyRole: role,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settlement['receipt_number'] ?? settlement['id']}',
                    style: const TextStyle(
                      color: Color(0xFF143B68),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_date(settlement['created_at'])} • '
                    '${_paymentMethodLabel('${settlement['payment_method'] ?? ''}')}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
                  if ('${settlement['note'] ?? ''}'.trim().isNotEmpty)
                    Text(
                      '${settlement['note']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF475467),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(settlement['amount']),
                style: TextStyle(
                  color: reversed
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF16A34A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextButton.icon(
                onPressed: () => printAlinSettlementReceiptPdf(
                  settlement,
                  partyName: partyName,
                  partyRole: role,
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('طباعة'),
              ),
              if (!reversed &&
                  '${settlement['reversed_from'] ?? ''}'.isEmpty)
                TextButton(
                  onPressed: () => _reverseSettlement(settlement),
                  child: const Text('عكس'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String value) => switch (value.toLowerCase()) {
    'cash' => 'نقدي',
    'transfer' || 'bank_transfer' => 'تحويل',
    _ => value.isEmpty ? '—' : value,
  };

  Future<void> _reverseSettlement(Map<String, dynamic> settlement) async {
    final reason = TextEditingController();
    bool valid = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('عكس التسوية'),
          content: TextField(
            controller: reason,
            autofocus: true,
            maxLength: 250,
            maxLines: 3,
            onChanged: (value) =>
                setLocal(() => valid = value.trim().length >= 3),
            decoration: const InputDecoration(
              labelText: 'سبب العكس',
              hintText: 'اكتب سبب واضح لعكس السند',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: valid
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('تأكيد العكس'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      reason.dispose();
      return;
    }

    try {
      await widget.repository.adminReverseSettlementV2(
        settlementId: '${settlement['id']}',
        reason: reason.text.trim(),
      );
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم عكس التسوية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      reason.dispose();
    }
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FB),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF143B68), size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF143B68),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE3EAF1)),
    ),
    alignment: Alignment.center,
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF667085),
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Future<void> _printStatement() async {
    final entries = partyEntries;
    final settlementRows = filteredSettlements;

    try {
      final regular = await PdfGoogleFonts.notoKufiArabicRegular();
      final bold = await PdfGoogleFonts.notoKufiArabicBold();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );

      final statementTitle = fromDate == null && toDate == null
          ? 'كشف حساب كامل'
          : 'كشف حساب من ${_shortDate(fromDate)} إلى ${_shortDate(toDate)}';

      pw.Widget labelValue(String label, String value, {bool strong = false}) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  label,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                    fontWeight:
                        strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: strong ? 11 : 9,
                  fontWeight:
                      strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pdfContext) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey900,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'منصة آلين',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 19,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          statementTitle,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    partyName,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _roleLabel(role),
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  labelValue('المكتسب', money(summary['earned'])),
                  if (role != 'teacher')
                    labelValue('إجمالي الذمة', money(summary['debt_total'])),
                  labelValue('المسدد', money(summary['settled'])),
                  labelValue(
                    'المتبقي',
                    money(summary['remaining']),
                    strong: true,
                  ),
                  pw.Divider(height: 20),
                  pw.Text(
                    'حركات الطلبات (${entries.length})',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if (entries.isEmpty)
                    pw.Text(
                      'لا توجد حركات ضمن الفترة',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    )
                  else
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: .5,
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.05),
                        1: pw.FlexColumnWidth(2.2),
                        2: pw.FlexColumnWidth(1.15),
                        3: pw.FlexColumnWidth(1.0),
                        4: pw.FlexColumnWidth(1.0),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            _pdfCell('الطلب', bold: true),
                            _pdfCell('المادة', bold: true),
                            _pdfCell('التاريخ', bold: true),
                            _pdfCell('الحصة', bold: true),
                            _pdfCell('الذمة', bold: true),
                          ],
                        ),
                        ...entries.map(
                          (row) => pw.TableRow(
                            children: [
                              _pdfCell(
                                '${row['order_number'] ?? row['order_id'] ?? '—'}',
                              ),
                              _pdfCell('${row['title'] ?? 'طلب'}'),
                              _pdfCell(_dateOnly(row['created_at'])),
                              _pdfCell(money(_shareFor(row))),
                              _pdfCell(money(_debtFor(row))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'سندات التسوية (${settlementRows.length})',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if (settlementRows.isEmpty)
                    pw.Text(
                      'لا توجد سندات ضمن الفترة',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    )
                  else
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: .5,
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.5),
                        1: pw.FlexColumnWidth(1.0),
                        2: pw.FlexColumnWidth(1.0),
                        3: pw.FlexColumnWidth(1.0),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            _pdfCell('رقم السند', bold: true),
                            _pdfCell('التاريخ', bold: true),
                            _pdfCell('الحالة', bold: true),
                            _pdfCell('المبلغ', bold: true),
                          ],
                        ),
                        ...settlementRows.map(
                          (row) => pw.TableRow(
                            children: [
                              _pdfCell(
                                '${row['receipt_number'] ?? row['id'] ?? '—'}',
                              ),
                              _pdfCell(_dateOnly(row['created_at'])),
                              _pdfCell('${row['status'] ?? '—'}'),
                              _pdfCell(money(row['amount'])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 18),
                  pw.Center(
                    child: pw.Text(
                      'تم إصدار كشف الحساب من منصة آلين',
                      style: const pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        name: 'alin-statement-$partyId',
        onLayout: (_) => pdf.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تجهيز كشف الحساب: ${'$e'.replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _dateOnly(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (parsed == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)}';
  }
}
