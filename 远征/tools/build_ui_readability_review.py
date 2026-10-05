"""Package full-resolution game captures and checked text reports."""
from pathlib import Path
import html
import json
import re
from capture_checks import failures

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'shots/ui_all_polish_20261005'
LABELS = {
    'home':'行旅营帐','bag':'行旅背包','bag_full':'满包状态','settings':'设置',
    'settings_profile':'旅人档案','settings2':'设置第二页','quests':'任务与委托',
    'city_guests':'访客簿','city_notice':'城内告示','city_shop':'城内商铺',
    'city_build_panel':'建筑筹备','gate':'城门','archive':'档案馆','main_world':'边城探索',
    'main_world_battle_commands':'战斗指令','main_world_battle_skills':'战斗技能',
    'battle':'战斗','forge_enhance':'装备强化','forge_gem':'宝石镶嵌','equip':'装备',
    'growth':'养成','skillbook':'技能书','worlds':'世界地图','codex':'图鉴',
    'deploy':'出征准备','arena':'竞技','gacha':'灵宠召唤','mount':'坐骑','titles':'称号',
    'trade_warden_dialog':'守卫交谈','title':'开始菜单','createrole':'选择职业',
    'pet_raise':'灵宠培养','login':'旅人登记','avatar':'旅人小像','load':'启程加载',
    'title_settings':'菜单设置','namerecover':'补录姓名','prologue':'序章',
    'deploy_role':'出征职业','deploy_pet':'出征伙伴','city_deploy':'城内整备','gm':'调试菜单',
    'talent':'天赋树','forge_refine':'装备精炼','workshop_low':'工坊资源不足',
    'workshop_progress':'工坊进度','city':'城务','city_repair':'建筑修复','city_built':'建筑落成',
    'city_all':'完整城务','city_mix':'城内交互','city_frost_choice':'双关定路',
    'city_tide_choice':'潮汐抉择','port_services':'港务','side_city_accept':'接取支线',
    'beast_notice':'兽栏告示','mentor_choice':'导师分支','order_preview':'订单预览',
    'mount_claim':'领取坐骑','pet_claim':'领取伙伴','mentor_world':'导师交谈',
    'chapter_archive':'章节档案','chapter_gate':'城门交谈','waystone_world':'路石交互',
    'trade_slope_panel':'路口交易','picker':'选择奖励','picker_school':'流派选择',
    'story_intro':'剧情开场','story_outro':'剧情余韵','second_hatch':'孵化',
    'second_relation':'港务关系','second_shipping':'船单','second_fishing':'垂钓',
    'second_side_choice':'支线抉择','third_dialog':'霜关交谈','third_regions':'地区地图',
    'third_items':'行旅物资','third_choice':'章节抉择','third_merchant':'商旅',
    'third_market':'霜关市场','third_side_choice':'霜关支线',
    'companion_locked':'未解锁同行','companion_first':'同行初阶','companion_second':'同行进阶',
    'companion_help':'同行说明','curriculum_list':'招式研习','curriculum_detail':'招式详情',
    'curriculum_branch':'招式分支','gear_pending':'旅装待领','gear_preview':'旅装预览',
    'gear_detail':'旅装详情','title_intro':'游戏介绍','title_intro_party':'同行介绍',
    'title_intro_journey':'旅程介绍','reading_help':'装备说明','reading_help2':'装备说明第二页',
}

def main():
    rows = []
    for folder in ['after','other_pages']:
        source = json.loads((OUT/folder/'results.json').read_text(encoding='utf-8'))
        assert source and all(r['passed'] for r in source)
        for r in source:
            file = Path(r['path'])
            assert file.is_file()
            name = r.get('name',r['scene'])
            rows.append(dict(title=LABELS.get(name,LABELS.get(r['scene'],r['scene'])),
                             size=r['size'],src=file.relative_to(OUT).as_posix()))
    reports = list((OUT/'after').rglob('*.text.json'))+list((OUT/'other_pages').rglob('*.text.json'))
    audits = [json.loads(p.read_text(encoding='utf-8')) for p in reports]
    assert len(reports)==len(rows)
    issues = {key:sum(len(d[key]) for d in audits) for key in ['nonlinear_text','compact_art','short_text_boxes']}
    assert not any(issues.values()),issues
    tokens = ['UI_LAYOUT','VISUAL_REFRESH','FIELD_UI','GAME_HOME','NAV','PERF','QUESTS',
              'SHIPPING','COMPANIONS','CURRICULUM','GACHA','PANELS','GROWTH','CITY','INVENTORY_UI','UI_TEXT']
    logs = [(p,p.read_text(encoding='utf-8-sig')) for p in (OUT/'verification').glob('*.log')]
    for token in tokens:
        matched = [log for _,log in logs if re.search(r'^'+token+r'_OK\b',log,re.M)]
        assert len(matched)==1 and not failures(matched[0]),token
    motion = (OUT/'motion/capture.log').read_text(encoding='utf-8')
    assert 'MOTION_PREVIEW_OK readability' in motion and not failures(motion)
    counts={'home':24,'ready':24,'claim':50,'unlock':50,'loading':50}
    assert all(len(list((OUT/'motion'/key).glob('*.png')))==count for key,count in counts.items())
    validation=dict(screenshots=len(rows),text_nodes=sum(len(d['text_nodes']) for d in audits),
                    text_issues=issues,regression_cases=len(tokens),motion_frames=sum(counts.values()))
    (OUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
    template = r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>远征 · 文字与界面细修</title><style>
*{box-sizing:border-box}body{margin:0;background:#111b23;color:#e8e9e2;font:16px/1.8 system-ui,sans-serif}main{max-width:1260px;margin:auto;padding:40px 24px}h1{font-size:34px;font-weight:500;margin:8px 0}h2{font-size:24px;font-weight:500;margin:36px 0 16px}p{color:#b3bec2;margin:0 0 20px}small{color:#cfb780}nav{display:flex;gap:12px;margin:24px 0}a{color:#ead5a8;text-decoration:none}nav a{padding:6px 16px;border:1px solid #42515a;border-radius:24px}.gallery{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px}figure{margin:0;background:#20303a;border:1px solid #34434b;border-radius:6px;overflow:hidden}figure img{display:block;width:100%;height:auto;cursor:zoom-in}figcaption{padding:10px 14px;font-size:14px;color:#c9d1d2}.motions{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}label{color:#c7d0d1}select,input{padding:9px 12px;background:#21303a;color:#eff0e6;border:1px solid #465760;border-radius:4px;font:inherit}form{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:18px 0}.compare{display:grid;grid-template-columns:1fr 1fr;gap:24px;max-width:980px}dialog{background:#14212a;color:#f2e9d5;border:1px solid #ad9165;padding:14px;max-width:96vw;max-height:95vh}dialog::backdrop{background:#071017e8}.view{overflow:auto;max-height:81vh;max-width:92vw}.view img{display:block;max-width:none;width:auto;height:auto}button{font:inherit;cursor:pointer;border:1px solid #60707a;background:#20333f;color:#f6e7c5;padding:6px 14px;border-radius:4px}.toolbar{display:flex;justify-content:space-between;gap:20px;padding-bottom:12px}footer{color:#98a9af;border-top:1px solid #34434b;margin-top:36px;padding-top:20px;font-size:14px}
@media(max-width:950px){.gallery{grid-template-columns:repeat(2,minmax(0,1fr))}.motions{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){main{padding:24px 16px}h1{font-size:28px}.motions,.compare{grid-template-columns:1fr}.gallery{gap:10px}input{width:100%}}
</style><main><small>昭元行旅录</small><h1>笔锋留给标题，正文读得清楚。</h1><p>主页徽记、背包细节与领取反馈一并打磨。点开截图，以原始尺寸检查笔画；缩略图只用于浏览。</p><nav><a href="#motion">领取与解锁</a><a href="#compare">前后对比</a><a href="#pages">全部页面</a></nav>
<h2 id="motion">实际游戏动效</h2><div class="motions">__MOTIONS__</div>
<h2 id="compare">主页与背包</h2><div class="compare">__COMPARE__</div>
<p style="margin-top:14px"><a href="font_probe.png">查看文字采样对照原图</a> · 动效预览使用 GIF，笔画检查请看静态原图。</p>
<h2 id="pages">逐页检查</h2><form onsubmit="return false"><label>屏幕比例 <select id="size"><option>480x800</option><option>480x1067</option></select></label><input id="search" placeholder="搜索页面，如背包、技能、城内"><small id="count"></small></form><div class="gallery" id="gallery"></div>
<footer>__COUNTS__ · 两种屏幕比例。截图与演出均来自隔离存档的游戏运行。</footer></main>
<dialog id="zoom"><div class="toolbar"><span>原尺寸查看 · 可滚动</span><button onclick="zoom.close()">关闭</button></div><div class="view"><img id="full" alt="原尺寸游戏画面"></div></dialog>
<script>const rows=__DATA__;const gallery=document.querySelector('#gallery');const zoom=document.querySelector('#zoom');function openImage(src){document.querySelector('#full').src=src;zoom.showModal()}document.addEventListener('click',e=>{if(e.target.matches('figure img'))openImage(e.target.src);if(e.target===zoom)zoom.close()});function render(){const items=rows.filter(x=>x.size===document.querySelector('#size').value&&x.title.includes(document.querySelector('#search').value));gallery.replaceChildren();for(const item of items){const figure=document.createElement('figure'),img=document.createElement('img'),caption=document.createElement('figcaption');img.src=item.src;img.alt=item.title;img.loading='lazy';caption.textContent=item.title;figure.append(img,caption);gallery.append(figure)}document.querySelector('#count').textContent=items.length+' 张'}document.querySelector('#size').onchange=render;document.querySelector('#search').oninput=render;render();</script></html>'''
    motions=''.join(f'<figure><img src="motion/{key}.gif" alt="{name}"><figcaption>{name}</figcaption></figure>' for key,name in [('ready','可领取 · 呼吸光纹'),('claim','领取 · 收获入囊'),('unlock','解锁 · 招式解封')])
    compare=''.join(f'<figure><img src="{stage}/480x800/{key}.png" alt="{title}"><figcaption>{title}</figcaption></figure>' for key,label in [('home','主页'),('bag','背包')] for stage,title in [('before',label+' · 修改前'),('after',label+' · 修改后')])
    template=template.replace('__MOTIONS__',motions).replace('__COMPARE__',compare).replace('__COUNTS__',f'{len(rows)} 张界面截图 · {len(tokens)} 项回归检查通过').replace('__DATA__',json.dumps(rows,ensure_ascii=False).replace('</','<\\/'))
    (OUT/'index.html').write_text(template,encoding='utf-8')
    print('UI_READABILITY_REVIEW_OK',validation)

if __name__=='__main__':main()
