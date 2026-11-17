# 受限数据库与恢复批次的完整单机回归

Godot 4.7.2，唯一入口 `远征/tools/run_regression.ps1`，2026-11-17 UTC 05:41:29–05:55:49。**79/79，实际退出码 0**；玩家目录按原运行器隔离及核对。

- [验收索引](verification.json)、[实际进程结果](full-regression-result.json)、[原始控制台](full-regression-console.log)、[UTF-8 浏览版](full-regression-console-utf8.log)及 [79 份用例日志](cases)保留原记录。
- [性能日志](cases/VerifyPerf.log)：主界面 89/260ms、召唤首开 39/130ms、兑换 74/130ms、设置 86/130ms、设置重开 54/70ms、城镇 88/700ms；没有改预算或性能测试。
- 运行前后运行器和 `LoadScreen.gd` 摘要相同；实际使用的运行器另存[快照](run_regression-used.ps1.snapshot)。
- 正常 Windows 证书环境下没有证书库错误；[逐案诊断审计](diagnostics-audit.json)记录 29 个用例中的 48 条已有退出资源诊断，继续由 issue #43 跟踪，没有把这些诊断描述为已修复。

这是当前工作区的单机兼容验收。受限数据库身份、真实 HTTPS 双端、备份与新库恢复另见[本批联机证据](../database-recovery/README.md)。不替代手机、广域网、多人合作/PVP、容量或生产恢复验收；完整 L0–L6 目标继续 active。
