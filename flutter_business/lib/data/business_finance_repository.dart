import 'business_repository.dart';

extension BusinessFinanceRepository on BusinessRepository {
  Future<Map<String, dynamic>> adminFinanceOverviewV2() async {
    final raw = await client.rpc('alin_admin_finance_overview_v2');
    if (raw is! Map) throw Exception('تعذر تحميل الملخص المالي');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحميل الملخص المالي'}');
    return map;
  }

  Future<Map<String, dynamic>> financePartySummaryV2({
    required String role,
    required String partyId,
  }) async {
    final raw = await client.rpc('alin_finance_party_summary_v2', params: {
      'p_role': role,
      'p_party_id': partyId,
    });
    if (raw is! Map) throw Exception('تعذر تحميل رصيد الحساب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحميل رصيد الحساب'}');
    return map;
  }

  Future<Map<String, dynamic>> adminRecordSettlementV2({
    required String role,
    required String partyId,
    required num amount,
    required String method,
    String note = '',
  }) async {
    final raw = await client.rpc('alin_finance_record_settlement_v2', params: {
      'p_role': role,
      'p_party_id': partyId,
      'p_amount': amount,
      'p_method': method,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تثبيت التسوية');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تثبيت التسوية'}');
    return map;
  }

  Future<Map<String, dynamic>> adminReverseSettlementV2({
    required String settlementId,
    required String reason,
  }) async {
    final raw = await client.rpc('alin_finance_reverse_settlement_v2', params: {
      'p_settlement_id': settlementId,
      'p_reason': reason.trim(),
    });
    if (raw is! Map) throw Exception('تعذر عكس التسوية');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر عكس التسوية'}');
    return map;
  }

  Future<List<Map<String, dynamic>>> adminBookSupplierBalancesV2() async {
    final raw = await client.rpc('alin_admin_book_supplier_balances');
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> adminSettleBookSupplier({
    required String supplierKey,
    String note = '',
  }) async {
    final raw = await client.rpc('alin_admin_settle_book_supplier', params: {
      'p_supplier_key': supplierKey,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تسوية مورد الكتب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تسوية مورد الكتب'}');
    return map;
  }
}
