

## Codely Structured Memories

### User

### Feedback
- [2026-10-27 04:07:26] 远征项目存在多个会话并行修改同一工作区的情况；审计或跑回归前先检查 src/、tools/ 的文件修改时间，并在结论中标注测试快照，避免把并行会话已修掉的旧失败当成当前产品缺陷。

### Project
- [2026-10-27 04:07:23] 远征（D:\new-bee\远征）是 Godot 4.7.2 单机手游，当前版本 0.2.3-optimization；回归入口为 tools/run_regression.ps1（全量 78 项，需指定 Godot 4.7.2 exe 并用隔离 APPDATA），交付报告统一放在 D:\new-bee\reports\<主题>_<日期>\。
### Reference
- [2026-10-27 04:07:28] 《远征》2026-10-27 当前问题与改进方案审计报告：D:\new-bee\reports\current_audit_20261027\远征当前问题与改进方案_20261027.md（含包体约747MiB、射艺重复奖励无上限、active_run 损坏锁档、CityScene 479ms、正式包 GM 入口、职业/天赋与世界同质化等问题及分阶段验收标准）。
