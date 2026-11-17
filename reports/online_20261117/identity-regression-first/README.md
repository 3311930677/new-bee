# 身份功能首轮完整回归：保留失败

本轮完整运行于 2026-11-17 UTC 13:17:36 至 13:29:19，**78/79 通过、实际退出码 1**。[进程结果](full-regression-result.json)、[原始控制台](full-regression-console.log)、[UTF-8 浏览版](full-regression-console-utf8.log)、[全部用例日志](cases)和所用脚本快照独立保存，不作为通过证据。

唯一失败用例是 [VerifySecondAct](cases/VerifySecondAct.log)，报告盐鳞王靠近观察、目标交付和港口支线完成三条断言失败。首次失败没有帧计数采样，不能仅从该日志断定每一步的运行时序。

后续读取实际代码发现，观察判定在怪物的 `_physics_process` 中执行，测试只等待两次 `process_frame`。两次正常帧率的隔离副本均在这两帧之间发生物理更新并通过；受控副本只在观察片段把物理频率临时设为 1 Hz，测得两次绘制帧后物理计数 187→187、任务 active、未观察，等待物理更新后 187→188、任务 ready、已观察，同一免战斗及交付断言随后通过。这证明原等待方式存在时序缺口，受控条件不冒充正式游戏设置或首轮原样复现。诊断副本及报告保存在后续 [身份验收 test-timing](../character-identity/test-timing)。

修复仅将该处第一条等待改为 `physics_frame`，随后仍等 `process_frame`，再执行原有免战斗、可交付和完成断言。[Godot 官方 SceneTree 文档](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#signals)明确物理帧信号在节点物理回调之前发出，因此保留后续绘制帧以等待回调完成。没有增加重试至通过的循环、睡眠或修改任务规则/距离/预算。

本目录保留的是修复前的结果，后续完整运行另存目录；已有退出资源诊断继续由 issue #43 跟踪。完整 L0–L6 目标保持 active。
