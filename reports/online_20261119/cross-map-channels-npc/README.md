# L1-B 频道切换、跨图（昭元边城 ↔ 枫林古道）与按角色 NPC 隔离

本批（L1-B）落地并整体验证频道管理（`world_channels`：`GET /v1/rooms/channels`、`POST /v1/rooms/channels/switch`、可选指定频道入图）、跨图迁移（`cross_map`：`POST /v1/rooms/travel`、`lorin_wilds` ↔ `maple_road`、`WorldAuthority.gd` 从 `online_rules.json` 动态校验多图边界、断线重连恢复所在地图与位置、跨图战斗拒止）、迁移 `006_online_world_l1.sql` 与 20 张表最小权限/备份恢复同步，以及按角色隔离的 NPC 对话状态（`npc_isolation`：`POST /v1/npcs/{id}/interact`、`npc_interactions`）。所有校验基于统一源码指纹 `3bf8eb9f87372aa094538b648c7ecfec6bae02e3f4fbdbee24ff04153ca73486`（`content_version = 0b4631213b5f9c41625c76de818e7d893fa43f3a6b915602c11c01e5e14a642f`），详见[验收索引](verification.json)。

- **Go / PostgreSQL 完整套件**：**62/62 通过，退出码 0**（含新增 `TestChannelsListSwitchAndOverflowIsolation`、`TestCrossMapTravelPortalDistanceAndBattleIsolation`、`TestNPCIsolationPerCharacterAndMap`，以及 `dbops` 20 表备份恢复与 `npc_interactions` 受限权限拒删检核），见 [go-integration.jsonl](go-integration.jsonl)。
- **独立 Godot 权威检查**：`room_a4c7962ce31840fda19cd7b6c2933880` **29/29 通过，退出码 0**，见 [room/report.json](room/report.json)。
- **双真实 Godot 客户端跨图与 NPC 隔离验证**：`world_l1_ca32c1f27ac240928b233bf23f02f5c8` 通过，两端退出码 `0`（`db_npc_interactions: 2`、`db_rooms: "lorin_wilds:1,maple_road:1"`、20 张表只读备份与新库恢复一致、零报错、单机数据不变），目检截图 [world_l1/maple-road.png](world_l1/maple-road.png)。
- **L1-A 位置流与 L0-H 边城旅程无回退**：`positions_650c26eb82b04aaea689d5629871318b`（两端退出码 `0`）、`journey_0e2da7d87a1a4a75a66c91d9df27df4b`（**6/6**，20 表恢复），以及单机边界 `VerifyOnlineBoundary`（`ONLINE_BOUNDARY_OK`，退出码 `0`）均在同一源码摘要上通过。
