# P09-A 旧档恢复与未来档保护

- `future_480800.png`：480×800真实Godot渲染，未来档恢复提示正文、备份地址、返回标题/导入旧档两按钮完整。
- `future_4801067.png`：长屏恢复提示，完整正文和按钮；没有解锁继续按钮。
- 对应`.log`保存生成日志，PNG保存后仍有引擎退出纹理/RID/RenderingServer诊断，未记为已修复。
- 截图场景`ShotRunner --scene=save_future`在写入之前显式使用`res://tools/_logs/save_shot_future_recovery.json`；不触碰`user://save.json`。

全量回归、追加入口点击与第一幕A/B记录见`docs/plans/2026-10-02-save-story-recovery.md`及本目录最终`acceptance.json`。
