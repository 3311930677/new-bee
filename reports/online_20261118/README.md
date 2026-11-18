# 独立角色监督、L0-H 边城旅程与完整重验

L0-G（角色监督）及 L0-H（独立行囊、伴兽出战与八阶段边城旅程）全部实现与最终验收已在北京时间 **11 月 18 日–19 日 00:14** 分批完成。完整联机目标继续 active，L0–L6 没有被本机演练替代。

- **L0-H 边城旅程与监督重验（最终源码）**：[town-journey](town-journey/README.md) —— Go/PostgreSQL **57/57**（`go test -p=1`），Godot 权威 **29/29**，双真实端边城 8 阶段旅程 **6/6**（19 表恢复、16 条行囊历史、16 条任务历史），双真实端角色监督与故障恢复 **12/12**（权威恢复 9.141s、网关恢复 2.547s），并保留 4 轮历史失败样本。
- **L0-H 最终完整单机回归**：[journey-regression](journey-regression/README.md) —— **79/79 PASS、实际退出码 0**，原性能预算保留；16 项用例 31 条退出资源诊断（issue #43）继续记录。
- **L0-G 基线归档**：[service-supervision](service-supervision/README.md)（Go 53/53、双端 12/12、17 表恢复）与 [supervision-regression](supervision-regression/README.md)（79/79、退出码 0）；[首轮完整失败](../online_20261117/supervision-regression-first/README.md)（78/79、退出码 1）继续保留。

当前尚无封测服务器。Linux 网关/监督器只完成交叉编译，分身份服务模板尚未在目标机运行；Windows 前台开发使用显式权限验收标记。系统身份、公网、手机/广域网、生产备份、容量和剩余玩法继续按原实施方案推进。
