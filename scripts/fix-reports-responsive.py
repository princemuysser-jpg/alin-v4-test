#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
CSS=ROOT/'styles/alin-shared.css'
CONFIG=ROOT/'alin-config.js'
PAGES=[ROOT/'store-desktop.html',ROOT/'store-mobile.html',ROOT/'store-tablet.html']
TOKEN='4.2.0-stable-reports-responsive-20260825-1810'
MARKER='/* ALIN v4.2 Stable Lock — canonical admin reports responsive layout. */'

BLOCK=r'''

/* ALIN v4.2 Stable Lock — canonical admin reports responsive layout. */
#adminPage .admin-v143-reports,
#adminPage .admin-v143-reports *{box-sizing:border-box}
#adminPage .admin-v143-reports{width:100%;max-width:100%;min-width:0;overflow:visible}
#adminPage .admin-v143-head,
#adminPage .admin-v143-toolbar,
#adminPage .admin-v143-metrics,
#adminPage .admin-v143-grid,
#adminPage .admin-v143-card,
#adminPage .admin-v143-table-wrap{width:100%;max-width:100%;min-width:0}
#adminPage .admin-v143-head>div:first-child,
#adminPage .admin-v143-card-head>div,
#adminPage .admin-v143-rank>div{min-width:0}
#adminPage .admin-v143-head h2,
#adminPage .admin-v143-head p,
#adminPage .admin-v143-card h3,
#adminPage .admin-v143-card small,
#adminPage .admin-v143-rank b,
#adminPage .admin-v143-rank strong,
#adminPage .admin-v143-metric strong{overflow-wrap:anywhere;word-break:normal}
#adminPage .admin-v143-toolbar{display:grid;grid-template-columns:minmax(220px,1.6fr) repeat(4,minmax(130px,1fr)) auto auto;gap:10px;align-items:stretch}
#adminPage .admin-v143-toolbar>input,
#adminPage .admin-v143-toolbar>select,
#adminPage .admin-v143-toolbar>button{width:100%;max-width:100%;min-width:0;margin:0}
#adminPage .admin-v143-metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
#adminPage .admin-v143-metric{min-width:0;overflow:hidden}
#adminPage .admin-v143-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;align-items:start}
#adminPage .admin-v143-card{overflow:hidden}
#adminPage .admin-v143-rank{display:grid;grid-template-columns:auto minmax(0,1fr) minmax(92px,auto);align-items:center;gap:10px;min-width:0}
#adminPage .admin-v143-rank>strong{min-width:0;text-align:end;white-space:normal}
#adminPage .admin-v143-status{display:grid;grid-template-columns:minmax(70px,.8fr) minmax(90px,2fr) auto;gap:9px;align-items:center;min-width:0}
#adminPage .admin-v143-table-wrap{overflow-x:auto;overflow-y:hidden;-webkit-overflow-scrolling:touch;overscroll-behavior-inline:contain;padding-bottom:4px}
#adminPage .admin-v143-table{width:100%;min-width:780px;border-collapse:collapse}
#adminPage .admin-v143-table th,
#adminPage .admin-v143-table td{white-space:nowrap}

@media (min-width:701px) and (max-width:1180px){
  #adminPage .admin-v143-reports{padding-inline:0!important}
  #adminPage .admin-v143-head{gap:14px!important;padding:20px!important}
  #adminPage .admin-v143-toolbar{grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:10px!important}
  #adminPage .admin-v143-toolbar>input:first-child{grid-column:1/-1}
  #adminPage .admin-v143-metrics{grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:10px!important}
  #adminPage .admin-v143-grid{grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:12px!important}
  #adminPage .admin-v143-card{min-width:0!important;padding:16px!important}
  #adminPage .admin-v143-table-wrap{margin-inline:0!important}
  #adminPage .admin-v143-table{min-width:760px!important}
}

@media (max-width:700px){
  #adminPage #adminContent{min-width:0!important;overflow:visible!important}
  #adminPage .admin-v143-reports{display:grid!important;gap:12px!important;width:100%!important;max-width:100%!important;min-width:0!important;overflow:visible!important}
  #adminPage .admin-v143-head{display:grid!important;grid-template-columns:minmax(0,1fr) auto!important;align-items:start!important;gap:10px!important;padding:16px!important;border-radius:18px!important}
  #adminPage .admin-v143-head h2{font-size:22px!important;line-height:1.35!important;margin:0!important}
  #adminPage .admin-v143-head p{font-size:12px!important;line-height:1.7!important;margin-top:5px!important}
  #adminPage .admin-v143-head-icon{width:46px!important;height:46px!important;min-width:46px!important;font-size:21px!important}
  #adminPage .admin-v143-toolbar{display:grid!important;grid-template-columns:1fr!important;gap:8px!important;padding:12px!important;overflow:visible!important}
  #adminPage .admin-v143-toolbar>input,
  #adminPage .admin-v143-toolbar>select,
  #adminPage .admin-v143-toolbar>button{grid-column:auto!important;width:100%!important;max-width:100%!important;min-width:0!important;min-height:44px!important;height:auto!important;padding:10px 12px!important;font-size:13px!important;white-space:normal!important}
  #adminPage .admin-v143-metrics{display:grid!important;grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:8px!important}
  #adminPage .admin-v143-metric{min-width:0!important;padding:12px!important;border-radius:14px!important}
  #adminPage .admin-v143-metric small{font-size:10px!important;line-height:1.45!important}
  #adminPage .admin-v143-metric strong{font-size:clamp(16px,5.2vw,21px)!important;line-height:1.35!important;white-space:normal!important}
  #adminPage .admin-v143-metric span{font-size:9.5px!important;line-height:1.45!important;white-space:normal!important}
  #adminPage .admin-v143-grid{display:grid!important;grid-template-columns:1fr!important;gap:10px!important}
  #adminPage .admin-v143-card{width:100%!important;max-width:100%!important;min-width:0!important;padding:13px!important;border-radius:16px!important;overflow:hidden!important}
  #adminPage .admin-v143-card-head{display:flex!important;align-items:flex-start!important;gap:8px!important;min-width:0!important}
  #adminPage .admin-v143-card-head h3{font-size:15px!important;line-height:1.45!important}
  #adminPage .admin-v143-card-head small{font-size:10px!important;line-height:1.55!important;white-space:normal!important}
  #adminPage .admin-v143-rank-list{display:grid!important;gap:7px!important;min-width:0!important}
  #adminPage .admin-v143-rank{grid-template-columns:28px minmax(0,1fr)!important;gap:8px!important;padding:10px!important;min-width:0!important}
  #adminPage .admin-v143-rank>strong{grid-column:2;justify-self:start!important;text-align:start!important;font-size:11px!important;line-height:1.45!important;white-space:normal!important}
  #adminPage .admin-v143-rank b{white-space:normal!important;line-height:1.45!important}
  #adminPage .admin-v143-status{grid-template-columns:minmax(62px,.8fr) minmax(70px,2fr) auto!important;gap:7px!important;font-size:11px!important}
  #adminPage .admin-v143-table-wrap{display:block!important;width:100%!important;max-width:100%!important;min-width:0!important;overflow-x:auto!important;overflow-y:hidden!important;margin:0!important;padding:0 0 8px!important;border-radius:12px!important;-webkit-overflow-scrolling:touch!important;scrollbar-width:thin}
  #adminPage .admin-v143-table{width:max-content!important;min-width:760px!important;max-width:none!important;font-size:11px!important}
  #adminPage .admin-v143-table th,
  #adminPage .admin-v143-table td{padding:9px 10px!important;white-space:nowrap!important}
  #adminPage .admin-v143-empty{width:100%!important;max-width:100%!important;min-width:0!important;padding:18px 12px!important;white-space:normal!important}
}

@media (max-width:390px){
  #adminPage .admin-v143-metrics{grid-template-columns:1fr!important}
  #adminPage .admin-v143-head{grid-template-columns:1fr!important}
  #adminPage .admin-v143-head-icon{display:none!important}
}
'''

css=CSS.read_text(encoding='utf-8')
if MARKER not in css:
    css += BLOCK
    CSS.write_text(css,encoding='utf-8')

cfg=CONFIG.read_text(encoding='utf-8')
cfg,n=re.subn(r"assetVersion:'[^']+'",f"assetVersion:'{TOKEN}'",cfg,count=1)
if n!=1: raise SystemExit('assetVersion not found')
CONFIG.write_text(cfg,encoding='utf-8')

for page in PAGES:
    data=page.read_text(encoding='utf-8')
    data=re.sub(r'\?v=[A-Za-z0-9._:-]+',f'?v={TOKEN}',data)
    page.write_text(data,encoding='utf-8')

print('reports responsive layout added; cache',TOKEN)
