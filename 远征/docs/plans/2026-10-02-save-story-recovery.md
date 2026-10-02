# P09-A 存档与剧情回归恢复

当前基线为 `570fb43`，全量回归45项中的VerifySave与VerifyStory失败。本包先恢复可验收基线，再推进第四幕与剩余S0–S7内容。

## 规则与旧档

- 读取缺少companions、campaign_growth、skill_curriculum的旧档时，清除上一档的相应内存字段；有字段时完整复制，保留真实投入。版本仍为v6，无重排或重发奖励。
- 未来版本档继续兼容读取与备份，但锁定自动写盘，保护未知字段；成功读取支持的旧档或当前档后解除锁写。
- VerifyStory从完整初始状态开始，不继承自动加载的正式玩家档。测试仅写专用存档。

## 验收

专项5/5通过，覆盖VerifySave、VerifyStory、VerifyCompanions、VerifyCampaignGrowth、VerifyCurriculum。45项全量终态为`ALL GREEN (45 cases)`、退出0，日志在`tools/_logs/goal_recovery_full_20261002`；31项仍有76条引擎退出资源诊断，原issue43未解决。此后只增强测试与截图工具，追加VerifySave 1/1通过，真实点击导入入口保持原档字节，VerifyStory重复运行也通过。

两项红项的根因分开：VerifyStory继承自动加载的正式档支线/账本，重置完整初始状态并执行与正常启动相同的起始建筑归一后恢复；G读取缺省旧档漏清三个新增可选字段，导致跨角色经验标记残留。未来档写回还与整体方案保护未知字段的规则相悖，本包改为兼容读取、备份并锁写，成功读取支持的档解除锁写。

480×800与480×1067实际恢复提示截图已检查正文、返回标题与导入按钮完整。引擎成功保存PNG后仍输出纹理/RID/RenderingServer退出诊断，保留原日志，不把截图当无退出诊断证明。四职业真实第一幕输入与A/B独立进程验收全部通过，终态`PLAYTHROUGH_ALL_OK (4 roles, A+B per role, real save untouched)`，每职业存档字节与状态一致；正式玩家档SHA256保持`BA8054B3D2F46D21D5CFE70E6EF5EFCADCC817A8267FF67FC7522379E2805BE7`。重放包含胜/败/逃/满包掉落/任务物交付，是自动化操作证据，不替代人工30–45分钟时长或安卓触控验收。

本包不增加内容量，仍是主线28/36、支线18/36、机制首领6/8、主世界14图，不能宣告S0–S7整体完成。
