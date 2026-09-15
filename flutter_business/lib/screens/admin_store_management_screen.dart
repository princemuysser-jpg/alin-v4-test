import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

enum StoreManagementTab { products, categories, banners }

class AdminStoreManagementScreen extends StatefulWidget {
  final BusinessRepository repository;
  final StoreManagementTab initialTab;

  const AdminStoreManagementScreen({
    super.key,
    required this.repository,
    this.initialTab = StoreManagementTab.products,
  });

  @override
  State<AdminStoreManagementScreen> createState() =>
      _AdminStoreManagementScreenState();
}

class _AdminStoreManagementScreenState
    extends State<AdminStoreManagementScreen> {
  static const _bucket = 'alin-files';

  bool loading = true;
  String? error;
  String productSearch = '';
  String productType = 'all';
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subcategories = [];
  List<Map<String, dynamic>> banners = [];

  SupabaseClient get client => widget.repository.client;

  @override
  void initState() {
    super.initState();
    load();
  }

  String _id(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = Random().nextInt(999999).toString().padLeft(6, '0');
    return '$prefix$now$salt';
  }

  num _n(dynamic value) => num.tryParse('$value') ?? 0;
  String _money(dynamic value) => '${_n(value).round()} د.ع';

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        client
            .from('products')
            .select(
              'id,name,title,type,category,category_id,subcategory_id,price,sale_price,stock,low_stock_limit,description,details,image_path,images,status,deleted_at,created_at,updated_at',
            )
            .order('created_at', ascending: false),
        client
            .from('categories')
            .select('id,type,name,status,sort_order,created_at,updated_at')
            .order('sort_order')
            .order('name'),
        client
            .from('product_subcategories')
            .select(
              'id,parent_category_id,name,status,sort_order,created_at,updated_at',
            )
            .order('sort_order')
            .order('name'),
        client
            .from('banners')
            .select(
              'id,title,subtitle,image_path,image_url,link_url,button_text,placement,active,status,sort_order,starts_at,ends_at,created_at,updated_at',
            )
            .order('sort_order')
            .order('created_at', ascending: false),
      ]);
      if (!mounted) return;
      setState(() {
        products = (values[0] as List).cast<Map<String, dynamic>>();
        categories = (values[1] as List).cast<Map<String, dynamic>>();
        subcategories = (values[2] as List).cast<Map<String, dynamic>>();
        banners = (values[3] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _publicImage(dynamic value) {
    final path = '${value ?? ''}'.trim();
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<String?> _pickAndUpload(String folder) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('تعذر قراءة الصورة');
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('حجم الصورة يجب أن يكون أقل من 5MB');
    }
    final ext = (file.extension ?? 'png').toLowerCase();
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final path =
        '$folder/${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}.$ext';
    await client.storage.from(_bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المتجر'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_rounded), text: 'المنتجات'),
              Tab(icon: Icon(Icons.category_rounded), text: 'الأقسام'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'الإعلانات'),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _errorView()
                : TabBarView(
                    children: [
                      _productsTab(),
                      _categoriesTab(),
                      _bannersTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );

  List<Map<String, dynamic>> get _visibleProducts {
    final q = productSearch.trim().toLowerCase();
    return products.where((row) {
      if (row['deleted_at'] != null) return false;
      final type = '${row['type'] ?? ''}'.toLowerCase();
      if (productType != 'all' && type != productType) return false;
      if (q.isEmpty) return true;
      final text =
          '${row['name'] ?? ''} ${row['title'] ?? ''} ${row['category'] ?? ''} ${row['description'] ?? ''}'
              .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Widget _productsTab() {
    final rows = _visibleProducts;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pageHeader(
            icon: Icons.inventory_2_rounded,
            title: 'المنتجات',
            subtitle: 'إضافة وتعديل القرطاسية والهدايا والمخزون والأسعار',
            actionLabel: 'إضافة منتج',
            onAction: () => _productDialog(),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final search = TextField(
                    onChanged: (v) => setState(() => productSearch = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'بحث بالاسم أو القسم',
                    ),
                  );
                  final type = DropdownButtonFormField<String>(
                    initialValue: productType,
                    decoration: const InputDecoration(labelText: 'النوع'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(
                        value: 'stationery',
                        child: Text('قرطاسية'),
                      ),
                      DropdownMenuItem(value: 'gift', child: Text('هدايا')),
                    ],
                    onChanged: (v) =>
                        setState(() => productType = v ?? 'all'),
                  );
                  if (c.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(flex: 2, child: search),
                        const SizedBox(width: 10),
                        Expanded(child: type),
                      ],
                    );
                  }
                  return Column(
                    children: [search, const SizedBox(height: 10), type],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _empty('لا توجد منتجات')
          else
            ...rows.map(_productCard),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> row) {
    final image = _publicImage(row['image_path']);
    final status = '${row['status'] ?? 'published'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: BusinessBrand.softBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: image.isEmpty
                  ? const Icon(Icons.inventory_2_rounded, size: 30)
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row['name'] ?? row['title'] ?? 'منتج'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _statusChip(status == 'published' ? 'منشور' : 'مخفي',
                          active: status == 'published'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_typeLabel(row['type'])} • ${row['category'] ?? 'بدون قسم'}',
                    style: const TextStyle(color: BusinessBrand.muted),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('السعر: ${_money(row['sale_price'] ?? row['price'])}'),
                      Text('المخزون: ${_n(row['stock']).round()}'),
                      if (_n(row['stock']) <= _n(row['low_stock_limit']))
                        const Text(
                          'مخزون منخفض',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') await _productDialog(existing: row);
                if (value == 'toggle') await _toggleProduct(row);
                if (value == 'delete') await _deleteProduct(row);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(status == 'published' ? 'إخفاء' : 'نشر'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _productDialog({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final price = TextEditingController(text: '${existing?['price'] ?? ''}');
    final salePrice =
        TextEditingController(text: '${existing?['sale_price'] ?? ''}');
    final stock = TextEditingController(text: '${existing?['stock'] ?? 0}');
    final lowStock = TextEditingController(
      text: '${existing?['low_stock_limit'] ?? 5}',
    );
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    final details =
        TextEditingController(text: '${existing?['details'] ?? ''}');

    String type = '${existing?['type'] ?? 'stationery'}';
    if (!['stationery', 'gift'].contains(type)) type = 'stationery';
    String? categoryId = '${existing?['category_id'] ?? ''}'.trim().isEmpty
        ? null
        : '${existing?['category_id']}';
    String? subcategoryId =
        '${existing?['subcategory_id'] ?? ''}'.trim().isEmpty
            ? null
            : '${existing?['subcategory_id']}';
    String status = '${existing?['status'] ?? 'published'}';
    if (!['published', 'hidden', 'draft'].contains(status)) status = 'published';
    String imagePath = '${existing?['image_path'] ?? ''}';
    bool uploading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final typeCategories = categories
              .where((c) =>
                  '${c['type']}' == type && '${c['status']}' == 'active')
              .toList();
          if (categoryId != null &&
              !typeCategories.any((c) => '${c['id']}' == categoryId)) {
            categoryId = null;
            subcategoryId = null;
          }
          final subs = subcategories
              .where((s) =>
                  categoryId != null &&
                  '${s['parent_category_id']}' == categoryId &&
                  '${s['status']}' == 'active')
              .toList();
          if (subcategoryId != null &&
              !subs.any((s) => '${s['id']}' == subcategoryId)) {
            subcategoryId = null;
          }
          return AlertDialog(
            title: Text(existing == null ? 'إضافة منتج' : 'تعديل المنتج'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'اسم المنتج *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'النوع'),
                      items: const [
                        DropdownMenuItem(
                          value: 'stationery',
                          child: Text('قرطاسية'),
                        ),
                        DropdownMenuItem(value: 'gift', child: Text('هدايا')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() {
                          type = v;
                          categoryId = null;
                          subcategoryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'القسم'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('بدون قسم'),
                        ),
                        ...typeCategories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: '${c['id']}',
                            child: Text('${c['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() {
                        categoryId = v;
                        subcategoryId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: subcategoryId,
                      decoration: const InputDecoration(labelText: 'الشعبة الفرعية'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('بدون شعبة'),
                        ),
                        ...subs.map(
                          (s) => DropdownMenuItem<String?>(
                            value: '${s['id']}',
                            child: Text('${s['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => subcategoryId = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'السعر *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: salePrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر العرض (اختياري)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'المخزون'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lowStock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تنبيه المخزون عند',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: details,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'التفاصيل'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('منشور'),
                        ),
                        DropdownMenuItem(value: 'hidden', child: Text('مخفي')),
                        DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imagePath.isEmpty
                                ? 'لا توجد صورة للمنتج'
                                : 'تم تحديد صورة المنتج',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: uploading
                              ? null
                              : () async {
                                  setLocal(() => uploading = true);
                                  try {
                                    final path = await _pickAndUpload('products');
                                    if (path != null) {
                                      setLocal(() => imagePath = path);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      _snack('$e'.replaceFirst('Exception: ', ''));
                                    }
                                  } finally {
                                    setLocal(() => uploading = false);
                                  }
                                },
                          icon: uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_rounded),
                          label: Text(uploading ? 'جاري الرفع' : 'رفع صورة'),
                        ),
                      ],
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
              FilledButton(
                onPressed: uploading
                    ? null
                    : () {
                        if (name.text.trim().isEmpty ||
                            _n(price.text) <= 0) {
                          _snack('اكتب اسم المنتج وسعراً صحيحاً');
                          return;
                        }
                        final category = categoryId == null
                            ? null
                            : categories.cast<Map<String, dynamic>?>().firstWhere(
                                  (c) => '${c?['id']}' == categoryId,
                                  orElse: () => null,
                                );
                        Navigator.pop(dialogContext, {
                          'name': name.text.trim(),
                          'title': name.text.trim(),
                          'type': type,
                          'category_id': categoryId,
                          'category': category?['name'],
                          'subcategory_id': subcategoryId,
                          'price': _n(price.text),
                          'sale_price': salePrice.text.trim().isEmpty
                              ? null
                              : _n(salePrice.text),
                          'stock': _n(stock.text),
                          'low_stock_limit': _n(lowStock.text),
                          'description': description.text.trim(),
                          'details': details.text.trim(),
                          'image_path': imagePath.isEmpty ? null : imagePath,
                          'images': imagePath.isEmpty ? <String>[] : [imagePath],
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

    name.dispose();
    price.dispose();
    salePrice.dispose();
    stock.dispose();
    lowStock.dispose();
    description.dispose();
    details.dispose();

    if (result == null) return;
    try {
      if (existing == null) {
        await client.from('products').insert({
          'id': _id('PRD'),
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client.from('products').update(result).eq('id', '${existing['id']}');
      }
      await load();
      _snack(existing == null ? 'تمت إضافة المنتج' : 'تم تحديث المنتج');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleProduct(Map<String, dynamic> row) async {
    final published = '${row['status']}' == 'published';
    try {
      await client.from('products').update({
        'status': published ? 'hidden' : 'published',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', '${row['id']}');
      await load();
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> row) async {
    final ok = await _confirm('حذف المنتج', 'هل تريد حذف هذا المنتج من المتجر؟');
    if (!ok) return;
    try {
      await client.from('products').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'archived',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', '${row['id']}');
      await load();
      _snack('تم حذف المنتج');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget _categoriesTab() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pageHeader(
            icon: Icons.category_rounded,
            title: 'أقسام المتجر',
            subtitle: 'إدارة الأقسام والشعب وترتيب ظهورها في المتجر',
            actionLabel: 'إضافة قسم',
            onAction: () => _categoryDialog(),
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            _empty('لا توجد أقسام')
          else
            ...categories.map(_categoryCard),
        ],
      ),
    );
  }

  Widget _categoryCard(Map<String, dynamic> row) {
    final subs = subcategories
        .where((s) => '${s['parent_category_id']}' == '${row['id']}')
        .toList();
    final active = '${row['status']}' == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: BusinessBrand.softBlue,
          child: const Icon(Icons.category_rounded, color: BusinessBrand.navy),
        ),
        title: Text(
          '${row['name']}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_typeLabel(row['type'])} • الترتيب ${row['sort_order'] ?? 0}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip(active ? 'فعال' : 'مخفي', active: active),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') await _categoryDialog(existing: row);
                if (value == 'toggle') await _toggleCategory(row);
                if (value == 'sub') await _subcategoryDialog(row);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل القسم')),
                const PopupMenuItem(value: 'sub', child: Text('إضافة شعبة')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(active ? 'إخفاء القسم' : 'تفعيل القسم'),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (subs.isEmpty)
            const ListTile(title: Text('لا توجد شعب فرعية'))
          else
            ...subs.map(
              (sub) => ListTile(
                leading: const Icon(Icons.subdirectory_arrow_left_rounded),
                title: Text('${sub['name']}'),
                subtitle: Text('الترتيب ${sub['sort_order'] ?? 0}'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'تعديل',
                      onPressed: () => _subcategoryDialog(row, existing: sub),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _deleteSubcategory(sub),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _subcategoryDialog(row),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة شعبة'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _categoryDialog({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final order =
        TextEditingController(text: '${existing?['sort_order'] ?? 10}');
    String type = '${existing?['type'] ?? 'stationery'}';
    if (!['booklet', 'stationery', 'gift'].contains(type)) type = 'stationery';
    String status = '${existing?['status'] ?? 'active'}';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'إضافة قسم' : 'تعديل القسم'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم القسم *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'نوع القسم'),
                  items: const [
                    DropdownMenuItem(value: 'booklet', child: Text('ملازم')),
                    DropdownMenuItem(
                      value: 'stationery',
                      child: Text('قرطاسية / كتب'),
                    ),
                    DropdownMenuItem(value: 'gift', child: Text('هدايا')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => type = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الترتيب'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('فعال')),
                    DropdownMenuItem(value: 'inactive', child: Text('مخفي')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  _snack('اكتب اسم القسم');
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'type': type,
                  'status': status,
                  'sort_order': int.tryParse(order.text) ?? 10,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    order.dispose();
    if (result == null) return;
    try {
      if (existing == null) {
        await client.from('categories').insert({
          'id': _id('CAT-'),
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client
            .from('categories')
            .update(result)
            .eq('id', '${existing['id']}');
      }
      await load();
      _snack(existing == null ? 'تمت إضافة القسم' : 'تم تحديث القسم');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleCategory(Map<String, dynamic> row) async {
    final active = '${row['status']}' == 'active';
    try {
      await client.from('categories').update({
        'status': active ? 'inactive' : 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', '${row['id']}');
      await load();
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _subcategoryDialog(
    Map<String, dynamic> category, {
    Map<String, dynamic>? existing,
  }) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final order =
        TextEditingController(text: '${existing?['sort_order'] ?? 10}');
    String status = '${existing?['status'] ?? 'active'}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            existing == null
                ? 'إضافة شعبة إلى ${category['name']}'
                : 'تعديل الشعبة',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الشعبة *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('فعال')),
                  DropdownMenuItem(value: 'inactive', child: Text('مخفي')),
                ],
                onChanged: (v) {
                  if (v != null) setLocal(() => status = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'parent_category_id': '${category['id']}',
                  'name': name.text.trim(),
                  'status': status,
                  'sort_order': int.tryParse(order.text) ?? 10,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    order.dispose();
    if (result == null) return;
    try {
      if (existing == null) {
        await client.from('product_subcategories').insert({
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client
            .from('product_subcategories')
            .update(result)
            .eq('id', '${existing['id']}');
      }
      await load();
      _snack(existing == null ? 'تمت إضافة الشعبة' : 'تم تحديث الشعبة');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteSubcategory(Map<String, dynamic> row) async {
    final ok = await _confirm('حذف الشعبة', 'هل تريد حذف هذه الشعبة؟');
    if (!ok) return;
    try {
      await client.from('product_subcategories').delete().eq('id', '${row['id']}');
      await load();
      _snack('تم حذف الشعبة');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget _bannersTab() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pageHeader(
            icon: Icons.campaign_rounded,
            title: 'الإعلانات والبنرات',
            subtitle: 'إدارة إعلانات واجهة المتجر وترتيب ظهورها',
            actionLabel: 'إضافة إعلان',
            onAction: () => _bannerDialog(),
          ),
          const SizedBox(height: 14),
          if (banners.isEmpty)
            _empty('لا توجد إعلانات')
          else
            ...banners.map(_bannerCard),
        ],
      ),
    );
  }

  Widget _bannerCard(Map<String, dynamic> row) {
    final image = _publicImage(row['image_path'] ?? row['image_url']);
    final active = row['active'] == true && '${row['status']}' == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final preview = Container(
              width: c.maxWidth >= 700 ? 190 : double.infinity,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: BusinessBrand.softBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: image.isEmpty
                  ? const Icon(Icons.image_rounded, size: 32)
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            );
            final details = Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: c.maxWidth >= 700 ? 14 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row['title'] ?? 'إعلان'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _statusChip(active ? 'فعال' : 'متوقف', active: active),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if ('${row['subtitle'] ?? ''}'.trim().isNotEmpty)
                      Text(
                        '${row['subtitle']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 5),
                    Text(
                      'المكان: ${row['placement'] ?? 'store'} • الترتيب: ${row['sort_order'] ?? 0}',
                      style: const TextStyle(color: BusinessBrand.muted),
                    ),
                  ],
                ),
              ),
            );
            final menu = PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') await _bannerDialog(existing: row);
                if (value == 'toggle') await _toggleBanner(row);
                if (value == 'delete') await _deleteBanner(row);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(active ? 'إيقاف الإعلان' : 'تفعيل الإعلان'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
            if (c.maxWidth >= 700) {
              return Row(children: [preview, details, menu]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: 10),
                Row(children: [details, menu]),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _bannerDialog({Map<String, dynamic>? existing}) async {
    final title = TextEditingController(text: '${existing?['title'] ?? ''}');
    final subtitle =
        TextEditingController(text: '${existing?['subtitle'] ?? ''}');
    final link = TextEditingController(text: '${existing?['link_url'] ?? ''}');
    final button =
        TextEditingController(text: '${existing?['button_text'] ?? ''}');
    final order =
        TextEditingController(text: '${existing?['sort_order'] ?? 0}');
    String placement = '${existing?['placement'] ?? 'store'}';
    bool active = existing?['active'] == null ? true : existing?['active'] == true;
    String status = '${existing?['status'] ?? 'active'}';
    String imagePath =
        '${existing?['image_path'] ?? existing?['image_url'] ?? ''}';
    bool uploading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'إضافة إعلان' : 'تعديل الإعلان'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'عنوان الإعلان *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'النص الفرعي'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: link,
                          decoration: const InputDecoration(
                            labelText: 'رابط الإعلان (اختياري)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: button,
                          decoration: const InputDecoration(
                            labelText: 'نص الزر (اختياري)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: placement,
                          decoration: const InputDecoration(labelText: 'المكان'),
                          items: const [
                            DropdownMenuItem(
                              value: 'store',
                              child: Text('واجهة المتجر'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setLocal(() => placement = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'الترتيب'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الإعلان فعال'),
                    value: active,
                    onChanged: (v) => setLocal(() {
                      active = v;
                      status = v ? 'active' : 'inactive';
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          imagePath.isEmpty
                              ? 'لا توجد صورة للإعلان'
                              : 'تم تحديد صورة الإعلان',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: uploading
                            ? null
                            : () async {
                                setLocal(() => uploading = true);
                                try {
                                  final path = await _pickAndUpload('banners');
                                  if (path != null) {
                                    setLocal(() => imagePath = path);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    _snack('$e'.replaceFirst('Exception: ', ''));
                                  }
                                } finally {
                                  setLocal(() => uploading = false);
                                }
                              },
                        icon: uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.image_rounded),
                        label: Text(uploading ? 'جاري الرفع' : 'رفع صورة'),
                      ),
                    ],
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
            FilledButton(
              onPressed: uploading
                  ? null
                  : () {
                      if (title.text.trim().isEmpty || imagePath.isEmpty) {
                        _snack('اكتب عنوان الإعلان وارفع صورته');
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'title': title.text.trim(),
                        'subtitle': subtitle.text.trim(),
                        'image_path': imagePath,
                        'image_url': null,
                        'link_url': link.text.trim().isEmpty ? null : link.text.trim(),
                        'button_text': button.text.trim().isEmpty
                            ? null
                            : button.text.trim(),
                        'placement': placement,
                        'active': active,
                        'status': status,
                        'sort_order': int.tryParse(order.text) ?? 0,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      });
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    subtitle.dispose();
    link.dispose();
    button.dispose();
    order.dispose();
    if (result == null) return;
    try {
      if (existing == null) {
        await client.from('banners').insert({
          'id': _id('BN'),
          ...result,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client
            .from('banners')
            .update(result)
            .eq('id', '${existing['id']}');
      }
      await load();
      _snack(existing == null ? 'تمت إضافة الإعلان' : 'تم تحديث الإعلان');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleBanner(Map<String, dynamic> row) async {
    final active = row['active'] == true && '${row['status']}' == 'active';
    try {
      await client.from('banners').update({
        'active': !active,
        'status': active ? 'inactive' : 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', '${row['id']}');
      await load();
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> row) async {
    final ok = await _confirm('حذف الإعلان', 'هل تريد حذف هذا الإعلان نهائياً؟');
    if (!ok) return;
    try {
      await client.from('banners').delete().eq('id', '${row['id']}');
      await load();
      _snack('تم حذف الإعلان');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget _pageHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BusinessBrand.heroGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final info = Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white.withValues(alpha: .14),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: BusinessBrand.navy,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          );
          if (c.maxWidth >= 720) {
            return Row(
              children: [Expanded(child: info), const SizedBox(width: 16), button],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 14), button],
          );
        },
      ),
    );
  }

  Widget _statusChip(String label, {required bool active}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? BusinessBrand.softTeal : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.teal.shade800 : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _empty(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Center(child: Text(text)),
        ),
      );

  Future<bool> _confirm(String title, String text) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _typeLabel(dynamic value) => switch ('$value') {
        'booklet' => 'ملازم',
        'gift' => 'هدايا',
        'stationery' => 'قرطاسية',
        _ => '$value',
      };
}
