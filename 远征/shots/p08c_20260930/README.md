# P08-C 第三幕六支线截图与验收

八个场景各有 480×800 和 480×1067 两张，共 16 张，均为隔离构图演示档。真实输入续玩另见验收清单中的四职业 A/B 日志。

| 场景 | 短屏 | 长屏 |
|---|---|---|
| 风灯两种修法 | [查看](third_side_choice_480x800.png) | [查看](third_side_choice_480x1067.png) |
| 添炭后的暖灯 | [查看](third_side_coal_480x800.png) | [查看](third_side_coal_480x1067.png) |
| 挡风片与蓝灯 | [查看](third_side_shield_480x800.png) | [查看](third_side_shield_480x1067.png) |
| 裂纹名牌 | [查看](third_side_nameplate_480x800.png) | [查看](third_side_nameplate_480x1067.png) |
| 霜苔取样 | [查看](third_side_lichen_480x800.png) | [查看](third_side_lichen_480x1067.png) |
| 矿道排气口 | [查看](third_side_vents_480x800.png) | [查看](third_side_vents_480x1067.png) |
| 赤砂接应人 | [查看](third_side_parcel_480x800.png) | [查看](third_side_parcel_480x1067.png) |
| 冰隘封碑 | [查看](third_side_echo_480x800.png) | [查看](third_side_echo_480x1067.png) |

[acceptance.json](acceptance.json) 记录 38 项回归、四职业从已验收 s01–s28 新档存档继续实际完成六支线、跨进程奖励判重与 A/B 原始存档一致的证据。它还比较旧十二条支线配置、已有进度、装备 UID、导师状态、主线选择和已清首领，保存真实玩家存档保护哈希，以及 33 张 UTF-8 无 BOM 数据表的哈希。

这批未重新从创角回放 28 步主线；来源存档和其哈希明确列入清单。两种修法均有真实按钮专项验证，四职业续玩统一选择挡风。失败回放记录保留，最终成功日志在 `tools/_logs/p08c_final_zs_ck/` 与 `p08c_final_fs_fz/`。

截图已核对任务目标、角色、按钮和正文在两种屏高内可见。程序绘制的人物/任务图形不算完整动画美术交付，自动测试也不证明人工时长或 Android 触控/性能；第三幕养成、合约/誓约、第四幕及其余总方案门槛继续实施。
