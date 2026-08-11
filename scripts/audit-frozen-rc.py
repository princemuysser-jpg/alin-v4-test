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

files=['dist/alin-core.v4.js','alin-app-desktop.v4.1.5.js','alin-app-mobile.v4.1.5.js','dist/alin-role-runtime.v4.js']
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
