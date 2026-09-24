# 《笑傲江湖》Godot 联机复刻 — 总体计划与 Phase 0-1 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将斯凯 MRP 网游《笑傲江湖》(xaqd.mrp) 复刻为 Godot 4.7.2 联机游戏（自建 Rust 服务端），Phase 0-1 交付可玩的离线单机版，后续阶段逐步接入联机。

**Architecture:** 客户端仿照「远征」项目模式（G.gd 单例 + 代码构建 UI + 数据驱动 JSON + 运行时 SpriteFrames 重建），网络层参考 kunlun 项目（WebSocket + JSON RPC）。资源管线用 Python 从已拆解的 `xaqd_tree` 提取精灵帧并 2x nearest 放大 UI。服务端为 Rust 单二进制（tokio + WebSocket + SQLite），分阶段实现账号/世界/战斗。

**Tech Stack:** Godot 4.7.2 (Compatibility/nearest/480×800) · GDScript · Python 3.10 + Pillow（资源管线）· Rust + tokio-tungstenite + rusqlite（Phase 2 起服务端）· Noto Sans SC (OFL)

**环境常量（所有命令共用）：**

```
GODOT   = D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
PROJECT = d:\new bee\xajh
SRC_TREE = d:\new bee\apk_xajh\xaqd_tree\gwy\wm1     # 原版拆解产物（只读，勿改）
YUANZHENG = d:\new bee\远征                            # 参考项目（只读，勿改）
```

**版权约束：** 提取的原版资源（精灵/UI/文本）仅限个人学习复刻使用，不得商用或公开分发。若日后要公开，需用 AI 重绘替换全部原版素材（参照战场女神项目的做法）。

---

## 里程碑总览

| 阶段 | 内容 | 交付物 |
|---|---|---|
| **Phase 0** | 资源管线 + 项目骨架 | 转换脚本、可显示标题画面与精灵动画的 Godot 项目 |
| **Phase 1** | 离线单机骨架 | 登录→创角→地图行走→回合制战斗完整流程（本地存档） |
| **Phase 2** | Rust 服务端 + 账号系统 | 注册/登录/token/角色创建，客户端接入 |
| **Phase 3** | 联机世界 | 地图玩家同步（AOI）、世界/地图聊天、组队 |
| **Phase 4** | 联机战斗 | 服务器权威回合制 PVE、PVP（排位全数值归一 / 休闲带养成） |

Phase 2-4 各自开工时再写详细子计划（每阶段独立产出可测试软件）。**本计划只详细展开 Phase 0 与 Phase 1。**

---

## 项目文件结构（全景）

```
d:\new bee\xajh\
├── project.godot                 # 仿远征: 480×800, canvas_items, nearest, gl_compatibility
├── icon.svg
├── .gitignore                    # .godot/ server/target/
├── tools/                        # Python 资源管线（一次性/可重跑）
│   ├── convert_sprites.py        # .pwd/.dl → 帧PNG目录
│   ├── convert_ui.py             # UI类PNG 2x nearest 放大
│   └── dump_aef.py               # .aef → JSON（动画挂点元数据，供后续研究）
├── assets/
│   ├── fonts/                    # NotoSansSC-Regular/Bold.otf（从远征复制，OFL许可）
│   ├── sprites/                  # convert_sprites 输出: <原相对路径>/f000.png...
│   │   └── map/role/zhandou/z/zs_nan/f000.png  （示例）
│   └── ui/                       # convert_ui 输出（保持 ui/ map/ pk/ 目录结构, 2x）
│       └── ui/titlebg.png        # （示例, 480×640）
├── data/                         # 数值全自设计
│   ├── roles.json                # 三职业（战士zs/法师fs/猎手ls）
│   ├── skills.json
│   ├── monsters.json
│   ├── maps.json                 # 格子地图: 地形/碰撞/NPC/出口/遇敌率
│   └── npcs.json
├── src/
│   ├── autoload/G.gd             # 字号/色板/字体/场景切换/精灵帧缓存/存档
│   ├── main/Main.gd + Main.tscn  # 入口, 场景路径常量
│   ├── dev/SpriteTest.gd + .tscn # 精灵动画验证场景（--test-sprites 启动）
│   ├── ui/
│   │   ├── Title.gd/.tscn        # 标题画面（titlebg/title 原版素材）
│   │   ├── Login.gd/.tscn        # Phase1 本地登录, Phase2 改接服务端
│   │   ├── CreateRole.gd/.tscn   # 三职业×男女 + 名字
│   │   └── GameHome.gd/.tscn     # 主界面（角色信息/进入江湖）
│   ├── map/MapScene.gd/.tscn     # 格子地图 + 摄像机 + 遇敌
│   └── battle/BattleScene.gd/.tscn # 回合制战斗
└── docs/plans/                   # 本计划
```

**关键决策与理由：**

1. **分辨率**：原版 240×320 → 2x nearest = 480×640，视口 480×800（同远征），多出的 160px 纵向留给底部指令栏/聊天栏。全局 `default_texture_filter=0`（nearest）保证像素锐利。
2. **.pwd 格式**（已验证）：6 字节头 + 连续 PNG 流。切帧方式 = 按 `\x89PNG\r\n\x1a\n` 签名切分，每片即完整 PNG 帧。
3. **.aef 格式**（已验证首 40 字节）：8 字节/条记录 `u16 key, u16 frame, i16 dx, i16 dy`（小端）。key 疑似动作/资源编号，**完整语义未解**，Phase 0 只 dump 成 JSON 留档，动画分组改为自设计（data JSON 配置），不阻塞主线。
4. **地图**：原版地图 tile 数据未定位（可能在未拆解的 wm2.mrp 内），Phase 1 用自研格子地图（代码绘制色块 tile + 数据驱动），视觉美化是后续增强项。
5. **网络协议**（Phase 2 落地）：WebSocket 文本帧 JSON —— 请求 `{"t":"req","id":N,"route":"auth.login","data":{...}}`，响应 `{"t":"res","id":N,"ok":bool,"data":{...}}`，推送 `{"t":"push","event":"chat","data":{...}}`。
6. **数值**：全部自设计（原版数值在服务器侧，抓包未破解）。职业名依据拆解文件命名：`zs`=战士、`fs`=法师、`ls`=猎手。

---

# Phase 0：资源管线 + 项目骨架

### Task 0.1：初始化项目目录与 Godot 配置

**Files:**
- Create: `project.godot`、`.gitignore`、`icon.svg`
- Create: `src/main/Main.tscn`、`src/main/Main.gd`
- Copy: 远征字体 → `assets/fonts/`

- [ ] **Step 1: 创建目录结构**

```powershell
$P = "d:\new bee\xajh"
foreach ($d in @("src\autoload","src\main","src\dev","src\ui","src\map","src\battle","assets\fonts","data","docs\plans","tools")) { New-Item -ItemType Directory -Force -Path "$P\$d" | Out-Null }
Copy-Item "d:\new bee\远征\assets\fonts\NotoSansSC-Regular.otf" "$P\assets\fonts\"
Copy-Item "d:\new bee\远征\assets\fonts\NotoSansSC-Bold.otf" "$P\assets\fonts\"
```

- [ ] **Step 2: 写 `project.godot`**

```ini
config_version=5

[application]

config/name="笑傲江湖复刻"
run/main_scene="res://src/main/Main.tscn"
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://icon.svg"

[autoload]

G="*res://src/autoload/G.gd"

[display]

window/size/viewport_width=480
window/size/viewport_height=800
window/stretch/mode="canvas_items"
window/handheld/orientation=1

[rendering]

textures/canvas_textures/default_texture_filter=0
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 3: 写 `.gitignore`**

```
.godot/
*.tmp
server/target/
__pycache__/
```

- [ ] **Step 4: 写 `icon.svg`**（简约剑形占位，黑底金剑）

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" rx="20" fill="#2b2016"/>
  <path d="M64 14 L76 78 L64 92 L52 78 Z" fill="#d9a94e"/>
  <rect x="42" y="80" width="44" height="7" rx="3" fill="#8a6d3b"/>
  <rect x="60" y="86" width="8" height="22" rx="3" fill="#5a4527"/>
</svg>
```

- [ ] **Step 5: 写 `src/main/Main.gd` 与 `src/main/Main.tscn`**

`src/main/Main.gd`:

```gdscript
extends Node
## 入口：统一场景路径常量 + 启动跳转

const TITLE_SCENE := "res://src/ui/Title.tscn"
const LOGIN_SCENE := "res://src/ui/Login.tscn"
const CREATE_ROLE_SCENE := "res://src/ui/CreateRole.tscn"
const GAME_HOME_SCENE := "res://src/ui/GameHome.tscn"
const MAP_SCENE := "res://src/map/MapScene.tscn"
const BATTLE_SCENE := "res://src/battle/BattleScene.tscn"
const SPRITE_TEST_SCENE := "res://src/dev/SpriteTest.tscn"

func _ready() -> void:
	if "--test-sprites" in OS.get_cmdline_user_args():
		G.go(SPRITE_TEST_SCENE)
	else:
		G.go(TITLE_SCENE)
```

`src/main/Main.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main/Main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 6: git 初始化并提交**（在 `d:\new bee\xajh` 下；提交身份沿用本机远征项目的 git 配置）

```powershell
git init
git add -A
git commit -m "chore: 初始化笑傲江湖 Godot 复刻项目骨架"
```

---

### Task 0.2：精灵帧提取脚本 convert_sprites.py

**Files:**
- Create: `tools/convert_sprites.py`

- [ ] **Step 1: 写脚本**

```python
# -*- coding: utf-8 -*-
"""从 xaqd_tree 提取 .pwd/.dl 精灵帧 -> assets/sprites/<相对路径>/fNNN.png
格式: 6字节头 + 连续PNG流, 按PNG签名切帧, 每片为完整PNG"""
import re
from pathlib import Path

SRC = Path(r"d:\new bee\apk_xajh\xaqd_tree\gwy\wm1")
DST = Path(r"d:\new bee\xajh\assets\sprites")
PNG_SIG = re.compile(re.escape(b"\x89PNG\r\n\x1a\n"))

def split_frames(data: bytes) -> list:
    starts = [m.start() for m in PNG_SIG.finditer(data)]
    return [data[s:(starts[i + 1] if i + 1 < len(starts) else len(data))]
            for i, s in enumerate(starts)]

def main() -> None:
    n_files = n_frames = 0
    for f in sorted(SRC.rglob("*")):
        if f.suffix.lower() not in (".pwd", ".dl"):
            continue
        rel = f.relative_to(SRC).with_suffix("")
        out_dir = DST / rel
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, png in enumerate(split_frames(f.read_bytes())):
            (out_dir / f"f{i:03d}.png").write_bytes(png)
            n_frames += 1
        n_files += 1
    print(f"精灵文件 {n_files} 个, 总帧数 {n_frames}")
    print(f"输出目录: {DST}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 运行并验证**

```powershell
python "d:\new bee\xajh\tools\convert_sprites.py"
```

预期输出：`精灵文件 ~109 个, 总帧数 ~250+`（数值以实际为准，关键是无报错且 zs_nan 等目录存在）。

- [ ] **Step 3: 抽查多帧精灵（找出动画素材）**

```powershell
Get-ChildItem "d:\new bee\xajh\assets\sprites" -Recurse -Directory | ForEach-Object { [PSCustomObject]@{ dir = $_.FullName.Replace("d:\new bee\xajh\assets\sprites\",""); frames = (Get-ChildItem $_.FullName -File).Count } } | Where-Object { $_.frames -gt 1 } | Sort-Object frames -Descending | Select-Object -First 10
```

预期：列出 frames > 1 的目录（如 `map/role/zhandou/l/new_7` 等），记下来供 Task 0.7 用。

- [ ] **Step 4: 提交**

```powershell
git add tools/convert_sprites.py assets/sprites
git commit -m "feat: 精灵帧提取管线 (.pwd/.dl -> 帧PNG)"
```

---

### Task 0.3：UI 放大脚本 convert_ui.py

**Files:**
- Create: `tools/convert_ui.py`

- [ ] **Step 1: 写脚本**

```python
# -*- coding: utf-8 -*-
"""UI类PNG 2x nearest 放大 -> assets/ui (保持 ui/ map/ pk/ 目录结构)"""
from pathlib import Path
from PIL import Image

SRC = Path(r"d:\new bee\apk_xajh\xaqd_tree\gwy\wm1")
DST = Path(r"d:\new bee\xajh\assets\ui")
SCALE = 2

def main() -> None:
    n = 0
    for sub in ("ui", "map", "pk"):
        for f in sorted((SRC / sub).rglob("*.png")):
            img = Image.open(f)
            if img.mode == "P":
                img = img.convert("RGBA")
            big = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
            out = DST / f.relative_to(SRC)
            out.parent.mkdir(parents=True, exist_ok=True)
            big.save(out)
            n += 1
    print(f"放大 {n} 张 UI 图 -> {DST}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 运行并验证**

```powershell
python "d:\new bee\xajh\tools\convert_ui.py"
```

预期：`放大 ~140 张`（ui 96 + map 图标 + pk 图等）；抽查 `assets/ui/ui/titlebg.png` 尺寸为原版 2 倍（原 240 宽 → 480 宽）。

```powershell
python -c "from PIL import Image; im=Image.open(r'd:\new bee\xajh\assets\ui\ui\titlebg.png'); print(im.size)"
```

预期输出形如 `(480, 640)`（以原图尺寸 2 倍为准）。

- [ ] **Step 3: 提交**

```powershell
git add tools/convert_ui.py assets/ui
git commit -m "feat: UI 素材 2x nearest 放大管线"
```

---

### Task 0.4：.aef 元数据 dump 脚本

**Files:**
- Create: `tools/dump_aef.py`

- [ ] **Step 1: 写脚本**

```python
# -*- coding: utf-8 -*-
""".aef -> JSON: 8字节/条记录 (u16 key, u16 frame, i16 dx, i16 dy) 小端
语义未完全破解, 仅留档供后续动画分组研究"""
import json
import struct
from pathlib import Path

SRC = Path(r"d:\new bee\apk_xajh\xaqd_tree\gwy\wm1")
DST = Path(r"d:\new bee\xajh\assets\sprites")

def main() -> None:
    n = 0
    for f in sorted(SRC.rglob("*.aef")):
        data = f.read_bytes()
        recs = []
        for off in range(0, len(data) - 7, 8):
            key, frame, dx, dy = struct.unpack_from("<HHhh", data, off)
            recs.append({"key": key, "frame": frame, "dx": dx, "dy": dy})
        rel = f.relative_to(SRC)
        out = DST / (str(rel)[:-4] + ".aef.json")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(recs, ensure_ascii=False), encoding="utf-8")
        n += 1
    print(f"转换 {n} 个 .aef -> JSON")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 运行并人工观察**

```powershell
python "d:\new bee\xajh\tools\dump_aef.py"
python -c "import json; d=json.load(open(r'd:\new bee\xajh\assets\sprites\map\role\zhandou\z\zd_nan.aef.json',encoding='utf-8')); print(len(d)); print(d[:12])"
```

观察 key/frame/dx/dy 分布规律（key 是否连续分段=动作分组？），把结论记到本文件末尾「研究笔记」一节。**不阻塞主线**——动画分组 Phase 1 用自设计配置。

- [ ] **Step 3: 提交**

```powershell
git add tools/dump_aef.py
git commit -m "feat: .aef 动画元数据 dump 工具"
```

---

### Task 0.5：Godot 导入资源验证

- [ ] **Step 1: headless 导入**

```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "d:\new bee\xajh" --import
```

预期：输出无 `ERROR`，退出码 0。`assets/` 下生成 `.import` 文件。

- [ ] **Step 2: 提交导入描述文件**（`.import` 文件需要提交；`.godot/` 已忽略）

```powershell
git add -A
git commit -m "chore: Godot 资源导入"
```

---

### Task 0.6：G.gd 单例 + Title 标题画面

**Files:**
- Create: `src/autoload/G.gd`、`src/ui/Title.gd`、`src/ui/Title.tscn`

- [ ] **Step 1: 写 `src/autoload/G.gd`**

```gdscript
extends Node
## 全局单例: 字号/色板/字体/场景切换/精灵帧缓存 (仿远征模式)

# ---- 字号系统 ----
const FS_XS := 13
const FS_SM := 16
const FS_MD := 18
const FS_LG := 22
const FS_BIG := 30
const FS_HERO := 56

# ---- 色板 (暖木+描金, 契合原版UI) ----
const C_BG := Color("2b2016")      # 深木底
const C_PANEL := Color("3d2e1e")   # 面板木色
const C_GOLD := Color("d9a94e")    # 描金
const C_TEXT := Color("f0e6d2")    # 主文字
const C_DIM := Color("9a8b73")     # 次要文字
const C_HP := Color("c0392b")
const C_MP := Color("2e6da4")
const C_OK := Color("6aa84f")
const C_WARN := Color("d98c3f")

var font_regular: FontFile
var font_bold: FontFile

# ---- 运行状态 ----
var account := ""          # 账号
var role_name := ""        # 角色名
var role_class := "zs"     # zs=战士 fs=法师 ls=猎手
var role_gender := "nan"   # nan/nv
var role_level := 1
var role_exp := 0
var role_gold := 0

# ---- 精灵帧缓存 ----
var _frames_cache := {}

func _ready() -> void:
	font_regular = load("res://assets/fonts/NotoSansSC-Regular.otf")
	font_bold = load("res://assets/fonts/NotoSansSC-Bold.otf")

func go(path: String) -> void:
	get_tree().change_scene_to_file(path)

## 统一描边文字 (描边宽随字号: 13-18=1px, 22-30=2px, 56=4px)
func make_label(text: String, size: int, color: Color = C_TEXT) -> Label:
	var lb := Label.new()
	lb.text = text
	var ls := LabelSettings.new()
	ls.font = font_bold
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 4 if size >= FS_HERO else (2 if size >= FS_LG else 1)
	ls.outline_color = Color(0, 0, 0, 0.85)
	lb.label_settings = ls
	return lb

## 按帧PNG目录运行时构建 SpriteFrames (帧序=播放序)
func build_frames(dir: String, fps := 8.0) -> SpriteFrames:
	var key := "%s@%s" % [dir, fps]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var i := 0
	var frames := []
	while true:
		var p := "%s/f%03d.png" % [dir, i]
		if not ResourceLoader.exists(p):
			break
		frames.append(load(p))
		i += 1
	if frames.is_empty():
		push_warning("精灵目录无帧: " + dir)
		return null
	var sf := SpriteFrames.new()
	sf.add_animation("default")
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	for tex in frames:
		sf.add_frame("default", tex)
	_frames_cache[key] = sf
	return sf
```

- [ ] **Step 2: 写 `src/ui/Title.gd`**

```gdscript
extends Control
## 标题画面: 原版 titlebg + title + 开始按钮

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/ui/titlebg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var title := TextureRect.new()
	title.texture = load("res://assets/ui/ui/title.png")
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2((480.0 - title.texture.get_width()) / 2.0, 110.0)
	add_child(title)

	var btn := Button.new()
	btn.text = "开 始 游 戏"
	btn.custom_minimum_size = Vector2(240, 64)
	btn.add_theme_font_override("font", G.font_bold)
	btn.add_theme_font_size_override("font_size", G.FS_LG)
	btn.add_theme_color_override("font_color", G.C_TEXT)
	btn.add_theme_color_override("font_hover_color", G.C_GOLD)
	btn.pressed.connect(func() -> void: G.go("res://src/ui/Login.tscn"))
	var cb := CenterContainer.new()
	cb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cb.position = Vector2(120, 690)
	cb.custom_minimum_size = Vector2(240, 64)
	cb.add_child(btn)
	add_child(cb)
```

- [ ] **Step 3: 写 `src/ui/Title.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/Title.gd" id="1"]

[node name="Title" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 4: 先建占位 Login 场景（Title 要跳过去，本任务只放一个底色+文字）**

`src/ui/Login.gd`:

```gdscript
extends Control
## Phase 0 占位; Phase 1 Task 1.2 完整实现

func _ready() -> void:
	color = G.C_BG
	var lb := G.make_label("登录（Phase 1 实现）", G.FS_MD, G.C_DIM)
	lb.set_anchors_preset(Control.PRESET_CENTER)
	add_child(lb)
```

注意：`Control` 没有内置 `color` 属性，改用 `ColorRect`。占位版修正为：

```gdscript
extends ColorRect
## Phase 0 占位; Phase 1 Task 1.2 完整实现

func _ready() -> void:
	color = G.C_BG
	var lb := G.make_label("登录（Phase 1 实现）", G.FS_MD, G.C_DIM)
	lb.set_anchors_preset(Control.PRESET_CENTER)
	add_child(lb)
```

`src/ui/Login.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/Login.gd" id="1"]

[node name="Login" type="ColorRect"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 5: 运行验证**

```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "d:\new bee\xajh"
```

预期：480×800 窗口显示原版标题背景与标题图（像素锐利无模糊），点「开始游戏」进入占位登录页。

- [ ] **Step 6: 提交**

```powershell
git add -A
git commit -m "feat: G单例与标题画面"
```

---

### Task 0.7：精灵动画验证场景 SpriteTest

**Files:**
- Create: `src/dev/SpriteTest.gd`、`src/dev/SpriteTest.tscn`

- [ ] **Step 1: 写 `src/dev/SpriteTest.gd`**

```gdscript
extends Control
## 精灵动画验证: 静态战斗立绘 + 多帧动画轮播 (--test-sprites 启动)

const STATIC_SPRITES := [
	"res://assets/sprites/map/role/zhandou/z/zs_nan",   # 战士·男
	"res://assets/sprites/map/role/zhandou/f/fs_nv",    # 法师·女
	"res://assets/sprites/map/default/monster/tyzhanli", # 怪物
]
# 多帧目录在 Task 0.2 Step 3 的统计结果里选 1-2 个填入:
const ANIM_SPRITES := [
	"res://assets/sprites/map/role/zhandou/l/new_7",
]

func _ready() -> void:
	color = G.C_BG
	var x := 40.0
	for dir in STATIC_SPRITES:
		var sp := Sprite2D.new()
		sp.texture = load(dir + "/f000.png")
		sp.position = Vector2(x, 260)
		add_child(sp)
		var lb := G.make_label(dir.get_file(), G.FS_XS, G.C_DIM)
		lb.position = Vector2(x - 30, 400)
		add_child(lb)
		x += 140
	x = 140.0
	for dir in ANIM_SPRITES:
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = G.build_frames(dir, 8.0)
		if sp.sprite_frames:
			sp.play("default")
		sp.position = Vector2(x, 560)
		add_child(sp)
		var lb := G.make_label(dir.get_file() + " (动画)", G.FS_XS, G.C_DIM)
		lb.position = Vector2(x - 40, 680)
		add_child(lb)
		x += 200
```

`src/dev/SpriteTest.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/dev/SpriteTest.gd" id="1"]

[node name="SpriteTest" type="ColorRect"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

注意：`SpriteTest.gd` 中 `color = G.C_BG` 要求 root 是 `ColorRect`（tscn 已是）。若 ANIM_SPRITES 里填的目录实际无帧，运行时会有 warning——按 Task 0.2 Step 3 的实际结果修正目录名。

- [ ] **Step 2: 运行验证**

```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "d:\new bee\xajh" -- --test-sprites
```

预期：深木底色上显示战士/法师/怪物立绘，且至少一个精灵在循环播放动画。

- [ ] **Step 3: 提交**

```powershell
git add -A
git commit -m "feat: 精灵动画运行时重建验证场景"
```

**Phase 0 完成标志：** 标题画面 + 精灵动画验证场景均正常显示，资源管线三条脚本可重跑（幂等）。

---

# Phase 1：离线单机骨架

### Task 1.1：数值配置 data/*.json

**Files:**
- Create: `data/roles.json`、`data/skills.json`、`data/monsters.json`、`data/maps.json`、`data/npcs.json`

- [ ] **Step 1: `data/roles.json`**（三职业，精灵路径直接写死规避原版命名不规律）

```json
{
  "zs": {
    "name": "战士", "hp": 120, "mp": 30, "atk": 18, "def": 10, "spd": 8,
    "skills": ["zs_1", "zs_2"],
    "sprites": {
      "nan": "res://assets/sprites/map/role/zhandou/z/zs_nan",
      "nv": "res://assets/sprites/map/role/zhandou/z/zs_nv"
    }
  },
  "fs": {
    "name": "法师", "hp": 80, "mp": 80, "atk": 10, "def": 5, "spd": 10,
    "skills": ["fs_1", "fs_2"],
    "sprites": {
      "nan": "res://assets/sprites/map/role/zhandou/f/fs_nan",
      "nv": "res://assets/sprites/map/role/zhandou/f/fs_nv"
    }
  },
  "ls": {
    "name": "猎手", "hp": 100, "mp": 50, "atk": 15, "def": 7, "spd": 14,
    "skills": ["ls_1", "ls_2"],
    "sprites": {
      "nan": "res://assets/sprites/map/role/zhandou/l/nanlrzd",
      "nv": "res://assets/sprites/map/role/zhandou/l/nvlrzd"
    }
  }
}
```

注意：`ls` 的 sprite 目录名（nanlrzd/nvlrzd）以 Task 0.2 实际输出为准，若不存在则改用 `map/role/cgd` 下可用的 l 职业目录并在文件内修正。

- [ ] **Step 2: `data/skills.json`**

```json
{
  "zs_1": {"name": "重斩",   "mp": 0,  "power": 1.2, "type": "phys",  "desc": "挥出沉重一击"},
  "zs_2": {"name": "裂空斩", "mp": 10, "power": 1.8, "type": "phys",  "desc": "破空斩击"},
  "fs_1": {"name": "火球术", "mp": 8,  "power": 1.6, "type": "magic", "desc": "掷出灼热火球"},
  "fs_2": {"name": "寒冰箭", "mp": 12, "power": 2.0, "type": "magic", "desc": "冰晶贯穿"},
  "ls_1": {"name": "连射",   "mp": 5,  "power": 0.8, "type": "phys",  "hits": 2, "desc": "快速双箭"},
  "ls_2": {"name": "穿心箭", "mp": 12, "power": 2.2, "type": "phys",  "desc": "精准要害一击"}
}
```

- [ ] **Step 3: `data/monsters.json`**（sprite 用 map/default/monster 下实际存在的）

```json
{
  "slime":   {"name": "泥怪",   "hp": 30,  "atk": 8,  "def": 2,  "spd": 5,  "exp": 8,   "gold": 5,
              "sprite": "res://assets/sprites/map/default/monster/touying"},
  "bandit":  {"name": "山贼",   "hp": 55,  "atk": 12, "def": 4,  "spd": 8,  "exp": 15,  "gold": 12,
              "sprite": "res://assets/sprites/map/default/monster/tyzhanli"},
  "wolf":    {"name": "恶狼",   "hp": 45,  "atk": 14, "def": 3,  "spd": 13, "exp": 14,  "gold": 9,
              "sprite": "res://assets/sprites/map/default/monster/tyjc"},
  "hawk":    {"name": "岩鹰",   "hp": 40,  "atk": 15, "def": 2,  "spd": 16, "exp": 16,  "gold": 10,
              "sprite": "res://assets/sprites/map/default/monster/tyyc"}
}
```

- [ ] **Step 4: `data/maps.json`**（自研格子地图；`tiles` 行主序字符串，`.`=路 `#`=墙 `N`=NPC `E`=出口）

```json
{
  "luolin": {
    "name": "洛林郊野",
    "cols": 15, "rows": 20,
    "tile": 32,
    "tiles": [
      "###############",
      "#.............#",
      "#..###....###.#",
      "#..#........N.#",
      "#..#....##....#",
      "#.......##....#",
      "#..###.........",
      "#........###..#",
      "#..N.....###..#",
      "#.............#",
      "#...##....#...#",
      "#...##....#...#",
      "#.............#",
      "#......P......E",
      "#.............#",
      "#..###...###..#",
      "#..#.......#..#",
      "#..#............",
      "#.............#",
      "###############"
    ],
    "start": [7, 13],
    "encounter_rate": 0.12,
    "encounters": ["slime", "bandit", "wolf"],
    "next_map": "huangcheng"
  },
  "huangcheng": {
    "name": "黄城",
    "cols": 15, "rows": 20,
    "tile": 32,
    "tiles": [
      "###############",
      "#.............#",
      "#..#######..#.#",
      "#..#.....#..#.#",
      "#..#..N..#....#",
      "#..#.....#..#.#",
      "#..#######..#.#",
      "#.............#",
      "#..E..........#",
      "#.............#",
      "#...####.####.#",
      "#...#.......#.#",
      "#...#..N....#.#",
      "#...#.......#.#",
      "#...####.####.#",
      "#.............#",
      "#..###.....##.#",
      "#..............",
      "#.............#",
      "###############"
    ],
    "start": [3, 8],
    "encounter_rate": 0.06,
    "encounters": ["bandit", "hawk"],
    "next_map": "luolin"
  }
}
```

说明：`P` 为起点标记（与 start 字段一致，仅文档用途）；`E` 为出口（走上去切 next_map）；行内字符数必须等于 cols，每张图都按此校验。

- [ ] **Step 5: `data/npcs.json`**

```json
{
  "luolin_1": {"map": "luolin", "cell": [12, 3], "name": "樵夫",
    "lines": ["听说山那边有恶狼出没…", "少年，出门在外小心些。"]},
  "luolin_2": {"map": "luolin", "cell": [3, 8], "name": "货郎",
    "lines": ["卖草药咯——", "（Phase 2 开放商店）"]},
  "huangcheng_1": {"map": "huangcheng", "cell": [6, 4], "name": "守城兵",
    "lines": ["黄城重地，闲人免进。", "……算了，看你也是练武之人，进吧。"]},
  "huangcheng_2": {"map": "huangcheng", "cell": [7, 12], "name": "老铁匠",
    "lines": ["好剑需千锤百炼。", "（Phase 2 开放锻造）"]}
}
```

- [ ] **Step 6: 验证 JSON 合法性**

```powershell
python -c "import json,glob; [json.load(open(p,encoding='utf-8')) for p in glob.glob(r'd:\new bee\xajh\data\*.json')]; print('all json ok')"
```

预期输出 `all json ok`。

- [ ] **Step 7: 提交**

```powershell
git add data
git commit -m "feat: 三职业/技能/怪物/地图/NPC 数值配置"
```

---

### Task 1.2：Login 登录场景（本地版）

**Files:**
- Modify: `src/ui/Login.gd`（替换 Phase 0 占位实现）

- [ ] **Step 1: 重写 `src/ui/Login.gd`**

```gdscript
extends ColorRect
## 本地登录: 账号绑定本地存档; Phase 2 替换为服务端 auth.login

func _ready() -> void:
	color = G.C_BG
	_add_title()
	_add_input()
	_add_buttons()

func _add_title() -> void:
	var lb := G.make_label("笑 傲 江 湖", G.FS_HERO, G.C_GOLD)
	lb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lb.position = Vector2(0, 130)
	lb.custom_minimum_size = Vector2(480, 0)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lb)
	var sub := G.make_label("末日浩劫 · 龙怒", G.FS_MD, G.C_DIM)
	sub.position = Vector2(0, 205)
	sub.custom_minimum_size = Vector2(480, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

func _add_input() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(140, 320)
	box.custom_minimum_size = Vector2(200, 120)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "输入侠士名号"
	name_edit.custom_minimum_size = Vector2(200, 48)
	name_edit.add_theme_font_override("font", G.font_regular)
	name_edit.add_theme_font_size_override("font_size", G.FS_MD)
	name_edit.name = "NameEdit"
	box.add_child(name_edit)

func _add_buttons() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vb.position = Vector2(120, 660)
	vb.custom_minimum_size = Vector2(240, 110)
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var enter := _mk_btn("江 湖 进 入")
	enter.pressed.connect(_on_enter)
	vb.add_child(enter)
	var quit := _mk_btn("离 开")
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

func _mk_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.add_theme_font_override("font", G.font_bold)
	b.add_theme_font_size_override("font_size", G.FS_MD)
	b.add_theme_color_override("font_color", G.C_TEXT)
	b.add_theme_color_override("font_hover_color", G.C_GOLD)
	return b

func _on_enter() -> void:
	var edit := get_node_or_null(^"VBoxContainer/NameEdit") as LineEdit
	var acc := edit.text.strip_edges()
	if acc.is_empty():
		return
	G.account = acc
	G.load_game()   # Task 1.7 实现; 无存档时字段保持默认
	if G.role_name.is_empty():
		G.go("res://src/ui/CreateRole.tscn")
	else:
		G.go("res://src/ui/GameHome.tscn")
```

注意：`_add_input` 中 VBoxContainer 名为 `VBoxContainer`（默认），LineEdit 挂其下，路径 `VBoxContainer/NameEdit` 有效。

- [ ] **Step 2: 运行验证**（标题→登录→输入名字→应跳创角；此时创角未实现会报缺失场景，先建 Task 1.3 再联测）

- [ ] **Step 3: 提交**

```powershell
git add src/ui/Login.gd
git commit -m "feat: 本地登录场景"
```

---

### Task 1.3：CreateRole 创角场景

**Files:**
- Create: `src/ui/CreateRole.gd`、`src/ui/CreateRole.tscn`

- [ ] **Step 1: 写 `src/ui/CreateRole.gd`**

```gdscript
extends ColorRect
## 创角: 三职业 × 男女 + 名号输入, 立绘预览用战斗精灵 f000

const CLASSES := ["zs", "fs", "ls"]
const GENDERS := ["nan", "nv"]

var sel_class := "zs"
var sel_gender := "nan"

func _ready() -> void:
	color = G.C_BG
	var title := G.make_label("创 建 侠 士", G.FS_BIG, G.C_GOLD)
	title.position = Vector2(0, 50)
	title.custom_minimum_size = Vector2(480, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_add_class_row()
	_add_preview()
	_add_gender_row()
	_add_name_and_confirm()

func _roles() -> Dictionary:
	if not G.has_meta("roles"):
		var f := FileAccess.open("res://data/roles.json", FileAccess.READ)
		G.set_meta("roles", JSON.parse_string(f.get_as_text()))
	return G.get_meta("roles")

func _add_class_row() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(60, 120)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for c in CLASSES:
		var b := Button.new()
		b.text = _roles()[c]["name"]
		b.custom_minimum_size = Vector2(110, 44)
		b.add_theme_font_override("font", G.font_bold)
		b.add_theme_font_size_override("font_size", G.FS_MD)
		b.toggle_mode = true
		b.button_pressed = (c == sel_class)
		b.pressed.connect(func() -> void:
			sel_class = c
			for other in row.get_children():
				other.button_pressed = false
			b.button_pressed = true
			_refresh_preview())
		row.add_child(b)

var _preview: Sprite2D

func _add_preview() -> void:
	_preview = Sprite2D.new()
	_preview.position = Vector2(240, 330)
	add_child(_preview)
	_refresh_preview()

func _refresh_preview() -> void:
	var path: String = _roles()[sel_class]["sprites"][sel_gender] + "/f000.png"
	if ResourceLoader.exists(path):
		_preview.texture = load(path)

func _add_gender_row() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(140, 450)
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	for gd in GENDERS:
		var b := Button.new()
		b.text = "男侠" if gd == "nan" else "女侠"
		b.custom_minimum_size = Vector2(90, 40)
		b.add_theme_font_override("font", G.font_regular)
		b.add_theme_font_size_override("font_size", G.FS_SM)
		b.toggle_mode = true
		b.button_pressed = (gd == sel_gender)
		b.pressed.connect(func() -> void:
			sel_gender = gd
			for other in row.get_children():
				other.button_pressed = false
			b.button_pressed = true
			_refresh_preview())
		row.add_child(b)

func _add_name_and_confirm() -> void:
	var edit := LineEdit.new()
	edit.placeholder_text = "侠士名号"
	edit.position = Vector2(140, 520)
	edit.custom_minimum_size = Vector2(200, 44)
	edit.add_theme_font_override("font", G.font_regular)
	edit.add_theme_font_size_override("font_size", G.FS_MD)
	add_child(edit)
	var ok := Button.new()
	ok.text = "踏 入 江 湖"
	ok.position = Vector2(120, 600)
	ok.custom_minimum_size = Vector2(240, 52)
	ok.add_theme_font_override("font", G.font_bold)
	ok.add_theme_font_size_override("font_size", G.FS_LG)
	ok.add_theme_color_override("font_hover_color", G.C_GOLD)
	ok.pressed.connect(func() -> void:
		var n := edit.text.strip_edges()
		if n.is_empty():
			return
		G.role_name = n
		G.role_class = sel_class
		G.role_gender = sel_gender
		G.role_level = 1
		G.role_exp = 0
		G.role_gold = 0
		G.save_game()
		G.go("res://src/ui/GameHome.tscn"))
	add_child(ok)
```

`src/ui/CreateRole.tscn`（root=ColorRect，同 Login.tscn 模板，Script 路径换掉）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/CreateRole.gd" id="1"]

[node name="CreateRole" type="ColorRect"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 2: 运行验证**：登录输入账号 → 创角页选职业/性别立绘切换 → 输名字 → 踏入江湖 →（GameHome 未建会报错，建完 Task 1.4 联测）
- [ ] **Step 3: 提交**

```powershell
git add src/ui/CreateRole.gd src/ui/CreateRole.tscn
git commit -m "feat: 创角场景 (三职业x男女)"
```

---

### Task 1.4：GameHome 主界面

**Files:**
- Create: `src/ui/GameHome.gd`、`src/ui/GameHome.tscn`

- [ ] **Step 1: 写 `src/ui/GameHome.gd`**

```gdscript
extends ColorRect
## 主界面: 角色信息 + 进入江湖按钮 (后续加背包/设置入口)

func _ready() -> void:
	color = G.C_BG
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 90)
	panel.custom_minimum_size = Vector2(400, 300)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var roles := _roles()
	vb.add_child(G.make_label(G.role_name, G.FS_BIG, G.C_GOLD))
	vb.add_child(G.make_label("%s · %s · Lv.%d" % [
		roles[G.role_class]["name"],
		"男侠" if G.role_gender == "nan" else "女侠",
		G.role_level], G.FS_MD))
	vb.add_child(G.make_label("历练 %d    碎银 %d" % [G.role_exp, G.role_gold], G.FS_SM, G.C_DIM))

	var go_map := Button.new()
	go_map.text = "出 城 行 走"
	go_map.position = Vector2(120, 460)
	go_map.custom_minimum_size = Vector2(240, 56)
	go_map.add_theme_font_override("font", G.font_bold)
	go_map.add_theme_font_size_override("font_size", G.FS_LG)
	go_map.add_theme_color_override("font_hover_color", G.C_GOLD)
	go_map.pressed.connect(func() -> void: G.go("res://src/map/MapScene.tscn"))
	add_child(go_map)

	var save_btn := Button.new()
	save_btn.text = "存 档"
	save_btn.position = Vector2(120, 540)
	save_btn.custom_minimum_size = Vector2(240, 44)
	save_btn.add_theme_font_override("font", G.font_regular)
	save_btn.add_theme_font_size_override("font_size", G.FS_SM)
	save_btn.pressed.connect(func() -> void:
		G.save_game()
		save_btn.text = "已 存 档")
	add_child(save_btn)

func _roles() -> Dictionary:
	if not G.has_meta("roles"):
		var f := FileAccess.open("res://data/roles.json", FileAccess.READ)
		G.set_meta("roles", JSON.parse_string(f.get_as_text()))
	return G.get_meta("roles")
```

`src/ui/GameHome.tscn`：同 CreateRole.tscn 模板（root=ColorRect，Script 指向 GameHome.gd）。

- [ ] **Step 2: 运行验证** + 提交

```powershell
git add src/ui/GameHome.gd src/ui/GameHome.tscn
git commit -m "feat: 主界面"
```

---

### Task 1.5：MapScene 格子地图行走

**Files:**
- Create: `src/map/MapScene.gd`、`src/map/MapScene.tscn`

- [ ] **Step 1: 写 `src/map/MapScene.gd`**

```gdscript
extends Node2D
## 格子地图: 色块tile渲染 + 方向键/WASD格子移动 + NPC对话 + 随机遇敌 + 出口切图

const TILE := 32
const DIRS := {
	"ui_right": Vector2i(1, 0), "ui_left": Vector2i(-1, 0),
	"ui_up": Vector2i(0, -1), "ui_down": Vector2i(0, 1),
}

var map_id := "luolin"
var map_data: Dictionary
var npcs_here: Array = []
var cell := Vector2i.ZERO
var _moving := false
var _steps_since_fight := 0

@onready var player: Sprite2D = $Player
@onready var cam: Camera2D = $Camera2D

func _ready() -> void:
	map_id = G.get_meta("map_id", "luolin")
	_load_map()

func _load_map() -> void:
	for c in get_children():
		if c is not Camera2D and c is not Sprite2D:
			c.queue_free()
	var maps := _json("res://data/maps.json")
	map_data = maps[map_id]
	var rows: Array = map_data["tiles"]
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			var r := ColorRect.new()
			r.position = Vector2(x, y) * TILE
			r.size = Vector2(TILE, TILE)
			match ch:
				"#": r.color = Color("241a10")
				"E": r.color = Color("6a5a30")
				_:   r.color = Color("3a4a2e") if (x + y) % 2 == 0 else Color("35442a")
			if ch == "N":
				r.color = Color("55452c")
			add_child(r)
	npcs_here = []
	for npc_id in _json("res://data/npcs.json").keys():
		var npc: Dictionary = _json("res://data/npcs.json")[npc_id]
		if npc["map"] == map_id:
			npcs_here.append(npc)
			var dot := ColorRect.new()
			dot.position = Vector2(npc["cell"][0], npc["cell"][1]) * TILE + Vector2(8, 8)
			dot.size = Vector2(16, 16)
			dot.color = Color("d9a94e")
			add_child(dot)
	var st: Array = map_data["start"]
	cell = Vector2i(st[0], st[1])
	_refresh_player()

func _refresh_player() -> void:
	var roles := _json("res://data/roles.json")
	var dir: String = roles[G.role_class]["sprites"][G.role_gender]
	var tex_path := dir + "/f000.png"
	if ResourceLoader.exists(tex_path):
		player.texture = load(tex_path)
	player.position = cell * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	cam.position = player.position

func _unhandled_input(event: InputEvent) -> void:
	if _moving or not event.is_action_pressed("ui_right") and not event.is_action_pressed("ui_left") \
			and not event.is_action_pressed("ui_up") and not event.is_action_pressed("ui_down"):
		return
	for action in DIRS:
		if event.is_action_pressed(action):
			_try_move(DIRS[action])

func _try_move(d: Vector2i) -> void:
	var target := cell + d
	var ch := _tile_at(target)
	if ch == "#" or ch == "":
		return
	_moving = true
	var tw := create_tween()
	tw.tween_property(player, "position", target * TILE + Vector2(TILE / 2.0, TILE / 2.0), 0.15)
	await tw.finished
	cell = target
	_moving = false
	_on_arrive()

func _on_arrive() -> void:
	var ch := _tile_at(cell)
	for npc in npcs_here:
		if Vector2i(npc["cell"][0], npc["cell"][1]) == cell:
			_show_dialog(npc)
			return
	if ch == "E":
		G.set_meta("map_id", map_data["next_map"])
		G.go("res://src/map/MapScene.tscn")
		return
	_steps_since_fight += 1
	if _steps_since_fight >= 3 and randf() < float(map_data["encounter_rate"]):
		_steps_since_fight = 0
		var pool: Array = map_data["encounters"]
		G.set_meta("battle_monsters", [pool[randi() % pool.size()]])
		G.go("res://src/battle/BattleScene.tscn")

func _show_dialog(npc: Dictionary) -> void:
	var lines: Array = npc["lines"]
	var i := 0
	var panel := PanelContainer.new()
	panel.position = Vector2(30, 620)
	panel.custom_minimum_size = Vector2(420, 140)
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var name_lb := G.make_label(str(npc["name"]), G.FS_MD, G.C_GOLD)
	var line_lb := G.make_label(str(lines[0]), G.FS_SM)
	var tip := G.make_label("（点击继续）", G.FS_XS, G.C_DIM)
	vb.add_child(name_lb); vb.add_child(line_lb); vb.add_child(tip)
	var next := func() -> void:
		i += 1
		if i >= lines.size():
			panel.queue_free()
		else:
			line_lb.text = str(lines[i])
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			next.call())

func _tile_at(c: Vector2i) -> String:
	var rows: Array = map_data["tiles"]
	if c.y < 0 or c.y >= rows.size():
		return ""
	var line: String = rows[c.y]
	if c.x < 0 or c.x >= line.length():
		return ""
	return line[c.x]

func _json(path: String) -> Variant:
	if not G.has_meta("json_" + path):
		var f := FileAccess.open(path, FileAccess.READ)
		G.set_meta("json_" + path, JSON.parse_string(f.get_as_text()))
	return G.get_meta("json_" + path)
```

`src/map/MapScene.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/map/MapScene.gd" id="1"]

[node name="MapScene" type="Node2D"]
script = ExtResource("1")

[node name="Player" type="Sprite2D" parent="."]

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(1, 1)
position_smoothing_enabled = true
```

注意：`ui_right` 等方向 action 是 Godot 内置的（含 WASD 绑定），无需注册。窗口 480×800 时视口可见约 15×25 格，与 15×20 地图匹配，摄像机可留默认（地图小于视口时居中需 `Camera2D.limit_*`，Phase 1 不强求）。

- [ ] **Step 2: 运行验证**：主界面→出城行走→地图上用方向键移动；撞墙不动；踩 NPC 点出对话；走若干步后切入战斗场景（BattleScene 未建时报缺失，建完 Task 1.6 联测）。
- [ ] **Step 3: 提交**

```powershell
git add src/map
git commit -m "feat: 格子地图行走/对话/遇敌/出口"
```

---

### Task 1.6：BattleScene 回合制战斗

**Files:**
- Create: `src/battle/BattleScene.gd`、`src/battle/BattleScene.tscn`

- [ ] **Step 1: 写 `src/battle/BattleScene.gd`**

```gdscript
extends ColorRect
## 回合制战斗: 速度决定顺序; 指令=攻击/技能/防御/逃跑; 结算后回地图

var player := {}     # {hp,mp,max_hp,max_mp,atk,def,spd}
var monster := {}    # {id,name,hp,max_hp,atk,def,spd,exp,gold}
var guarding := false
var round_no := 1
var _busy := false

var log_lb: Label
var monster_sp: Sprite2D
var player_sp: Sprite2D
var menu: VBoxContainer

func _ready() -> void:
	color = Color("1a140c")
	_setup_units()
	_setup_ui()
	_log("遭遇 %s！" % monster["name"])
	_show_round()

func _setup_units() -> void:
	var roles: Dictionary = G._json("res://data/roles.json")
	var r: Dictionary = roles[G.role_class]
	player = {"hp": r["hp"], "max_hp": r["hp"], "mp": r["mp"], "max_mp": r["mp"],
		"atk": r["atk"], "def": r["def"], "spd": r["spd"],
		"name": G.role_name}
	var mid: String = G.get_meta("battle_monsters")[0]
	var m: Dictionary = G._json("res://data/monsters.json")[mid]
	monster = {"id": mid, "name": m["name"], "hp": m["hp"], "max_hp": m["hp"],
		"atk": m["atk"], "def": m["def"], "spd": m["spd"],
		"exp": m["exp"], "gold": m["gold"], "sprite": m["sprite"]}

func _setup_ui() -> void:
	monster_sp = Sprite2D.new()
	monster_sp.position = Vector2(240, 200)
	var mp: String = monster["sprite"] + "/f000.png"
	if ResourceLoader.exists(mp):
		monster_sp.texture = load(mp)
	add_child(monster_sp)
	player_sp = Sprite2D.new()
	player_sp.position = Vector2(110, 430)
	var roles: Dictionary = G._json("res://data/roles.json")
	var pp: String = roles[G.role_class]["sprites"][G.role_gender] + "/f000.png"
	if ResourceLoader.exists(pp):
		player_sp.texture = load(pp)
	add_child(player_sp)

	log_lb = G.make_label("", G.FS_SM)
	log_lb.position = Vector2(24, 500)
	log_lb.custom_minimum_size = Vector2(432, 130)
	log_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(log_lb)

	menu = VBoxContainer.new()
	menu.position = Vector2(24, 640)
	menu.add_theme_constant_override("separation", 8)
	add_child(menu)

func _show_round() -> void:
	_log("—— 第 %d 回合 ——" % round_no)
	guarding = false
	_menu_attack()

func _menu_attack() -> void:
	_clear_menu()
	_add_cmd("攻 击", func() -> void: _player_act(null))
	var skills: Array = G._json("res://data/roles.json")[G.role_class]["skills"]
	for sid in skills:
		var sk: Dictionary = G._json("res://data/skills.json")[sid]
		var ok_mp := player["mp"] >= int(sk["mp"])
		var b := _add_cmd("%s (气%d)" % [sk["name"], sk["mp"]],
			func() -> void: _player_act(sk))
		b.disabled = not ok_mp
	_add_cmd("防 御", func() -> void: await _round(null, true))
	_add_cmd("逃 跑", _try_flee)

func _add_cmd(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 36)
	b.add_theme_font_override("font", G.font_regular)
	b.add_theme_font_size_override("font_size", G.FS_SM)
	b.pressed.connect(cb)
	menu.add_child(b)
	return b

func _clear_menu() -> void:
	for c in menu.get_children():
		c.queue_free()

func _player_act(sk: Dictionary) -> void:
	await _round(sk, false)

func _try_flee() -> void:
	if randf() < 0.6:
		_log("成功脱离战斗！")
		await _back_to_map()
	else:
		_log("逃跑失败！")
		await _enemy_turn_then_next()

func _round(sk: Dictionary, guard: bool) -> void:
	_clear_menu()
	guarding = guard
	var p_first: bool = player["spd"] + randi() % 4 >= monster["spd"] + randi() % 4
	if p_first:
		if sk == null and not guard:
			_damage_to_monster(player["atk"], 1.0, "普通攻击")
		elif sk != null:
			_use_skill(sk)
		if monster["hp"] > 0:
			await _enemy_turn_then_next()
			return
	else:
		await _enemy_turn()
		if player["hp"] > 0:
			if sk == null and not guard:
				_damage_to_monster(player["atk"], 1.0, "普通攻击")
			elif sk != null:
				_use_skill(sk)
		else:
			return
	_check_end()

func _use_skill(sk: Dictionary) -> void:
	player["mp"] -= int(sk["mp"])
	var hits := int(sk.get("hits", 1))
	for i in hits:
		_damage_to_monster(player["atk"], float(sk["power"]), str(sk["name"]), str(sk["type"]) == "magic")

func _damage_to_monster(atk: int, power: float, label: String, magic := false) -> void:
	var def: int = monster["def"] if not magic else int(monster["def"] / 2.0)
	var dmg := maxi(1, int(round(atk * power)) - def)
	monster["hp"] = maxi(0, monster["hp"] - dmg)
	_log("%s 使出%s，对 %s 造成 %d 伤害！" % [player["name"], label, monster["name"], dmg])

func _enemy_turn_then_next() -> void:
	await _enemy_turn()
	_check_end()

func _enemy_turn() -> void:
	await get_tree().create_timer(0.4).timeout
	var dmg := maxi(1, monster["atk"] - (player["def"] if not guarding else player["def"] * 2))
	player["hp"] = maxi(0, player["hp"] - dmg)
	_log("%s 发起攻击，对你造成 %d 伤害！" % [monster["name"], dmg])

func _check_end() -> void:
	if monster["hp"] <= 0:
		_win()
	elif player["hp"] <= 0:
		_lose()
	else:
		round_no += 1
		_show_round()

func _win() -> void:
	_clear_menu()
	G.role_exp += int(monster["exp"])
	G.role_gold += int(monster["gold"])
	_log("击败 %s！获得历练 %d、碎银 %d。" % [monster["name"], monster["exp"], monster["gold"]])
	while G.role_exp >= _next_exp(G.role_level):
		G.role_exp -= _next_exp(G.role_level)
		G.role_level += 1
		_log("升到 Lv.%d！" % G.role_level)
	G.save_game()
	_add_cmd("返 回", _back_to_map)

func _lose() -> void:
	_clear_menu()
	player["hp"] = 1
	_log("你倒下了……被路过的樵夫救起。")
	_add_cmd("返 回", _back_to_map)

func _next_exp(lv: int) -> int:
	return int(20 * pow(lv, 1.5))

func _back_to_map() -> void:
	G.go("res://src/map/MapScene.tscn")

func _log(s: String) -> void:
	log_lb.text = s + "\n" + log_lb.text
```

说明：`G._json()` 是 Task 1.5 中定义的私有助手——GDScript 无真私有，跨对象可调用；为一致性把 `_json` 保留在 G 上更合理。**执行本任务时先把 MapScene.gd 中的 `_json` 移到 `G.gd` 末尾（去掉下划线改名 `json_data`），两处调用同步更新**：

在 `G.gd` 末尾追加：

```gdscript
var _json_cache := {}

func json_data(path: String) -> Variant:
	if not _json_cache.has(path):
		var f := FileAccess.open(path, FileAccess.READ)
		_json_cache[path] = JSON.parse_string(f.get_as_text())
	return _json_cache[path]
```

并将 MapScene.gd / BattleScene.gd / GameHome.gd / CreateRole.gd 中所有 `_json(...)` / `_roles()` 调用统一替换为 `G.json_data("res://data/....json")`（CreateRole/GameHome 的 `_roles()` 一并删除，改用 `G.json_data("res://data/roles.json")`）。

`src/battle/BattleScene.tscn`（root=ColorRect + Script）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/battle/BattleScene.gd" id="1"]

[node name="BattleScene" type="ColorRect"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 2: 运行验证**：地图遇敌→战斗场景显示怪物/玩家精灵→攻击/技能/防御/逃跑全指令可用→胜利拿经验升级→返回地图继续走；战败回地图 HP=1。
- [ ] **Step 3: 提交**

```powershell
git add src data
git commit -m "feat: 回合制战斗与数据助手统一"
```

---

### Task 1.7：本地存档 G.save_game / load_game

**Files:**
- Modify: `src/autoload/G.gd`

- [ ] **Step 1: 在 `G.gd` 末尾追加存档方法**

```gdscript
## ---- 本地存档 (Phase 2 由服务端存档替代) ----
func save_path() -> String:
	return "user://save_%s.json" % account

func save_game() -> void:
	if account.is_empty():
		return
	var data := {
		"role_name": role_name, "role_class": role_class,
		"role_gender": role_gender, "role_level": role_level,
		"role_exp": role_exp, "role_gold": role_gold,
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))

func load_game() -> void:
	role_name = ""; role_class = "zs"; role_gender = "nan"
	role_level = 1; role_exp = 0; role_gold = 0
	if account.is_empty() or not FileAccess.file_exists(save_path()):
		return
	var f := FileAccess.open(save_path(), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for k in ["role_name", "role_class", "role_gender"]:
		if data.has(k):
			set(k, data[k])
	for k in ["role_level", "role_exp", "role_gold"]:
		if data.has(k):
			set(k, int(data[k]))
```

注意：Task 1.3 创角确认与 Task 1.6 战斗胜利里已调用 `G.save_game()`，本任务补齐实现即可。Login 里的 `G.load_game()`（Task 1.2）同此生效。

- [ ] **Step 2: 运行验证**：创角→存档→关游戏重开→同账号登录→直接进 GameHome 且等级/碎银保持。
- [ ] **Step 3: 提交**

```powershell
git add src/autoload/G.gd
git commit -m "feat: 本地存档"
```

---

### Task 1.8：全流程冒烟测试

- [ ] **Step 1: 全流程手测清单**

启动 → 标题 → 登录(新账号) → 创角(猎手/女) → GameHome → 出城 → 行走 → NPC对话 → 遇敌 → 技能战斗 → 胜利升级 → 出口切黄城 → 存档 → 重启读档 → GameHome 数据正确。

- [ ] **Step 2: 修复发现的问题，逐项提交**

- [ ] **Step 3: Phase 1 收尾提交**

```powershell
git add -A
git commit -m "feat: Phase 1 离线单机骨架完成"
```

**Phase 1 完成标志：** 上述冒烟清单全绿。

---

# Phase 2-4：概要（开工时各写详细子计划）

## Phase 2：Rust 服务端 + 账号系统
- `xajh/server/`：cargo 项目，tokio + tokio-tungstenite + rusqlite。
- 消息协议（前述 JSON 三型）；route：`auth.register` / `auth.login`（返回 token）/ `role.create` / `role.list` / `role.enter`。
- 客户端新增 `src/autoload/Net.gd`（WebSocketPeer，请求-响应 id 配对 + push 信号分发），Login.gd 改走 `auth.login`，本地存档逻辑替换为服务端存档。
- 验收：两台机器各自注册登录，服务端 SQLite 有账号与角色记录。

## Phase 3：联机世界
- 服务端：房间/地图实例、AOI 九宫格广播、移动节流、世界/地图聊天频道、组队状态。
- 客户端：MapScene 渲染其他玩家（头顶名字）、聊天栏（底部 160px 区域派上用场）、组队面板。
- 验收：两个客户端同地图互相可见移动与聊天。

## Phase 4：联机战斗
- 服务器权威回合制 PVE（遇敌在服务端判定，战斗指令转发，结算广播）。
- PVP：排位（属性全归一，仅拼策略）与休闲（带养成数值）双模式（对齐战场女神经验）。
- 验收：双客户端 PVP 对战一局，排位模式属性一致。

---

# 研究笔记（执行中追加）

- （Task 0.4 的 .aef key 语义观察结论写在这里）
- （多帧精灵目录清单写在这里）

---

# Self-Review 记录

1. **Spec 覆盖**：资源管线（Task 0.2-0.4）、客户端骨架（Task 0.6-1.7）、数值自设计（Task 1.1）、服务端 Rust（Phase 2 概要+子计划承诺）均已覆盖。原版地图/动画格式未解部分已显式声明降级方案。
2. **占位符扫描**：Phase 2-4 为「概要+子计划」结构（符合 scope check 的独立子系统拆分），Phase 0-1 无 TBD。
3. **类型一致性**：`G.json_data(path)` 在 Task 1.6 统一收口（MapScene/CreateRole/GameHome/BattleScene 同步替换）；`G.build_frames(dir, fps)` 签名 Task 0.6 定义、Task 0.7 使用一致；`battle_monsters` meta 键 Task 1.5 写入、Task 1.6 读取一致；`map_id` meta 键 Task 1.5 内部自洽。
