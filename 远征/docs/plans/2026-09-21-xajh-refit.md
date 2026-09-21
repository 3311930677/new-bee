# 远征 → 《笑傲江湖》复刻改造方案

> **改造对象：** `d:\new bee\远征\`（Godot 4.7.2，480×800，单机）
> **定位（2026-09-21 修订）：** 「形似神不似」——**战斗形态与画风模仿原版**（实时动作战斗 + 高饱和武侠奇幻像素风），**玩法保留远征自有特色**（肉鸽历练/图鉴/寻访抽卡），以原版系统为骨架融合创新，后续接入自建服务端联机。设计边界见「〇、设计定位」节。
> **战斗/遇敌形态修订（2026-09-21，依据原版实机录屏 🎬）：** 录屏实测原版为**实时动作战斗 + 地图明雷**，本方案原「回合制指令战斗 + 随机遇敌」判断**作废**。实录证据见 `原版玩法全景.md` §十一（含 §4.4 / §5.1 / §11.3）。
> **素材路线（已变更）：** 原版素材不进游戏 assets，仅作 AI 生成参考图——全部素材走 `2026-09-21-xajh-asset-regen.md` 的 AI 重生成管线。
> **性质：** 原地改造（用户已确认），战场女神版本靠 git 快照回退。

**素材来源（只读，勿改）：** `d:\new bee\apk_xajh\xaqd_tree\gwy\wm1\`（275 文件完整树）
**格式备忘：** `.pwd`/`.dl` = 6 字节头 + 连续 PNG 流（按 `\x89PNG\r\n\x1a\n` 签名切帧）；`.aef` = 8 字节记录 `u16 key, u16 frame, i16 dx, i16 dy`（语义未全解，仅留档）；原版 240×320 → 2x nearest → 480×640，视口 480×800。
**版权约束：** 原版提取素材仅限个人学习复刻，禁止商用/公开分发。

---

## 〇、设计定位：模仿什么、保留什么、融合什么

| 层 | 原则 | 内容 |
|---|---|---|
| **模仿（形）** | 贴原版 | ① 画风：高饱和+强描边像素、木牌描金+织锦 UI（AI 重生成走原版气质，见 asset-regen）② 战斗：**实时动作制**（🎬 自由走位出招、双弯刀青蓝弧光、脚下红血条/蓝 MP 条、伤害飘字+技能名、命中星爆特效、右下「自动」键、「遭遇战/失败」横幅）③ 系统清单：坐骑（骑姿+本体叠合渲染）/宠物/邮件/排行榜 ④ 世界观：末日浩劫·龙怒剧情线（readme 全文在手）⑤ 遇敌：**地图明雷**（🎬 怪物精灵在地图层游走，接触即触发「遭遇战」，NPC 名绿/怪物标签紫） |
| **特色（神）** | 留远征 | ① 江湖历练（肉鸽 3 选 1 路线，run 模块）② 图鉴 codex 收集 ③ 江湖寻访（gacha 抽卡）④ 演武场段位 ⑤ PVP 排位（属性归一）/休闲（带养成）双模式 |
| **融合（创新）** | 1+1>2 | ① **肉鸽 × 实时战斗**：历练每层战斗接实时战斗核心，奇遇节点产出本局有效的 roguelike 增益（心法残卷/灵药），与永久养成分层 ② **抽卡 × 宠物**：寻访产出「侠客伙伴」= 宠物战斗位，远征稀有度四档色正好映射原版宠物四档品阶特效 ③ **坐骑 × 探索**：坐骑不只是外观，给探索机动加成（疾行提速/明雷规避），延伸原版坐骑收集动机 |

> **判断准则**：凡是"看着像原版"的归模仿；凡是"玩着比原版多出来"的归特色。**特色系统只换皮（武侠命名/文案/素材），机制一律不动、不砍、不删。**

---

## 一、差异对比

### 1.1 画风

| 维度 | 远征现状 | 笑傲江湖原版 | 差距 | 动作 |
|---|---|---|---|---|
| 色系 | 暖棕+羊皮纸+金（`BG_DEEP 2a1f14`/`PARCHMENT e8d5a3`/`GOLD f0c060`/`WOOD 6b4a28`） | 暖木+描金（深木底 `2b2016`、面板 `3d2e1e`、描金 `d9a94e`、米字 `f0e6d2`） | **基本同调**，远征略亮、原版更沉 | 微调色值（见 Task 1.1 对照表） |
| UI 材质 | 代码绘制木匾/羊皮纸面板（ColorRect+工厂函数） | 位图 UI：`bg0~bg7`、`button0~3`、木牌、title/titlebg、HP/MP 条、数字图 | 远征是"画的"，原版是"贴图" | 引入原版 UI 位图替换代码底板 |
| 角色/怪物素材 | **仅 pojun 1 个角色** spritesheet（4×5 网格 128px） | 109 个精灵：三职业×男女战斗精灵、创角立绘、怪物（tyzhanli/tyjc/tyyc 等）、坐骑 8+、宠物、特效 | **素材荒 → 大换血**（画风变化的主来源） | 全量导入原版精灵 |
| 字体 | Noto Sans SC + 站酷小薇（标题） | 原版 16×16 位图字库（已弃用） | 无需变 | 保留现状 |
| 图标语言 | 圆形入口图标、稀有度四档色 | 原版 icon（headicon/npcicon/pk 图等） | 局部替换 | 地图/社交图标换原版 |

**结论：画风差距的核心不是配色，是素材密度。** 远征把"古风骨架"已经搭好了，换上原版 109 精灵 + 96 UI 图后会自然呈现原版味。

### 1.2 玩法逻辑

| 系统 | 远征现状 | 笑傲江湖原版 | 改造方向 | 工作量 |
|---|---|---|---|---|
| 战斗 | **帧级实时 sim**（BattleScene 步进+事件消费；技能 CD 秒级、连击、taunt/lurk、打击感参数） | **实时动作制**（🎬 录屏实测：自由走位出招、双弯刀弧光、脚下 HP/MP 条、伤害飘字、命中特效） | **核心保留**，仅补原版表现层（脚下血蓝条/飘字+技能名/命中特效/遭遇战横幅/自动键） | ★★ |
| 探索 MapScene | 32×42 格自由移动、怪物警戒/接触开战、传送阵出口、小地图/罗盘/疾行 | 走格 + **地图明雷**（🎬 怪物游走，接触即触发「遭遇战」）+ NPC 对话 + 出口切图 | 遇敌改**全明雷**（原「随机遇敌率」作废），其余保留 | ★ |
| 主城 CityScene | 24×20 走格主城、程序绘制建筑、布告板委托、图志阁/兽栏/演武场入口 | 网游主城（多人同图、功能 NPC） | 保留骨架，建筑/命名对齐原版系统 | ★ |
| run/RouteScene | **肉鸽 3 选 1 路线**（每层三节点到 BOSS、羊皮纸卷轴背景） | 无此模式 | **特色保留**（D1 已定：机制不动，武侠化+融合实时战斗） | ★ |
| 养成 | growth/talents/traits/skillbook/equip/exchange/gacha | 坐骑/宠物/装备/技能书（武侠 MMO 套路） | 保留系统骨架，数值文案换血 | ★★ |
| 演武场 Arena | 本地切磋+段位 | PK（联机后=排位/切磋） | 保留，Phase 2 接 PVP | ★ |
| 坐骑/宠物 | mounts.json/pets.json 已有结构 | 原版 zq 系坐骑 8+（sj/mj/lxn/jxl/dyq/bl…）、宠物 wmpet | 换素材+数值 | ★★ |
| 社交/联机 | **无任何网络代码** | 网游：聊天/组队/多人同图/PK | Phase 2-4（沿用既有规划） | ★★★ |

### 1.3 题材文案

| | 远征现状 | 目标（原版） |
|---|---|---|
| 职业 | 破军(战士)/穿杨(枪骑)/霜语(法师)…自设武侠 | 按原版精灵重定：战士 zs/法师 fs/猎手 ls ×男女（立绘/战斗精灵齐备） |
| 世界观 | 自设 lore | 末日浩劫·龙怒：造物神帕拉多、洛林国、钢剑王子（`readme.txt` 完整剧情，about.txt 客服信息勿用） |
| 地图 | 自设 maps/nodes | 洛林郊野→黄城等（原版 6 图的地名/风格参照，tile 自建） |

---

## 二、改造原则

1. **保留远征工程骨架**：G.gd 单例、场景流转、数据驱动（data/*.json）、全部工程规范（语义色、字号阶梯、按钮三档、浮层工厂）。
2. **素材全量换血（AI 重生成）**：所有素材经 asset-regen 管线 AI 重新生成（原版仅作参考图），pojun 相关仅作存档兼容保留。
3. **战斗贴原版手感（实时制保留）**：🎬 录屏证实原版是**实时动作战斗**，与远征 `BattleSim` 同构——**不重写核心**，只在表现层对齐原版（脚下 HP/MP 条、伤害飘字+技能名、命中星爆特效、遭遇战/失败横幅、右下「自动」键），`target`/`effect` 数据体系原样沿用。
4. **数值自设计、世界观贴原版、玩法机制保特色**：系统清单对齐原版，数值重写；远征特色玩法（肉鸽/图鉴/寻访/演武）只换皮不砍机制（见〇节判断准则）。
5. **联机化沿用既有规划**：Net.gd + Rust 服务端（账号→世界→PVP），落点从 xajh 改为远征。
6. **git 分支保护**：改造前打 tag，战场女神版本随时可回退。

---

## 三、分阶段任务

### 阶段 0：安全网 + 素材管线

**Task 0.1 git 快照与分支**

```powershell
git -C "d:\new bee\远征" add -A
git -C "d:\new bee\远征" commit -m "chore: 改造前快照"
git -C "d:\new bee\远征" tag v-zhanchang-nvshen-final
git -C "d:\new bee\远征" checkout -b xajh-remake
```

**Task 0.2 素材脚本**（**⚠️ 路线已变更 2026-09-21**：游戏素材不再直接使用原版提取物，改走 asset-regen 的 AI 重生成管线。下列 convert_sprites 保留改造为参考图库导出工具 `export_refs.py`——切帧逻辑不变，输出目标改 `assets_regan/refs/`；convert_ui/dump_aef 一并保留作研究工具）

`tools/convert_sprites.py`：`.pwd/.dl` → `assets_regan/refs/sprites/<原相对路径>/fNNN.png`（**仅作 AI 参考图库，不进游戏 assets**）

```python
# -*- coding: utf-8 -*-
"""原版精灵帧提取 -> 参考图库 assets_regan/refs/sprites（仅供 AI 生图参考）"""
import re
from pathlib import Path

SRC = Path(r"d:\new bee\apk_xajh\xaqd_tree\gwy\wm1")
DST = Path(r"d:\new bee\远征\assets_regan\refs\sprites")
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
        out_dir = DST / f.relative_to(SRC).with_suffix("")
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, png in enumerate(split_frames(f.read_bytes())):
            (out_dir / f"f{i:03d}.png").write_bytes(png)
            n_frames += 1
        n_files += 1
    print(f"精灵 {n_files} 个, 总帧 {n_frames} -> {DST}")

if __name__ == "__main__":
    main()
```

`tools/convert_ui.py`：UI 类 PNG 2x nearest → `assets_regan/refs/ui/`（保持 ui/ map/ pk/ 结构；**仅作 AI 参考图库**）

```python
# -*- coding: utf-8 -*-
from pathlib import Path
from PIL import Image

SRC = Path(r"d:\new bee\apk_xajh\xaqd_tree\gwy\wm1")
DST = Path(r"d:\new bee\远征\assets_regan\refs\ui")

def main() -> None:
    n = 0
    for sub in ("ui", "map", "pk"):
        for f in sorted((SRC / sub).rglob("*.png")):
            img = Image.open(f)
            if img.mode == "P":
                img = img.convert("RGBA")
            big = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
            out = DST / f.relative_to(SRC)
            out.parent.mkdir(parents=True, exist_ok=True)
            big.save(out)
            n += 1
    print(f"放大 {n} 张 -> {DST}")

if __name__ == "__main__":
    main()
```

`tools/dump_aef.py`：`.aef` → 同名 `.aef.json`（挂在 `assets_regan/refs/sprites` 目录旁，仅研究留档；代码同 xajh 计划 Task 0.4）。

**Task 0.3 运行与登记**（⚠️ 2026-09-21 路线变更：本任务现产出**参考图库**，非游戏素材）

```powershell
python "d:\new bee\远征\tools\convert_sprites.py"
python "d:\new bee\远征\tools\convert_ui.py"
# 统计多帧精灵目录（供 AI 生图挑参考帧）：
Get-ChildItem "d:\new bee\远征\assets_regan\refs\sprites" -Recurse -Directory | ForEach-Object { [PSCustomObject]@{ dir = $_.FullName.Replace("d:\new bee\远征\assets_regan\refs\sprites\",""); frames = (Get-ChildItem $_.FullName -File).Count } } | Where-Object { $_.frames -gt 1 } | Sort-Object frames -Descending | Select-Object -First 15
```

产出即 AI 生图的参考图源；素材登记改为按 `2026-09-21-xajh-asset-regen.md` 的 A-H 编号执行（映射见本文档「附录 A」）。提交：`git commit -m "feat: 原版参考图库导出管线"`。

**Task 0.4 Godot 导入验证**

```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "d:\new bee\远征" --import
```

预期无 ERROR。提交 `.import` 文件。

---

### 阶段 1：画风落地（视觉换血）

**Task 1.1 色板微调**（`src/autoload/G.gd` L4-46，原版取色更沉更木）

| 常量 | 现值 | 新值 | 说明 |
|---|---|---|---|
| `BG_DEEP` | `2a1f14` | `2b2016` | 对齐原版深木底 |
| `BANNER` | `5a3a1e` | `4a3018` | 横幅更沉 |
| `PARCHMENT` | `e8d5a3` | `d8c8a0` | 羊皮纸降饱和（贴近原版木牌纸面） |
| `GOLD` | `f0c060` | `d9a94e` | 对齐原版描金 |
| `GOLD_BRIGHT` | `ffd97a` | `e8c06a` | 选中亮金同步降亮 |
| `WOOD` | `6b4a28` | `5a3d20` | 木框更沉 |
| `VEIL` | `241a10` | 不变 | 已同调 |

语义色（C_GAIN/C_COST/C_HINT/C_RARE）、稀有度四档、按钮三档**全部不动**（规范保留）。

**Task 1.2 标题/登录换肤**（`src/ui/Login.gd`）
- 黄昏营地背景 → asset-regen **G 类** `assets/bg/titlebg.png`（480×640，底部 160px 留给按钮区）
- 金色标题横幅 → **F2 木牌匾** `assets/ui/plaque.png` 居中
- 登录面板底板换 **F3 面板底板** `assets/ui/panel_*.png`；按钮底贴 **F1 横幅按钮** `assets/ui/button_*.png`（三档按钮统一走 `G` 新增的 `mk_wood_button()` 工厂，内部 NinePatch）

**Task 1.3 主界面立绘换血**（`src/ui/GameHome.gd`）
- pojun 立绘 → 按当前职业/性别映射 **A2 战斗精灵**（AI 产物，映射见附录 A）

**Task 1.4 面板木匾/羊皮纸位图化**
- 在 `G.gd` 增加两个工厂：`mk_panel()`（**F3** `assets/ui/panel_*.png` 九宫格拉伸）与 `mk_plaque()`（**F2** `assets/ui/plaque.png` + `maxi(2, 字号/8)` 字距），逐面板替换代码绘制的底板——**只换底板，布局与交互代码不动**
- 战斗 HP/MP 条 → **F4** `assets/ui/hp.png`、`assets/ui/mp.png`；伤害数字 → **F5** `assets/ui/num/` 数字图

**Task 1.5 探索/主城贴图替换**
- MapScene：怪物贴图接 **B 类** `assets/monster/<name>/`（明雷精灵）；地图底接 **H2** `assets/map/tileset_grass.tres`；装饰散件接 **H3** `assets/map/deco/`（y_sort）；出口/NPC 图标沿用现有程序绘制
- CityScene：建筑立面用 **H4**（可选，后置）；程序绘制保留

每任务一提交：`git commit -m "style: <场景> AI 重生素材换肤"`。

---

### 阶段 2：玩法逻辑对齐

**Task 2.1 战斗表现对齐原版（实时制核心保留，🎬 2026-09-21 修订）**
- **不重写核心**：`BattleSim` 帧级实时 sim **保留**（录屏证实原版亦为实时动作制，非回合制），无需新建 BattleTurn，也不需移入 legacy
- **新增/对齐表现层**（对齐录屏 §11.3 实测）：
  - 脚下 **HP 红条 + MP 蓝条**（跟随角色，非顶部固定条）
  - 伤害飘字：黄橙渐变大数字（如 `-42`）+ 技能名（如「重击」）同屏
  - 命中特效：白黄五角星爆 + 橙色放射光线（接 asset-regen E 类特效）
  - 顶部「**遭遇战**」入场横幅；战斗结束「**胜利 / 失败**」横幅
  - 右下红色「**自动**」按钮（挂机自动出招）
  - 怪物头顶标签 **紫色「Lv{n}名」**，NPC 名 **绿色**
- skills.json 的 `target`/`effect`/`k`/`hits`/`cost`/`cd`/`dur` **语义不变**（仍为秒/实时），**取消**原「改秒为回合」的字段改造与 effect.type 映射表
- 伤害数字接 asset-regen F5 数字图；BattleScene 既有技能栏网格/打击感参数/buff 显示**全部保留**
- 验收：探索接触明雷 → 实时战斗（脚下血蓝条/飘字/命中特效/自动键）→ 胜负横幅 → 结算回地图，打击感（震屏/闪白）不丢

**Task 2.2 探索遇敌改造 → 全明雷**（`src/explore/MapScene.gd`）
- 🎬 录屏实测原版为**地图明雷**：僵尸（Lv12）、落叶蛙（Lv8）等怪物精灵**在地图层自行游走**，玩家靠近/接触即触发顶部「**遭遇战**」横幅并进入战斗——**取消随机遇敌 roll**（原 D2「随机+明雷精英」作废）
- 改造点：怪物 `Sprite2D` 常驻地图 + 简单巡逻；接触/碰撞 → 弹「遭遇战」横幅 → 进 BattleScene；精英/Boss **沿用同一明雷机制**（不再区分随机/明雷）
- 怪物标签配色对齐原版：**NPC 名=绿色、怪物标签=紫色「Lv{n}名」**
- NPC 对话接 `data/npcs.json`（新增），出口用传送阵逻辑不变

**Task 2.3 run/RouteScene 特色保留**（D1 已定：保留+融合）
- 「江湖历练」= 远征肉鸽机制**原样保留**（3 选 1 路线/层进 BOSS/随机节点），皮肤与文案武侠化：节点类型换山贼截道/采药识药/古墓奇遇/镖局护送/心法残卷（增益）等武侠事件
- **融合点**：历练战斗接 Task 2.1 实时战斗核心；奇遇节点产出**本局有效**的 roguelike 增益，与永久养成（growth）分层不打架
- 联机后定位：单机日常玩法，与 PVP/世界探索并行——此为差异化特色，原版无此内容

**Task 2.4 主城对齐**（`src/city/CityScene.gd`）
- 建筑/入口命名按原版系统：图志阁→藏经阁、兽栏→坐骑厩（zq 坐骑）、演武场→切磋台；布告板委托→江湖告示（quests 换武侠任务）
- gacha →「江湖寻访」换文案换素材（D3 已定：**保留机制换皮**）；**与宠物系统融合**：寻访产出「侠客伙伴」= 宠物战斗位，稀有度四档色对齐原版宠物四档品阶特效（asset-regen D 类）

**Task 2.5 坐骑/宠物换血**
- `data/mounts.json` 重写为 6-8 坐骑（zq_sj/mj/lxn/jxl/dyq/bl 对应 asset-regen C 类生成产物，名字武侠风自拟）；**融合点**：坐骑附加探索机动加成（疾行提速/遇敌率增减），不只是外观
- `data/pets.json` 伙伴位：接「侠客伙伴」（寻访产出，asset-regen D 类），宠物战斗位 + 品阶特效；wmpet 拆解仅为参考图补充

---

### 阶段 3：数值与文案重写

- **Task 3.1** `data/roles.json` → 三职业 zs/fs/ls ×男女，字段结构不动（id/name/job/weapon/tags/desc/attack_range/base/skills），desc 按「末日浩劫·龙怒」世界观重写；精灵映射写进附录 A
- **Task 3.2** `data/skills.json` 按映射表改字段语义+技能名武侠化；`monsters.json` 接原版怪物精灵；`maps.json` 改洛林郊野/黄城等；新增 `data/npcs.json`
- **Task 3.3** `lore.json`/`codex.json`/`quests.json` 移植 readme.txt 剧情（造物神帕拉多/洛林国/钢剑王子）
- **Task 3.4** 存档兼容：`G._load_save()` 增加旧存档检测（角色 id 为 pojun 体系时提示重开），避免引用不存在资源崩溃

### 阶段 4：联机化（沿用既有规划，落点改为远征）
- Phase A：`src/autoload/Net.gd`（WebSocketPeer，JSON 三型消息 req/res/push）+ Rust 服务端（tokio+tokio-tungstenite+rusqlite）：auth.register/auth.login/token/角色 CRUD；Login.gd 改走服务端
- Phase B：联机世界（AOI 广播、聊天、组队），主城/探索地图渲染其他玩家+底部 160px 聊天栏
- Phase C：服务器权威实时战斗（BattleSim 逻辑上移服务端）；PVP 排位（属性归一）/休闲（带养成）
（细化时各写子计划，协议与结构已在 `d:\new bee\xajh\docs\plans\2026-09-21-xajh-godot-remake.md` Phase 2-4 节定义，直接沿用）

---

## 四、决策点（2026-09-21 已全部拍板：相似但留特色）

| # | 问题 | 结论 |
|---|---|---|
| D1 | run 肉鸽路线 | **保留为特色玩法**「江湖历练」：肉鸽机制不动，节点武侠化+融合实时战斗与本局增益 |
| D2 | 探索遇敌方式 | ~~随机遇敌 + 明雷精英~~ → **全地图明雷**（🎬 2026-09-21 实机录屏修正）：怪物在地图层游走，接触即触发「遭遇战」，随机遇敌 roll 作废 |
| D3 | gacha 抽卡 | **保留为特色玩法**「江湖寻访」：机制不动换皮，并融合宠物系统为「侠客伙伴」 |

## 四点五、实施记录（2026-09-21 首轮落地）

**已做**

| 任务 | 状态 | 落点 / 说明 |
|---|---|---|
| 0.1 git 安全网 | ✅ | 快照 commit `651f28f`、tag `v-zhanchang-nvshen-final`、分支 `xajh-remake` |
| 0.2 参考图库 | ✅ | 精灵/容器：`tools/export_refs.py`（218 图 + manifest）；UI/地图：新增 `tools/export_refs_ui.py`（96 图）→ `assets_regen/refs/`（已 gitignore） |
| 0.3 素材入库 | ✅ | batch0_v2/batch1/batch2_ui/batch3_combat/batch4_mount_pet/batch5_scene_map 的 **ready 成品 77 张**按类别入库 `image/generated_362_xajh/ready/{role,monster,mount,pet,fx,ui,bg,map}/`，文件名统一去掉尺寸/`_v2` 后缀 |
| 0.4 Godot 导入 | ✅ | `--headless --import` 无 ERROR |
| 1.1 色板微调 | ✅ | `G.gd`：BG_DEEP/BANNER/PARCHMENT/GOLD/GOLD_BRIGHT/WOOD 按原版取色；语义色与稀有度四档未动 |
| 1.2 标题/登录换肤 | ✅ | Login 背景 `g_title_background`、标题 `G.mk_plaque`、面板 `G.mk_panel` |
| 1.3 主界面立绘 | ✅ | `G.xa_idle_frames()`：用 A3 行走网格第 1 行 5 帧拼待机动画（拿不到才回落旧 4 帧图） |
| 1.4 位图控件 | ✅（分批） | 新增 `G.mk_panel / mk_plaque / mk_wood_button`：九宫格位图 + **缺图一律回落程序绘制**；Login 已接，其余面板按同一签名逐个替换 |
| 1.5 探索/主城贴图 | ✅（部分） | 新增取图入口 `G.art()` + `XA_ART` 映射表：怪物/宠物优先用 AI 重生成素材，地图与战斗两处都已切换 |
| 2.1 战斗表现对齐 | ✅ | 脚下 HP 红条 + **MP 蓝条**（仅人物）、怪物紫色 `Lv{n}名`、命中五角星爆（程序绘制）、遭遇战/精英战/首领战入场横幅、右下红色「自动」键 |
| 2.2 遇敌 | ✅（已满足） | 大地图本就是**全明雷**（怪物游走 + 接触开战），本轮补紫标 `Lv{n}`；随机遇敌 roll 从不存在所以无需移除 |
| 2.3 历练武侠化 | ✅（部分） | 节点显示名：遭遇→劫道、事件→奇遇、商店→货栈、篝火→营火（类型 id 与机制未动） |
| 2.4 主城对齐 | ✅（部分） | 图志阁→藏经阁、兽栏→坐骑厩、演武场→切磋台、布告板→江湖告示（`祭坛`/`仓廪` 保留：`VerifyCity` 断言里用到） |
| 3.1 三职业 × 男女 | ✅ | `roles.json` 改为 **zs 铁衣（战士·环首大刀）/ ls 追风（猎手·铁胎长弓）/ fs 霜语（法师·九环法杖）**，desc 按「末日浩劫·龙怒」重写；`image/role/ck` → `image/role/ls`（`.tres` 内引用同步修正）；新增 `G.xa_portrait()/xa_avatar_tex()`：立绘/头像按**职业×性别**取 A1/A4，`CreateRole` 已接 |
| 3.2 数值文案 | ✅（部分） | `skills.json` 20→15（三职业各 5；猎手接管原枪骑五技能，法师并入「圣愈」补回治疗）；`combos.json` 4→3；`equip.json` 武器 4 系→3 系（长弓槽沿用 id `spear` 保住宿存档键）；`MonsterAI` 托管条件同步。**未做**：maps/npcs/世界观地名 |
| 3.4 旧存档兼容 | ✅ | `G.XA_LEGACY_ROLE`：老档 `selected_role`/`avatar_id` 为 `ck`/`fz` 时换算成 `ls`/`fs`，并在主界面弹一次「旧档已换算」（不静默改档） |
| 3.2 地名 | ✅ | `maps.json` 八主题改名：枫林郊野 / 凛雪原 / 赤焰岭 / 黄城废墟 / 流沙关 / 千岁冰原 / **龙怒渊** / **希望之都**；`quests.json` 7 处目标、`titles.json` 5 条称号、`lore.json` 序章同步 |
| 3.3 世界观移植 | ✅ | `lore.json` 全量重写为 **「末日浩劫·龙怒」**线：造物神帕拉多 / 天狼星系·帕拉多诺 / 洛林国内忧外患 / 毒矛以演习为名的政变 / 侍卫长月影连夜出逃 / 枫林村七年 / 神秘来客与钢剑王子不辞而别 → 序章五页、八方镇龙印、八境志异与首领对峙/余韵全部改写；`Title.gd` 开场白同步。**保留**原有结构键与八境首领名，机制与回归零改动 |

**与方案的偏离（重要）**

1. **素材入库路径**：方案附录 A 写 `assets/role/<id>/`，但运行时取图入口是 `G.res_tex()`，它只扫 `image/generated_*/ready/`。为满足「接入点不变」，实际落在 `image/generated_362_xajh/ready/<类别>/`（并在 `G._build_res_index` 的批次表里登记）。
2. **id 改名延后**：`roles/monsters/pets` 的 id 与数值文案改属阶段 3，本轮一律不动，改用 `G.XA_ART` / `G.XA_ROLE_GRID` **映射层**接新素材——换画风与改 id 解耦，各自可单独回退。
3. **只做「对得上号」的映射**：AI 只生成了 10 怪 / 4 宠，气质对不上的（如雪怪、狮鹫）暂不映射，继续用原素材，不硬凑。

**第二轮追加（2026-09-22）**

| 任务 | 状态 | 落点 |
|---|---|---|
| 2.2 NPC 对话 | ✅ | 新增 `data/npcs.json`（每主题 1 位，帕拉多诺/洛林线台词）+ `TableCache.theme_npcs()`；MapScene 新增 `_build_npcs()` 与 `npc` 交互类型：**头顶绿名签**、走近自动搭话、走统一详情弹层、**可反复谈**（`cd` 防连点，不像宝箱用一次就熄）；程序兜底画法=斗篷+提灯 |
| 1.3/1.5 行走动画 | ✅ | 新增 `G.xa_walk_frames()`（A3 网格四向 × 5 帧）；**探索图与主城的角色**已切到 AI 素材，旧 `.tres` 仅作回落。两套素材单元尺寸不同（128×128 vs 128×200），缩放与脚底偏移**按实测人高折算**，换素材不会浮空 |
| 3.2 怪物映射 | ✅（补） | `XA_ART` 补 `mon_traitor → b_bandit`（叛军）、`pet_frostwolf → d_pet_snow_mink`；AI 只出了 10 只怪，岩鹰等暂未分配 |
| 2.5 坐骑换皮 | ✅（部分） | `mounts.json` 6 → **8 类**，名字按帕拉多诺线自拟（追风骏/墨甲狻猊/金鳞鲤/暗霜狼/踏云青/玲犀/白鹿/焰驹），图标全部指向 AI 的 C 类素材；**id 与数值未动**（存档键与回归口径不变）。二阶美术待补，`icon2` 暂与一阶同图。**未做**：坐骑的探索机动加成（疾行提速/明雷规避）——那是新玩法，单独一轮 |
| 性能 | ✅（修） | 探索/主城改用 AI 网格后首次进图多了一次 640×800 贴图加载，`VerifyPerf` 的 250ms 预算被顶到 261ms → 把三张 A3 网格加进 `LoadScreen` 预热清单（该开销本就该在加载页付掉） |

**第三轮追加（2026-09-22）：Task 1.5 地图素材落地**

**5 轮巡检（2026-09-22，全部落地）**：① 界面：小面板换肤会顶厚信息条（切片最小尺寸）→ 按 ≥240×160 才上九宫格 + 断言；坐骑跑图加成在坐骑面板上屏。② 玩法：祭坛重择/C 批主题规则核对无误。③ 战斗：结算路径（撤退/负/胜）逐支核对无误。④ 数据：怪物素材映射名实不符与重复引用（蜘蛛→毒蟒、树精→泥怪、两怪共用一图）→ 删错映射 + 唯一性断言。⑤ 性能：切主城 245→63ms（`warm_res` 留引用）、启动预热 2298ms（含编译，该成本在加载页付掉）；全量 26 项全绿。

**素材补齐（2026-09-22）**：35 怪 + 8 宠 + 8 世界插画 AI 全覆盖。

| 任务 | 状态 | 落点 |
|---|---|---|
| H2 地表图集 → 主题地砖 | ✅ | 新增 `tools/slice_map_atlas.py`：H2 第 1 行 4 个草地变体 → `001/002/003_tile_forest_*`（64→48 降到引擎 tile_size），产物落 `image/generated_362_xajh/ready/map/` |
| 路面套件 | ✅ | **未**从 H2 重建位掩码表（H2 是"素材目录"：4 草 + 2 路 + 过渡 + 水 + 石，凑不出三岔/四岔）。改为把现有 4×4 位掩码表的**草底换成新草地、路形原样保留**（`rebase_path_sheet`）——路带不会在满屏新草上割出一条旧绿色带 |
| H3 散件图集 → 装饰 | ✅ | 抠黑底 + 裁到实体外框 + 缩到与旧素材同档的尺寸：大树/秋树/松树 128、灌木 48、草丛 32、灰石 64（旧素材对应 125/105/115/41/27/59） |
| 取图口径 | ✅ | MapScene / CityScene 新增 `_map_tex()`：先问 AI 批次目录（`G.res_tex` 按名索引），否则回落 `asset_dir`。**先 exists 再 load**，表里写错名字不再刷一屏 load 失败；两处的 `asset_dir` 兜底也收成一处 |
| 回归断言 | ✅ | `VerifyMapScene` 新增 G5 段：AI 地砖命中（48×48）、AI 散件命中（大树 128 高）、无 AI 版本时回落旧目录、两边都没有时老实返回 null |

**⚠️ 截图才看得见的一个 bug（已修）**：A3 行走网格是**纯黑底**生成的（batch1 的 ready 成品没抠图），接上代码后角色背后是一块黑方块——**26 项回归全绿也照样漏**。修复 `tools/alpha_walk_grids.py`：从四角**洪水填充**（只清与边缘连通的近黑像素，保住人物描边与头发里的深色）＋ 按已知网格几何清除格间那 2px 灰褐分隔线（分隔线比背景亮、比描边暗，阈值抠不掉）＋ 清图集最外圈。
过程教训两条：① PIL 的 `floodfill` 以**种子像素**比色，四角一旦不是纯黑就只填掉一个角（实测只清 6.8%）；② **运行时不会自动重导贴图**——改完 PNG 必须再跑一次 `--import`，否则看到的一直是旧缓存。

**未做（下一轮）**

- 1.4 收尾：其余面板逐个换 `mk_panel`（大面板才上九宫格；`TraitPicker` 这种 140px 宽卡片必须继续用程序绘制，否则九宫格边距会吃掉内容区）。
- 1.5 收尾：主城建筑立面（H4）、H2/H3 地图图集切图与 Terrain 自动图块。
- 战斗角色五态 sprite（idle/attack/cast/hit/death）仍是旧素材——AI 未出对应套图，等 A2 补齐再换（`BattleScene.ROLE_BATTLE_SHEET`）。
- 2.5 坐骑/宠物换血（含探索机动加成）——与 3.x 的 id 改名一起做更省事。
- **3.2 剩余**：`monsters.json` 按原版怪物精灵改显示名、新增 `data/npcs.json` + 探索图 NPC 对话（属 2.2 的 NPC 部分）。
- **`codex.json`**：现为纯图鉴里程奖励（无世界观文案），无需移植。
- **孤儿素材**：`image/role/fz/`（晨星）已无代码引用，等确认后清掉。
- 阶段 4 联机化。

## 五、验收清单（阶段 1-3 完成 = 单机版达标）

- [ ] 登录→创角（三职业×男女，AI 重生成立绘）→主城→探索→**接触明雷**→**实时战斗**→升级→坐骑/宠物→存档，全流程无报错
- [ ] 特色玩法在位且可玩：江湖历练（肉鸽 3 选 1 + 本局增益）、图鉴收集、江湖寻访（侠客伙伴产出）全流程无报错
- [ ] 全链路无战场女神素材残留（pojun 仅存档兼容路径引用）
- [ ] 色板对照表落地，木匾/面板/按钮均为 AI 重生成位图（asset-regen F 类）
- [ ] lore/codex/quests 全部为末日浩劫·龙怒世界观
- [ ] `git tag v-zhanchang-nvshen-final` 可一键回退验证

## 六、风险

1. **战斗表现对齐**工作量最大（实时核心保留，改动集中在表现层：脚下血蓝条/飘字+技能名/命中特效/横幅/自动键）——逐项替换，保持可回退
2. **.aef 动画语义未解**——动画分组自设计（附录 A 登记），不阻塞
3. **原版地图 tile 未定位**（可能在未拆解的 wm2.mrp）——维持程序 tile，后续可补拆
4. **素材版权**——个人学习限定；若公开需 AI 重绘替换全部原版素材
5. **旧存档兼容**——Task 3.4 强制处理，防崩溃

---

## 附录 A 素材映射表（AI 重生管线 · 2026-09-21 修订）

> **修订说明**：原「Task 0.3 把原版素材拷进 `assets/xajh/`」路线**已作废**（见 `2026-09-21-xajh-asset-regen.md` §八）。
> 现全部素材由 AI 重生成，入库目标统一为 `d:\new bee\远征\assets\`，**接入代码不变**。
> 原版仅作参考图，导出到 `assets_regan/refs/sprites/<相对路径>/`（Step 0，不进游戏 assets）。
> 表中「asset-regen」列为 `2026-09-21-xajh-asset-regen.md` 的素材编号。

| 用途 | asset-regen 产物 | 入库路径（`assets/` 下） | 接入点 |
|---|---|---|---|
| 战士·男 战斗精灵 | A2（112×124，6 张之一） | `role/zs_nan/` | roles.json[zs] |
| 战士·女 战斗精灵 | A2 | `role/zs_nv/` | roles.json[zs] |
| 法师·男/女 | A2 | `role/fs_nan/`、`role/fs_nv/` | roles.json[fs] |
| 猎手·男/女 | A2 | `role/ls_nan/`、`role/ls_nv/` | roles.json[ls] |
| 职业立绘锚点 | A1（512×768，6 张） | `role/<class>_<gender>/portrait.png` | 创角/主界面立绘 |
| 头像 | A4（A1 裁脸 96×96） | `role/<class>_<gender>/avatar.png` | 聊天/队伍/顶部信息 |
| 行走动画帧 | A3 网格 → `slice_grid.py` 切 20 帧 | `role/<class>_<gender>/fXXX.png` | 地图行走动画 |
| 怪物 ×10 | B（128×128） | `monster/<name>/` | monsters.json |
| 坐骑 ×8 | C（160×160） | `mount/<name>/` | mounts.json |
| 宠物 ×4 | D（96×96） | `pet/<name>/` | pets.json |
| 技能特效 ×8 | E（256×256 黑底 → 抠透明） | `fx/<name>.png` | 技能演出叠加 |
| 横幅按钮 ×4 态 | F1（480×96 无字） | `ui/button_*.png` | G.mk_wood_button |
| 木牌匾 | F2（480×128 无字） | `ui/plaque.png` | G.mk_plaque |
| 面板底板（九宫格） | F3（512×512，明/暗 2 张） | `ui/panel_*.png` | G.mk_panel |
| HP/MP 条框 | F4（480×36） | `ui/hp.png`、`ui/mp.png` | BattleScene 表现层（脚下血蓝条） |
| 数字图 0-9 | F5（512×64 → 切 10 帧） | `ui/num/` | BattleScene 伤害飘字 |
| 系统图标 ×8 | F6（96×96） | `ui/icon/` | 主界面图标栏 |
| 场景背景 ×5 | G（768×1024） | `bg/`（含 `titlebg.png`） | 标题/主城/地图远景 Login |
| 地表 tile 图集 | H2（256×256 → `slice_tiles.py` 切 64px） | `map/tileset_grass.tres` | MapScene/CityScene |
| 装饰散件图集 | H3（256×256 黑底 → `chroma_key.py`） | `map/deco/` | Sprite2D（y_sort） |
| 主城建筑立面（可选） | H4（512×512） | `map/building/` | CityScene 建筑 |
