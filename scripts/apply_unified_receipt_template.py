from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def insert_after(path: str, marker: str, addition: str):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    if addition.strip() in text:
        return
    if marker not in text:
        raise SystemExit(f'marker not found in {path}: {marker!r}')
    p.write_text(text.replace(marker, marker + addition, 1), encoding='utf-8')

# Courier order receipt preview: use the unified design while keeping the existing PDF printer.
insert_after(
    'flutter_business/lib/widgets/grouped_order_receipt_list.dart',
    "import 'business_brand.dart';\n",
    "import 'alin_receipt_template.dart';\n",
)
replace(
    'flutter_business/lib/widgets/grouped_order_receipt_list.dart',
    "                    child: GroupedOrderReceiptCard(\n                      order: widget.order,\n                      courierName: widget.courierName,\n                      courierView: widget.courierView,\n                    ),",
    "                    child: AlinReceiptTemplate.order(\n                      order: widget.order,\n                      courierName: widget.courierName,\n                      courierView: widget.courierView,\n                      viewerRole: widget.courierView ? 'courier' : '',\n                    ),",
)

# Teacher settlement receipts.
insert_after(
    'flutter_business/lib/screens/teacher_dashboard_screen.dart',
    "import '../models/business_account.dart';\n",
    "import '../widgets/alin_receipt_template.dart';\n",
)
replace(
    'flutter_business/lib/screens/teacher_dashboard_screen.dart',
    "            trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),\n          ),",
    "            trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),\n            onTap: () => showAlinSettlementReceipt(\n              context,\n              s,\n              partyName: widget.account.name,\n              partyRole: 'teacher',\n            ),\n          ),",
)

# Library settlement receipts.
insert_after(
    'flutter_business/lib/screens/library_dashboard_screen.dart',
    "import '../models/business_account.dart';\n",
    "import '../widgets/alin_receipt_template.dart';\n",
)
replace(
    'flutter_business/lib/screens/library_dashboard_screen.dart',
    "                      trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),\n                    ),",
    "                      trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),\n                      onTap: () => showAlinSettlementReceipt(\n                        context,\n                        s,\n                        partyName: widget.account.name,\n                        partyRole: 'library',\n                      ),\n                    ),",
)

# Admin: every settlement card opens the same official receipt design.
insert_after(
    'flutter_business/lib/screens/admin_finance_v2_screen.dart',
    "import '../data/business_repository.dart';\n",
    "import '../widgets/alin_receipt_template.dart';\n",
)
replace(
    'flutter_business/lib/screens/admin_finance_v2_screen.dart',
    "        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [\n          Text(money(settlement['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),\n          if (!reversed && '${settlement['reversed_from'] ?? ''}'.isEmpty)\n            TextButton(onPressed: () => _reverseSettlement(settlement), child: const Text('عكس')),\n        ]),\n      ),",
    "        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [\n          Text(money(settlement['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),\n          if (!reversed && '${settlement['reversed_from'] ?? ''}'.isEmpty)\n            TextButton(onPressed: () => _reverseSettlement(settlement), child: const Text('عكس')),\n        ]),\n        onTap: () => showAlinSettlementReceipt(\n          context,\n          settlement,\n          partyName: '${settlement['party_name'] ?? settlement['name'] ?? ''}',\n          partyRole: '${settlement['party_role'] ?? ''}',\n        ),\n      ),",
)

# Bump business build so web/mobile artifacts clearly move to a new build.
pubspec = ROOT / 'flutter_business/pubspec.yaml'
text = pubspec.read_text(encoding='utf-8')
text = text.replace('version: 1.0.4+12', 'version: 1.0.5+13', 1)
text = text.replace('# Build 12: publish courier receipts web-style layout and clearer courier dashboard.', '# Build 13: unified official ALIN receipt design for orders and settlements.', 1)
pubspec.write_text(text, encoding='utf-8')

print('Unified ALIN receipt template integrated successfully.')
