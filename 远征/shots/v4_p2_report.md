# V4 P2 阶段验收报告（核心主循环 10 屏重构）

## 1. 阶段目标与范围
按照 [`docs/2026-10-28-商业化画面重构方案.md`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/docs/2026-10-28-%E5%95%86%E4%B8%9A%E5%8C%96%E7%94%BB%E9%9D%A2%E9%87%8D%E6%9E%84%E6%96%B9%E6%A1%88.md) 第 4.1–4.6、4.9、4.22、4.23 节及第 6 节 P2 要求，完成核心主循环 10 屏的商业化重构。

## 2. 10 屏重构明细

| 页面标识 | 对应规范章节 | 关键重构内容 | 审计截图 |
|---|---|---|---|
| `s00_first_launch_create` | §4.1 创角页 | 接入 `B-01` 篝火远征山谷原画、`C-01..C-03` 三职业全身立绘、`D-01` 职业纹章与六维倾向条，底部搭载 `btn_create_enter` 巨型铸铁金框按钮 | [`s00_first_launch_create.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s00_first_launch_create.png) |
| `s01_home_full` | §4.2 主界面 | 顶栏 3 芯片 + 中央营地舞台 + 英雄立绘 + 章节推进大按钮 + 右侧折叠/展开 `3x3` 毛玻璃入口网格 | [`s01_home_full.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s01_home_full.png) |
| `s02_world_hub_map` | §4.3 世界地图 | 全屏铺满 `B-03` 四幕彩绘大舆图，叠加 4 座可点击立体建筑地标节点与底部紧凑章节抽屉 | [`s02_world_hub_map.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s02_world_hub_map.png) |
| `s02b_chapter_route` | §4.4 章节路线 | 接入 `B-04` 羊皮纸路线底图 + 发光推进虚线 + 5 态节点图标（已完成/当前闪烁/未解锁/精英首领/秘境） | [`s02b_chapter_route.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s02b_chapter_route.png) |
| `s03_bag_equip` | §4.5 背包与装备 | 上半屏 `6+立绘+6` 装备检视舞台，下半屏 `5x4` 96px 品质发光槽位 + 底部浮动对比操作抽屉 | [`s03_bag_equip.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s03_bag_equip.png) |
| `s06_task_chapter` | §4.8 章节任务 | 顶部 180px 章节卷轴插画 + 里程碑宝箱进度条 + 128px 标准任务行卡（左章、中进度、右领奖） | [`s06_task_chapter.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s06_task_chapter.png) |
| `s08_mail` | §4.22 邮件 | 信封状态图标 (`D-11`) + 附件道具预览格 + 空信箱信鸦插画 (`E-12`) + 底栏一键已读/一键领取 | [`s08_mail.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s08_mail.png) |
| `s09_map_broken_slope` | §4.23 探索 HUD | 顶部 72px 极简横条 + 左上紧凑任务追踪胶囊 + 左下 180px 半透明摇杆 + 右下扇形动作键与折叠抽屉 | [`s09_map_broken_slope.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s09_map_broken_slope.png) |
| `s09b_map_hud_expanded` | §4.23 探索菜单 | 右侧探索菜单抽屉采用 `2列x4行` 72px 圆角图标网格，半透明模糊黑金底板不遮挡角色视野 | [`s09b_map_hud_expanded.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s09b_map_hud_expanded.png) |
| `s09e_map_battle_settlement` | §4.9 战斗结算 | 胜利剑盾绶带徽章 (`E-15`) + 星级评价 (`E-16`) + 战利品发光展示格 + 伤害/承伤/治疗三色统计条 | [`s09e_map_battle_settlement.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/s09e_map_battle_settlement.png) |

## 3. 验证与对比产物
- 视觉审计截图 (`141 steps`)：[`shots/v4_p2/audit/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/audit/)
- 多分辨率响应式审计 (`132 shots, overruns=0`)：[`shots/v4_p2/responsive/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/responsive/)
- Before | After 对比图（10 张）：[`shots/v4_p2/comparisons/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p2/comparisons/)
