from pathlib import Path
from urllib.parse import urlsplit
import re,json,sys,hashlib,subprocess
root=Path(__file__).resolve().parents[1]
errors=[]
for html in ['index.html','store-desktop.html','store-mobile.html','setup-new-project.html']:
 p=root/html;text=p.read_text(encoding='utf-8',errors='ignore')
 if re.search(r'\son(?:click|change|input|submit|keydown|keyup|load|error)\s*=',text,re.I): errors.append(f'{html}: inline event attrs')
 for m in re.finditer(r'<script\b([^>]*)>(.*?)</script>',text,re.I|re.S):
  if 'src=' not in m.group(1).lower() and m.group(2).strip(): errors.append(f'{html}: inline script')
 for _,val in re.findall(r'\b(src|href)=["\']([^"\']+)["\']',text,re.I):
  if val.startswith(('http://','https://','data:','#','mailto:','tel:','javascript:')): continue
  path=urlsplit(val).path
  if not path or path=='./': continue
  fp=(p.parent/path).resolve()
  try: fp.relative_to(root.resolve())
  except ValueError: continue
  if not fp.exists(): errors.append(f'{html}: missing {val}')
for mf in ['manifest-desktop.webmanifest','manifest-mobile.webmanifest']:
 try: json.loads((root/mf).read_text(encoding='utf-8'))
 except Exception as e: errors.append(f'{mf}: invalid json {e}')
sw=(root/'service-worker.js').read_text(encoding='utf-8')
for val in re.findall(r"['\"](\./[^'\"?]+)(?:\?[^'\"]*)?['\"]",sw):
 if val!='./' and not (root/val[2:]).exists(): errors.append(f'SW missing {val}')
if not (root/'dist/alin-role-runtime.v4.js').is_file(): errors.append('missing lazy role runtime')
loader=(root/'core/role-runtime-loader.js').read_text(encoding='utf-8',errors='ignore')
if 'dist/alin-role-runtime.v4.js' not in loader: errors.append('role runtime loader path missing')
bad=['financial_entries','financial_payouts','library_settlements','teacher_settlements','delegate_settlements','admin_settlements','order_items']
for base in ['modules','core','store']:
 for p in (root/base).rglob('*.js'):
  t=p.read_text(encoding='utf-8',errors='ignore')
  for x in bad:
   if x in t: errors.append(f'legacy schema {x}: {p.relative_to(root)}')

# Validate actions against JS files that are actually loaded by each storefront.
def local_script_paths(html_path):
 text=html_path.read_text(encoding='utf-8',errors='ignore')
 paths=[]
 for src in re.findall(r'<script\b[^>]*\bsrc=["\']([^"\']+)["\']',text,re.I):
  if src.startswith(('http://','https://','data:')): continue
  rel=urlsplit(src).path
  fp=(html_path.parent/rel).resolve()
  if fp.is_file(): paths.append(fp)
 return paths

def unresolved_loaded_actions(html_name):
 html_path=root/html_name
 scripts=local_script_paths(html_path)
 loaded='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in scripts)
 surface=html_path.read_text(encoding='utf-8',errors='ignore')+'\n'+loaded
 used=set(re.findall(r'data-alin-(?:click|change|input|submit|keydown)=["\']([A-Za-z_$][\w$]*)["\']',surface))
 missing=[]
 for a in sorted(used):
  if a=='print': continue
  patterns=[
   rf'window\.{re.escape(a)}\s*=',
   rf'function\s+{re.escape(a)}\s*\(',
   rf'(?:^|[{{,]\s*){re.escape(a)}\s*:',
   rf'Object\.assign\(window,\s*{{[^}}]*\b{re.escape(a)}\b',
  ]
  if not any(re.search(pattern,loaded,re.M|re.S) for pattern in patterns): missing.append(a)
 return missing

for storefront in ['store-desktop.html','store-mobile.html']:
 runtime_missing=unresolved_loaded_actions(storefront)
 if runtime_missing: errors.append(f'{storefront}: unresolved loaded actions: '+', '.join(runtime_missing))


# CLEAN1 structural checks that catch regressions the older action/syntax audit missed.
mobile_html=(root/'store-mobile.html').read_text(encoding='utf-8',errors='ignore')
desktop_html=(root/'store-desktop.html').read_text(encoding='utf-8',errors='ignore')
for html_name,html_text in [('store-mobile.html',mobile_html),('store-desktop.html',desktop_html)]:
 if re.search(r'<style\b',html_text,re.I): errors.append(f'{html_name}: inline style block is forbidden; use owned CSS files')
if 'alinMobileEntrySplash' in mobile_html: errors.append('store-mobile.html: duplicate in-page mobile splash returned')
if not (root/'styles/alin-tablet.css').is_file(): errors.append('missing canonical tablet stylesheet')
for css_name in ['styles/alin-mobile.css','styles/alin-tablet.css']:
 css=(root/css_name).read_text(encoding='utf-8',errors='ignore')
 if 'overflow-wrap:anywhere' in css: errors.append(f'{css_name}: unsafe mid-word wrapping remains')
 # Catalogue columns may be defined only outside independent shelf mode.
 for m in re.finditer(r'([^{}]*#storeGrid[^{}]*)\{[^{}]*grid-template-columns',css,re.I|re.S):
  selector=m.group(1)
  if '.alin-product-shelves' not in selector and ':not(.alin-product-shelves)' not in selector:
   errors.append(f'{css_name}: #storeGrid column rule can override shelf mode: {selector.strip()[:120]}')
student_auth=(root/'modules/store/student-auth.js').read_text(encoding='utf-8',errors='ignore')
if 'localStorage.getItem(SESSION_KEY)' not in student_auth: errors.append('student session is not persistent across app restarts')
if re.search(r'return JSON\.parse\(sessionStorage\.getItem\(SESSION_KEY',student_auth): errors.append('student session still uses sessionStorage as primary storage')
push=(root/'core/push-notifications.js').read_text(encoding='utf-8',errors='ignore')
if 'hiddenAt' in push: errors.append('push Later behavior still resets on background/foreground')
if "Notification.permission==='denied')hidePrompt()" not in push: errors.append('push denied state does not remove opt-in prompt')
required_migrations=[
 'database/migrations/007_product_subcategories_shelf_system.sql',
 'database/migrations/010_student_retention_personal_offers.sql',
 'database/migrations/011_student_retention_single_active_offer.sql',
 'database/migrations/012_store_web_push_notifications.sql',
 'database/migrations/013_admin_customer_activity_directory.sql']
for rel in required_migrations:
 mp=root/rel
 if not mp.is_file(): errors.append(f'missing reproducible migration: {rel}'); continue
 sql=mp.read_text(encoding='utf-8',errors='ignore').lower()
 if len(sql.splitlines())<20 or not re.search(r'\b(create|alter)\b',sql): errors.append(f'incomplete reproducible migration: {rel}')
if not (root/'supabase/functions/admin-send-push/index.ts').is_file(): errors.append('missing local Edge Function admin-send-push')

# UI5 storefront checks: one canonical splash entry, details-only product cards and single CSS ownership.
device_router=(root/'core/device-router.js').read_text(encoding='utf-8',errors='ignore')
if "if(chosen==='mobile')go();" in device_router: errors.append('mobile entry bypasses the canonical splash')
if "current.searchParams.set('__alin_entry','1')" not in device_router: errors.append('entry router marker missing; direct store routes can skip splash')
for rel,view in [('core/csp-mobile-inline-1.js','mobile'),('core/csp-desktop-inline-1.js','desktop')]:
 guard=(root/rel).read_text(encoding='utf-8',errors='ignore')
 if "__alin_entry" not in guard or f"url.searchParams.set('view','{view}')" not in guard: errors.append(f'{rel}: canonical entry guard missing')
for rel,view in [('manifest-mobile.webmanifest','mobile'),('manifest-desktop.webmanifest','desktop')]:
 manifest=json.loads((root/rel).read_text(encoding='utf-8'))
 if f'view={view}' not in str(manifest.get('start_url','')): errors.append(f'{rel}: start_url bypasses splash entry')
 if manifest.get('background_color')!='#f7fbff': errors.append(f'{rel}: launch background does not match splash')
catalog=(root/'modules/store/discovery-catalog.js').read_text(encoding='utf-8',errors='ignore')
try:
 card_source=catalog[catalog.index('function card(item)'):catalog.index('function matches(item)')]
except ValueError:
 card_source=''
if 'اختر التصميم' in card_source or 'أضف للسلة' in card_source: errors.append('catalog product card bypasses details flow')
if '>تفاصيل</button>' not in card_source: errors.append('catalog product card details action missing')
responsive=(root/'styles/alin-store-responsive-1z4.css').read_text(encoding='utf-8',errors='ignore')
shared=(root/'styles/alin-shared.css').read_text(encoding='utf-8',errors='ignore')
tablet=(root/'styles/alin-tablet.css').read_text(encoding='utf-8',errors='ignore')
if '.alin-category-showcase{' in shared: errors.append('category showcase has multiple CSS owners')
if 'aspect-ratio:4/3!important' not in responsive: errors.append('desktop product media ratio missing')
if 'aspect-ratio:1/1!important' not in responsive: errors.append('mobile product media ratio missing')
if re.search(r'#alinStoreCategories\{\s*display:grid',tablet,re.S): errors.append('tablet legacy category grid returned')
if 'v99-category-tools' not in responsive or 'v99-category-search' not in responsive or 'v99-category-sort' not in responsive: errors.append('classic category search/sort toolbar styles missing')

files=['dist/alin-core.v4.js','alin-app-desktop.v4.2.0.js','alin-app-mobile.v4.2.0.js','dist/alin-role-runtime.v4.js']
before={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files}
subprocess.run([sys.executable,str(root/'scripts/build-runtime.py')],cwd=root,check=True,stdout=subprocess.DEVNULL)
after={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files}
if before!=after: errors.append('runtime build is not deterministic/source drift')
srcs=list(root.rglob('*.html'))+list((root/'modules').rglob('*.js'))+list((root/'core').rglob('*.js'))+list((root/'store').rglob('*.js'))
alltext='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in srcs)
actions=set(re.findall(r'data-alin-(?:click|change|input|submit|keydown)=["\']([A-Za-z_$][\w$]*)["\']',alltext))
missing=[]
for a in sorted(actions):
 if a=='print': continue
 pats=[rf'window\.{re.escape(a)}\s*=',rf'function\s+{re.escape(a)}\s*\(',rf'["\']{re.escape(a)}["\']\s*:']
 if not any(re.search(q,alltext) for q in pats): missing.append(a)
if missing: errors.append('unresolved actions: '+', '.join(missing))
for p in root.rglob('*.js'):
 r=subprocess.run(['node','--check',str(p)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
 if r.returncode: errors.append(f'JS syntax {p.relative_to(root)}: {r.stderr.strip()}')
print(json.dumps({'ok':not errors,'errors':errors,'actions':len(actions),'build_hashes':after,'js_files':len(list(root.rglob('*.js')))},ensure_ascii=False,indent=2))
sys.exit(1 if errors else 0)
