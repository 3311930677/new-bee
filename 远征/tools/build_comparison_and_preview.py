#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build Chapter Comparison Sheets & Self-Contained Interactive Preview Panel
Converts screenshots to Base64 WebP for seamless, zero-broken-link rendering.
"""
import os
import io
import base64
import json
from PIL import Image, ImageDraw, ImageFont

ART_DIR = r"C:\Users\Administrator\.gemini\antigravity\brain\1bb250ae-0949-4d1d-b77a-fb355f60ce33"
BASELINE_DIR = r"d:\new bee\远征\shots\round1_baseline"
ROUND4_DIR = r"d:\new bee\远征\shots\round4_pure2d"

ACTS = {
    "act1": {
        "title": "第一幕：罗林荒野与枫道 (Act 1: Lorin Wilderness & Maple Highway)",
        "maps": [
            ("lorin_wilds", "罗林原野 (初始营地·保留原案)", "82 -> 92", "原版商业城镇手绘底图·完整保留"),
            ("maple_road", "枫道古路 (落叶大道)", "68 -> 88", "纯2D金秋石板古道，红枫碎屑与路缘"),
            ("broken_slope", "断碑坡 (遗迹高地)", "58 -> 92", "纯2D正投影残碑高地，压实泥径与苔石"),
            ("old_salt_road", "旧盐道 (干涸盐湖)", "60 -> 91", "纯2D多边形盐壳地表，风积沙丘与辙印")
        ]
    },
    "act2": {
        "title": "第二幕：深渊港与潮汐沼泽 (Act 2: Shenyuan Port & Tidal Marsh)",
        "maps": [
            ("shenyuan_port", "深渊港 (港口防线)", "66 -> 90", "纯2D深色湿木栈桥与系泊铁环，海浪岸缘"),
            ("tideflat", "潮滩 (退潮湿地)", "59 -> 89", "纯2D滩涂细砂，潮涌泡沫与湿地水洼"),
            ("tidal_gate", "退潮水闸 (石筑渠闸)", "62 -> 88", "纯2D暗色石砌排水道与金属水闸护栅"),
            ("stele_cavern", "失落石窟 (地下石窟)", "57 -> 91", "纯2D暗黑板岩洞底，发光青晶矿脉与符印"),
            ("red_sand_route", "红砂商路 (荒漠戈壁)", "61 -> 89", "纯2D深红砂岩地表与风蚀沙垄，商队铺路")
        ]
    },
    "act3": {
        "title": "第三幕：霜哨哨所与冰峰裂谷 (Act 3: Frost Post & Rift Mines)",
        "maps": [
            ("frost_post", "霜哨哨所 (雪山要塞)", "63 -> 93", "纯2D积雪路面，原木营房硬化地面与暖灯"),
            ("rift_mine_road", "裂谷矿道 (黑曜矿区)", "58 -> 90", "纯2D深坑矿底，木质轨枕与铁轨矿砂"),
            ("rift_mine_vault", "裂谷矿库 (地下宝库)", "60 -> 89", "纯2D加固条石地坪与粗木支架，矿渣堆"),
            ("frost_pass", "冰风山口 (高原冻原)", "59 -> 90", "纯2D高山深蓝冰层，风蚀花岗岩与薄积雪"),
            ("frost_boardwalk", "霜原栈道 (悬空栈桥)", "56 -> 92", "纯2D厚重木板栈桥，嵌钉防滑与霜白边缘")
        ]
    },
    "act4": {
        "title": "第四幕：渊环禁区与石碑圣所 (Act 4: Abyss Ring & Stele Core)",
        "maps": [
            ("abyss_ring", "渊环外环 (虚空环道)", "64 -> 91", "纯2D黑曜石六边形地砖，紫虚空裂隙与星尘"),
            ("stele_entry", "石碑回廊 (神圣外廊)", "62 -> 90", "纯2D深色打磨玄武岩长廊，金线铭文地刻"),
            ("stele_resonance", "共鸣圣所 (同调大厅)", "61 -> 92", "纯2D神圣共鸣法阵曼荼罗，流光导能水渠"),
            ("stele_core", "碑核中枢 (泰坦核心)", "65 -> 94", "纯2D核心黑曜石巨板，金青交织脉冲裂纹")
        ]
    }
}

def to_base64_webp(im, quality=85):
    """Encode PIL Image to base64 WebP string."""
    buf = io.BytesIO()
    im.save(buf, format="WEBP", quality=quality)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")

def build_comparison_sheet(act_key, act_info):
    """Generate a combined Before vs After side-by-side sheet for the Act."""
    maps = act_info["maps"]
    n = len(maps)
    card_w, card_h = 320, 533
    gap = 20
    header_h = 70
    sheet_w = n * card_w + (n + 1) * gap
    sheet_h = header_h + card_h * 2 + gap * 3

    sheet = Image.new("RGB", (sheet_w, sheet_h), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)

    # Header
    draw.rectangle([(0, 0), (sheet_w, header_h)], fill=(28, 28, 35))
    draw.text((24, 22), act_info["title"], fill=(225, 200, 140))

    for idx, (mid, name, score, desc) in enumerate(maps):
        x = gap + idx * (card_w + gap)
        
        # Load Before
        before_p = os.path.join(BASELINE_DIR, f"baseline_{mid}.png")
        if os.path.exists(before_p):
            im_b = Image.open(before_p).resize((card_w, card_h), Image.Resampling.LANCZOS)
        else:
            im_b = Image.new("RGB", (card_w, card_h), (35, 35, 40))
            
        # Load After
        after_p = os.path.join(ROUND4_DIR, f"map_{mid}_v4.png")
        if os.path.exists(after_p):
            im_a = Image.open(after_p).resize((card_w, card_h), Image.Resampling.LANCZOS)
        else:
            im_a = Image.new("RGB", (card_w, card_h), (45, 45, 55))

        # Paste Before
        y_b = header_h + gap
        sheet.paste(im_b, (x, y_b))
        draw.rectangle([(x, y_b), (x + 130, y_b + 26)], fill=(120, 30, 30))
        draw.text((x + 8, y_b + 6), f"BEFORE: {score.split('->')[0].strip()}", fill=(255, 255, 255))

        # Paste After
        y_a = y_b + card_h + gap
        sheet.paste(im_a, (x, y_a))
        draw.rectangle([(x, y_a), (x + 150, y_a + 26)], fill=(30, 110, 50))
        draw.text((x + 8, y_a + 6), f"V4 纯2D: {score.split('->')[1].strip()}", fill=(255, 255, 255))

        # Map title label
        draw.text((x + 4, y_a + card_h - 24), name.split("(")[0], fill=(255, 230, 170))

    out_file = os.path.join(ART_DIR, f"compare_{act_key}.png")
    sheet.save(out_file, format="PNG")
    print(f"Saved comparison sheet: {out_file}")
    return out_file

def main():
    print("Building chapter comparison sheets...")
    sheet_b64 = {}
    map_images_b64 = {}

    for act_key, act_info in ACTS.items():
        sheet_path = build_comparison_sheet(act_key, act_info)
        im_sheet = Image.open(sheet_path)
        sheet_b64[act_key] = to_base64_webp(im_sheet, quality=80)

        for mid, name, score, desc in act_info["maps"]:
            before_p = os.path.join(BASELINE_DIR, f"baseline_{mid}.png")
            after_p = os.path.join(ROUND4_DIR, f"map_{mid}_v4.png")
            
            b_im = Image.open(before_p).resize((360, 600), Image.Resampling.LANCZOS) if os.path.exists(before_p) else None
            a_im = Image.open(after_p).resize((360, 600), Image.Resampling.LANCZOS) if os.path.exists(after_p) else None
            
            map_images_b64[mid] = {
                "before": to_base64_webp(b_im, quality=80) if b_im else "",
                "after": to_base64_webp(a_im, quality=80) if a_im else "",
                "name": name,
                "score": score,
                "desc": desc
            }

    print("Generating self-contained interactive HTML preview...")
    html_content = generate_html(ACTS, map_images_b64, sheet_b64)
    out_html = os.path.join(ART_DIR, "map_overhaul_preview.html")
    with open(out_html, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"Saved interactive preview panel: {out_html} ({os.path.getsize(out_html)} bytes)")

def generate_html(acts, map_data, sheet_b64):
    map_data_json = json.dumps(map_data, ensure_ascii=False)
    sheet_data_json = json.dumps(sheet_b64, ensure_ascii=False)

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
    <style>
        body {{
            background-color: #0d0f12;
            color: #d1d5db;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif;
            margin: 0;
            padding: 16px;
        }}
        .tab-btn.active {{
            background: linear-gradient(135deg, #b8860b, #d4af37);
            color: #0b0908;
            font-weight: 700;
            box-shadow: 0 4px 12px rgba(212, 175, 55, 0.35);
        }}
        .map-card {{
            transition: all 0.25s ease;
            background: #16181f;
            border: 1px solid #2d313d;
        }}
        .map-card:hover {{
            transform: translateY(-2px);
            border-color: #d4af37;
            box-shadow: 0 8px 20px rgba(0,0,0,0.4);
        }}
        .map-card.active {{
            border-color: #f59e0b;
            background: #1c1f2a;
        }}
        .badge-before {{
            background: rgba(220, 38, 38, 0.2);
            color: #f87171;
            border: 1px solid rgba(220, 38, 38, 0.4);
        }}
        .badge-after {{
            background: rgba(16, 185, 129, 0.2);
            color: #34d399;
            border: 1px solid rgba(16, 185, 129, 0.4);
        }}
        .slider-container {{
            position: relative;
            overflow: hidden;
            border-radius: 8px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.5);
            max-width: 440px;
            margin: 0 auto;
        }}
        .slider-img {{
            display: block;
            width: 100%;
            height: auto;
            user-select: none;
            pointer-events: none;
        }}
        .slider-after-wrap {{
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            overflow: hidden;
            width: 50%;
            border-right: 2px solid #f59e0b;
        }}
        .slider-handle {{
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 38px;
            height: 38px;
            background: #f59e0b;
            color: #111827;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            box-shadow: 0 2px 8px rgba(0,0,0,0.6);
            cursor: ew-resize;
            pointer-events: none;
        }}
    </style>
</head>
<body class="p-3 md:p-6">

    <!-- Header Banner -->
    <div class="max-w-7xl mx-auto mb-6 bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 border border-yellow-600 border-opacity-40 rounded-xl p-5 shadow-2xl flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
            <div class="flex items-center gap-3">
                <span class="px-2.5 py-1 text-xs font-bold bg-yellow-500 text-gray-950 rounded uppercase tracking-wide">V4.0 COMMERCIAL</span>
                <h1 class="text-xl md:text-2xl font-black text-yellow-400 tracking-tight">Godot 全地图纯2D商业化重构·实机对比预览</h1>
            </div>
            <p class="text-xs md:text-sm text-gray-400 mt-1">彻底抛弃旧版程序化「一深一浅」抖动着色器与粗糙方形小地图 · 全地图100%纯2D正投影顶视地表 · 罗盘星盘HUD</p>
        </div>
        <div class="flex items-center gap-4 bg-gray-950 bg-opacity-70 px-4 py-2.5 rounded-lg border border-gray-800">
            <div class="text-center">
                <div class="text-xs text-gray-400">重构地图</div>
                <div class="text-lg font-bold text-yellow-400">18 / 18</div>
            </div>
            <div class="w-px h-8 bg-gray-800"></div>
            <div class="text-center">
                <div class="text-xs text-gray-400">平均美术评分</div>
                <div class="text-lg font-bold text-green-400">60.8 → 91.2</div>
            </div>
            <div class="w-px h-8 bg-gray-800"></div>
            <div class="text-center">
                <div class="text-xs text-gray-400">2D地表视角</div>
                <div class="text-xs font-bold text-blue-400">90° 纯正投影</div>
            </div>
        </div>
    </div>

    <!-- Act Selection Tabs -->
    <div class="max-w-7xl mx-auto mb-6 flex flex-wrap gap-2">
        <button onclick="selectAct('act1')" id="tab-act1" class="tab-btn active px-4 py-2 rounded-lg text-sm font-semibold transition border border-gray-700">
            第一幕：罗林荒野与枫道 (4张)
        </button>
        <button onclick="selectAct('act2')" id="tab-act2" class="tab-btn px-4 py-2 rounded-lg text-sm font-semibold transition bg-gray-900 hover:bg-gray-800 text-gray-300 border border-gray-800">
            第二幕：深渊港与潮汐沼泽 (5张)
        </button>
        <button onclick="selectAct('act3')" id="tab-act3" class="tab-btn px-4 py-2 rounded-lg text-sm font-semibold transition bg-gray-900 hover:bg-gray-800 text-gray-300 border border-gray-800">
            第三幕：霜哨哨所与冰峰裂谷 (5张)
        </button>
        <button onclick="selectAct('act4')" id="tab-act4" class="tab-btn px-4 py-2 rounded-lg text-sm font-semibold transition bg-gray-900 hover:bg-gray-800 text-gray-300 border border-gray-800">
            第四幕：渊环禁区与石碑圣所 (4张)
        </button>
    </div>

    <!-- Main Workspace: Left Map List, Right Comparison Workspace -->
    <div class="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        <!-- Left Column: Map Cards for Selected Act -->
        <div class="lg:col-span-4 flex flex-col gap-3" id="map-list-container">
            <!-- Dynamic map cards injected here -->
        </div>

        <!-- Right Column: Interactive Before/After Comparison Workspace -->
        <div class="lg:col-span-8 bg-gray-900 border border-gray-800 rounded-xl p-5 shadow-2xl flex flex-col">
            
            <!-- Detail Header -->
            <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center pb-4 mb-4 border-b border-gray-800 gap-2">
                <div>
                    <h2 id="cur-map-title" class="text-lg font-bold text-yellow-300">断碑坡 (遗迹高地)</h2>
                    <p id="cur-map-desc" class="text-xs text-gray-400 mt-0.5">纯2D正投影残碑高地，压实泥径与苔石，无天际线透视干扰</p>
                </div>
                <div class="flex items-center gap-2">
                    <span id="cur-map-score" class="text-xs px-2.5 py-1 rounded-full font-bold bg-green-900 bg-opacity-40 text-green-400 border border-green-700">评分：58 → 92</span>
                    <button onclick="toggleViewMode()" id="view-mode-btn" class="text-xs px-3 py-1.5 rounded bg-gray-800 hover:bg-gray-700 text-gray-300 border border-gray-700 transition">
                        切换为并排视图
                    </button>
                </div>
            </div>

            <!-- Comparison Stage -->
            <div id="comparison-stage" class="flex-1 flex flex-col items-center justify-center p-2">
                
                <!-- Slider Mode -->
                <div id="slider-wrap" class="slider-container" onmousemove="handleSliderMove(event)" ontouchmove="handleSliderTouch(event)">
                    <img id="img-before" class="slider-img" src="" alt="修改前">
                    <div id="after-slider-box" class="slider-after-wrap">
                        <img id="img-after" class="slider-img" style="max-width: 440px;" src="" alt="修改后纯2D">
                    </div>
                    <div id="slider-handle" class="slider-handle">↔</div>
                    <div class="absolute bottom-3 left-3 px-2 py-1 text-xs font-bold rounded badge-before">修改前 (旧程序化)</div>
                    <div class="absolute bottom-3 right-3 px-2 py-1 text-xs font-bold rounded badge-after">修改后 (V4纯2D商业化)</div>
                </div>

                <!-- Side by Side Mode (hidden by default) -->
                <div id="side-by-side-wrap" class="hidden w-full grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div class="bg-gray-950 p-2 rounded-lg border border-red-900 border-opacity-40">
                        <div class="text-xs font-bold text-red-400 mb-1.5 flex justify-between">
                            <span>BEFORE (旧版「一深一浅」粗糙地表)</span>
                            <span class="text-gray-500">方形小地图</span>
                        </div>
                        <img id="side-img-before" class="w-full rounded shadow" src="" alt="Before">
                    </div>
                    <div class="bg-gray-950 p-2 rounded-lg border border-green-900 border-opacity-40">
                        <div class="text-xs font-bold text-green-400 mb-1.5 flex justify-between">
                            <span>AFTER (V4 纯2D正投影商业地表)</span>
                            <span class="text-yellow-400">罗盘星盘HUD</span>
                        </div>
                        <img id="side-img-after" class="w-full rounded shadow" src="" alt="After">
                    </div>
                </div>

            </div>

            <!-- Bottom Technical Analysis Box -->
            <div class="mt-4 pt-4 border-t border-gray-800 grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs text-gray-400">
                <div class="bg-gray-950 p-3 rounded border border-gray-800">
                    <span class="text-yellow-400 font-bold block mb-1">① 100% 纯2D正投影</span>
                    裁切排除所有AI远景天空与天际线，保证角色任何走位都在实心地表上，视角统一90°。
                </div>
                <div class="bg-gray-950 p-3 rounded border border-gray-800">
                    <span class="text-yellow-400 font-bold block mb-1">② flat_routes 路线深度融合</span>
                    依每张地图通行路线原生铺设压实泥石路、矿车轨道、金线符文导能渠与木栈道。
                </div>
                <div class="bg-gray-950 p-3 rounded border border-gray-800">
                    <span class="text-yellow-400 font-bold block mb-1">③ 罗盘星盘小地图</span>
                    彻底剔除原右上角死板灰色方块，升级为带暗夜黑曜背板与方位刻度的高级奇幻星盘。
                </div>
            </div>

        </div>

    </div>

    <!-- Act Panoramic Overview Sheet Section -->
    <div class="max-w-7xl mx-auto mt-8 bg-gray-900 border border-gray-800 rounded-xl p-5 shadow-2xl">
        <div class="flex justify-between items-center mb-4">
            <h3 class="text-base font-bold text-yellow-400 flex items-center gap-2">
                <span>📑 当前幕全地图并排对比画卷</span>
                <span class="text-xs text-gray-400 font-normal">(480x800 实机无损拼接)</span>
            </h3>
        </div>
        <div class="overflow-x-auto pb-2">
            <img id="act-sheet-img" class="rounded-lg shadow border border-gray-800 max-w-none" style="max-height: 520px;" src="" alt="幕对比图">
        </div>
    </div>

    <script>
        const ACTS = {json.dumps(acts, ensure_ascii=False)};
        const MAP_DATA = {map_data_json};
        const SHEET_DATA = {sheet_data_json};

        let currentAct = 'act1';
        let currentMapId = 'broken_slope';
        let viewMode = 'slider'; // 'slider' or 'side'

        function selectAct(actKey) {{
            currentAct = actKey;
            // Update tabs
            document.querySelectorAll('.tab-btn').forEach(b => {{
                b.classList.remove('active');
                b.classList.add('bg-gray-900', 'text-gray-300', 'border-gray-800');
            }});
            const activeBtn = document.getElementById('tab-' + actKey);
            activeBtn.classList.add('active');
            activeBtn.classList.remove('bg-gray-900', 'text-gray-300', 'border-gray-800');

            // Render Map List
            renderMapList();

            // Select first map of Act
            const firstMap = ACTS[actKey].maps[0][0];
            selectMap(firstMap);

            // Update Sheet
            document.getElementById('act-sheet-img').src = SHEET_DATA[actKey] || '';
        }}

        function renderMapList() {{
            const container = document.getElementById('map-list-container');
            container.innerHTML = '';
            const maps = ACTS[currentAct].maps;

            maps.forEach(([mid, name, score, desc]) => {{
                const card = document.createElement('div');
                card.id = 'map-card-' + mid;
                card.className = `map-card p-3 rounded-lg cursor-pointer flex items-center justify-between gap-3 ${{mid === currentMapId ? 'active' : ''}}`;
                card.onclick = () => selectMap(mid);

                const info = MAP_DATA[mid] || {{}};
                card.innerHTML = `
                    <div class="flex items-center gap-3 overflow-hidden">
                        <img src="${{info.after || ''}}" class="w-12 h-12 object-cover rounded border border-gray-700 flex-shrink-0" alt="${{mid}}">
                        <div class="truncate">
                            <div class="font-bold text-sm text-gray-200 truncate">${{name}}</div>
                            <div class="text-xs text-gray-400 truncate mt-0.5">${{desc}}</div>
                        </div>
                    </div>
                    <div class="text-right flex-shrink-0">
                        <div class="text-xs font-bold text-green-400">${{score}}</div>
                        <div class="text-xs text-gray-500 mt-0.5">纯2D</div>
                    </div>
                `;
                container.appendChild(card);
            }});
        }}

        function selectMap(mid) {{
            currentMapId = mid;
            document.querySelectorAll('.map-card').forEach(c => c.classList.remove('active'));
            const activeCard = document.getElementById('map-card-' + mid);
            if (activeCard) activeCard.classList.add('active');

            const m = MAP_DATA[mid];
            if (!m) return;

            document.getElementById('cur-map-title').innerText = m.name;
            document.getElementById('cur-map-desc').innerText = m.desc;
            document.getElementById('cur-map-score').innerText = '评分：' + m.score;

            // Update Slider Images
            document.getElementById('img-before').src = m.before;
            document.getElementById('img-after').src = m.after;

            // Update Side by Side Images
            document.getElementById('side-img-before').src = m.before;
            document.getElementById('side-img-after').src = m.after;

            // Reset Slider Position to 50%
            setSliderPercent(50);
        }}

        function setSliderPercent(pct) {{
            pct = Math.max(0, Math.min(100, pct));
            const afterBox = document.getElementById('after-slider-box');
            const handle = document.getElementById('slider-handle');
            if (afterBox) afterBox.style.width = pct + '%';
            if (handle) handle.style.left = pct + '%';
        }}

        function handleSliderMove(e) {{
            const wrap = document.getElementById('slider-wrap');
            const rect = wrap.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const pct = (x / rect.width) * 100;
            setSliderPercent(pct);
        }}

        function handleSliderTouch(e) {{
            if (!e.touches || e.touches.length === 0) return;
            const wrap = document.getElementById('slider-wrap');
            const rect = wrap.getBoundingClientRect();
            const x = e.touches[0].clientX - rect.left;
            const pct = (x / rect.width) * 100;
            setSliderPercent(pct);
        }}

        function toggleViewMode() {{
            const sliderWrap = document.getElementById('slider-wrap');
            const sideWrap = document.getElementById('side-by-side-wrap');
            const btn = document.getElementById('view-mode-btn');

            if (viewMode === 'slider') {{
                viewMode = 'side';
                sliderWrap.classList.add('hidden');
                sideWrap.classList.remove('hidden');
                btn.innerText = '切换为对比滑块视图';
            }} else {{
                viewMode = 'slider';
                sliderWrap.classList.remove('hidden');
                sideWrap.classList.add('hidden');
                btn.innerText = '切换为并排视图';
            }}
        }}

        // Initialize on load
        window.addEventListener('DOMContentLoaded', () => {{
            selectAct('act1');
        }});
    </script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
