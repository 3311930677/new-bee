"""Build the before/after review gallery and six contact sheets from captures."""
from pathlib import Path
import argparse
import html as html_module
import json
import os

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / 'shots/all_scenes_20261001'
OUTPUT = PROJECT / 'shots/visual_refresh_20261001/final'

def main():
    global OUTPUT
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default=str(OUTPUT))
    parser.add_argument('--before', default=str(SOURCE))
    args = parser.parse_args()
    OUTPUT = Path(args.output).resolve()
    before = Path(args.before).resolve()
    records = OUTPUT / 'results.json'
    rows = json.loads((records if records.exists() else OUTPUT / 'manifest.json').read_text(encoding='utf-8'))
    rows = [row for row in rows if row.get('passed', True)]
    labels = {'load':'加载','title':'标题','login':'登录','namerecover':'补全昵称',
              'createrole':'角色创建','prologue':'序章','home':'行旅营帐','growth':'养成',
              'equip':'装备','talent':'天赋树','bag':'背包','settings':'设置','worlds':'地区图',
              'gacha':'灵宠召唤','arena':'演武场','quests':'委托','city':'昭元边城',
              'main_world_battle':'主世界战斗','main_world_battle_skills':'战斗技能选择',
              'battle':'历练战斗','companion_help':'伙伴帮助','route_forest':'林海路线',
              'settings_profile':'旅人设置','settings2':'存档设置','title_intro':'手记 · 世界',
              'title_intro_party':'手记 · 旅人','title_intro_journey':'手记 · 启程',
              'reading_help':'规则 · 第一页','reading_help2':'规则 · 第二页'}
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 实机视觉复查</title>
<style>*{box-sizing:border-box}body{margin:0;background:#192629;color:#eee5ce;font:16px/1.6 "Microsoft YaHei",sans-serif}header{padding:26px 5%;background:#203437;position:sticky;top:0;z-index:2;border-bottom:1px solid #65716b}h1{font-size:24px;margin:0}p{margin:6px 0;color:#c4c9be}input,select{font:inherit;background:#f1e7cf;color:#292f2b;border:0;border-radius:5px;padding:9px;margin:10px 8px 0 0}main{padding:24px 4%;display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:22px}.card{background:#203437;padding:14px;border:1px solid #536260;border-radius:8px}.card h2{font-size:18px;margin:0 0 12px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}.pair figure{margin:0}.pair figcaption{padding:4px;text-align:center;color:#c9cbbb}.pair img{width:100%;display:block;cursor:zoom-in}small{font-size:13px;color:#aebbb4}dialog{border:1px solid #a38b5d;background:#192629;color:white;max-width:94vw;max-height:96vh;padding:12px}dialog::backdrop{background:#000b}dialog img{max-height:85vh;max-width:85vw}button{font:inherit;background:#c6a264;color:#292f2b;border:0;border-radius:4px;padding:7px 18px;cursor:pointer}[hidden]{display:none!important}</style>
<header><h1>远征 · 实机视觉复查</h1><p>本轮修改前 / 修改后及新增页面。点击图片查看原尺寸；长屏为独立逻辑视口截图。</p><input id="query" placeholder="搜索页面或场景"><select id="size"><option value="">全部尺寸</option><option>480x800</option><option>480x1067</option></select><small id="count"></small></header><main>'''
    for row in rows:
        sub = 'long_480x1067/' if row['size'] == '480x1067' else ''
        name = row['image'] + '.png'
        label = labels.get(row['scene'], row['image'].replace('_', ' · '))
        html += f'<article class="card" data-key="{label} {row["scene"]}" data-size="{row["size"]}"><h2>{label} <small>{row["size"]}</small></h2><div class="pair">'
        pictures = [('修改后', f'{sub}{name}')]
        old_image = before / sub / name
        if old_image.exists():
            old_src = os.path.relpath(old_image, OUTPUT).replace(os.sep, '/')
            pictures.insert(0, ('修改前', old_src))
        else:
            html += '<figure><figcaption>无旧版对照</figcaption><p>此页面或尺寸未留存上一版截图。</p></figure>'
        for caption, src in pictures:
            src = html_module.escape(src, quote=True)
            html += f'<figure><figcaption>{caption}</figcaption><img loading="lazy" src="{src}" alt="{label} · {caption}"></figure>'
        html += '</div></article>'
    html += '''</main><dialog><button id="close">关闭</button><p id="caption"></p><img id="zoom"></dialog><script>
const cards=[...document.querySelectorAll('.card')],q=document.querySelector('#query'),s=document.querySelector('#size'),dlg=document.querySelector('dialog');
function filter(){let n=0;for(const c of cards){c.hidden=!(c.dataset.key.toLowerCase().includes(q.value.toLowerCase())&&(!s.value||c.dataset.size===s.value));if(!c.hidden)n++}document.querySelector('#count').textContent=n+' / '+cards.length+' 个场景'}q.oninput=s.onchange=filter;filter();
document.querySelectorAll('figure img').forEach(img=>img.onclick=()=>{document.querySelector('#zoom').src=img.src;document.querySelector('#caption').textContent=img.alt;dlg.showModal()});document.querySelector('#close').onclick=()=>dlg.close();dlg.onclick=e=>{if(e.target===dlg)dlg.close()};</script></html>'''
    (OUTPUT / 'index.html').write_text(html, encoding='utf-8')
    # Reuse the existing scene grouping, writing only the new output directory.
    overview = (SOURCE / '_overview.py').read_text(encoding='utf-8')
    overview = overview.replace('SRC = os.path.dirname(os.path.abspath(__file__))', f'SRC = {str(OUTPUT)!r}')
    exec(compile(overview, str(SOURCE / '_overview.py'), 'exec'), {'__name__':'__main__','__file__':str(SOURCE / '_overview.py')})
    print(f'VISUAL_GALLERY_OK {len(rows)} captured scene states')

if __name__ == '__main__':
    main()
