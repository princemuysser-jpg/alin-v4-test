#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

# Public core: only what the storefront/student flow needs at startup.
CORE=[
'modules/core/config.js','modules/core/i18n-en.js','modules/core/i18n-ku.js','modules/core/i18n.js',
'modules/core/ui.js','modules/core/platform.js','modules/core/storage.js','modules/core/supabase.js',
'modules/core/notifications.js','modules/store/coupons.js','modules/store/personal-offers.js','modules/admin/shell.js','modules/core/features.js',
'modules/store/student-isolation.js','modules/store/discovery-core.js','modules/store/discovery-catalog.js',
'modules/store/discovery-details.js','modules/store/discovery-growth.js','modules/store/discovery.js',
'modules/store/cart.js','modules/store/order-routing.js','modules/store/student-auth.js','modules/teacher/shell.js','core/role-runtime-loader.js',
'core/runtime-guard.js','core/app-health.js'
]

# Public app: storefront, branding, login/session restore and checkout only.
PUBLIC_APP=[
'modules/core/design.js','modules/library/entry.js','store/banners.js','modules/store/delivery.js','modules/admin/branding.js',
'modules/core/supabase-ui.js','modules/core/cloud-status.js','modules/core/auth-service.js',
'modules/core/checkout-service.js','modules/store/tracking.js','modules/core/cloud-status-ui.js'
]

# Staff runtime: downloaded once only after a teacher/library/courier/admin session is actually needed.
ROLE_APP=[
'core/lazy-libs.js','core/finance-runtime.js','modules/admin/accounts.js',
'modules/teacher/booklets.js','modules/teacher/finance.js','modules/teacher/dashboard.js','modules/teacher/publishing.js',
'modules/teacher/notifications.js','modules/teacher/profile.js','modules/library/dashboard.js','modules/library/orders.js',
'modules/library/finance.js','modules/library/printing.js','modules/admin/dashboard.js','modules/admin/orders.js',
'modules/admin/booklets.js','modules/admin/products.js','modules/admin/accounts-advanced.js','modules/admin/finance.js',
'modules/admin/coupons.js','modules/admin/retention.js','modules/admin/reports.js','modules/admin/settings.js','modules/admin/notifications.js',
'modules/admin/couriers.js','modules/courier/core.js','modules/courier/admin.js','modules/courier/areas.js',
'modules/courier/assignment.js','modules/courier/dashboard.js','modules/courier/finance.js','modules/core/security.js',
'modules/admin/backup.js','modules/core/backend-check.js','modules/core/account-admin-service.js','modules/core/order-bell.js',
'modules/teacher/admin-word-download.js','core/v2-runtime.js','modules/core/receipts-center.js',
'modules/core/receipts-navigation-guard.js','modules/core/section-header.js','modules/admin/remove-diagnostic-tabs.js'
]


def concat(paths,out):
    chunks=[]
    for rel in paths:
        p=ROOT/rel
        if not p.is_file(): raise FileNotFoundError(rel)
        text=p.read_text(encoding='utf-8').rstrip()
        chunks.append(f'/* {rel} */\n{text}\n;\n')
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text('\n'.join(chunks),encoding='utf-8')
    print(f'{out.relative_to(ROOT)} <- {len(paths)} sources')

concat(CORE,ROOT/'dist/alin-core.v4.js')
concat(PUBLIC_APP+['store/notifications.js'],ROOT/'alin-app-desktop.v4.2.0.js')
concat(PUBLIC_APP+['store/mobile-navigation.js','store/notifications.js'],ROOT/'alin-app-mobile.v4.2.0.js')
concat(ROLE_APP,ROOT/'dist/alin-role-runtime.v4.js')
