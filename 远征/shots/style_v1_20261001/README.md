# 参考画风 V1 首批样板

实际 Godot 4.7.2 Compatibility 输出，六张已目视检查。当前完成地表/占屏比例/硬边界面/独立战斗地表；角色、NPC、建筑仍为旧资产，整套参考画风未验收。

| 内容 | 480×800 | 480×1067 |
|---|---|---|
| 昭元边城 | [截图](style_city_480x800.png) | [截图](style_city_480x1067.png) |
| 主世界对阵 | [截图](style_battle_480x800.png) | [截图](style_battle_480x1067.png) |
| 背包 | [截图](style_bag_480x800.png) | [截图](style_bag_480x1067.png) |

截图使用隔离的已验收主线档构图；对阵暂停，并非实际输入录像。真实点击待领取翻页/领取/换装/回图和两进程恢复见 `tools/_logs/style_v1_input/`，最终41项正式回归见 `tools/_logs/style_v1_final_regression/`。日志不入仓库，内容哈希与各测试自己的OK标记记录在 [acceptance.json](acceptance.json)。真实玩家存档未改动。

选中资产：`lorin_wilds_reference_v4.png`、`classic_floor_reference_v1.png`。v3保留为未接入候选，提示词与选择过程见 [完整提示词](../../docs/plans/2026-10-01-reference-style-prompts.md)。下一批优先统一人物/NPC，再统一建筑与后续地区。
