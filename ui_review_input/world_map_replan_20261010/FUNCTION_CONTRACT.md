# 功能合同 · 保留用途，允许迁移位置

本合同中的位置和范围可重新设计；ID、功能、地区连接、任务关系与开放条件保留。当前坐标在context/CURRENT_MAP_FACTS.json，仅作为迁移依据。

## 城镇建筑/功能

| ID | 名称 | 功能入口 | 类型 |
|---|---|---|---|
| hall | 议事厅 | notice | core |
| gate | 城门 | visit | core |
| archive | 图志阁 | worlds | func |
| kennel | 兽栏 | codex | func |
| barracks | 巡界厅 | deploy | func |
| storehouse | 仓廪 | activity:levy | func |
| stable | 边城马厩 | mount | func |
| shrine | 祭坛 | activity:signin | func |
| forge | 锻造铺 | shop | func |

待建/已落成状态必须表达；可以换掉工地造型，不能直接解锁或删除建造条件。

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

另保留来访旅人的生成与交谈位置；角色可移位，不能删除访问功能。

## 地区连接

| 地图 | 出口ID | 目标 | 开放条件 |
|---|---|---|---|
| lorin_wilds | north_gate | maple_road | 沿用现有条件 |
| maple_road | south_gate | lorin_wilds | 沿用现有条件 |
| maple_road | north_path | broken_slope | 沿用现有条件 |
| maple_road | east_salt_path | old_salt_road | s12 |

## 关键任务/交互

下列为地图表定义的实体；不同进度可能不同时显示。可重排并重做视觉，保留ID、种类、任务关联、可达性与可交互性。

| 地图 | 实体ID | 名称 | 类型 | 任务 |
|---|---|---|---|---|
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

敌人活动区和出生点可重排，保留种类、奖励、任务与刷新语义。碰撞可随新布局重新制作，但道路、NPC、任务点、出口必须实际可达。

最终方案应列出新的地图布局版本及旧存档位置适配任务：避免角色恢复到墙内、河中、地图外或封闭区。无需Cloud读取存档或编程，由Codex实施。
