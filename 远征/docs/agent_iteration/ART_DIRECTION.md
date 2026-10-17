# 《远征》视觉风格与商业像素美术规范（ART_DIRECTION）

## 一、核心视觉定调
- **艺术风格**：商业级暗金羊皮纸奇幻像素风（Dark-Gold Parchment & Crisp Pixel RPG）。
- **画布与采样规范**：
  - 基准视口：`480×800`（竖屏 3:5），兼容长屏 `480×1067`（竖屏 9:20）。
  - 纹理过滤：全局 `default_texture_filter = 0`（Nearest 最近邻像素采样），严禁模糊双线性插值破坏像素边缘。
- **色彩体系**：
  - **深邃底板**：`#16121A`（夜幕玄铁）、`#211B24`（古碑深褐）
  - **羊皮纸面板**：`#EEDFC3`（暖羊皮卷底）、`#DFC9A3`（次级内衬）、`#5A3E28`（深木框描边）
  - **商业级视觉焦点色**：`#F4C04E`（鎏金高亮/主CTA）、`#D9534F`（朱砂战意/危险）、`#3FA76C`（翠玉完成/增益）、`#4DA6FF`（星辉法力/稀有）
  - **文本对比度**：深底浅字使用 `#FAF3E3` / `#E5D2B0`；羊皮纸浅底深字使用 `#2A1B10` / `#523A24`，确保小屏阅读清晰锐利。

## 二、字体与排版铁律（自动化门禁强制约束）
- 严禁在 `res://src/`（除 `src/preview/` 外）使用任何字面量数字调用 `add_theme_font_size_override("font_size", <数字>)`。
- 必须且只能使用 `G.gd` 定义的六级字号常量：
  - `G.FS_XS` (15px)：辅助角标、次要属性说明
  - `G.FS_SM` (17px)：正文、对话、常规按钮、列表项
  - `G.FS_MD` (18px)：小标题、重点标签、导航按钮
  - `G.FS_LG` (24px)：面板主标题、章节名
  - `G.FS_BIG` (28px)：核心大按钮（如「出征」）、结算大标题
  - `G.FS_HERO` (56px)：主标题/大徽章数字
- **触控热区规范**：所有 `GameHome` 与子面板主操作按钮（`Field.Action`、`ChestUI.ChestButton`）的最小高度 `size.y >= 44px`，完全容纳在 `Rect2(0, 0, 480, H)` 视口安全区内。

## 三、角色精灵与接地规范
- 四大职业统一采用 `128×128` 标准单帧画布（4 帧待机 `512×128`，四方向行走 `512×512`）。
- 角色在野外地图（`MapScene`）、主城（`CityScene`）与主页舞台（`TownHome`）均配备脚底像素接触阴影（外层柔和椭圆 + 内层深色核心），并在移动时随步态相位（`_bob_time`）同步微调精灵重心与阴影呼吸缩放，确保脚底基线与地面砖石/草地严丝合缝。

## 四、视觉参考图板（`docs/agent_iteration/references/`）
1. `docs/agent_iteration/references/ref_role_select_concepts.png`：四角色名册选角页与主页舞台四职业（破军/穿杨/霜语/晨星）实时切换视觉方案图板。
2. `docs/agent_iteration/references/ref_world_map_hud_concepts.png`：世界行路图驿车直达、路牌任务方向指引、行囊信使速交与 11 步剧情式新手引导视觉对比图板。
3. `docs/agent_iteration/references/ref_archery_curio_concepts.png`：第四阶段五轮实质性玩法扩充（校场射艺靶场、史诗神兵与动态战力评估、古碑共鸣与行商奇珍鉴宝、灵宠五阶羁绊）视觉总览图板。
