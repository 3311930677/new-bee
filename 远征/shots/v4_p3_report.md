# V4 P3 阶段验收报告（二级养成、玩法、社交与商业化页面重构）

## 1. 阶段目标与范围
按照 [`docs/2026-10-28-商业化画面重构方案.md`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/docs/2026-10-28-%E5%95%86%E4%B8%9A%E5%8C%96%E7%94%BB%E9%9D%A2%E9%87%8D%E6%9E%84%E6%96%B9%E6%A1%88.md) §4.6–4.7、§4.10–4.21、§4.25–4.28 及第 6 节 P3 要求，完成全部二级功能面板与弹窗的商业化升级。

## 2. 二级页面重构清单

| 页面标识 | 对应规范章节 | 关键重构内容 | 审计截图 |
|---|---|---|---|
| `s02c_dungeon_select` | §4.27 副本选择 | 横幅式副本入口卡 (`220px`)，右侧嵌入 `E-01` 4 主题油画切片与渐隐遮罩，左下展示核心掉落与钥匙消耗 | [`s02c_dungeon_select.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s02c_dungeon_select.png) |
| `s04_role_stats` | §4.6 角色属性 | 顶部英雄概要与战力铭牌，中部六维雷达图 + 6 大核心指标网格，下部可折叠详细词条手风琴 | [`s04_role_stats.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s04_role_stats.png) |
| `s05_skills` | §4.7 技能流派 | 上半屏环形主动技能槽 (`D-02`) + 被动槽，中部流派连携发光线，底部固定技能详情与一键装配栏 | [`s05_skills.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s05_skills.png) |
| `s07_shop_sundries` | §4.9 营地商店 | 顶部 240px 店主迎宾横幅 (`B-06`)，中部 `3x3` 漆木货架商品卡 + 限购角标 + 底部价格购买条 | [`s07_shop_sundries.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s07_shop_sundries.png) |
| `s10_forge_enhance` | §4.10 铁匠铺 | 上半屏 `B-05` 铁砧火炉熔铸舞台 + 材料环绕槽，下半屏强化对比条/词条锁定洗练列表与保底进度条 | [`s10_forge_enhance.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s10_forge_enhance.png) |
| `s11_companion` / `s26_mount` | §4.11 同伴与坐骑 | 取消左侧竖列，采用顶部星级铭牌 + 中部 `620px` 全身立绘舞台 (`C-04..C-05`) + 横向圆角头像切换栏 | [`s11_companion.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s11_companion.png) / [`s26_mount.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s26_mount.png) |
| `s12_boss_challenge` | §4.12 首领挑战 | 上半屏 `520px` 首领半身立绘压迫舞台 (`C-06..C-08`) + 机制词缀芯片，下半屏掉落预览与首领横向切换 | [`s12_boss_challenge.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s12_boss_challenge.png) |
| `s13_arena_hall` | §4.14 竞技场 | 顶部段位徽章 (`E-04`) 与赛季倒计时，中部 3 名对手全身立绘台座 (`E-05`)，底部固定自身段位条 | [`s13_arena_hall.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s13_arena_hall.png) |
| `s14_bounty` | §4.13 悬赏榜 | 木质告示栏 + 双列做旧羊皮纸通缉令 (`E-02`) + 铜钉与朱砂「已揭榜」印章 (`E-03`) | [`s14_bounty.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s14_bounty.png) |
| `s15_idle_expedition` | §4.15 远征挂机 | 顶部 `360px` 动态营火远征队插画 (`B-07`) + 满溢宝箱 (`E-06`) + 每小时效率芯片与快速挂机双按钮 | [`s15_idle_expedition.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s15_idle_expedition.png) |
| `s16_collection` | §4.16 博物志 | 顶部收集率金色进度条與属性总览，中部 `4列` 180x220 精致图鉴卡 + 未解锁剪影遮罩 (`E-07`) | [`s16_collection.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s16_collection.png) |
| `s17_activity` / `s18_achievement` / `s19_pass_daily` | §4.17 活动/成就/战令 | 顶部 `260px` 庆典主题插画横幅 (`B-08`)；战令采用左等级轴 + 普通/进阶双轨对照 + 底部常驻一键领取 | [`s17_activity.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s17_activity.png) / [`s19_pass_daily.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s19_pass_daily.png) |
| `s21_guild` / `s22_rank` | §4.20–4.21 公会与排行 | 公会大厅插画 (`B-10`) + 旗帜纹章 (`E-10`) + 4 宫格建筑功能卡；排行榜前三名金银铜领奖台 (`E-11`) | [`s21_guild.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s21_guild.png) / [`s22_rank.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s22_rank.png) |
| `s23_settings` | §4.25 设置弹窗 | 分组卡片式布局（画面与帧率 / 音频控制 / 账号与兑换码），自定义铜金滑块与开关 (`A-13..A-15`) | [`s23_settings.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s23_settings.png) |
| `s24_codex` / `s25_alchemy` | §4.18–4.19 秘闻录与炼金台 | 秘闻录对开古籍书页 (`E-08..E-09`)；炼金台左侧折叠配方树 + 右侧 `B-09` 炼金坩埚阵列 (`E-18`) | [`s24_codex.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s24_codex.png) / [`s25_alchemy.png`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/s25_alchemy.png) |

## 3. 验证与对比产物
- 视觉审计截图 (`141 steps`)：[`shots/v4_p3/audit/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/audit/)
- 多分辨率响应式审计 (`132 shots, overruns=0`)：[`shots/v4_p3/responsive/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/responsive/)
- Before | After 对比图（19 张）：[`shots/v4_p3/comparisons/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p3/comparisons/)
