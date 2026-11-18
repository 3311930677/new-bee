# L1 完成态完整单机回归（79/79）

执行时间：UTC `2026-11-18T17:32:56.215724+00:00` 至 `2026-11-18T17:45:17.734330+00:00`（北京时间 11 月 19 日 01:32–01:45），严格完整单机回归 **79/79 通过（`ALL GREEN`），实际退出码 `0`**。

- [控制台日志](full-regression-console.log) | [结果清单](full-regression-result.json) | [79 项明细日志](cases)
- `VerifyNav` 与 `VerifyPerf`（[VerifyPerf.log](cases/VerifyPerf.log)：GameHome 91/260ms、世界 72/130ms & 40/70ms、图鉴 65/130ms & 22/70ms、召唤 30/130ms & 18/70ms、兑换 49/130ms & 13/70ms、设置 84/130ms & 49/70ms、养成 64/130ms & 42/70ms、CityScene 66/700ms）均未放宽预算、全部通过。
- 退出资源诊断（issue #43）：19 项用例合计 34 条退出阶段资源诊断，继续如实记录；前序 `78/79` 失败记录保留于 [l1-regression-first](../l1-regression-first/README.md)。
