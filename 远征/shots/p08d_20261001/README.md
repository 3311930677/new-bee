# P08-D1 伙伴协战验收

2026-10-01，Godot 4.7.2 Compatibility。已完成霜关驿舍伙伴服务、现有九种伙伴的两项战术特性、胜利协战计数与旧档保存。总方案尚未完成。

[实施与范围](../../docs/plans/2026-09-30-p08-third-act-companions.md) · [证据及源文件哈希](acceptance.json)

最终 39 项回归通过，测试 runner 11 项故障自检通过。四职业从已验收 P08-C 存档真实走图领取岩龟、训练、撤退及三次胜利，再回驿训练第二项；四组 A/B 进程状态及原始存档相同。真实玩家存档不变。专项测试另外覆盖合成败局的真实结算分支、保存失败回滚、冷却、元素对应、前排规则、入场快照和旧养成保留。

截图为隔离构图/事件演示，不能替代真实输入记录。三种战术的实际计算由 `VerifyCompanions` 验证；领取、购买、三胜、训练和重启由 `PlaythroughCompanions` 验证。

| 界面/表现 | 480×800 | 480×1067 |
|---|---|---|
| 原图志与伙伴服务 | [短屏](companion_lodge_480x800.png) | [长屏](companion_lodge_480x1067.png) |
| 第二项三胜门槛 | [短屏](companion_locked_480x800.png) | [长屏](companion_locked_480x1067.png) |
| 第一项/费用 | [短屏](companion_first_480x800.png) | [长屏](companion_first_480x1067.png) |
| 双特性/第二项 | [短屏](companion_second_480x800.png) | [长屏](companion_second_480x1067.png) |
| 元素对应技能说明 | [短屏](companion_help_480x800.png) | [长屏](companion_help_480x1067.png) |
| 地图伙伴训练标记 | [短屏](companion_world_480x800.png) | [长屏](companion_world_480x1067.png) |
| 护卫盾弧 | [短屏](companion_guard_480x800.png) | [长屏](companion_guard_480x1067.png) |
| 追击连线 | [短屏](companion_pursuit_480x800.png) | [长屏](companion_pursuit_480x1067.png) |
| 元素净化圈 | [短屏](companion_resonance_480x800.png) | [长屏](companion_resonance_480x1067.png) |

重放：隔离 APPDATA 后在工程根运行 `tools/run_playthrough.ps1 -Companions -Roles zs,ck -SourceDir tools/_logs/p08c_final_zs_ck -LogDir tools/_logs/p08d_patrol_zs_ck`，另以 `fs,fz` 与 `p08c_final_fs_fz` 验证其余职业。最终日志、临时存档位于 `tools/_logs/`，属于本机验收证据；清单记录其路径和 SHA256，Git 保留场景、回放工具及截图。

现有退出时资源诊断仍登记为 issue 43。等级/资源曲线、坐骑/合约/阵营/誓约、第四幕、房间机关链、其余任务总量与 S4/S7 验收仍待后续实施。
