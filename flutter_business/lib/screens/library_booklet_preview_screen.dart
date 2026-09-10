import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../data/business_repository.dart';
import '../data/library_print_repository.dart';

class LibraryBookletPreviewScreen extends StatefulWidget {
  final BusinessRepository repository;
  final Map<String, dynamic> order;

  const LibraryBookletPreviewScreen({
    super.key,
    required this.repository,
    required this.order,
  });

  @override
  State<LibraryBookletPreviewScreen> createState() => _LibraryBookletPreviewScreenState();
}

class _LibraryBookletPreviewScreenState extends State<LibraryBookletPreviewScreen> {
  bool loading = true;
  bool printing = false;
  String? error;
  Map<String, dynamic> printContext = {};
  Uint8List? bytes;
  PdfControllerPinch? controller;

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
      final ctx = await widget.repository.libraryBookletPrintContext('${widget.order['id']}');
      final data = await widget.repository.libraryDownloadProtectedBooklet(
        bucket: '${ctx['bucket']}',
        objectPath: '${ctx['object_path']}',
      );
      final pdfController = PdfControllerPinch(document: PdfDocument.openData(data));
      if (!mounted) {
        pdfController.dispose();
        return;
      }
      controller?.dispose();
      setState(() {
        printContext = ctx;
        bytes = data;
        controller = pdfController;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> printBooklet() async {
    if (printing || bytes == null) return;
    if (printContext['print_available'] != true) {
      _snack('إذن الطباعة مستخدم أو غير متاح لهذا الطلب');
      return;
    }

    setState(() => printing = true);
    try {
      final printed = await Printing.layoutPdf(
        name: '${printContext['order_number'] ?? widget.order['id']} - ${printContext['title'] ?? 'ملزمة'}',
        onLayout: (_) async => bytes!,
      );
      if (!printed) return;

      await widget.repository.libraryUsePrintPermit('${printContext['permit_id']}');
      if (!mounted) return;
      setState(() => printContext = {
            ...printContext,
            'print_available': false,
            'permit_used': 1,
            'permit_status': 'used',
          });
      _snack('تم تسجيل استخدام إذن الطباعة');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copies = int.tryParse('${printContext['copies']}') ?? int.tryParse('${widget.order['qty']}') ?? 1;
    final canPrint = printContext['print_available'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${printContext['title'] ?? widget.order['title'] ?? 'معاينة الملزمة'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text('المطلوب $copies نسخة', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 54),
                      const SizedBox(height: 12),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(children: [
                        const Icon(Icons.lock_rounded, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            canPrint
                                ? 'عرض محمي داخل آلين للأعمال. لا يوجد تنزيل أو مشاركة. الطباعة مسموحة مرة واحدة لهذا الطلب.'
                                : 'تم استخدام إذن الطباعة لهذا الطلب. المعاينة فقط متاحة حالياً.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: controller == null
                          ? const Center(child: Text('تعذر فتح المستند'))
                          : PdfViewPinch(
                              controller: controller!,
                              padding: 12,
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: loading || error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: canPrint && !printing ? printBooklet : null,
                icon: printing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print_rounded),
                label: Text(
                  printing
                      ? 'جاري تجهيز الطباعة...'
                      : canPrint
                          ? 'طباعة $copies نسخة'
                          : 'تم استخدام إذن الطباعة',
                ),
              ),
            ),
    );
  }
}
