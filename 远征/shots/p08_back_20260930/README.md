# P08-B 第三幕后段截图

每项分别渲染 480×800 和 480×1067，共 22 张，使用隔离演示档。演示步骤和等级用于构图；真实新档进度以回放日志为准。

| 场景 | 短屏 | 长屏 |
|---|---|---|
| 裂谷矿脉 | [查看](third_vault_480x800.png) | [查看](third_vault_480x1067.png) |
| 重砸前摇 | [查看](third_vault_windup_480x800.png) | [查看](third_vault_windup_480x1067.png) |
| 霜林栈道 | [查看](third_boardwalk_480x800.png) | [查看](third_boardwalk_480x1067.png) |
| 冰隘 | [查看](third_pass_480x800.png) | [查看](third_pass_480x1067.png) |
| 风眼召唤 | [查看](third_eye_480x800.png) | [查看](third_eye_480x1067.png) |
| 风眼破绽 | [查看](third_break_480x800.png) | [查看](third_break_480x1067.png) |
| 回驿选择 | [查看](third_choice_480x800.png) | [查看](third_choice_480x1067.png) |
| 商货旗幡 | [查看](third_merchant_480x800.png) | [查看](third_merchant_480x1067.png) |
| 守关旗幡 | [查看](third_wardens_480x800.png) | [查看](third_wardens_480x1067.png) |
| 驿站行情 | [查看](third_market_480x800.png) | [查看](third_market_480x1067.png) |
| 地区定位 | [查看](third_back_regions_480x800.png) | [查看](third_back_regions_480x1067.png) |

阶段横幅是 1.5 秒的临时战斗提示；画面没有证明人工游玩时间、触摸操作或 Android 实机表现。

首领原图保留透明 alpha，运行图采用最近邻缩小和纹理过滤；单帧与半透明边缘仍需在专用动画生产时统一处理。

验收清单见 [acceptance.json](acceptance.json)：37 项回归、四职业从新档实际输入完成 s01–s28，以及 A/B 两进程存档与奖励幂等核验均通过。实际回放在 Lv9 完成；第三幕长期成长和总方案等级曲线尚待接入。

`snow_balance_probe.json` 是失败隔离档加预期第二式的平衡模拟，已标记 `simulation_only` 和 `prospective_mentor_unlock`；不能替代真实通关证据。早期失败回放日志保留在 `tools/_logs/p08_back_*`，最终成功日志位于 `p08_back_final_zs_ck` 与 `p08_back_final_fs_fz`。
