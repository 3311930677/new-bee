# 功能合同：功能与进度保留，位置/画风/路线可重做

坐标只描述当前版本；新规划可以改变道路、地形、地图尺寸、相机、碰撞、摆放和出生点。由Codex适配地图版本、旧档位置与寻路。保留以下ID、功能、开放条件和任务依赖。

## 城镇建筑

| ID | 名称 | 入口/用途 |
|---|---|---|
| hall | 议事厅 | notice |
| gate | 城门 | visit |
| archive | 图志阁 | worlds |
| kennel | 兽栏 | codex |
| barracks | 巡界厅 | deploy |
| storehouse | 仓廪 | activity:levy |
| stable | 边城马厩 | mount |
| shrine | 祭坛 | activity:signin |
| forge | 锻造铺 | shop |

保留已落成/待建状态，可以重做未落成视觉，不直接解锁全部设施。

## 常驻NPC

| ID | 名称/身份 | 关联建筑 |
|---|---|---|
| npc_steward | 闻叔 · 执事 |  |
| npc_guard | 老赵 · 城门卫 | gate |
| npc_scribe | 青姨 · 图志阁掌事 | archive |
| npc_keeper | 阿豆 · 兽栏伙计 | kennel |
| npc_smith | 石头 · 铁匠 | forge |
| npc_mentor | 岳教头 · 巡界导师 | barracks |
| npc_stablemaster | 马伯 · 马厩管事 | stable |
| npc_warden | 云游 · 行脚商人 |  |
| npc_child | 小满 · 城中孩童 |  |

保留来访旅人的访问和交谈功能。NPC可迁移，任务角色和用途保留。

## 地区连接

| 当前地图 | 出口ID | 目标 | 开放条件 |
|---|---|---|---|
| lorin_wilds | north_gate | maple_road | 沿用现有条件 |
| maple_road | south_gate | lorin_wilds | 沿用现有条件 |
| maple_road | north_path | broken_slope | 沿用现有条件 |
| maple_road | east_salt_path | old_salt_road | s12 |

## 地图任务和交互点

配置中的实体可能随任务进度显示；新方案必须给出迁移位置与可达性。

| 地图 | ID | 名称 | 类型 | 任务 |
|---|---|---|---|
| lorin_wilds | a4_secret_oralbook_step_1 | 听城门旧识讲归路 | listen | a4_secret_oralbook |
| lorin_wilds | a4_secret_oralbook_feedback_0 | 三城口述册 | feedback | a4_secret_oralbook |
| lorin_wilds | a4_rel_nighttable_step_1 | 邀请边城旧识 | listen | a4_rel_nighttable |
| lorin_wilds | a4_rel_nighttable_step_4 | 选择桌边先讲的故事 | mark | a4_rel_nighttable |
| lorin_wilds | a4_rel_nighttable_step_5 | 听完桌边三段故事 | listen | a4_rel_nighttable |
| lorin_wilds | a4_rel_nighttable_feedback_0 | 三城小聚留桌 | feedback | a4_rel_nighttable |
| maple_road | a1_chime | 旧风铃 | collect | a1_rel_child |
| maple_road | act1_waystone_cache | 旧路石匣 | cache |  |
| maple_road | a1_roots_a | 草根 | collect | a1_eco_roots |
| maple_road | a1_roots_b | 草根 | collect | a1_eco_roots |
| maple_road | a1_postrider | 交付盐袋 | deliver | a1_trade_cart |
| maple_road | trade_maple_post | 驿亭交易 | trade |  |
| maple_road | a4_waylight | 古道路灯 | observe | a4_rel_waylight |
| maple_road | a1_trade_bridge_step_1 | 西桥承重点 | inspect | a1_trade_bridge |
| maple_road | a1_trade_bridge_step_2 | 东桥承重点 | inspect | a1_trade_bridge |
| maple_road | a1_trade_bridge_step_3 | 嵌入桥楔 | repair | a1_trade_bridge |
| maple_road | a1_trade_bridge_feedback_0 | 新楔归桥 | feedback | a1_trade_bridge |

修桥/旧路石匣/风铃等事件可以重做视觉与布局，保留进度逻辑、奖励和可交互性。敌人摆位可重排，保留种类、奖励与刷新语义。

## 前端功能

- 加载：真实资源/脚本预热、进度与原自动进入流程。不得用装饰进度代替实际加载。
- 标题：开始游戏、游戏介绍、设置、退出；保留现有平台退出行为。
- 登记/登录：本地旅人登记，账号/密码输入、密码查看切换、头像选择/导入、登录提交、游客入口与错误反馈。没有远程认证服务，不增加新登录服务。
- 创建角色的后续流程保留，本轮不新增昵称/职业/付费限制。
- 手记/介绍（可选范围）：世界、旅人、启程三类内容与翻页。

地图与前端设计不得改变成长、货币、战斗、奖励、任务条件及付费规则。
