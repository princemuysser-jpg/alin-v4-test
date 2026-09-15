import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminBooksScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminBooksScreen({super.key, required this.repository});

  @override
  State<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> {
  bool loading = true;
  bool settling = false;
  String? error;
  String search = '';
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> libraries = [];
  List<Map<String, dynamic>> balances = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.client
            .from('products')
            .select()
            .eq('type', 'book')
            .order('created_at', ascending: false),
        widget.repository.adminAccounts(),
      ]);
      List<Map<String, dynamic>> supplierBalances = [];
      try {
        final raw = await widget.repository.client.rpc(
          'alin_admin_book_supplier_balances',
        );
        if (raw is List) {
          supplierBalances = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Book management remains available if the optional supplier balance RPC is unavailable.
      }
      if (!mounted) return;
      setState(() {
        books = (values[0] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        libraries = (values[1] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(
              (e) =>
                  '${e['role']}' == 'library' &&
                  '${e['status']}' == 'active' &&
                  e['deleted_at'] == null,
            )
            .toList();
        balances = supplierBalances;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return books;
    return books.where((row) {
      final text =
          '${row['name'] ?? row['title'] ?? ''} ${row['supplier_name'] ?? ''} ${row['description'] ?? ''}'
              .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  String supplierLabel(Map<String, dynamic> row) {
    final type = '${row['supplier_type'] ?? 'platform'}';
    if (type == 'library')
      return 'مكتبة ${row['supplier_name'] ?? 'غير محددة'}';
    if (type == 'printer')
      return 'مطبعة ${row['supplier_name'] ?? 'غير محددة'}';
    return 'منصة آلين';
  }

  Future<void> editBook([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: '${existing?['name'] ?? existing?['title'] ?? ''}',
    );
    final price = TextEditingController(
      text: '${existing?['unit_price'] ?? existing?['price'] ?? 0}',
    );
    final stock = TextEditingController(text: '${existing?['stock'] ?? 0}');
    final lowStock = TextEditingController(
      text: '${existing?['low_stock_limit'] ?? 5}',
    );
    final platformShare = TextEditingController(
      text: '${existing?['platform_share_percent'] ?? 100}',
    );
    final supplierShare = TextEditingController(
      text: '${existing?['supplier_share_percent'] ?? 0}',
    );
    final supplierName = TextEditingController(
      text: '${existing?['supplier_name'] ?? ''}',
    );
    final description = TextEditingController(
      text: '${existing?['description'] ?? existing?['details'] ?? ''}',
    );
    final imagePath = TextEditingController(
      text: '${existing?['image_path'] ?? existing?['image_url'] ?? ''}',
    );
    String supplierType = '${existing?['supplier_type'] ?? 'platform'}';
    if (!const {'platform', 'library', 'printer'}.contains(supplierType))
      supplierType = 'platform';
    String libraryId = '${existing?['supplier_account_id'] ?? ''}';
    String status = '${existing?['status'] ?? 'published'}';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          if (supplierType == 'platform') {
            platformShare.text = '100';
            supplierShare.text = '0';
          }
          return AlertDialog(
            title: Text(existing == null ? 'إضافة كتاب' : 'تعديل الكتاب'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم الكتاب *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر البيع',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المخزون',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lowStock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'حد تنبيه المخزون',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: supplierType,
                      decoration: const InputDecoration(
                        labelText: 'نوع مصدر الكتاب',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'platform',
                          child: Text('مخزون منصة آلين'),
                        ),
                        DropdownMenuItem(
                          value: 'library',
                          child: Text('مكتبة'),
                        ),
                        DropdownMenuItem(
                          value: 'printer',
                          child: Text('مطبعة'),
                        ),
                      ],
                      onChanged: (value) =>
                          setLocal(() => supplierType = value ?? 'platform'),
                    ),
                    const SizedBox(height: 8),
                    if (supplierType == 'library')
                      DropdownButtonFormField<String>(
                        initialValue: libraryId.isEmpty ? null : libraryId,
                        decoration: const InputDecoration(
                          labelText: 'المكتبة الموردة',
                        ),
                        items: libraries
                            .map(
                              (row) => DropdownMenuItem(
                                value: '${row['id']}',
                                child: Text(
                                  '${row['name'] ?? row['username'] ?? row['id']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocal(() => libraryId = value ?? ''),
                      ),
                    if (supplierType == 'printer')
                      TextField(
                        controller: supplierName,
                        decoration: const InputDecoration(
                          labelText: 'اسم المطبعة',
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: platformShare,
                            readOnly: supplierType == 'platform',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'حصة المنصة %',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: supplierShare,
                            readOnly: supplierType == 'platform',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'حصة المورد %',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'حالة الكتاب',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('منشور'),
                        ),
                        DropdownMenuItem(value: 'hidden', child: Text('مخفي')),
                      ],
                      onChanged: (value) =>
                          setLocal(() => status = value ?? 'published'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: imagePath,
                      decoration: const InputDecoration(
                        labelText: 'مسار/رابط صورة الكتاب',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'وصف الكتاب',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'أجرة المندوب مستقلة عن نسب الكتاب، مثل نظام الويب القديم.',
                      style: TextStyle(color: BusinessBrand.muted),
                    ),
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
                  final bookName = name.text.trim();
                  final bookPrice = num.tryParse(price.text.trim()) ?? -1;
                  final bookStock = num.tryParse(stock.text.trim()) ?? -1;
                  final p = num.tryParse(platformShare.text.trim()) ?? -1;
                  final s = num.tryParse(supplierShare.text.trim()) ?? -1;
                  if (bookName.isEmpty ||
                      bookPrice < 0 ||
                      bookStock < 0 ||
                      p < 0 ||
                      s < 0 ||
                      p + s != 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تحقق من الاسم والسعر والمخزون وأن مجموع النسب يساوي 100%',
                        ),
                      ),
                    );
                    return;
                  }
                  if (supplierType == 'library' && libraryId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختر المكتبة الموردة')),
                    );
                    return;
                  }
                  final library = libraries
                      .where((e) => '${e['id']}' == libraryId)
                      .toList();
                  final resolvedSupplierName = supplierType == 'library'
                      ? (library.isEmpty
                            ? ''
                            : '${library.first['name'] ?? ''}')
                      : supplierType == 'printer'
                      ? supplierName.text.trim()
                      : 'منصة آلين';
                  Navigator.pop(context, {
                    'name': bookName,
                    'title': bookName,
                    'type': 'book',
                    'category': 'كتب',
                    'category_id': 'CAT-BOOKS',
                    'unit_price': bookPrice,
                    'price': bookPrice,
                    'stock': bookStock,
                    'low_stock_limit': num.tryParse(lowStock.text.trim()) ?? 5,
                    'description': description.text.trim(),
                    'details': description.text.trim(),
                    'image_path': imagePath.text.trim().isEmpty
                        ? null
                        : imagePath.text.trim(),
                    'platform_share_percent': p,
                    'supplier_share_percent': s,
                    'supplier_type': supplierType,
                    'supplier_account_id': supplierType == 'library'
                        ? libraryId
                        : null,
                    'supplier_name': resolvedSupplierName.isEmpty
                        ? null
                        : resolvedSupplierName,
                    'supplier_pickup_enabled': false,
                    'status': status,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  });
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );

    for (final c in [
      name,
      price,
      stock,
      lowStock,
      platformShare,
      supplierShare,
      supplierName,
      description,
      imagePath,
    ]) {
      c.dispose();
    }
    if (result == null) return;
    try {
      if (existing == null) {
        await widget.repository.client.from('products').insert({
          'id': 'BK-${DateTime.now().microsecondsSinceEpoch}',
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await widget.repository.client
            .from('products')
            .update(result)
            .eq('id', '${existing['id']}');
      }
      await load();
      if (mounted)
        _toast(existing == null ? 'تمت إضافة الكتاب' : 'تم تعديل الكتاب');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> toggleStatus(Map<String, dynamic> row) async {
    final status = '${row['status'] ?? 'published'}' == 'published'
        ? 'hidden'
        : 'published';
    try {
      await widget.repository.client
          .from('products')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', '${row['id']}');
      await load();
      if (mounted)
        _toast(status == 'published' ? 'تم نشر الكتاب' : 'تم إخفاء الكتاب');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> settle(Map<String, dynamic> row) async {
    if (settling) return;
    final key = '${row['supplier_key'] ?? ''}';
    if (key.isEmpty || n(row['pending_amount']) <= 0) return;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تسوية مورد الكتب'),
            content: Text(
              'تثبيت تسوية ${row['supplier_name'] ?? 'المورد'} بمبلغ ${money(row['pending_amount'])}؟\nهذه التسوية مستقلة عن الملازم والمندوبين.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تثبيت التسوية'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => settling = true);
    try {
      await widget.repository.client.rpc(
        'alin_admin_settle_book_supplier',
        params: {'p_supplier_key': key, 'p_note': null},
      );
      await load();
      if (mounted) _toast('تمت تسوية مورد الكتب');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => settling = false);
    }
  }

  void _toast(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final published = books
        .where((e) => '${e['status'] ?? 'published'}' == 'published')
        .length;
    final totalStock = books.fold<num>(0, (sum, e) => sum + n(e['stock']));
    final pending = balances.fold<num>(
      0,
      (sum, e) => sum + n(e['pending_amount']),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكتب'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editBook(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة كتاب'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final count = c.maxWidth >= 900 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: count,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: c.maxWidth >= 900 ? 2.25 : 1.5,
                        children: [
                          _metric(
                            'كل الكتب',
                            '${books.length}',
                            Icons.menu_book_rounded,
                          ),
                          _metric('منشورة', '$published', Icons.public_rounded),
                          _metric(
                            'إجمالي المخزون',
                            '${totalStock.round()}',
                            Icons.inventory_2_rounded,
                          ),
                          _metric(
                            'مستحق الموردين',
                            money(pending),
                            Icons.account_balance_wallet_rounded,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      labelText: 'بحث بالكتب أو المورد',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('لا توجد كتب')),
                      ),
                    )
                  else
                    ...filtered.map(_bookCard),
                  const SizedBox(height: 16),
                  const Text(
                    'تسويات موردي الكتب',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (balances.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'لا توجد مبالغ مستحقة لموردي الكتب حالياً.',
                        ),
                      ),
                    )
                  else
                    ...balances.map(_balanceCard),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: BusinessBrand.softBlue,
            child: Icon(icon, color: BusinessBrand.navy),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bookCard(Map<String, dynamic> row) {
    final image = '${row['image_path'] ?? row['image_url'] ?? ''}'.trim();
    final status = '${row['status'] ?? 'published'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: LayoutBuilder(
          builder: (context, c) {
            final info = Row(
              children: [
                Container(
                  width: 66,
                  height: 78,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: BusinessBrand.softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: image.isEmpty
                      ? const Icon(
                          Icons.menu_book_rounded,
                          color: BusinessBrand.navy,
                          size: 31,
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.menu_book_rounded,
                            color: BusinessBrand.navy,
                          ),
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['name'] ?? row['title'] ?? 'كتاب'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${supplierLabel(row)} • ${money(row['unit_price'] ?? row['price'])}',
                      ),
                      Text(
                        'المخزون: ${n(row['stock']).round()} • المنصة ${n(row['platform_share_percent']).round()}% • المورد ${n(row['supplier_share_percent']).round()}%',
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(status == 'published' ? 'منشور' : 'مخفي'),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(
                  onPressed: () => editBook(row),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
                FilledButton.icon(
                  onPressed: () => toggleStatus(row),
                  icon: Icon(
                    status == 'published'
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  label: Text(status == 'published' ? 'إخفاء' : 'نشر'),
                ),
              ],
            );
            if (c.maxWidth >= 760)
              return Row(
                children: [
                  Expanded(child: info),
                  actions,
                ],
              );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 10), actions],
            );
          },
        ),
      ),
    );
  }

  Widget _balanceCard(Map<String, dynamic> row) => Card(
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: BusinessBrand.softBlue,
        child: Icon(Icons.payments_rounded, color: BusinessBrand.navy),
      ),
      title: Text(
        '${row['supplier_name'] ?? 'مورد كتب'}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${row['supplier_type'] == 'library' ? 'مكتبة' : 'مطبعة'} • ${row['orders_count'] ?? 0} طلب',
      ),
      trailing: n(row['pending_amount']) > 0
          ? FilledButton(
              onPressed: settling ? null : () => settle(row),
              child: Text('تسديد ${money(row['pending_amount'])}'),
            )
          : const Text('مسدد'),
    ),
  );
}
