from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'flutter_business/lib/screens/courier_dashboard_screen.dart'
text = PATH.read_text(encoding='utf-8')

old_padding = """          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width > 1180
                ? (MediaQuery.sizeOf(context).width - 1120) / 2
                : 16,
            vertical: 16,
          ),"""
new_padding = """          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width > 1280
                ? (MediaQuery.sizeOf(context).width - 1240) / 2
                : 16,
            vertical: 16,
          ),"""
if old_padding in text:
    text = text.replace(old_padding, new_padding, 1)

old_hero = """                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)),
                      child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 31),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25)),
                        const SizedBox(height: 3),
                        const Text('طلباتك وتوصيلاتك ووصولاتك بمكان واحد', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        if (courierArea.isNotEmpty || courierAreas.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                        const SizedBox(height: 11),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ChoiceChip(label: const Text('متاح'), selected: availability == 'available', onSelected: (_) => setAvailability('available')),
                          ChoiceChip(label: const Text('مشغول'), selected: availability == 'busy', onSelected: (_) => setAvailability('busy')),
                          ChoiceChip(label: const Text('خارج الخدمة'), selected: availability == 'offline', onSelected: (_) => setAvailability('offline')),
                        ]),
                      ]),
                    ),
                  ]),
                ),"""
new_hero = """                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, heroConstraints) {
                      final compactHero = heroConstraints.maxWidth < 760;
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً ${widget.account.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'طلباتك وتوصيلاتك ووصولاتك بمكان واحد',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (courierArea.isNotEmpty || courierAreas.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 11),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(label: const Text('متاح'), selected: availability == 'available', onSelected: (_) => setAvailability('available')),
                              ChoiceChip(label: const Text('مشغول'), selected: availability == 'busy', onSelected: (_) => setAvailability('busy')),
                              ChoiceChip(label: const Text('خارج الخدمة'), selected: availability == 'offline', onSelected: (_) => setAvailability('offline')),
                            ],
                          ),
                        ],
                      );

                      final icon = Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 31),
                      );

                      if (compactHero) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            icon,
                            const SizedBox(height: 12),
                            details,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 13),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                ),"""
if old_hero not in text:
    raise SystemExit('hero layout pattern not found')
text = text.replace(old_hero, new_hero, 1)

old_tabs = """            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('الحالية'), icon: Icon(Icons.local_shipping_rounded)),
                  ButtonSegment(value: 'completed', label: Text('المكتملة'), icon: Icon(Icons.check_circle_outline)),
                  ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),
                  ButtonSegment(value: 'receipts', label: Text('الوصولات'), icon: Icon(Icons.receipt_long_rounded)),
                ],
                selected: {filter},
                onSelectionChanged: (value) => setState(() => filter = value.first),
              ),
            ),"""
new_tabs = """            LayoutBuilder(
              builder: (context, tabConstraints) {
                final wideTabs = tabConstraints.maxWidth >= 760;
                final tabs = SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('الحالية'), icon: Icon(Icons.local_shipping_rounded)),
                    ButtonSegment(value: 'completed', label: Text('المكتملة'), icon: Icon(Icons.check_circle_outline)),
                    ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),
                    ButtonSegment(value: 'receipts', label: Text('الوصولات'), icon: Icon(Icons.receipt_long_rounded)),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) => setState(() => filter = value.first),
                );
                if (wideTabs) {
                  return Align(alignment: Alignment.centerRight, child: tabs);
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabs,
                );
              },
            ),"""
if old_tabs not in text:
    raise SystemExit('tabs pattern not found')
text = text.replace(old_tabs, new_tabs, 1)

PATH.write_text(text, encoding='utf-8')
print('Courier relogin layout stabilized.')
