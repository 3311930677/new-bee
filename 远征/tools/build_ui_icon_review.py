"""Review the icon pass using actual Godot captures, with native-size zoom."""
from pathlib import Path
import html
import json
import re
from PIL import Image
from capture_checks import failures

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'shots/ui_icon_polish_20261005'
LABELS = {'home':'行旅营帐','settings':'常规设置','settings_profile':'旅人档案',
          'settings2':'存档备份','title':'开始菜单','bag':'行旅背包','gacha':'灵宠召唤',
          'arena':'竞技','city_shop':'商铺','exchange':'演武补给','home_wallet_large':'大额余额'}
ICONS = [('settings','设置齿轮'),('coin','金币'),('expedition','远征币'),('soul','魂晶'),
         ('honor','荣誉'),('ticket','十连券'),('ticket_sweep','扫荡券'),('save','存档册'),
         ('person','旅人手札'),('sound','声音'),('music','音乐'),('shake','震屏'),
         ('story','演出'),('speed','倍速'),('gem','宝石'),('close','关闭')]
TOKENS = {'VerifyAssets':'ASSETS','VerifyUiLayout':'UI_LAYOUT','VerifyVisualRefresh':'VISUAL_REFRESH',
          'VerifyFieldUI':'FIELD_UI','VerifyGameHome':'GAME_HOME','VerifyNav':'NAV',
          'VerifyGacha':'GACHA','VerifyPanels':'PANELS','VerifyPerf':'PERF'}


def main():
    rows, reports = [], []
    for phase in ['before','after']:
        records = json.loads((OUT/phase/'results.json').read_text(encoding='utf-8'))
        assert records and all(record['passed'] for record in records), phase
        for path in sorted((OUT/phase).glob('*/*.png')):
            log = path.with_suffix('.log').read_text(encoding='utf-8')
            assert 'SHOT_SAVED ' in log and not failures(log), path
            expected = tuple(map(int,path.parent.name.split('x')))
            with Image.open(path) as picture: assert picture.size == expected, path
            if phase == 'after':
                report = json.loads(path.with_suffix('.text.json').read_text(encoding='utf-8'))
                reports.append(report)
                rows.append(dict(key=path.stem,title=LABELS[path.stem],size=path.parent.name,
                                 src=path.relative_to(OUT).as_posix()))
    issues = {key:sum(len(report[key]) for report in reports)
              for key in ['nonlinear_text','compact_art','short_text_boxes']}
    assert not any(issues.values()), issues
    for name,token in TOKENS.items():
        log = (OUT/'verification'/(name+'.log')).read_text(encoding='utf-8')
        assert re.search(r'^'+token+r'_OK\b',log,re.M) and not failures(log), name
    frames = sorted((OUT/'motion/gear').glob('*.png'))
    assert len(frames) == 20, len(frames)
    pictures = []
    for frame in frames:
        with Image.open(frame) as picture: pictures.append(picture.convert('RGBA'))
    pictures[0].save(OUT/'motion/gear.png',save_all=True,append_images=pictures[1:],
                     duration=50,loop=0,disposal=0,blend=0)
    for picture in pictures: picture.close()
    validation = dict(screenshots=len(rows),before_screenshots=18,
                      text_nodes=sum(len(report['text_nodes']) for report in reports),
                      text_issues=issues,regressions=list(TOKENS),motion_frames=len(frames),icons=len(ICONS))
    (OUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
    gallery = ''.join('<figure><div class="samples dark">'+''.join(
        f'<img width="{size}" height="{size}" src="../../assets/ui/refined_icons/{key}.svg" alt="{name}">' for size in [18,22,34,48])+
        '</div><div class="samples paper">'+''.join(
        f'<img width="{size}" height="{size}" src="../../assets/ui/refined_icons/{key}.svg" alt="{name}">' for size in [18,22,34,48])+
        f'</div><figcaption>{html.escape(name)}</figcaption></figure>' for key,name in ICONS)
    template = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 小图标精修</title>
<style>*{box-sizing:border-box}body{margin:0;background:#111e29;color:#eee5d1;font:16px/1.65 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1180px;margin:auto;padding:42px 28px}h1{font-family:serif;font-size:36px;font-weight:500;margin:8px 0 18px}h2{font-size:23px;font-weight:500;margin:46px 0 18px}p{color:#b4c3c5;max-width:780px}a{color:#e3c992}nav{display:flex;gap:22px;margin:24px 0 32px}select,button{font:inherit;color:inherit;background:#263d49;border:1px solid #58707b;padding:8px 14px;border-radius:4px}form{display:flex;gap:24px;flex-wrap:wrap;margin:18px 0}figure{margin:0;background:#1a2c37;border:1px solid #314954;border-radius:6px;overflow:hidden}figcaption{padding:12px 14px;color:#deceb0}.compare{display:grid;grid-template-columns:repeat(2,1fr);gap:20px}.compare img{display:block;max-width:100%;width:480px;height:auto;margin:auto;cursor:zoom-in}.icons{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.samples{display:flex;align-items:center;justify-content:center;gap:12px;min-height:76px;image-rendering:pixelated}.dark{background:#243d49}.paper{background:#e9e5d8}.shots{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}.shots img{display:block;width:100%;cursor:zoom-in}.motion{display:grid;grid-template-columns:280px 1fr;gap:24px;align-items:center}.motion img{width:100%;cursor:zoom-in}small{color:#b8a981}footer{color:#8fabb3;border-top:1px solid #35505c;margin-top:32px;padding-top:18px}dialog{background:#182c38;border:1px solid #b9a170;color:inherit;max-width:96vw;max-height:96vh;padding:12px}dialog::backdrop{background:#08121cef}.view{overflow:auto;max-width:92vw;max-height:80vh}.view img{display:block;width:auto;height:auto;max-width:none}dialog button{margin-bottom:12px}@media(max-width:850px){.icons,.shots{grid-template-columns:repeat(2,1fr)}}@media(max-width:560px){main{padding:24px 16px}.compare,.motion{grid-template-columns:1fr}.motion figure{max-width:280px}.samples{gap:6px}.samples img:last-child{display:none}}</style>
<main><small>昭元行旅录 / 小器物图标</small><h1>清楚的轮廓，克制的细节。</h1><p>设置齿轮采用钢灰、旧金与蓝色晶核；四种货币用不同外形区分。存档、声音、演出和票券也补上了材质层次。下面的游戏画面来自原生运行，点击可按原尺寸检查。</p><nav><a href="#compare">前后对照</a><a href="#icons">图标细节</a><a href="#motion">设置动效</a><a href="#pages">逐页检查</a></nav>
<h2 id="compare">前后对照</h2><form><label>界面 <select id="module">__OPTIONS__</select></label><label>屏幕比例 <select id="ratio"><option>480x800</option><option>480x1067</option></select></label></form><div class="compare" id="comparison"></div>
<h2 id="icons">16 枚器物图标</h2><p>图标原稿以 18、22、34、48 像素展示。深浅两种底色用于检查边界；游戏里的实际效果见原生截图。</p><div class="icons">__ICONS__</div>
<h2 id="motion">齿轮微转与亮边</h2><div class="motion"><figure><img src="motion/gear.png" alt="设置齿轮真实动效"><figcaption>悬停后轻转，移开后回正</figcaption></figure><p>圆形入口保留清楚的触控区域，悬停与键盘焦点会亮起弧线。轻微转动只在交互时播放。</p></div>
<h2 id="pages">逐页检查</h2><form><label>屏幕比例 <select id="size"><option>480x800</option><option>480x1067</option></select></label></form><div class="shots" id="shots"></div><footer>__CHECKS__ · 使用隔离的测试存档。<br><a href="../ui_design_blocks_20261005/index.html">上一轮全页面对照与动效</a></footer></main>
<dialog id="zoom"><button onclick="zoom.close()">关闭原尺寸预览</button><div class="view"><img id="full" alt="原尺寸游戏画面"></div></dialog>
<script>const data=__DATA__,labels=__LABELS__,zoom=document.querySelector('#zoom');document.querySelectorAll('form').forEach(f=>f.onsubmit=e=>e.preventDefault());function figure(src,title){const f=document.createElement('figure'),i=document.createElement('img'),c=document.createElement('figcaption');i.src=src;i.alt=title;i.loading='lazy';c.textContent=title;f.append(i,c);return f}function compare(){let key=document.querySelector('#module').value,size=document.querySelector('#ratio').value;document.querySelector('#comparison').replaceChildren(figure('before/'+size+'/'+key+'.png',labels[key]+' · 修改前'),figure('after/'+size+'/'+key+'.png',labels[key]+' · 修改后'))}function gallery(){document.querySelector('#shots').replaceChildren(...data.filter(x=>x.size===document.querySelector('#size').value).map(x=>figure(x.src,x.title)))}document.querySelector('#module').onchange=compare;document.querySelector('#ratio').onchange=compare;document.querySelector('#size').onchange=gallery;document.addEventListener('click',e=>{if(e.target.matches('.compare img,.shots img,.motion img')){document.querySelector('#full').src=e.target.src;zoom.showModal()}if(e.target===zoom)zoom.close()});compare();gallery();</script></html>'''
    options = ''.join(f'<option value="{key}">{LABELS[key]}</option>' for key in LABELS if key not in ['exchange','home_wallet_large'])
    template = template.replace('__OPTIONS__',options).replace('__ICONS__',gallery)
    template = template.replace('__CHECKS__',f'{len(rows)} 张修改后截图 · 9 项相关检查通过 · {validation["text_nodes"]} 个文字节点检查')
    template = template.replace('__DATA__',json.dumps(rows,ensure_ascii=False)).replace('__LABELS__',json.dumps(LABELS,ensure_ascii=False))
    (OUT/'index.html').write_text(template,encoding='utf-8')
    print('UI_ICON_REVIEW_OK',json.dumps(validation,ensure_ascii=False))


if __name__ == '__main__':
    main()
