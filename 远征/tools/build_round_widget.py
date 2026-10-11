import os, sys, json, base64

ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity\brain\5af44a56-5425-4bb8-8b64-cf82d0333bfe"

def make_widget(round_num, version_name, title, scores, screens, critique):
    # scores: {"before": 80.0, "after": 91.5, "delta": "+11.5", "vis": "27/30", "ui": "23/25", "com": "18/20", "con": "14/15", "tec": "9.5/10"}
    # screens: [{"id": "title", "name": "登录/开始界面", "before": "fn", "after": "fn", "issues": "...", "solution": "..."}]
    # critique: [q1, a1, q2, a2, q3, a3, q4, a4]

    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    .screen-img {{ max-height: 460px; object-fit: contain; }}
    .active-tab {{ border-color: #c29a5b !important; color: #fce2a6 !important; background: rgba(194, 154, 91, 0.15) !important; }}
  </style>
</head>
<body class="bg-transparent text-[var(--foreground)] antialiased p-3">
  <div class="bg-[var(--card)] text-[var(--foreground)] border border-[var(--border)] rounded-2xl p-5 shadow-xl max-w-4xl mx-auto backdrop-blur-md">
    
    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between border-b border-[var(--border)] pb-4 mb-4 gap-2">
      <div>
        <div class="flex items-center gap-2">
          <span class="px-2.5 py-1 text-xs font-semibold rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/40">{version_name}</span>
          <h2 class="text-xl font-bold text-[var(--foreground)]">第 {round_num} 轮：{title}</h2>
        </div>
        <p class="text-xs text-[var(--muted-foreground)] mt-1">美术总监 · UI/UX 设计师 · Godot 技术美术深度迭代闭环</p>
      </div>

      <!-- Score Badge -->
      <div class="flex items-center gap-3 bg-[var(--background)] px-4 py-2 rounded-xl border border-[var(--border)]">
        <div class="text-right">
          <div class="text-xs text-[var(--muted-foreground)]">综合评分</div>
          <div class="text-xs font-mono text-zinc-400">前: {scores['before']} → <span class="text-amber-400 font-bold">后: {scores['after']}</span></div>
        </div>
        <div class="text-2xl font-black text-emerald-400">+{scores['delta']}</div>
      </div>
    </div>

    <!-- Score Breakdown Bar -->
    <div class="grid grid-cols-5 gap-2 mb-4 text-center text-xs">
      <div class="bg-[var(--background)] p-2 rounded-lg border border-[var(--border)]">
        <span class="text-[var(--muted-foreground)] block">视觉质量(30)</span>
        <span class="font-bold text-amber-300">{scores.get('vis', '27/30')}</span>
      </div>
      <div class="bg-[var(--background)] p-2 rounded-lg border border-[var(--border)]">
        <span class="text-[var(--muted-foreground)] block">UI设计(25)</span>
        <span class="font-bold text-amber-300">{scores.get('ui', '23/25')}</span>
      </div>
      <div class="bg-[var(--background)] p-2 rounded-lg border border-[var(--border)]">
        <span class="text-[var(--muted-foreground)] block">商业感(20)</span>
        <span class="font-bold text-amber-300">{scores.get('com', '18/20')}</span>
      </div>
      <div class="bg-[var(--background)] p-2 rounded-lg border border-[var(--border)]">
        <span class="text-[var(--muted-foreground)] block">一致性(15)</span>
        <span class="font-bold text-amber-300">{scores.get('con', '14/15')}</span>
      </div>
      <div class="bg-[var(--background)] p-2 rounded-lg border border-[var(--border)]">
        <span class="text-[var(--muted-foreground)] block">技术完成(10)</span>
        <span class="font-bold text-amber-300">{scores.get('tec', '9.5/10')}</span>
      </div>
    </div>

    <!-- Screen Tabs -->
    <div class="flex flex-wrap gap-1.5 border-b border-[var(--border)] pb-2 mb-4" id="tabs-{round_num}">
"""
    for idx, sc in enumerate(screens):
        act = "active-tab" if idx == 0 else ""
        html += f"""      <button onclick="switchScreen_{round_num}({idx})" id="tab-btn-{round_num}-{idx}" class="px-3 py-1.5 text-xs rounded-lg border border-[var(--border)] hover:bg-zinc-800 transition font-medium {act}">
        {sc['name']}
      </button>\n"""

    html += f"""    </div>

    <!-- Screen Displays -->
"""
    for idx, sc in enumerate(screens):
        disp = "block" if idx == 0 else "none"
        html += f"""    <div id="screen-panel-{round_num}-{idx}" style="display: {disp};" class="space-y-4">
      <!-- Control Bar: Mode Toggle -->
      <div class="flex items-center justify-between bg-[var(--background)] p-2.5 rounded-xl border border-[var(--border)]">
        <div class="text-sm font-semibold text-amber-200 flex items-center gap-2">
          <span>●</span> 界面：{sc['name']}
        </div>
        <div class="flex items-center gap-1.5 bg-[var(--card)] p-1 rounded-lg border border-[var(--border)] text-xs">
          <button onclick="setMode_{round_num}_{idx}('before')" id="mode-before-{round_num}-{idx}" class="px-3 py-1 rounded font-medium hover:bg-zinc-700 transition">修改前 (Before)</button>
          <button onclick="setMode_{round_num}_{idx}('after')" id="mode-after-{round_num}-{idx}" class="px-3 py-1 rounded font-medium bg-amber-500/20 text-amber-300 border border-amber-500/40">修改后 (After)</button>
          <button onclick="setMode_{round_num}_{idx}('split')" id="mode-split-{round_num}-{idx}" class="px-3 py-1 rounded font-medium hover:bg-zinc-700 transition">并排对比 (Split)</button>
        </div>
      </div>

      <!-- Image Area -->
      <div class="bg-black/60 rounded-xl p-3 border border-zinc-800 flex justify-center items-center min-h-[420px]">
        <div id="img-container-{round_num}-{idx}" class="w-full flex justify-center items-center gap-4">
          <!-- Dynamically toggled in JS -->
          <img id="img-view-{round_num}-{idx}" src="{sc['after']}" class="screen-img rounded-lg shadow-2xl border border-zinc-700" alt="Preview"/>
        </div>
      </div>

      <!-- Problem & Solution Analysis -->
      <div class="grid md:grid-cols-2 gap-3 text-xs">
        <div class="bg-red-950/20 border border-red-900/40 rounded-xl p-3">
          <div class="font-bold text-red-400 mb-1 flex items-center gap-1.5">
            <span>⚠️</span> 视觉审查发现的问题 (Before Issues)
          </div>
          <p class="text-zinc-300 leading-relaxed whitespace-pre-line">{sc['issues']}</p>
        </div>
        <div class="bg-emerald-950/20 border border-emerald-900/40 rounded-xl p-3">
          <div class="font-bold text-emerald-400 mb-1 flex items-center gap-1.5">
            <span>✨</span> 美术总监优化方案 (After Improvements)
          </div>
          <p class="text-zinc-300 leading-relaxed whitespace-pre-line">{sc['solution']}</p>
        </div>
      </div>
    </div>\n"""

    # Add Critique Section
    html += f"""
    <!-- Producer Critique Accordion -->
    <div class="mt-6 border-t border-[var(--border)] pt-4">
      <div class="text-xs font-bold text-amber-400 uppercase tracking-wider mb-2">商业游戏制作人深度自我剖析 (Producer Critique)</div>
      <div class="space-y-2 text-xs">
        <div class="bg-[var(--background)] p-3 rounded-lg border border-[var(--border)]">
          <div class="font-semibold text-zinc-300">1. 如果我是商业游戏制作人，我为什么不会满意？</div>
          <div class="text-[var(--muted-foreground)] mt-1">{critique[0]}</div>
        </div>
        <div class="bg-[var(--background)] p-3 rounded-lg border border-[var(--border)]">
          <div class="font-semibold text-zinc-300">2. 玩家第一次看到这里，会觉得哪里廉价？</div>
          <div class="text-[var(--muted-foreground)] mt-1">{critique[1]}</div>
        </div>
        <div class="bg-[var(--background)] p-3 rounded-lg border border-[var(--border)]">
          <div class="font-semibold text-zinc-300">3. 这个界面和成熟手游相比最大差距是什么？</div>
          <div class="text-[var(--muted-foreground)] mt-1">{critique[2]}</div>
        </div>
        <div class="bg-[var(--background)] p-3 rounded-lg border border-[var(--border)]">
          <div class="font-semibold text-zinc-300">4. 下一轮最值得优化的三个地方是什么？</div>
          <div class="text-[var(--muted-foreground)] mt-1">{critique[3]}</div>
        </div>
      </div>
    </div>

  </div>

  <script>
    const screens_{round_num} = {json.dumps(screens)};

    function switchScreen_{round_num}(idx) {{
      for (let i = 0; i < screens_{round_num}.length; i++) {{
        document.getElementById('screen-panel-{round_num}-' + i).style.display = (i === idx) ? 'block' : 'none';
        const tab = document.getElementById('tab-btn-{round_num}-' + i);
        if (i === idx) {{
          tab.classList.add('active-tab');
        }} else {{
          tab.classList.remove('active-tab');
        }}
      }}
    }}
"""
    for idx, sc in enumerate(screens):
        html += f"""
    function setMode_{round_num}_{idx}(mode) {{
      const c = document.getElementById('img-container-{round_num}-{idx}');
      const bBefore = document.getElementById('mode-before-{round_num}-{idx}');
      const bAfter = document.getElementById('mode-after-{round_num}-{idx}');
      const bSplit = document.getElementById('mode-split-{round_num}-{idx}');
      [bBefore, bAfter, bSplit].forEach(b => {{
        b.className = "px-3 py-1 rounded font-medium hover:bg-zinc-700 transition";
      }});
      if (mode === 'before') {{
        bBefore.className = "px-3 py-1 rounded font-medium bg-red-500/20 text-red-300 border border-red-500/40";
        c.innerHTML = '<img src="{sc['before']}" class="screen-img rounded-lg shadow-2xl border border-red-800" alt="Before"/>';
      }} else if (mode === 'after') {{
        bAfter.className = "px-3 py-1 rounded font-medium bg-amber-500/20 text-amber-300 border border-amber-500/40";
        c.innerHTML = '<img src="{sc['after']}" class="screen-img rounded-lg shadow-2xl border border-amber-500" alt="After"/>';
      }} else {{
        bSplit.className = "px-3 py-1 rounded font-medium bg-emerald-500/20 text-emerald-300 border border-emerald-500/40";
        c.innerHTML = '<div class="flex gap-2 w-full justify-center"><div class="text-center"><span class="text-xs text-red-400 block mb-1">优化前 (Before)</span><img src="{sc['before']}" class="screen-img rounded-lg shadow-xl border border-red-800/80"/></div><div class="text-center"><span class="text-xs text-amber-400 block mb-1">优化后 (After)</span><img src="{sc['after']}" class="screen-img rounded-lg shadow-xl border border-amber-500/80"/></div></div>';
      }}
    }}
"""

    html += """  </script>
</body>
</html>"""

    out_file = os.path.join(ARTIFACT_DIR, f"round_{round_num}_preview.html")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated round preview: {out_file}")
    return out_file

if __name__ == "__main__":
    pass
