# TLS 与监控增量后的完整回归

唯一入口 `远征/tools/run_regression.ps1` 完成 **79/79**，每项均有实际退出 0、自己的完成标记并处于墙钟期限内；[进程结果](full-regression-result.json)保存原始开始/结束时间和退出码。[索引](verification.json)与[逐份日志审计](diagnostics-audit.json)复核完成集及错误模式。

[性能日志](cases/VerifyPerf.log)：主界面 108ms/260ms，召唤首开 66ms/130ms，兑换 82ms/130ms，设置 94ms/130ms，设置重开 56ms/70ms，城镇进场 234ms/700ms。全部预算保留。

原运行器把主机证书存储和退出资源例外混计成“79 项/129 条资源诊断”。原始控制台保留这段输出；实际分类为 79 条精确的已知沙箱证书库诊断，以及 30 项中的 50 条退出资源诊断，后者仍由 issue #43 跟踪。计数修复没有改变任何允许规则；[运行时原脚本快照](run_regression-used.ps1.snapshot)由运行期间未改动的提交源码恢复，[计数修复后快照](run_regression-current.ps1.snapshot)单独保存。

[运行器自检](validation/operations-runner-selftest.log)为 15/15、[进程退出记录](validation/operations-runner-selftest-result.json)为 0：精确主机诊断单列，近似内容和普通 ERROR 仍失败，退出资源也不混入主机计数。[正常证书环境的两项复验](validation/operations-certificate-context.log)及其实际进程记录均通过，原始用例日志中没有证书库诊断；真实 TLS 正反场景另见[运维报告](../operations/operations/report.json)。没有通过关掉证书或主机名验证来通过测试。

[原始控制台](full-regression-console.log)保留原环境编码；[UTF-8 浏览版](full-regression-console-utf8.log)从严格解码生成，原始字节未覆盖。单机完整回归不替代双手机、广域网、压力或多人竞技验收。
