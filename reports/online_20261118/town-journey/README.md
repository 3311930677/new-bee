# L0-H 独立行囊、伴兽出战、八阶段边城旅程与监督重验

本批（L0-H）落地并重验在线行囊、武器/护具装备槽、战斗中一次扣药、`pet_rockturtle` 岩龟出战、昭元边城 8 阶段新手旅程、迁移 `005_online_journey.sql`、`OnlineJourneyPanel.gd` 及 `verify_journey.py`，并在审计修复后于统一源码摘要 `online_sources_sha256 = 98ded236fbacabf84b94233b0e5d455d4dbd39460e8781aeeb53169f5d4073fe` 上完成全套 5 项验收，详情见[验收索引](verification.json)。

## 本批通过项

1. **Go / PostgreSQL 完整套件**：`python 远征/server/tools/dev.py test`（含 `go test -p=1 ./...` 及新增 `inventory_ledger` / `quest_events` / `inventory_items` 受限权限拒写与失败上下文日志捕获）**57/57 通过，退出码 0**，事件流见 [go-integration.jsonl](go-integration.jsonl)。
2. **独立 Godot 权威进程检查**：`verify_room.py`（含 `pet_rockturtle` 出战配置、`flee`、`battle.release` 与非法宠物 `pet_illegal` 拒绝）**29/29 通过，退出码 0**，单机数据不变，见 [room/report.json](room/report.json)。
3. **双真实 Godot 客户端 8 阶段边城旅程与新库恢复**：`verify_journey.py` **6/6 通过，退出码 0**，两端退出码 `0`。两位旅人各自完成全部 8 个任务事件与 2 场战斗（`125` 金币、3 个装备/出战槽、2 瓶药；幂等重放扣药 1 次），会话计数 `["2","1","0"]`，只读备份并恢复到新库一致匹配 **19 张表**，保留 **16 条行囊历史** 与 **16 条任务历史**，见 [journey/report.json](journey/report.json)。
   - 目检截图：[领取补给](journey/journey-supplies.png)、[岩龟伴兽](journey/journey-companion.png)、[碑窟资格](journey/journey-coop-entry.png)。
4. **双真实 Godot 客户端角色监督、注入 DB 故障与新库恢复**：`verify_world.py --database-recovery --supervision --capture` **12/12 通过，退出码 0**（使用重编译 `gateway.exe` 与 `servicehost.exe`）。挂起权威进程 22 个线程后自动恢复 **9.141 秒**，终止网关子进程后自动恢复 **2.547 秒**，4 次计划停机均退出 0，2 笔注入数据库错误为 PostgreSQL `P0001`、重试后一次入账，新库恢复一致 **19 张表**，见 [world/report.json](world/report.json)。
   - 目检截图：[昭元边城](world/world-a.png)、[权威战斗](world/battle-a.png)、[结算回城](world/result-a.png)。
5. **完整 79 项单机回归**：**79/79 PASS (`ALL GREEN`)，退出码 0**，见[完整回归记录](../journey-regression/README.md)。

## 审计修复与保留失败记录

- 修复 `dev.py` `go test -p=1` 串行包执行及 `roles_test.go` `DROP DATABASE ... WITH (FORCE)`，消除 `dbops` 建删库锁与 `online` 并发导致的 600 秒超时。
- 修复 `servicehost/manager.go` Windows `readStatus`/`replaceStateFile` 与每 250ms 状态刷新的并发打开竞争（修复前复现失败于 [world_370b384c9a514410a99602b8d821d1cd](failed-runs/world_370b384c9a514410a99602b8d821d1cd/report.json)）。
- 完整保留先前失败记录（不覆盖追认）：[journey_50ae6159ad004eb3b1fbc5c0f21f376f](failed-runs/journey_50ae6159ad004eb3b1fbc5c0f21f376f/report.json) 与 [world_e2ee9b84334540fa98662de0343f24a5](failed-runs/world_e2ee9b84334540fa98662de0343f24a5/report.json)（双端偶发 15,000ms 网关/DB 超时）、[world_5fe4395b799246789dfaba71a8e23089](failed-runs/world_5fe4395b799246789dfaba71a8e23089/report.json)（Windows `_console.exe` 包装进程句柄差异导致的监督超时），以及单机回归 16 项 / 31 条 issue #43 退出资源诊断。

当前仍处于桌面对桌面开发与局域/回环 TLS 验收阶段，尚无已配置封测服务器、目标 Linux 主机运行、真实手机/广域网与 L1–L6 功能；完整联机目标继续 active。
