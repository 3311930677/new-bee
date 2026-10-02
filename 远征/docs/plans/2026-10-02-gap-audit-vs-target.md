# 《远征》对标原版复刻目标 · 差异与问题全面排查

> 排查日期：2026-10-02
> 排查范围：`D:\new bee\远征`（Godot 4.7.2，分支 `xajh-remake`，HEAD `f8dedff`）
> 对标目标：`docs/plans/2026-09-24-yuanzheng-master-plan.md` §0/§2.2/§11.1（总方案硬验收）+ `docs/原版玩法全景.md`（原版《笑傲江湖·末日浩劫·龙怒》结构基准）
> 证据等级：本报告区分「**实机复跑**」（本次亲自运行）｜「**代码/数据实证**」（读表读码）｜「**文档自述**」（历史记录，未独立复现）。

---

## 0. 本次排查的关键发现（先读这段）

### 0.1 两条"回归失败"是环境假象，不是代码缺陷

历史记录（`2026-10-02-aesthetic-refinement.md` 等）反复登记：

- `VerifySave` 失败 1 条：「重新写盘后应回到 current 模式，实为 invalid」
- `VerifyStory` 失败 18 条（集中在 `prog.side` / `prog.ledger` 支线状态）

并且被描述为「根因未定位」「与本轮改动无调用路径关联」。

**本次排查定位到根因，并已实测证实它是环境问题：**

- `VerifySave` 实际不是断言失败，而是 `SCRIPT ERROR: Cannot call method 'get_files' on a null value.`（`tools/VerifySave.gd:332`）——`DirAccess.open("user://")` 返回 `null` 后崩溃，进程非零退出被 runner 判红，日志里根本没有那一行 FAIL。
- 根因：本次 shell 会话里 **`APPDATA` 环境变量未导出**。Godot 因此把 `user://` 解析成**相对路径** `./Godot/app_userdata/远征`（实测 `ProjectSettings.globalize_path("user://")` 输出 `./Godot/app_userdata/远征`），目录不存在 → `DirAccess.open` 失败。
- 显式 `export APPDATA=C:/Users/Administrator/AppData/Roaming` 后，`user://` 恢复为绝对的 `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/远征`，两用例立刻全绿。

**本次在修正环境下跑了完整回归：41/41 PASS，FAIL=0。** 见 §2。

> 结论：`VerifyStory` 18 条与 `VerifySave` 1 条属**同一环境根因**，被历次文档误记为"未定位的玩法缺陷"并逐轮复制。这是文档层面最大的一个失真点，需要更正。

### 0.2 内容/系统层面的真实差距仍然很大

功能回归全绿**只证明已有用例覆盖的情形**。对标总方案 §11.1 的 8 条硬验收，**当前 0 条完全达成**。真实差距见 §3。

---

## 1. 对标基准与当前状态速览

| 维度 | 目标（总方案） | 当前实测 | 完成度 |
|---|---|---|---|
| 可走城镇/驿站 | 3 座（昭元边城、沉渊港、霜关驿） | 3 座 | ✅ |
| 野外地图 | 9 张 | 8 张（枫林古道、断碑坡、旧盐道、潮痕滩、赤砂商路、裂谷矿道、霜林栈道、冰隘） | 🟡 8/9 |
| 主题副本 | 4 个（碑窟、水闸、矿脉、界碑深处） | 3 个且均**单房**（失声碑窟、退潮水闸、裂谷矿脉） | 🔴 3/4，且结构不达标 |
| 主世界地图总数 | 15（3城+9野+4副本−重复） | 15 张（含渊口外环） | ✅ 数量达标 |
| 主线步骤 | 36 | **32**（s01–s32） | 🟡 32/36 |
| 支线 | 36 条 | **18** | 🔴 18/36 |
| 机制首领 | 8 场 | **6** | 🟡 6/8 |
| 可重玩委托模板 | 12 个 | **13 个**（`quests.json` v1，`daily_slots: 2`） | ✅ 超额 |
| 四幕结构 | I–IV 全通 | I–III 完整 + IV 前半 | 🔴 |
| 结局 | 有 | **无**（第四幕后半未做） | 🔴 |
| 等级上限 | 60，四幕分段 1-12/13-25/26-42/43-60 | 60，前三幕等级校准已完成（Lv12/25/42 实测达成） | ✅ |
| 存档版本 | 逐版迁移 v1→当前 | v6，迁移链 v1→…→v6 齐全 | ✅ |

---

## 2. 本次实机复跑结果（环境修正后）

命令：`--headless --path . res://tools/<case>.tscn`，`APPDATA` 显式导出。

```
TOTAL: 41  PASS=41  FAIL=0
```

41 项全部通过：VerifyAssets / VerifyBattleScene / VerifySave / VerifyUiLayout / VerifyVisualRefresh / VerifySweep / VerifyCity / VerifyGameHome / VerifyMapScene / VerifyMainWorld / VerifyWorldSession / VerifyStory / VerifyEconomy / VerifyTradeWorld / VerifySecondAct / VerifyThirdAct / VerifyThirdBack / VerifyFourthFront / VerifyThirdSide / VerifyCompanions / VerifyCampaignGrowth / VerifyCampaignGear / VerifyWorkshop / VerifyCurriculum / VerifyFrostArt / VerifyPortGrowth / VerifyShipping / VerifyFishing / VerifyRouteScene / VerifyGacha / VerifyPanels / VerifyGrowth / VerifyPerf / VerifyLore / VerifyQuests / VerifyAudio / VerifyTransit / VerifyDrops / VerifyArena / VerifyAvatar / VerifyNav

真实玩家存档哈希在校验前后一致：`BA8054B3D2F46D21D5CFE70E6EF5EFCADCC817A8267FF67FC7522379E2805BE7`。

> ⚠️ 注意用例数与历史记录不一致：文档记「45/45」「46/46」，当前 runner 用例表实为 **41** 项（`-Expected` 默认 46 会让 runner 拒绝执行，需注意）。用例数在中途被增删过，历史计数不可比。

---

## 3. 差异与问题清单（按优先级）

### P0 —— 阻塞"复刻完成"的硬缺口

| 编号 | 差异点 | 目标 | 当前 | 证据 |
|---|---|---|---|---|
| **G-01** | **结局与第四幕后半整体缺失** | s33–s36：界碑深处入口房/共鸣廊/碑心房、剧情首领「渊脉化身」、可选终局首领「无名巡界者」、两选项结局、结局后自由回访 | 全部未实现。`abyss_ring` **只有 1 个出口回 frost_pass**；全库无「界碑深处」地图（grep 为空）。**关键证据**：s32 是最后一步且 `next: ""`，但它发放 `stele_key`（入窟凭证）——这个凭证**无处可去**，是当前最直观的"断头"证据 | `data/story_quests.json`（32 步，s32 的 `next` 为空串）；`main_world_maps.json` abyss_ring 出口表 |
| **G-02** | **副本仍是单房，未做多房间+机关链** | 每副本"2–3 个房间／机关或敌群 → 机制首领"，碑窟/水闸/矿脉/界碑深处四座均如此 | 失声碑窟、退潮水闸、裂谷矿脉三图**实测数据**：`node_type: "boss"`、`monster_count: 1`、**`entities: {}`（零实体）**、**仅 1 个出口**——字面意义的"一间房一个 boss"，无机关、无前置敌群、无房间切换 | `main_world_maps.json` 三图实测 |
| **G-03** | **支线只完成一半** | 36 条（每区 2 关系 + 2 生态 + 1 商旅 + 1 精英/秘闻） | **18 条**（a1×6、a2×6、a3×6）。第四幕 0 条；且 a1/a2/a3 的 `live` 字段缺失（仅 `a1_elite_beast` 显式 `true`），开门条件靠代码硬判 | `data/side_quests.json` |
| **G-04** | **美术风格整体未达标（最深的差距）** | §9.1 要求先做 480×800 同屏样板，手机+同视口对照通过后再批量扩展 | 自认为"多批资源拼接"：主角/NPC/建筑/怪物比例与像素密度跳跃；地表仍是程序化长矩形与纯色多边形；UI 混用圆角卡片+软影（2026-10-02 起正在改切角+硬影）。**逐张重绘（R-08）连续多轮被显式延后，未交付** | `2026-10-01-reference-style-diagnosis.md`、`2026-09-28-ui-art-review.md`、R-08 |
| **G-05** | **无人工时长与安卓真机验收** | 四职业新档 30–45 分钟人工计时通关；目标安卓 480×800 触控、性能 ≥30fps | 只有自动化输入回放（自认"不证明人工时长"）；长屏用离屏 SubViewport 截图，**从未做过真机触控** | 各包"未完成"段一致登记 |

### P1 —— 显著偏离目标，影响成品完整性

| 编号 | 差异点 | 目标 | 当前 | 证据 |
|---|---|---|---|---|
| **G-06** | **守碑誓约系统完全缺失** | 三种契约（庇护/征伐/丰收），随地区事件升级，城镇切换付费 | 全仓无 `誓约/covenant/oath/pact` 任何引用 | grep 全库为空 |
| **G-07** | **阵营关系系统完全缺失** | III 幕两派 NPC 委托影响供应/台词/便利（不锁结局） | 全仓无 `faction/阵营` 引用；s28 的 `merchant/wardens` 选择只落一条世界旗，未扩展成阵营系统 | grep 全库为空 |
| **G-08** | **延期交割合约完全缺失** | III 幕开放，保证金+游戏内日结算+可复现价格+持仓上限 | 全仓无 `合约/contract/futures` 引用；只有现货与船运订单 | grep 全库为空 |
| **G-09** | **坐骑地形特性缺失，且 6 坐骑只有 1 只有骑乘图** | "升级收益拆成地图速度、**特定地形便利**和少量战斗准备收益"；III 幕六只坐骑完成四向表现 | ① `mounts.json` 的 tiers bonus 只有 `spd_pct/atk_pct/def_pct/maxhp_pct/crit_add`，**零地形参数**；② **美术实测：`image/mounts/` 只有 4 个文件**（`first_horse_{zs,ck,fs,fz}.png`，即"首骑"四职业各一张 2×2 四向图）；`bear/griffin/nightmare/sandlizard/woolyrhino` **各自 0 个骑乘图** | `data/mounts.json`；`ls image/mounts/`；`src/world/MountVisual.gd` |
| **G-10** | **骑乘四向为单帧静态、无走路动画** | 四向骑乘表现 + 窄路/进城自动下马 | `MountVisual.frames_for()` 每方向只 `add_frame` **一帧**（`set_animation_loop(false)`、`speed 1.0`）→ 是**静态贴图换向**，不是骑乘动画。窄路/进城自动下马已实现（`CityScene.gd:605`） | `src/world/MountVisual.gd:24-34` |
| **G-11** | **历练主题缺差异化视觉** | 每图"地貌识别点、可走路径、可记住的人、敌人/采集特色、至少一个世界事件" | 8 个历练主题（`maps.json` themes：forest/snow/volcano/tomb/desert/glacier/abyss/castle）全部复用同一张羊皮纸卷轴 + 相同节点排列，仅靠"主题染色"（`RouteScene.gd:82`）区分；V27 已登记"缺少差异化视觉" | `data/maps.json`；`src/run/RouteScene.gd:67-82`；V27 |
| **G-12** | **长屏/异形屏适配未验证** | 480×800 / 540×960 / 720×1600 截图矩阵 + 安全区断言 | 只有 480×800 与 480×1067（离屏）；V24 长屏灰底问题"待验证"；无真机 | V24、V28、UI 复查 |
| **G-13** | **背包/工坊信息架构未收敛** | "选一件 → 看差值 → 决定操作"单一操作线 | 三件物品时列表下方约 200px 空白；工坊把强化/宝石/精炼/余量拆成多块小字 | UI 复查 §P2 |
| **G-14** | **战斗信息层优先级未收敛** | 目标名/血紧贴实体、预兆只圈目标、施法名固定安全提示带 | 预兆/施法/宠物名/能量/操作面板靠近时叠读；V22 登记"战斗画面焦点偏散" | V22、V23 |
| **G-15** | **历练局不落档** | 进程被杀后该局可恢复 | `RouteScene.pending_run` 仍只在进程内；**P00 登记、P02/P03/P04 均未解决**，已跨 3 个包 | P00 基线 §3 表；各包"未完成"段 |

### P2 —— 影响完成度与观感，不阻塞主线

| 编号 | 差异点 | 说明 |
|---|---|---|
| **G-16** | 两项命名/结构设计差异未收口 | ① 总方案按幕 8 节点、实际第一幕 12 个稳定 ID（已在交接文档登记，UI 聚合方案未落地）；② 总方案称碑窟首领"碎碑守卫"，实际叫"失声碑灵"（已登记以现名为准，但总方案正文未更正，留下两个称呼） |
| **G-17** | 装备模板存量偏少 | 设计卡自认"当前装备模板仅 14 个"，**实测已扩到 30 个**（`equip.json` v2，含四职业 basic/wolf/iron/stele/tidegate 等系列）——数据已优于文档自述，但仍不足以支撑四幕换代；必经首领的逐幕固定职业保底首通验收仍在推进 | 
| **G-18** | 宠物养成维度偏薄 | 目标"等级 + 亲密/协战熟练 + 两项特性 + 一次进阶"；当前 9 只宠物（目标 8 只，已超），但只有 3 条 `companion_growth.traits`（护卫/追击/元素响应），特性系统仅 III 幕 `requires_story: s24` 后开放 |
| **G-19** | 图鉴仅宠物一类 | `codex.json` 只有宠物图鉴 4 个里程（2/4/6/8 只）；`CodexPanel.gd` 标题实为"宠 物 图 鉴"，一屏一只大卡轮播。**无怪物图鉴、无地理图鉴、无"可能来源"掉落展示**（grep `bestiary/怪物图鉴` 为空） |
| **G-20** | 图标语义未统一 | 营帐/货币/装备/召唤混用不同高光、描边、主体占比、分辨率的图标（V16） |
| **G-21** | 建筑落地阴影仍不理想 | V17 登记"建筑下大椭圆阴影突兀"，2026-10-02 已做"按原透明通道提取底座轮廓生成接触影"，但**雪地/草地逐张核对未完成** |
| **G-22** | 引擎退出资源诊断（issue #43）长期未解决 | 每次回归 76–77 条 `RID allocations were leaked at exit` 等；runner 已单独计数不判红，但从未修复 |
| **G-23** | 音频量偏少、无地区专属 BGM | `assets/audio/` 实测 **29 个文件**（6 首 BGM：battle/city/home/map/route/title + 22 个音效）。总方案要求"完整音画"、"定版 BGM"；当前 BGM 按"界面类型"而非"地区"划分，14 张主世界地图共享 `bgm_map`，无地区专属曲目与混音/音量分级验收证据 |
| **G-24** | 无发布包 | 总方案 §11.1 要求"安装包与操作说明"，S7 未启动 |

---

## 4. 与"原版"（《笑傲江湖》）的对标差异

原版结构基准来自 `docs/原版玩法全景.md`（xaqd.mrp 拆包 + 3 段实机录屏 + 3 次抓包）。总方案 §0.4 明确"只借鉴经观察确认的结构，不照搬原作内容"，故以下为**有意的设计偏离**，需确认是"刻意取舍"而非"遗漏"：

| 原版特征 | 复刻决策 | 当前状态 | 判定 |
|---|---|---|---|
| 240×320 竖屏像素 | 480×800（资源 2x nearest） | 已落地 | ✅ 有意偏离，已确认 |
| 三职业×男女 6 形态 | 四职业（破军/穿杨/霜语/晨星） | 已落地 | ✅ 有意偏离 |
| 实时动作战斗 + 地图明雷 | 保留远征实时 sim，对齐表现层 | 已落地（遭遇战横幅/目标名条/脚下血蓝条/飘字+技能名） | ✅ |
| 6 地图 + 出口转接 + 小地图 | 自研格子地图，保留 6 地图节奏 | 15 张自研图 + 地区图 + 小地图出口菱 | ✅ |
| 14 NPC + 具名 NPC | 对齐，命名走数据配置 | `city.json` 7 NPC + 港口 4 + 霜关 3 | 🟡 数量偏少 |
| 6 坐骑 × 12 骑姿叠合渲染 | 保留"骑姿+本体"叠合结构 | 6 坐骑有；骑姿四向完整性未验收 | 🟡 |
| 宠物四档特效 | 4 宠物 + 品阶档 | 9 宠物 | ✅ 超额 |
| 商城（话费/支付宝/微信） | 换皮"江湖寻访"抽卡（本地货币） | `gacha.json` 1 池 | ✅ 有意偏离 |
| 多服务器/排行榜 | 单服起步，排行榜后置 | `arena.json` 5 段位 | ✅ 有意偏离 |
| 洛林国/枫林村/月影/毒矛剧情线 | 全套重写为昭元/界碑/渊叙事 | 32 步主线已落地 | ✅ 有意偏离 |
| 状态效果三阶中毒（`pk/poison/1/2/3`） | — | **已实现且超出**：`Combatant.gd` 支持 `bleed/poison/stun/fear/confusion/slow/def_break/atk_down` 八种 buff，毒带 `stack: 3` 叠层；`monsters.json` 有多种怪 `on_hit` 附毒 | ✅ 已覆盖（原"疑似遗漏"标记**撤销**） |
| NPC 头顶红色菱形任务标记 + 指引箭头 | — | 有支线蓝签/主线金菱，颜色与形状与原版不同 | 🟡 有意偏离？需确认 |
| 名称标签配色：NPC 绿 / 怪物紫「Lv{n}名」 | 对齐 | 怪物紫名 ✅、NPC 名签 ✅ | ✅ |
| 顶部「遭遇战」横幅 | 对齐 | 已落地 | ✅ |

---

## 5. 文档自身的偏差（需更正）

| 编号 | 问题 |
|---|---|
| **D-01** | 历轮文档把 `VerifyStory` 18 条 / `VerifySave` 1 条记为"既有未定位失败"，并作为**基线**逐轮复制（"与上轮逐条一致，新增 0 条"）。本次证实为 `APPDATA` 未设置导致的 `user://` 相对路径问题，属**环境假象**。 |
| **D-02** | 用例总数记录混乱：文中出现 28 / 29 / 31 / 32 / 35 / 37 / 40 / 41 / 43 / 44 / 45 / 46 等多种说法。当前 runner 用例表实为 **41** 项，默认 `-Expected 46` 与用例表不符（会直接 FATAL 退出）。 |
| **D-03** | P01「视觉样板已完成」的表述已被后续文档收紧为「布局与可用性规范已落地，美术风格仍未验收」，但更早文档仍在流通，易被误读为美术已达标。 |
| **D-04** | 总方案正文未同步"失声碑灵"更名与"第一幕 12 步 vs 8 节点"两项已登记的设计差异。 |
| **D-05** | 玩家存档哈希迭代：文中出现 `C5D29EE5…`（早期）与 `BA8054B3…`（P09-A 起）两个值；实测当前为 `BA8054B3…`。 |
| **D-06** | 设计卡自述"装备模板仅 14 个"，实测已 **30 个**；`2026-10-01-p08-campaign-growth.md` 等文档的资源口径已过期，会导致后续排期基于错误基数。 |
| **D-07** | 大量"未完成项"只写结论不写证据 ID。例如"支线 18/36"没有说明是哪 18 条 `live`、哪些被硬编码开门（`a1_elite_beast` 显式 `live: true`，其余 17 条 `live` 字段为 `null` 靠代码判定）。复核成本高。 |

---

## 6. 优先级建议（按"影响复刻完成度"排序）

**第一优先（决定能否宣告完成）**
1. G-01 第四幕后半 + 结局（s33–s36、界碑深处三房、两首领）——当前唯一"剧情上不能通关"的缺口
2. G-04 美术风格统一样板（先冻结边城同屏样板，再批量替换）——用户已明确反馈"画风严重偏离参考"
3. G-02 四副本多房间 + 机关链
4. G-05 人工时长 + 安卓真机验收

**第二优先（成体系但缺失）**
5. G-03 补足支线至 36 条（第四幕 6 条 + 前幕补齐）
6. G-06 守碑誓约
7. G-07 阵营关系 / G-08 延期合约
8. G-09 坐骑地形特性 / G-10 骑乘四向
9. G-15 历练局落档

**第三优先（打磨）**
10. G-11 ~ G-14 视觉/信息架构收敛
11. G-16 ~ G-24 命名收口、模板扩充、图鉴维度、图标统一、issue #43、发布包

**文档维护**
12. D-01/D-02 更正失败归因与用例计数；在 `run_regression.ps1` 里加 `APPDATA` 兜底或在使用说明中强制声明。

---

## 7. 复现命令

```bash
cd "D:/new bee/远征"
export APPDATA="C:/Users/Administrator/AppData/Roaming"   # 关键：否则 user:// 变相对路径
GODOT="C:/Users/Administrator/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless --path . res://tools/VerifyStory.tscn
"$GODOT" --headless --path . res://tools/VerifySave.tscn
```

完整回归（PowerShell 会话内需先 `$env:APPDATA`）：`tools/run_regression.ps1 -Expected 41`

---

## 附录 A：第二轮逐项实证（2026-10-02 复核）

本节列出**亲自跑命令/读数据**得到的硬证据，用于区分"文档自述"与"当前事实"。

### A.1 系统缺失（grep 全库为空）

```
grep -rn "誓约|covenant|oath|faction|阵营|合约|contract" --include=*.gd --include=*.json --include=*.tscn .
→ 仅命中 shots/*/acceptance.json 里"未完成"自述文本，源码与数据表零命中
```
确认 G-06 守碑誓约、G-07 阵营、G-08 延期合约 **完全未实现**。

### A.2 副本房间结构（实测三图）

| 图 | `node_type` | `monster_count` | `entities` | 出口数 |
|---|---|---|---|---|
| `stele_cavern` 失声碑窟 | boss | 1 | `{}` | 1 |
| `tidal_gate` 退潮水闸 | boss | 1 | `{}` | 1 |
| `rift_mine_vault` 裂谷矿脉 | boss | 1 | `{}` | 1 |

→ 确认 G-02。

### A.3 坐骑美术（`ls image/mounts/`）

```
first_horse_ck.png  first_horse_fs.png  first_horse_fz.png  first_horse_zs.png
```
**只有 4 个文件**。6 坐骑中仅"首骑"（horse）有四职业四向图；`bear/griffin/nightmare/sandlizard/woolyrhino` 各 0 个。且 `MountVisual.frames_for()` 每方向只加 1 帧 → 静态换向，非动画。→ 确认 G-09/G-10。

### A.4 主线"断头"（s32 凭证无处可去）

```
s32 旧卷新页 ... "next": "", reward: {item: "stele_key"}
grep -rn "界碑深处|deep_stele|stele_deep" data/ src/ → 仅一处 goal 文案
```
`s32` 是最后一步，发放 `stele_key`（入窟凭证）却无对应副本。→ 确认 G-01。

### A.5 视觉证据（实机截图）

- `shots/all_scenes_20261001/mw_rift_mine_road.png`（裂谷矿道）：路面为**大块纯色矩形**、地面光斑为**正圆**、建筑/树木为**硬边椭圆阴影**——肉眼可辨的"程序几何"外观，正是 `2026-10-01-reference-style-diagnosis.md` 所述根因。
- `shots/all_scenes_20261001/_overview_2_city.png`（城镇总览）：同一批截图内 UI 风格与地图层仍有明显层级断裂。→ 佐证 G-04。

### A.6 已收敛/优于文档自述的项目

| 项 | 事实 |
|---|---|
| 字号规范 | `src/ui/*.gd` 硬编码字号扫描**零命中**；地图名签全部走 `G.FS_SM/FS_XS` → 已完全收敛 |
| 状态效果 | poison 等 **8 种 buff** 已实现，毒带 3 层叠层 → 原"疑似遗漏"**撤销** |
| 委托模板 | **13 个**（目标 12）→ 已超额 |
| 装备模板 | **30 个**（设计卡自述 14 个）→ 已扩量，但文档未同步 |
| 音频 | **29 个文件**（6 BGM + 22 SFX），非"占位无音" |
| 宠物数 | 9 只（目标 8）→ 已超额 |
| 存档迁移 | v1→…→v6 链齐全，`validate()` 含 v5 深校验 |

