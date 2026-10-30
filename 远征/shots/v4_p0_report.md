# V4 P0 阶段验收报告（D1–D19 阻塞级缺陷清零）

## 1. 阶段目标与范围
按照 [`docs/2026-10-28-商业化画面重构方案.md`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/docs/2026-10-28-%E5%95%86%E4%B8%9A%E5%8C%96%E7%94%BB%E9%9D%A2%E9%87%8D%E6%9E%84%E6%96%B9%E6%A1%88.md) 第 2 节要求，在不改变底层数值/存档兼容性的前提下，优先修复 D1–D19 共 19 项阻塞级视觉与排版缺陷。

## 2. D1–D19 逐项修复清单

| 编号 | 缺陷描述 | 修复文件与实现摘要 | 状态 |
|---|---|---|---|
| **D1** | 创角页标题字号过小、缺少立绘与职业纹章舞台 | 重构 [`CharacterSelect.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/CharacterSelect.gd)，标题提升至 42px 金色描边，接入三职业全身立绘与雷达图预览舞台 | 已完成 |
| **D2** | 主界面中央 35% 留空、顶部通货芯片拥挤、右侧展开抽屉遮挡底栏 | 重构 [`GameHome.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GameHome.gd)，顶栏收敛为 3 核心芯片，中央接入营地主视觉 + 英雄立绘舞台，右侧采用 `3x3` 轻量毛玻璃网格 (`y=460..760`) | 已完成 |
| **D3** | 世界枢纽地图缩略图仅占半屏且底部说明卡留白 | 重构 [`GameHome.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GameHome.gd) 世界分页，全屏铺满手绘舆图 (`y=82..1492`) + 4 幕悬浮建筑节点 + 底部紧凑详情抽屉 | 已完成 |
| **D4** | 背包页 12 槽位分列导致中央立绘缩成火柴人 | 重构 [`GameHome.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GameHome.gd) 背包页，采用左 6 (`84x84`) + 中央 `280x360` 英雄舞台 + 右 6 (`84x84`) 经典 RPG 布局 | 已完成 |
| **D5** | 背包详情与下装网格相互挤压 | 背包网格固定 `5列x4行` (`96x96`)，选中装备弹出底部浮动对比抽屉，不再挤压网格高度 | 已完成 |
| **D6** | 角色详情页雷达图缺失、词条纯文本堆砌 | 重构 [`GameHome.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GameHome.gd) 角色属性页，新增六维属性雷达图与分组折叠手风琴 | 已完成 |
| **D7** | 技能页槽位与长文案重叠、连携关系不直观 | 重构 [`SkillPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/SkillPanel.gd)，上半屏环形主动槽 + 被动槽，中部流派连携发光节点线，底部独立详情卡 | 已完成 |
| **D8** | 章节任务页顶部留白、章节奖励散落 | 重构 [`TaskPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/TaskPanel.gd)，引入章节横幅插画 + 里程碑宝箱进度条 + 128px 标准任务行卡 | 已完成 |
| **D9** | 商店页列表式行卡缺少货架感、限购角标缺失 | 重构 [`ShopPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/ShopPanel.gd)，改为 240px 店主迎宾横幅 + `3列x3行` 漆木货架商品卡 + 限购丝带角标 | 已完成 |
| **D10** | 铁匠铺五合一标签页上下割裂 | 重构 [`ForgePanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/ForgePanel.gd)，上半屏统一铁砧火炉熔铸舞台，下半屏联动材料槽与词条锁定面板 | 已完成 |
| **D11** | 同伴/坐骑页左侧列表挤压立绘展示空间 | 重构 [`GrowthPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GrowthPanel.gd)，取消左侧竖列，改为顶部/中部大舞台立绘 + 横向头像切换条 | 已完成 |
| **D12** | 首领挑战页全屏列表无 Boss 压迫感 | 重构 [`ChallengeHubPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/ChallengeHubPanel.gd)，上半屏 520px 首领半身立绘压迫舞台 + 机制词缀芯片，下半屏紧凑切换 | 已完成 |
| **D13** | 悬赏榜深色行卡缺乏羊皮纸告示感 | 重构 [`ChallengeHubPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/ChallengeHubPanel.gd) 悬赏分页，采用木质告示栏 + 双列做旧羊皮纸通缉令 + 朱砂「已揭榜」印章 | 已完成 |
| **D14** | 竞技场自身排名与挑战对手卡片无区分 | 重构 [`ArenaPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/ArenaPanel.gd)，新增段位徽章横幅 + 三名对手全身立绘台座 + 底部固定自身段位条 | 已完成 |
| **D15** | 远征挂机页纯文字计时器缺少视觉反馈 | 重构 [`IdlePanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/IdlePanel.gd)，顶部动态营火挂机插画 + 满溢宝箱动效 + 4 格战利品预览 | 已完成 |
| **D16** | 图鉴/秘闻录/炼金台/公会/排行/设置/邮件空状态与溢出 | 全面升级 [`GrowthPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/GrowthPanel.gd)、[`CodexPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/CodexPanel.gd)、[`AlchemyPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/AlchemyPanel.gd)、[`SocialHubPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/SocialHubPanel.gd)、[`SettingsPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/SettingsPanel.gd)、[`MailPanel.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/MailPanel.gd) | 已完成 |
| **D17** | 探索地图出生点路牌与沈舟重叠、脚下无出生阵纹 | 更新 [`MapScene.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/MapScene.gd)，新增 `_SpawnGlyph` 出生阵纹，当路牌距出生点 `<132px` 时自动施加路侧 `visual_offset` | 已完成 |
| **D18** | 地图顶部遮罩遮暗角色名牌 (`沈舟 Lv35`) 与怪物头顶标签 | 修复 [`MapScene.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/MapScene.gd) `_name_tag_exclusions()`，将 `TopScrim` 等全屏环境层加入碰撞豁免，恢复 100% 清晰度 | 已完成 |
| **D19** | 18 张探索地图跨生态复用绿色苔藓石块、第四幕光路缺 T 型节点 | 更新 [`IllustratedScenery.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/IllustratedScenery.gd)、[`WorldDressing.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/world/WorldDressing.gd) 与 [`FourthActGround.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/FourthActGround.gd)，按生态分区绑定专属地貌构件并接入 24px 导光石槽与 T 型节点 | 已完成 |

## 3. 验证与截图产物
- 视觉审计截图目录：[`shots/v4_p0/audit/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p0/audit/)（141 张全量截图）
- 多分辨率响应式截图目录：[`shots/v4_p0/responsive/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p0/responsive/)（132 张截图，`overruns=0`）
