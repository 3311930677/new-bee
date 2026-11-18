# L0-H 最终单机完整回归

执行时间：UTC `2026-11-18T16:01:19.561805+00:00` 至 `2026-11-18T16:14:53.851689+00:00`（北京时间 11 月 19 日 00:01–00:14），严格完整回归 **79/79 通过（`ALL GREEN`），实际退出码 0**。

- [控制台日志](full-regression-console.log) | [结果清单](full-regression-result.json) | [汇总索引](verification.json) | [诊断审计](diagnostics-audit.json)
- 全部 79 项用例日志保留在 [cases](cases)；原性能预算与断言未放宽，`run_regression.ps1`、`LoadScreen.gd` 与 `VerifySecondAct.gd` 运行前后摘要一致。
- `VerifyPerf` 关键预算：[cases/VerifyPerf.log](cases/VerifyPerf.log)（GameHome 75/260ms、世界 60/130ms、图鉴 51/130ms、召唤 34/130ms、兑换 48/130ms、设置 82/130ms 与 50/70ms、养成 63/130ms、CityScene 108/700ms）。
- 退出资源诊断（issue #43）：16 项用例合计 31 条退出阶段 RID/资源诊断（已如实记录，不掩盖）；主机根证书库诊断：0。
- 同源码摘要 `online_sources_sha256` = `98ded236fbacabf84b94233b0e5d455d4dbd39460e8781aeeb53169f5d4073fe`，对应在线测试与双端验证归档于 [L0-H 边城旅程与监督重验](../town-journey/README.md)。
