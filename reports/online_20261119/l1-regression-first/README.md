# L1 首轮完整单机回归失败记录（78/79）

保留原因：严格执行不覆盖、不隐瞒历史失败记录原则。

- 执行时间：UTC `2026-11-18T17:19:21.777540+00:00` 至 `2026-11-18T17:31:31.376307+00:00`，退出码 `1`，通过 **78/79**。
- 失败用例：[cases/VerifyNav.log](cases/VerifyNav.log) 检出 `OnlineSocialPanel.gd` 缺少自身 `_unhandled_input` Esc（`ui_cancel`）处理（随后二次核对亦补上 `not G.ui_blocked` 守卫）。
- [控制台日志](full-regression-console.log) | [结果清单](full-regression-result.json)
- 修复后在最终版独立重跑全量 79 项回归，见 [l1-regression](../l1-regression/README.md)。
