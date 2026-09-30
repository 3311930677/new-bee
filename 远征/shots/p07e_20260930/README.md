# 第二幕当前运行画面

2026-09-30 使用 Godot 4.7.2 Compatibility 渲染，22 张 PNG。每个场景各有 480×800 与 480×1067 两张；后者是离屏逻辑视口，不是 Android 物理设备截图。演示状态只写工程测试目录。

| 文件前缀 | 画面 |
| --- | --- |
| second_port / second_port_south | 港口主街北部和南部，四栋建筑/四人 |
| second_salt / second_tideflat / second_gate | 旧盐道、潮痕滩、水闸 |
| second_gate_windup / second_gate_ebb | 真实施法队列生成的 1.4 秒预兆与低血退潮阶段 |
| second_hatch / second_fishing | 兽栏孵化和实际钓鱼面板 |
| second_shipping / second_relation | 船运和港务人物关系 |

首领机制图使用演示夹具冻结模拟，以便检查字幕、目标环、阶段横幅、角色和指令站位；机制规则另由 VerifySecondAct 和四职业真实输入回放验证。孵化面板在港口支线加入后增了托付按钮，其最终画面以 p07f_20260930/second_hatch_* 为准。
