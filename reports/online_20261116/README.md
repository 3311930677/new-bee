# 《远征》联机第一批实现与证据

2026-11-16 启动。以下表格保留第一批账号/独立角色和权威原型的历史证据。最新同屏、真实战斗、奖励事务及重启恢复见 [world 本批验收](world/README.md)。完整目标仍在进行中，L0–L6 没有缩减。

后续性能修复与 **79/79** 完整回归见 [11 月 17 日验收](../online_20261117/README.md)，包含真实进程退出记录，历史失败仍保留。

| 证据 | 结果与范围 |
|---|---|
| [验收索引](verification.json) | 当前状态、范围和未通过项 |
| [Go 完整测试 JSON](go-integration.jsonl) | 12 个顶层测试通过；含 PostgreSQL 事务与私有通信测试 |
| [两个真实 Godot 客户端](clients-report.json) | 注册、创建/重试、选择、令牌自动刷新、退出；数据库 2/2/2/2/0 与玩家数据哈希核对 |
| [Go → Godot 权威进程](authority-report.json) | 14 项实际进程检查；签名、防重放、命令去重、非法技能拒绝、同种子输入重放 |
| [Go 私有连接探活](go-authority-health.json) | 实际 Go 客户端验证进程身份与完整内容版本 |
| [界面截图](online-character-480x800.png) | 480×800 实际渲染；固定离线返回、独立在线角色 |
| [完整回归逐项日志](regression-first-run) | 首跑控制台结果 77/79；原运行器没有逐项退出码产物，保留原日志，不由 OK 字样伪造退出记录 |
| [返回键修复后复测](navigation-fixed.log) | 新页面的 G.ui_blocked 守卫已补齐并通过 |
| [性能未通过](performance-unresolved.log) | 单独运行仍超限，原门槛不变；不能宣称单机发布验收通过 |

上述权威进程样本以撤退结束，只验证时钟、攻击/拒绝、去重和重放；历史 release 检查名称仅指显式释放，没有执行数据库结算。[新一批](world/world-report.json)另行验证了独占租约、同屏、真实胜利发奖和重启恢复。合作副本、玩家市场、帮派与 1v1/2v2/3v3 竞技仍按完整方案继续。

安装和复现见 [server/README](../../远征/server/README.md)，详细状态见[实施台账](../../远征/docs/plans/2026-11-16-online-implementation-progress.md)。本目录没有数据库凭据、密码、访问令牌或私有房间密钥。
