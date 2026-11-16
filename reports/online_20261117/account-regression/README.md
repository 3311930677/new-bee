# 账号管理界面改动后的完整回归

唯一入口 `远征/tools/run_regression.ps1` 完成全部 79 项，逐项满足进程退出 0、自己的完成标记、无禁止错误模式以及墙钟期限；完整控制台与真实进程结果见[索引](verification.json)。对应开始/结束时间保存在 [full-regression-result.json](full-regression-result.json)。

本轮 [VerifyPerf](cases/VerifyPerf.log)：主界面 96ms/260ms，召唤首开 45ms/130ms，兑换 82ms/130ms，设置 92ms/130ms，设置重开 53ms/70ms，城镇进场 156ms/700ms。没有修改预算。28 项用例的 48 条已有退出资源诊断仍按 issue #43 记录，不宣称修复。

这是单机完整回归，真实在线账号、双客户端和数据库异常演练见[另行归档](../account-management/verification.json)。L0 及完整联机目标仍未完成。
