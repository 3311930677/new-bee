# -*- coding: utf-8 -*-
"""读 manifest.json 生成自包含画廊 index.html（图片走相对路径 thumbs/ 与 big/）。"""
import json, os

OUT = r"D:/new bee/远征/shots/v4_gallery"
with open(os.path.join(OUT, "manifest.json"), encoding="utf-8") as f:
    items = json.load(f)

PHASES = [
    ("P0", "P0 · 阻塞级缺陷", "12 项确定缺陷，全部代码修复，无需新美术"),
    ("P1", "P1 · 视觉底座", "色板 / 字号阶梯 / 九宫格 / 公共组件层统一"),
    ("P2", "P2 · 核心主循环", "加载 → 标题 → 登录 → 创角 → 主城 → 背包/邮件/任务 → 战斗 → 结算"),
    ("P3", "P3 · 二级页面", "养成、玩法、社交、商业化共 26 屏"),
    ("P4", "P4 · 探索地图", "18 张地图地貌、出生阵纹、三色导光石槽"),
]

STATS = [
    ("76", "张改前 / 改后对比"),
    ("141", "步全流程截图审计"),
    ("132", "张多分辨率截图 · 0 越界"),
    ("199", "项视觉打磨断言 · 0 失败"),
    ("78/78", "回归用例全绿"),
]

data_js = json.dumps(items, ensure_ascii=False)

html = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>远征 V4 商业化画面重构 · 改前改后对照</title>
<style>
:root{
  --bg:#100e0b; --panel:#1a1611; --panel2:#221c15; --line:#3a3025;
  --gold:#d8ab52; --gold-dim:#8a6f36; --text:#f0e7d7; --muted:#a2937c;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:var(--bg);color:var(--text);
  font-family:"Noto Sans SC","Microsoft YaHei",system-ui,-apple-system,sans-serif;
  -webkit-font-smoothing:antialiased}
a{color:var(--gold)}
.wrap{max-width:1400px;margin:0 auto;padding:0 24px 80px}

header.top{padding:44px 0 22px;border-bottom:1px solid var(--line)}
h1{margin:0 0 10px;font-size:30px;font-weight:700;letter-spacing:.04em}
h1 .sub{color:var(--gold);font-weight:500}
.lede{margin:0;color:var(--muted);font-size:14px;line-height:1.8;max-width:900px}
.lede b{color:var(--text);font-weight:600}

.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
  gap:12px;margin:24px 0 0}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;
  padding:14px 16px}
.stat .n{font-size:22px;font-weight:700;color:var(--gold);letter-spacing:.02em}
.stat .l{font-size:12px;color:var(--muted);margin-top:4px}

.bar{position:sticky;top:0;z-index:30;background:rgba(16,14,11,.94);
  backdrop-filter:blur(10px);border-bottom:1px solid var(--line);
  display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:12px 0;margin-top:26px}
.tab{appearance:none;border:1px solid var(--line);background:transparent;color:var(--muted);
  font:inherit;font-size:13px;padding:7px 14px;border-radius:999px;cursor:pointer;
  transition:.16s;white-space:nowrap}
.tab:hover{border-color:var(--gold-dim);color:var(--text)}
.tab.on{background:var(--gold);border-color:var(--gold);color:#1a1206;font-weight:700}
.tab .c{opacity:.62;margin-left:5px;font-size:11px}
.search{margin-left:auto;background:var(--panel);border:1px solid var(--line);
  border-radius:999px;padding:8px 16px;color:var(--text);font:inherit;font-size:13px;
  width:210px;outline:none}
.search:focus{border-color:var(--gold-dim)}

.phase{margin-top:38px;scroll-margin-top:76px}
.phase h2{margin:0 0 4px;font-size:19px;font-weight:700}
.phase h2 .tag{display:inline-block;background:var(--gold);color:#1a1206;
  font-size:11px;font-weight:800;padding:3px 8px;border-radius:5px;
  vertical-align:2px;margin-right:10px;letter-spacing:.08em}
.phase .desc{margin:0 0 18px;color:var(--muted);font-size:13px}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:18px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;
  overflow:hidden;cursor:zoom-in;transition:.18s;position:relative}
.card:hover{border-color:var(--gold-dim);transform:translateY(-2px);
  box-shadow:0 10px 26px rgba(0,0,0,.5)}
.card .shot{display:block;width:100%;background:#0a0908}
.card .meta{padding:11px 14px 13px}
.card .meta .t{font-size:14px;font-weight:600;line-height:1.45}
.card .meta .n{font-size:12px;color:var(--muted);margin-top:4px;line-height:1.55}
.card .zoom{position:absolute;top:10px;right:10px;background:rgba(16,14,11,.82);
  border:1px solid var(--line);color:var(--gold);font-size:11px;padding:3px 8px;
  border-radius:6px;opacity:0;transition:.16s}
.card:hover .zoom{opacity:1}
.empty{padding:60px 0;text-align:center;color:var(--muted);font-size:14px;display:none}

/* lightbox */
.lb{position:fixed;inset:0;z-index:100;display:none;background:rgba(6,5,4,.95);
  backdrop-filter:blur(6px)}
.lb.on{display:flex;flex-direction:column}
.lb .head{display:flex;align-items:center;gap:14px;padding:14px 22px;
  border-bottom:1px solid var(--line);flex:0 0 auto}
.lb .head .t{font-size:15px;font-weight:600}
.lb .head .n{font-size:12px;color:var(--muted)}
.lb .head .x{margin-left:auto;appearance:none;background:transparent;color:var(--text);
  border:1px solid var(--line);border-radius:8px;font:inherit;font-size:13px;
  padding:6px 14px;cursor:pointer}
.lb .head .x:hover{border-color:var(--gold);color:var(--gold)}
.lb .body{flex:1 1 auto;display:flex;align-items:center;justify-content:center;
  padding:14px 64px;min-height:0}
.lb img{max-width:100%;max-height:100%;object-fit:contain;
  border:1px solid var(--line);border-radius:8px;background:#0a0908}
.lb .nav{position:absolute;top:50%;transform:translateY(-50%);width:46px;height:76px;
  background:rgba(26,22,17,.9);border:1px solid var(--line);color:var(--gold);
  font-size:20px;cursor:pointer;border-radius:8px;display:flex;
  align-items:center;justify-content:center}
.lb .nav:hover{background:var(--panel2);border-color:var(--gold)}
.lb .prev{left:12px}.lb .next{right:12px}
.lb .foot{flex:0 0 auto;padding:10px 22px 16px;text-align:center;
  color:var(--muted);font-size:12px}
@media(max-width:640px){
  .wrap{padding:0 14px 60px}
  h1{font-size:22px}
  .grid{grid-template-columns:1fr}
  .search{margin-left:0;width:100%}
  .lb .body{padding:10px 8px}
  .lb .nav{width:34px;height:56px}
}
</style>
</head>
<body>
<div class="wrap">

<header class="top">
  <h1>远征 · V4 商业化画面重构 <span class="sub">改前 / 改后对照</span></h1>
  <p class="lede">左侧为 <b>2026-10-28 基线实拍</b>，右侧为 <b>重构后实拍</b>，同一场景、同一分辨率（480×800）、同一脚本流程。
  点击任意一张可放大逐处比对，放大后可用 <b>← →</b> 翻页、<b>Esc</b> 关闭。</p>
  <div class="stats">__STATS__</div>
</header>

<div class="bar">
  <button class="tab on" data-p="ALL">全部<span class="c">76</span></button>
  __TABS__
  <input class="search" id="q" type="search" placeholder="搜索页面名，如「背包」">
</div>

<main id="list"></main>
<div class="empty" id="empty">没有匹配的页面</div>
</div>

<div class="lb" id="lb">
  <div class="head">
    <div>
      <div class="t" id="lbT"></div>
      <div class="n" id="lbN"></div>
    </div>
    <button class="x" id="lbX">关闭 Esc</button>
  </div>
  <div class="body"><img id="lbI" alt=""></div>
  <button class="nav prev" id="lbP">‹</button>
  <button class="nav next" id="lbNx">›</button>
  <div class="foot" id="lbF"></div>
</div>

<script>
const DATA = __DATA__;
const PHASES = __PHASES__;
const list = document.getElementById('list');
const empty = document.getElementById('empty');
let cur = 'ALL', q = '', view = DATA.slice(), idx = -1;

function cardHTML(m){
  return `<div class="card" data-slug="${m.slug}">
    <img class="shot" loading="lazy" src="thumbs/${m.slug}.webp" alt="${m.label}">
    <div class="zoom">放大 ⤢</div>
    <div class="meta">
      <div class="t">${m.label}</div>
      ${m.note ? `<div class="n">${m.note}</div>` : ''}
    </div>
  </div>`;
}

function render(){
  list.innerHTML = '';
  let total = 0;
  for (const [k, title, desc] of PHASES){
    if (cur !== 'ALL' && cur !== k) continue;
    const rows = view.filter(m => m.p === k);
    if (!rows.length) continue;
    total += rows.length;
    const sec = document.createElement('section');
    sec.className = 'phase';
    sec.id = 'phase-' + k;
    sec.innerHTML = `<h2><span class="tag">${k}</span>${title.replace(k + ' · ', '')}
      <span style="color:var(--muted);font-weight:400;font-size:13px">（${rows.length} 张）</span></h2>
      <p class="desc">${desc}</p>
      <div class="grid">${rows.map(cardHTML).join('')}</div>`;
    list.appendChild(sec);
  }
  empty.style.display = total ? 'none' : 'block';
  list.querySelectorAll('.card').forEach(c => {
    c.addEventListener('click', () => open(c.dataset.slug));
  });
}

function filtered(){
  const kw = q.trim().toLowerCase();
  view = DATA.filter(m => !kw || (m.label + ' ' + m.note + ' ' + m.p).toLowerCase().includes(kw));
  render();
}

function open(slug){
  idx = view.findIndex(m => m.slug === slug);
  show();
  document.getElementById('lb').classList.add('on');
}
function show(){
  const m = view[idx];
  if (!m) return;
  document.getElementById('lbT').textContent = m.label;
  document.getElementById('lbN').textContent = m.note || '';
  document.getElementById('lbI').src = 'big/' + m.slug + '.webp';
  document.getElementById('lbF').textContent =
    (idx + 1) + ' / ' + view.length + '　·　' + m.p + '　·　左：改前　右：改后';
}
function step(d){
  idx = (idx + d + view.length) % view.length;
  show();
}
document.getElementById('lbX').onclick = () =>
  document.getElementById('lb').classList.remove('on');
document.getElementById('lbP').onclick = e => { e.stopPropagation(); step(-1); };
document.getElementById('lbNx').onclick = e => { e.stopPropagation(); step(1); };
document.getElementById('lb').addEventListener('click', e => {
  if (e.target.id === 'lb' || e.target.className === 'body')
    document.getElementById('lb').classList.remove('on');
});
document.addEventListener('keydown', e => {
  const on = document.getElementById('lb').classList.contains('on');
  if (!on) return;
  if (e.key === 'Escape') document.getElementById('lb').classList.remove('on');
  if (e.key === 'ArrowLeft') step(-1);
  if (e.key === 'ArrowRight') step(1);
});
document.querySelectorAll('.tab').forEach(t => {
  t.onclick = () => {
    document.querySelectorAll('.tab').forEach(x => x.classList.remove('on'));
    t.classList.add('on');
    cur = t.dataset.p;
    filtered();
    window.scrollTo({top: 0, behavior: 'smooth'});
  };
});
document.getElementById('q').addEventListener('input', e => { q = e.target.value; filtered(); });

render();
</script>
</body>
</html>
"""

stats_html = "".join(
    '<div class="stat"><div class="n">%s</div><div class="l">%s</div></div>' % (n, l)
    for n, l in STATS)

tabs = []
for k, title, _ in PHASES:
    n = sum(1 for m in items if m["p"] == k)
    tabs.append('<button class="tab" data-p="%s">%s<span class="c">%d</span></button>' % (k, k, n))

phases_js = json.dumps([[k, t, d] for k, t, d in PHASES], ensure_ascii=False)

html = (html.replace("__STATS__", stats_html)
            .replace("__TABS__", "".join(tabs))
            .replace("__PHASES__", phases_js)
            .replace("__DATA__", data_js))

path = os.path.join(OUT, "index.html")
with open(path, "w", encoding="utf-8") as f:
    f.write(html)
print("wrote", path, round(os.path.getsize(path) / 1024), "KB")
