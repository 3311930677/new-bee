# L1-A 实时位置流、AOI 视野订阅与双端同步验证

本批（L1-A）实现服务端 10Hz NDJSON 位置流 `GET /v1/rooms/positions`（`town_positions` 功能位）、480px 半径 AOI 视野裁剪（流式帧与 `/v1/rooms/current` 保持一致）、单频道 24 人共享采集以及客户端本地移动预测/对齐与远端 100ms 线性插值，并重验 L0 关键运维/旅程/监督恢复项，源码指纹 `2e0601026c86a5ef6beae933ded368e6d34a044dbe8fcf554fe6f0933431d556`，详见[验收索引](verification.json)。

- **Go / PostgreSQL 完整套件**：**59/59 通过，退出码 0**（含 `TestRoomPositionStreamFollowsCommittedNearbyPlayers` 与 `TestTownPositionFeedSharesAChannelAcross24Clients`），见 [go-integration.jsonl](go-integration.jsonl)。
- **双真实 Godot 客户端位置流与 AOI 实测**：`positions_a239e75527c2478b96ee9b7e36ebe7a5` 通过，两端退出码 `0`（`local_prediction_seen: true`、`tween_seen: true`、离开 480px 退订、重返视野恢复、登出后 `database_counts: ["2","1","0"]`），目检截图 [positions/position-together.png](positions/position-together.png)。
- **L0-H 双端旅程无回退**：`journey_49c6c60c613f4c50b64368e9495cf551` **6/6 通过**（19 表恢复、16 条行囊与任务历史），见 [journey/report.json](journey/report.json)。
- **L0-G 双端监督与故障恢复无回退**：`world_22ac6d267c284537810494b1e7231025` **12/12 通过**（权威恢复 9.296s / 网关恢复 2.547s、19 表恢复），见 [world/report.json](world/report.json)。
- **L0 本机运维与 Prometheus 重验**：在已提交 L0-H 版本（`0c2ef90d`）上安装官方 `prometheus-3.16.0` 并通过 `verify_operations.py`（`operations_d905b55475e4428bbeb5e9cd77cc27af`），见 [operations-report.json](operations-report.json)。
