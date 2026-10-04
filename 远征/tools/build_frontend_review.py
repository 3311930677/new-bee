"""Build a local visual review from actual Godot captures, with no network assets."""
from pathlib import Path
import html, json, re
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'shots/frontend_overhaul_20261004'
NAMES = {
    'home':'行旅营帐', 'main_world':'昭元边城', 'growth':'养成', 'equip':'装备',
    'forge_enhance':'装备强化', 'forge_gem':'宝石镶嵌', 'forge_refine':'装备精炼',
    'bag':'背包', 'bag_full':'背包满载', 'settings':'设置 · 常规', 'settings2':'设置 · 存档',
    'settings_profile':'设置 · 旅人', 'quests':'任务', 'codex':'图鉴', 'worlds':'世界',
    'arena':'竞技', 'gacha':'召唤', 'mount':'坐骑', 'titles':'称号', 'pet_raise':'伙伴养成',
    'avatar':'趣味头像', 'login':'登录', 'createrole':'创建旅人', 'title':'启程',
    'title_settings':'启程 · 设置', 'load':'读取存档', 'deploy':'出行筹备',
    'skillbook':'技能书', 'talent':'天赋', 'exchange':'兑换', 'city':'城内',
    'city_all':'城内总览', 'city_guests':'访客簿', 'city_notice':'告示板',
    'city_shop':'物资铺', 'city_build_panel':'建筑修缮', 'city_built_panel':'建筑服务',
    'gate':'城门', 'archive':'图志阁', 'trade_warden_dialog':'行脚商人对话',
    'main_world_battle_commands':'主世界 · 战斗指令', 'main_world_battle_skills':'主世界 · 战斗技能',
    'battle':'战斗', 'battle_cast':'战斗 · 施法', 'battle_low':'战斗 · 残血',
    'reading_help':'规则阅读 · 首页', 'reading_help2':'规则阅读 · 次页',
    'title_intro':'旅途序言', 'title_intro_party':'伙伴引言', 'title_intro_journey':'行路引言',
    'second_shipping':'港务船单', 'second_fishing':'垂钓', 'second_hatch':'潮羽孵化',
    'second_relation':'港口结缘', 'third_dialog':'霜关驿 · 长对话',
    'third_market':'霜关市集', 'third_merchant':'霜关商人', 'third_choice':'霜关抉择',
    'city_tide_choice':'潮汐抉择', 'city_frost_choice':'霜关抉择',
    'mentor_choice':'导师选修', 'order_preview':'现货与首单', 'port_services':'港口服务',
    'curriculum_list':'行旅课程', 'curriculum_detail':'课程详情', 'curriculum_branch':'课程分支',
    'story_intro':'首领对峙', 'story_outro':'战后余韵', 'prologue':'启程序章',
    'namerecover':'姓名恢复', 'picker':'词条选择', 'picker_school':'流派选择',
    'companion_help':'协战说明', 'companion_lodge':'伙伴歇脚', 'companion_resonance':'伙伴共鸣',
    'companion_locked':'伙伴未解锁', 'companion_guard':'伙伴守护', 'companion_pursuit':'伙伴追击',
    'pet_claim':'结缘领取', 'mount_claim':'坐骑领取', 'city_repair':'碑文修复',
    'gear_detail':'装备详情', 'gear_pending':'待领取装备', 'gear_preview':'装备预览',
    'workshop_progress':'工坊进度', 'workshop_low':'工坊 · 材料不足',
    'trade_slope_panel':'断碑坡交易', 'third_items':'霜关物资', 'gm':'管理面板', 'gm_open':'管理面板展开',
}
REGIONS = {'forest':'枫林','snow':'霜雪','volcano':'火山','tomb':'碑窟','desert':'赤沙',
           'glacier':'冰原','abyss':'深渊','castle':'古堡','lorin_wilds':'昭元边城','maple_road':'枫林古道',
           'broken_slope':'断碑坡','old_salt_road':'旧盐路','shenyuan_port':'深渊港','tideflat':'潮滩',
           'tidal_gate':'潮汐水闸','stele_cavern':'失声碑窟','red_sand_route':'赤沙商路','frost_post':'霜关驿',
           'rift_mine_road':'裂谷矿道','rift_mine_vault':'裂谷矿库','frost_pass':'霜关隘口','frost_boardwalk':'霜关栈道'}
THEMES = {'atlas':'行路图志','forge':'钢铁工坊','garden':'草木养成','arcane':'星砂灵契',
          'arena':'绛红演武','market':'皮革商旅','journal':'行旅书册','quiet':'素纸设置'}

def title(scene):
    if scene in NAMES: return NAMES[scene]
    for prefix, suffix in [('mw_',''),('route_',' · 路线'),('battlebg_',' · 战场')]:
        if scene.startswith(prefix): return REGIONS.get(scene[len(prefix):], '行路风景') + suffix
    for prefix, name in [('frost_art_','霜关细节'),('terrain_','地表细节'),('town_','城内细节'),
                         ('second_side_','港口支线'),('third_side_','霜关支线'),('side_','城郊支线'),
                         ('beast_','兽影事件'),('campaign_','归途'),('chapter_','章节回访'),
                         ('companion_','伙伴协战'),('third_','霜关旅途'),('second_','港口旅途'),
                         ('main_world_','主世界探索'),('style_','界面细节'),('city_','城内服务')]:
        if scene.startswith(prefix): return name
    return '旅途细节'

def family(scene):
    if scene in ['login','createrole','home','title','load','prologue','quests'] or 'dialog' in scene: return 'journal'
    if any(k in scene for k in ['settings','avatar','namerecover','gm']): return 'quiet'
    if any(k in scene for k in ['forge','equip','gear','bag','skillbook','workshop']): return 'forge'
    if any(k in scene for k in ['gacha','codex','picker','contract','hatch']): return 'arcane'
    if any(k in scene for k in ['growth','talent','pet','companion','mount','fishing','relation']): return 'garden'
    if any(k in scene for k in ['arena','battle','beast','titles']): return 'arena'
    if any(k in scene for k in ['exchange','trade','market','shop','shipping','order','port_services']): return 'market'
    if any(k in scene for k in ['city','quest','reading','story','curriculum','title_intro']): return 'journal'
    return 'atlas'

def rows(path, group):
    result=[]
    for i, row in enumerate(json.loads(path.read_text(encoding='utf-8'))):
        if not row['passed']: continue
        image=Path(row['path'])
        scene=row['scene']
        name=row.get('name',row.get('image',scene))
        result.append(dict(title=title(name if name in NAMES else scene), scene=scene,
                           family=family(scene), size=row['size'], group=group,
                           image=image.relative_to(OUT).as_posix()))
    return result

items = rows(OUT/'results.json','精选界面') + rows(OUT/'matrix/results.json','全部界面')
page = r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 行旅新章</title>
<style>
@font-face{font-family:brush;src:url('../../assets/fonts/MaShanZheng-Regular.ttf')}
:root{color-scheme:dark;--bg:#171f26;--ink:#e9e5d7;--muted:#a5aea8;--rim:#45535d}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.65 system-ui,'Microsoft YaHei',sans-serif}
main{max-width:1440px;margin:auto;padding:42px 32px}header{display:flex;justify-content:space-between;gap:28px;align-items:center;margin-bottom:32px}
.eyebrow{color:#bfad83;letter-spacing:.25em;font-size:12px}h1{font:54px/1.2 brush,serif;margin:10px 0 16px}p{margin:0;color:var(--muted);max-width:650px}
.facts{display:flex;gap:24px}.facts b{display:block;font-size:27px;color:#e6d3ad}.facts span{font-size:12px;color:var(--muted)}
nav{display:flex;gap:8px;flex-wrap:wrap;border-bottom:1px solid var(--rim);padding-bottom:20px;margin-bottom:20px}
button,select,input{font:inherit;border:1px solid #4b5860;color:var(--ink);background:#232f36;border-radius:3px;padding:8px 16px;cursor:pointer}
button:hover{border-color:#baa276}button.active{background:#e6d5af;color:#2e3439;border-color:#e6d5af}
input{cursor:text;min-width:200px}input:focus-visible,button:focus-visible,select:focus-visible{outline:2px solid #d9bd85;outline-offset:3px}
.filters{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:20px 0}.count{color:var(--muted);margin-left:auto;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(225px,1fr));gap:22px}figure{margin:0;background:#202a32;border:1px solid #37424a;overflow:hidden;border-radius:3px}
.shot{width:100%;display:block;cursor:zoom-in;aspect-ratio:480/800;object-fit:contain;object-position:center top;background:#11171e}
figcaption{padding:13px 14px}figcaption b{font-weight:500;color:#eee4cf}small{display:block;font-size:12px;color:var(--muted);margin-top:2px}
.motion{display:grid;grid-template-columns:repeat(3,1fr);gap:24px}.motion img{width:100%;display:block}
.compare{display:grid;grid-template-columns:repeat(2,minmax(200px,1fr));gap:22px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:2px;background:#202a32}.pair h2{grid-column:1/-1;font-size:18px;font-weight:500;padding:12px 18px;margin:0}.pair img{width:100%;display:block}.pair small{padding:8px 14px;margin:0}
.note{font-size:13px;margin:24px 0 0;color:var(--muted)}dialog{padding:0;border:1px solid #63717a;background:#11171d;max-width:92vw;max-height:96vh}dialog::backdrop{background:#080c12e8}dialog img{display:block;max-height:90vh;max-width:90vw;width:auto;height:auto}dialog button{position:absolute;right:8px;top:8px}
[hidden]{display:none!important}footer{border-top:1px solid var(--rim);padding-top:18px;margin-top:40px;color:var(--muted);font-size:12px}footer a{color:#ccb889}
@media(max-width:780px){main{padding:25px 16px}header{display:block}.facts{margin-top:20px}h1{font-size:42px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.motion,.compare{grid-template-columns:1fr}input{min-width:0;width:100%}.count{margin-left:0}}
@media(prefers-reduced-motion:no-preference){figure{animation:appear .25s ease-out}@keyframes appear{from{opacity:0;transform:translateY(5px)}to{opacity:1;transform:none}}}
</style><main><header><div><div class="eyebrow">远征 / 界面更新</div><h1>行旅新章</h1><p>书法题字、彩色像素图标与八种材质，让城中行路、星砂召唤和钢铁工坊各有自己的气质。</p></div>
<div class="facts"><div><b>8</b><span>材质主题</span></div><div><b>24</b><span>像素图标</span></div><div><b>273</b><span>界面状态</span></div></div></header>
<nav><button class="active" data-tab="精选界面">精选界面</button><button data-tab="全部界面">全页面图库</button><button data-tab="动效">动画预览</button><button data-tab="对比">前后对比</button></nav>
<section id="pictures"><div class="filters"><select id="size" aria-label="屏幕比例"><option value="480x800">标准屏 · 480 × 800</option><option value="480x1067">长屏 · 480 × 1067</option><option value="">两种比例</option></select><select id="family" aria-label="材质主题"><option value="">所有主题</option>__OPTIONS__</select><input id="search" type="search" placeholder="找一个页面，例如：召唤" aria-label="搜索界面"><span class="count" id="count"></span></div><div class="grid" id="grid"></div><p class="note">点击图片查看原始尺寸。图库展示游戏实际渲染的界面。</p></section>
<section id="motion" hidden><div class="motion">__MOTIONS__</div><p class="note">真实游戏运行录制：入口依次浮现、卡页滑动、对话逐字呈现。</p></section>
<section id="compare" hidden><div class="compare">__COMPARE__</div></section>
<footer>两种屏幕比例 · 原有任务、战斗、养成与头像功能保留。<br>标题字体：<a href="https://github.com/google/fonts/tree/main/ofl/mashanzheng">马善政</a>；按钮字体：<a href="https://github.com/google/fonts/tree/main/ofl/zcoolqingkehuangyou">站酷庆科黄油体</a>。均随项目保留 OFL 许可。</footer></main>
<dialog id="zoom"><button aria-label="关闭大图">关闭</button><img alt="界面大图"></dialog>
<script>
const items=__DATA__;let tab='精选界面';const themes=__THEMES__;
const byId=id=>document.getElementById(id);const grid=byId('grid');
function show(){grid.replaceChildren();const q=byId('search').value.trim();const selected=items.filter(r=>r.group===tab&&(!byId('size').value||r.size===byId('size').value)&&(!byId('family').value||r.family===byId('family').value)&&(!q||r.title.includes(q)));
for(const r of selected){const f=document.createElement('figure');const im=document.createElement('img');im.className='shot';im.src=r.image;im.alt=r.title;im.loading='lazy';im.style.aspectRatio=r.size==='480x1067'?'480/1067':'480/800';im.tabIndex=0;im.onclick=()=>{byId('zoom').querySelector('img').src=r.image;byId('zoom').showModal()};im.onkeydown=e=>{if(e.key==='Enter')im.click()};const c=document.createElement('figcaption');const b=document.createElement('b');b.textContent=r.title;const s=document.createElement('small');s.textContent=themes[r.family]+' · '+r.size.replace('x',' × ');c.append(b,s);f.append(im,c);grid.append(f)}byId('count').textContent=selected.length+' 个界面';}
for(const b of document.querySelectorAll('[data-tab]'))b.onclick=()=>{tab=b.dataset.tab;document.querySelectorAll('[data-tab]').forEach(n=>n.classList.toggle('active',n===b));byId('pictures').hidden=tab==='动效'||tab==='对比';byId('motion').hidden=tab!=='动效';byId('compare').hidden=tab!=='对比';if(!byId('pictures').hidden)show()};for(const id of ['size','family','search'])byId(id).oninput=show;byId('zoom').querySelector('button').onclick=()=>byId('zoom').close();byId('zoom').onclick=e=>{if(e.target===byId('zoom'))byId('zoom').close()};show();
</script></html>'''
options=''.join(f'<option value="{k}">{v}</option>' for k,v in THEMES.items())
motions=''.join(f'<figure><img src="motion/{key}.gif" alt="{label}"><figcaption><b>{label}</b><small>{detail}</small></figcaption></figure>'
                for key,label,detail in [('home','营帐入场','浮现与图标反馈'),('pages','图鉴翻页','滑动与淡入'),('dialogue','城内对话','逐字呈现与完整阅读')])
comparisons=[]
for key in ['home','equip','growth','login','main_world','settings']:
    before=PROJECT/'shots/crafted_game_20261004/480x800'/f'{key}.png'
    if before.exists():
        comparisons.append(f'<div class="pair"><h2>{title(key)}</h2><figure><img src="../crafted_game_20261004/480x800/{key}.png" alt="调整前"><small>调整前</small></figure><figure><img src="480x800/{key}.png" alt="当前效果"><small>当前效果</small></figure></div>')
page=page.replace('__OPTIONS__',options).replace('__MOTIONS__',motions).replace('__COMPARE__',''.join(comparisons)).replace('__DATA__',json.dumps(items,ensure_ascii=False).replace('</','<\\/')).replace('__THEMES__',json.dumps(THEMES,ensure_ascii=False))
(OUT/'index.html').write_text(page,encoding='utf-8')

# Compact overview; source screenshots are kept at full resolution alongside it.
names=['home','main_world','forge_enhance','growth','codex','gacha','settings','login']
font=ImageFont.truetype(str(PROJECT/'assets/fonts/NotoSansSC-Regular.otf'),17)
large=ImageFont.truetype(str(PROJECT/'assets/fonts/MaShanZheng-Regular.ttf'),38)
canvas=Image.new('RGB',(1020,972),'#18212b')
draw=ImageDraw.Draw(canvas)
draw.text((20,8),'远征   行旅新章',font=large,fill='#eedfc2')
draw.text((20,55),'游戏实际界面 / 八种主题 · 艺术字体 · 彩色像素图标',font=font,fill='#b5bdb5')
for i,key in enumerate(names):
    x=15+(i%4)*252;y=96+(i//4)*432
    im=Image.open(OUT/'480x800'/f'{key}.png').convert('RGB').resize((240,400),Image.Resampling.LANCZOS)
    canvas.paste(im,(x,y))
    draw.text((x+3,y+403),title(key),font=font,fill='#eee2c9')
canvas.save(OUT/'overview.png')
print('Review gallery:',len(items),'frames, overview.png')
