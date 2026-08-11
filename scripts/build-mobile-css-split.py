#!/usr/bin/env python3
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'dist/css/mobile.bundle.css'
PUBLIC_OUT=ROOT/'dist/css/mobile-public.v4.css'
ROLE_OUT=ROOT/'dist/css/mobile-role.v4.css'
ROLE_PREFIXES=('teacher/','library/','courier/','admin/')
text=SOURCE.read_text(encoding='utf-8')
pattern=re.compile(r'/\* === ([^*]+?) === \*/')
matches=list(pattern.finditer(text))
if not matches:
    raise SystemExit('mobile bundle section markers missing')
# Preserve bundle header before first marker in public output.
public=[text[:matches[0].start()]]
role=['/* Alin mobile staff-role CSS — lazy loaded only after staff authentication. */\n']
for i,m in enumerate(matches):
    end=matches[i+1].start() if i+1<len(matches) else len(text)
    block=text[m.start():end]
    name=m.group(1).strip()
    (role if name.startswith(ROLE_PREFIXES) else public).append(block)
PUBLIC_OUT.write_text(''.join(public).rstrip()+'\n',encoding='utf-8')
ROLE_OUT.write_text(''.join(role).rstrip()+'\n',encoding='utf-8')
print(f'{PUBLIC_OUT.relative_to(ROOT)} {PUBLIC_OUT.stat().st_size} bytes')
print(f'{ROLE_OUT.relative_to(ROOT)} {ROLE_OUT.stat().st_size} bytes')
