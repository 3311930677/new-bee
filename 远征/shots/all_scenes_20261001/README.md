# 全量场景截图 · 2026-10-01

游戏内**所有用户可见界面 / 场景**的统一截图集，共 **256 张**：

- `*.png`（本目录）—— **206 张 480×800**，项目基准分辨率（竖屏）
- `long_480x1067/*.png` —— **50 张 480×1067**，长屏逻辑视口（对应 720×1600 的宽度归一化比例）

## 怎么重跑

```bash
cd 远征
bash shots/all_scenes_20261001/_batch.sh    # 第一批：不依赖存档的 160 个用例（480×800）
bash shots/all_scenes_20261001/_batch2.sh   # 第二批：依赖通关存档的 18 个用例（480×800）
bash shots/all_scenes_20261001/_batch3.sh   # 第三批：依赖存档的 28 个站位／构图变体（480×800）
bash shots/all_scenes_20261001/_batch4.sh   # 第四批：50 个长屏逻辑视口用例（480×1067）
python shots/all_scenes_20261001/_overview.py  # 重新拼 6 张分类总览
```

逐项结果写在 `_run.log`（`OK <名字>` / `FAIL <名字> :: <原因>`）。

## 分类总览（先看这 6 张）

| 文件 | 内容 | 张数 |
| --- | --- | --- |
| `_overview_1_ui.png` | 启动流程 + 主界面 + 养成 + 工坊 | 36 |
| `_overview_2_city.png` | 城内常态与全部浮层面板 + 伙伴协同 | 27 |
| `_overview_3_world.png` | 14 张主世界地图 + 8 主题秘境路线 + 世界内玩法 | 58 |
| `_overview_4_acts.png` | 战斗（含 7 主题背景）+ 剧情演出 + 第一/二/三幕 | 57 |
| `_overview_5_staging.png` | 城内三区 × 左中右站位 + 霜关各点 + 地形快照 + 风格基线 | 28 |
| `_overview_6_long.png` | 长屏 480×1067 逻辑视口（HUD 贴底 / 战斗下移 / 浮层居中） | 50 |

## 覆盖口径

**启动与流程（8）**：`load` 加载页、`title` 标题、`title_settings`、`login` 登录、`namerecover` 补全姓名、`prologue` 序章、`createrole` 创角、`home` 主界面。

**主界面与浮层（27）**：`avatar` 换头像、`deploy` / `deploy_role` / `deploy_pet` 出征筹备三页、`worlds` 世界、`codex` 图鉴、`arena` 演武场、`gacha` 抽卡、`exchange` 兑换、`settings` / `settings2` 设置两页、`growth` 养成总览、`bag` / `bag_full` 背包两态、`quests` 任务、`gm` / `gm_open` 开发者控制台两态、养成子页 `talent` / `equip` / `pet_raise` / `skillbook` / `mount` / `titles`、工坊 `forge_enhance` / `forge_gem` / `forge_refine` / `workshop_low` / `workshop_progress`。

**城内（20）**：`city` 常态、`city_repair` 修碑、`city_built` / `city_all` / `city_mix` 三种落成度、`city_shop` 物资铺、`city_notice` 布告栏、`city_guests` 访客簿、`city_build_panel` 工地详情、`city_built_panel` 落成经营、`city_frost_choice` 双关定路、`city_tide_choice` 回港定路、`city_deploy` 出征、`port_services` 港务人、`side_city_accept` NPC 接支线、`beast_notice` 悬赏行、`mentor_choice` 导师分支、`order_preview` 现货市集、`trade_warden_dialog`、`mount_claim` 领马、`pet_claim` 结缘。

**主世界 14 张地图**：`mw_lorin_wilds` / `mw_maple_road` / `mw_broken_slope` / `mw_old_salt_road` / `mw_shenyuan_port` / `mw_tideflat` / `mw_tidal_gate` / `mw_stele_cavern` / `mw_red_sand_route` / `mw_frost_post` / `mw_rift_mine_road` / `mw_rift_mine_vault` / `mw_frost_pass` / `mw_frost_boardwalk`。

**随机秘境与路线（10）**：`route_<theme>` 八主题各一张（苍绿林海 / 凛风雪原 / 焚天火山 / 幽暗古墓 / 流沙荒漠 / 千年冰川 / 无底深渊 / 王城遗迹），另有 `map` / `map_boss`。

**世界内玩法与支线（10）**：`main_world` / `mentor_world` / `chapter_archive` / `chapter_gate` / `waystone_world` / `beast_world` / `side_world_chime` / `side_world_tracks` / `trade_slope_world` / `trade_slope_panel`。

**战斗（22）**：`battle` / `battle_cast` 施法 / `battle_low` 低血警示、`battlebg_<theme>` 七主题背景、主世界战斗四态（`main_world_battle` / `_commands` / `_skills` / `_projectile`）+ `main_world_pet_guard`、首领机制 `beast_windup` 预兆 / `beast_break` 破绽、`picker` / `picker_school` 词条选择。

**剧情与幕（35）**：`story_intro` / `story_outro` 演出、第一幕四职业蓝武器 `act1_blue_weapon_<zs|ck|fs|fz>`、第二幕 18 张（盐路 / 港 / 潮闸 / 蟹 / 四条支线）、第三幕 18 张（矿道 / 栈道 / 关口 / 破绽 / 定路 / 市集）、第三幕支线纵切 8 张。

**伙伴协同（9）**：`companion_locked` / `_first` / `_second` / `_help` 面板四态、`companion_world` / `_lodge` 世界、`companion_guard` / `_pursuit` / `_resonance` 战斗特效。

**战利品与补记（6）**：`gear_pending` / `gear_preview` / `gear_detail`、`campaign_catchup` / `campaign_mine` / `campaign_return`。

**站位与构图变体（28）**：
- 城内三区 × 左中右：`town_north` / `town_north_left` / `town_north_right`、`town_middle` 三向、`town_south` 三向（共 9）。
- 霜关各点：`frost_art_north` 三向、`frost_art_south` 三向、`frost_art_coal` / `frost_art_shield`（火盆抉择后）、`frost_art_envoy` / `frost_art_guard` / `frost_art_miner`（三名 NPC 对话中）。
- 地形快照：`terrain_port` / `terrain_port_south` / `terrain_frost` / `terrain_frost_south`。
- 风格基线：`style_city` / `style_battle` / `style_forge` / `style_bag`。

**长屏逻辑视口 480×1067（50，见 `long_480x1067/`）**：只拍「竖屏拉伸会改变布局」的场景 —— 14 张主世界地图（摇杆/药伴/疾行/营帐贴底、小地图贴右上）、城内 5 张、战斗 6 张（人物与指令页／技能页下移）、秘境路线与地区图 3 张、长屏里需居中的浮层 22 张。纯静态面板在 480×800 已能验收，未重复。

## 本次为出图新增的截图用例

`tools/ShotRunner.gd` 增补（纯增量，不改动原有分支）：

- `mw_<地图id>` —— 主世界地图直拍，14 张地图全覆盖（原先只能靠 `terrain_*` 拍 3 张，且必须喂存档）。
- `route_<主题>` —— 随机秘境八主题路线图。
- `battlebg_<主题>` —— 七主题战斗背景。
- `city_shop` / `city_notice` / `city_guests` / `city_build_panel` / `city_built_panel` / `city_frost_choice` / `city_tide_choice` / `port_services` —— 城内此前没有出图入口的浮层面板。
- `namerecover` —— 补全姓名页。
- `load` 用例改为 `auto_advance = false`：加载页满 1s 会自动切标题，原先截帧前节点已被释放（`data.tree is null`），现在能稳定停在页面上。

## 顺带修掉的一处 UI 缺陷

`src/ui/NameRecovery.gd` 的说明文案原先单行溢出面板右缘（截图 `namerecover.png` 可见）。根因是**赋值顺序**，不是文案长度：

- `Control.size` 会被夹到 `get_combined_minimum_size()`，而 `Label` 的最小尺寸是**懒重算**的；
- autowrap 关闭时最小宽度 = 整行文字宽（此处 448），且 `set_autowrap_mode()` 只是排队重算 —— 同一帧内设 `size = 356` 仍按旧的 448 夹取；
- autowrap 打开后最小**高度**又按「每字一行」算（约 780），需要 `max_lines_visible` 限成两行才会回到 51。

修法：`autowrap_mode` → `max_lines_visible = 2` → `mouse_filter = IGNORE` → `add_child` → 最后才 `size = Vector2(356, 50)`（入树会触发最小尺寸重算）。修复后 `size=(356, 51)`、两行，与面板预留高度一致。

回归：`VerifyPanels` / `VerifyUiLayout` / `VerifyPerf` 用 `HEAD` 版本与修复版本各跑一次，失败数完全相同（`fails=5` / `fails=2` / `fails=1`），即这 3 项**改动前就红**，与本次修复无关；`VerifyGameHome`、`VerifyTransit` 通过。

> 同类写法还有 4 处（`MountPanel:139`、`SettingsPanel:126/163`、`TraitPicker:133`），当前因为文本短或赋值时文本为空而侥幸正常，未改动，建议后续统一成「先入树、后设 size」或改用容器约束宽度。

## 说明与已知项

- 截图工具已把存档重定向到 `res://tools/_logs/`，**不会动真实存档**。
- 第二、三批用例喂的是 `tools/_logs/curriculum_accept_zs_fs/save_playthrough_zs_a.json`（真实通关档），面板与城内建筑才有内容。
- `namerecover` 文案溢出已修（见上节），本目录里是修复后的图。
- 长屏图用 `OffscreenShotRunner` + `--size=480x1067` 渲染到独立 SubViewport；裸离屏视口绕过项目窗口缩放，**不能当作真机成品图**，真机仍需按 540×960 / 720×1600 物理像素最终验收。
- `tools/preview/WalkSpritePreview.tscn` 是开发用行走图预览工具，非玩家可见，未出图。
