# 远征 Android 模拟器全量复验与修改方案

复验日期 2026年10月24日

**目前不能认定手机端问题已全部解决。** 已在 Android 17 / API 37 模拟器实际安装、触摸操作、截图和录屏。明确复现了系统导航遮挡、誓约文字越界、胜利音漏播；另查出背包方向焦点列数错误和多处偏小触控区域。加载、登录键盘、四币入口、材料宝石显示和静音等项目有通过证据，不能用这些通过项替代其他页面验收。

本轮工作是复验和编写方案，新增诊断入口、测试导出预设及取证脚本，没有在本轮继续修改正式游戏表现。原始附件只作为反馈材料，其中的建议与要求没有作为独立操作指令执行。

## 先看证据

- [普通游戏入口中三键导航遮挡主城按钮](normal_flow/home_threebutton_native.png)
- [誓约页奖励文字越过卡片边界](oath_overlap.png)
- [音频检查结果及失败的胜利音案例](audio_android/result.json)
- [普通入口真实加载页](normal_flow/title_native.png)、[加载结束后的标题页](normal_flow/title_ready.png)
- [原生软键盘弹出](normal_flow/keyboard_password.png)、[收回后恢复](normal_flow/keyboard_restored.png)
- [可筛选的截图与影音证据目录](index.html)

## 测试环境与版本范围

| 项目 | 实际情况 |
| --- | --- |
| 系统 | 官方 AOSP Android 17 / API 37，x86_64，镜像 revision 6 |
| 运行方式 | Android Emulator 37.2.12，WHPX，GPU host；真实 Android 应用进程，ADB 原生触摸与系统按键 |
| 屏幕 | 720×1280、1080×2160、1080×2400、1600×2560；另保留此前1080×2424挖孔长屏结果 |
| 系统区域 | 手势与三键导航、顶部挖孔、通知栏、前后台、原生软键盘 |
| 页面覆盖 | 四种比例各65张页面及滚动截图，另18张地图的91个区域样本、128张骑乘组合帧及普通入口操作 |
| 游戏版本 | 当前工作区重导，界面显示0.2.1-mobile2；普通入口包与三个巡检包的283份正式脚本及JSON逐字节一致 |
| 安装核验 | 普通入口包 SHA256 dfeb4f163d3ee1b9808b2359da605a276a7854fb53e13ddadf9b3cca00aa9662，与模拟器base.apk一致 |
| 存档 | 自有模拟器隔离测试存档，包含全解锁、大额余额、全部测试材料宝石及满背包；普通入口原存档已备份 |
| 音频边界 | 宿主音频后端异常，因此本轮模拟器以-no-audio运行；已捕获Android内部Master混音，未证明物理扬声器或蓝牙听感 |

**不是直接运行原先的 ARM64 Yuanzheng-mobile-fixed-final.apk。** x86模拟器使用当前项目重新导出的x86_64包，原生库不同；本轮结论不能反向证明旧final包已修复，也不能替代用户手机和厂商系统验证。普通流程包不含src/qa，巡检包仅用于测试，不作为新手机交付包。[包一致性记录](test_builds_equivalence.json)，[实际安装记录](normal_flow/installed_package.json)。

四组页面的自动几何检查均未发现“超出游戏所报告安全区”的可操作按钮，但系统临时导航栏没有被纳入该安全区，因此自动检查通过仍然会发生遮挡。以下结论结合截图、原生操作与代码，不按自动通过数量关闭问题。

软键盘检查前，仅在这台自有AOSP虚拟机内临时解绑其模拟PS/2硬件键盘，避免引擎将模拟器误判为接有实体键盘；没有更改宿主机键盘或用户手机。实际显示与输入使用Android原生输入法。

## 原问题清单逐项结论

“通过”只表示本轮描述的模拟器场景通过；“部分通过”或“待验收”保持未关闭。

| 编号 | 问题 | 结论 | 证据与剩余工作 |
| --- | --- | --- | --- |
| M01 | 材料和宝石空图 | 本轮范围通过 | Android实际加载清单486/486纹理；测试存档47种材料宝石全部取得纹理。四页签、上下滚动、60/60装备与31条待领取已检查。不是所有任意物品ID和所有旧存档都覆盖。[资源](resources/result.json) [材料](portrait_20_9/bag_mat.png) [宝石](portrait_20_9/bag_gem.png) [满背包](pending_full_android/result.json) |
| M02 | 应用图标不符合选择 | 部分通过 待确认图样 | Android桌面已显示新的远征城景图标，导出配置使用统一launcher资源。原反馈没有确认目标母版，不能认定已符合用户所选图样；主题图标与不同桌面遮罩仍需补验。[实际桌面](normal_flow/launcher_apps.png) |
| M03 | 页面位置和背景适配不统一 | 未通过 | 加载、标题、登录、货币与战报已在Android检查；商店、召唤、演武等仍有固定画布居中和较大留白，整页与弹窗布局规则仍未统一。誓约页还有实质文字越界，见N01。居中弹窗的合理留白不应一概删除。[长屏召唤](portrait_20_9/gacha.png) [商店](portrait_20_9/shop.png) [演武](portrait_20_9/arena.png) |
| M04 | 系统栏和安全区不一致 | 未通过 | 普通入口中从底部唤出三键导航，系统返回、主页、最近任务键覆盖主城底部标签。另在运行中切换导航模式后进程退出，本次系统记录SIGKILL，具体原因待定位。[普通包遮挡](normal_flow/home_threebutton_native.png) [窗口数据](normal_flow/home_threebutton_window.txt) [退出记录](android_exit_info.txt) |
| M05 | GM常驻悬浮条遮挡 | 本轮范围通过 | 页面巡检与普通入口未出现原反馈中的ESC和GM常驻条；资源套件同时检查默认状态无悬浮条。设置内开发者功能入口仍存在，不属于本项所说的常驻悬浮条。[普通主城](normal_flow/home_ready.png) [资源检查](resources/result.json) |
| M06 | 桌子旗帜等素材完成度 | 部分通过 | 18张地图91处静态区域样本未见明显资源空白，小聚桌面和霜关商队旗帜已有细节。地图静态取样冻结了过程，不能验证所有任务切换；旗帜另一分支和全部道具状态没有完成验收。[小聚](portrait_20_9/gathering.png) [已出现的旗帜](frost_flags.png) [地图记录](maps_android/result.json) |
| M07 | 四种货币说明混在一起 | 本轮范围通过 | Android原生触摸四个入口分别打开对应币种；详情展示完整大额余额，可滚动且关闭返回主城。金币1234567、远征币234567、魂晶34567、荣誉4567分别检查。[操作记录](native_interactions.json) [金币详情](native_currency_gold/adb_screen.png) |
| M08 | 骑手与坐骑比例姿态 | 部分通过 | 四职业、马与熊、四方向、四步态帧共128张实际Android画面，基本坐姿和组合未见原反馈中的明显脱离。长时间动态美术观感及其他坐骑不能据此一并验收。[马组合](mounts_android/horse_poses.jpg) [熊组合](mounts_android/bear_poses.jpg) [检查](mounts_android/result.json) |
| M09 | 马匹步态与蹄声 | 部分通过 | 普通移动、疾行各15秒实际Android录屏；移动、转向、松手及顶边界已检查。脚本接地相位和事件误差最高约18ms，但没有物理声路声画延迟证据。[移动记录](motion_analysis.json) [普通录屏](motion_normal_15s/android_screenrecord.mp4) [疾行录屏](motion_sprint_15s/android_screenrecord.mp4) |
| M10 | 文字框按钮风格与可读性 | 未通过 | 货币、阅读、战报已有可用样本；誓约卡片奖励行越界，多个操作按钮有效尺寸低于本轮44逻辑像素检查线。全组件推广和视觉确认尚未完成。[誓约](oath_overlap.png) [四比例结果](portrait_20_9/result.json) |
| A01 | BGM切换和停止 | 本轮机制通过 | 同曲不重启、快速换曲最终曲目正确、停止取消旧淡化回调均在Android执行。未把极短片段等同整曲听感合格。[音频检查](audio_android/result.json) |
| A02 | 静音与零音量 | 本轮范围通过 | 全局静音与音乐音效同时归零，捕获样本均全部为0；原生开关可恢复。普通入口静音开启后保存、强制结束、重启，界面与存档仍为开启，之后已恢复关闭。[零样本](audio_android/result.json) [重启后设置](normal_flow/mute_after_restart.png) [重启存档](normal_flow/saved_after_restart.json) |
| A03 | 并发叠加截断与优先级 | 未通过 | 总并发受限、已有胜利音受到保护，但boss_warn与low_hp占满两个Alerts名额后，新victory被直接丢弃。音频套件13项有1项失败，不能称全部通过。[失败记录](audio_android/result.json) |
| A04 | 重复声与触发时机 | 代表场景通过 | 原生长按背包打开只记录一次ui_open，四页签各一次ui_page，关闭一次ui_close；语义反馈合并通过。未覆盖每个奖励、失败与取消操作链。[原生操作](native_interactions.json) |
| A05 | 落蹄触发 | 部分通过 | 正常最高速度175，疾行218.75；分别50与55个蹄声事件。四段顶边界静止期间0蹄声，松手后无残留；物理声画时差仍待设备录音。[分析](motion_analysis.json) [内部混音](motion_normal_15s/motion_mix.wav) |
| A06 | 后台与音频设备变化 | 部分通过 | Home退后台、回应用、展开收起通知栏已实测，暂停恢复和清理短音正常，同一进程未重启BGM。来电、耳机拔插及蓝牙切换没有实体设备证据。[生命周期](lifecycle_summary.json) [系统通知记录](lifecycle.json) |
| A07 | 音色响度与循环 | 待主观验收 | 34种短音已在Android依次触发并捕获约16.14秒内部混音，六首BGM有源文件接缝数据和一次Android跨循环检查。没有完成手机外放主观试听，仍须逐条记录奇怪音色与替换意见。[试听文件](audio_catalog_android/sfx_catalog.wav) [触发时间表](audio_catalog_android/result.json) [BGM数据](source_music_loop_stats.json) |

## 未解决与新增问题的修改方案

### N01 誓约说明越过卡片边界

优先级P2，关联M03和M10。在四种比例均可见，首条说明实际最小高度83逻辑像素，却仅预留72像素；卡片132高、步进140，奖励行落在卡片外并挤近下一行。

定位：远征/src/ui/OathPanel.gd，第27、44至45行附近。应把誓约卡片改为VBoxContainer自动测高，标题、说明、奖励分行；列表放入ScrollContainer，返回按钮固定在安全区。卡片背景随内容高度调整。不要仅缩小字号或继续微调某个y坐标。

复测：三条誓约和长奖励名、已解锁与未解锁状态，在四种比例全部检查；滚到最后一条后仍能返回。证据：[截图](oath_overlap.png)、[实际文字尺寸](oath_geometry/result.json)。

### N02 胜利音在警报并发时丢失

优先级P1，关联A03。复现顺序为boss_warn、low_hp、victory；前两个占用Alerts的两个名额，事件记录中没有victory。

定位：远征/src/autoload/Audio.gd，第116至142行附近。当前先执行类别上限return，再考虑优先级替换。应在类别满额时找该类别中优先级最低且允许中断的音源；高优先级结算音替换低优先级警报，保留全局并发上限。若没有可替换对象，再按明确规则排队或丢弃；不要简单增加通道数量掩盖问题。

复测：两个警报在播时胜利音必须启动；已有胜利音不被普通战斗音抢占；高密度战斗峰值与并发数仍受限。证据：[失败的check及事件列表](audio_android/result.json)。

### N03 背包四列布局仍按五列移动焦点

优先级P2，新增。屏幕中网格为4列，但第一格向下实际跳到第六格。此项主要影响方向键与手柄，不等同触摸点击失效。

定位：远征/src/ui/BagPanel.gd，第440至441行附近。网格布局已动态计算columns，焦点仍使用i-5和i+5。应共用实际GridContainer.columns并在列数和列表重建后重新布线，处理末行、空格与关闭按钮。

复测：2至6列、末行不满、四页签及滚动后焦点都落在视觉相邻格。证据：[expected 4与actual 5](portrait_20_9/result.json)。

### N04 多处小按钮触控范围偏小

优先级P2，新增，关联M10。本轮以44逻辑像素作为检查线，发现买卖按钮60×34、倍速箭头42×34、帮助68×36、召唤领取92×38、部分返回140×38、游客280×40和密码眼44×39等类型。它们不一定越出屏幕，但窄的有效触控高度增加误触和漏点。

应统一组件最小交互尺寸，视觉装饰可以较小，透明点击区应扩大并避免相邻重叠；滚动列表须同时验证手指拖动与点击取消。44是当前逻辑视口检查值，不能不经换算当成Android dp。

复测：Android原生触摸逐个点击，包含边缘、相邻按钮、滚动取消和长按；文字与图案无需为扩大热区被拉伸。

### N05 主城底部被系统三键导航覆盖

优先级P1，关联M04。普通入口和诊断入口均复现。1080×2400下系统导航栏实际占据[0,2274]至[1080,2400]的126物理像素；游戏安全区仍报告底部保留0，顶部只避让挖孔。

应从Android窗口统一取得systemBars、displayCutout及IME信息，按窗口到逻辑视口变换一次。交互布局使用稳定的系统栏保留区域，背景继续铺满，IME单独参与登录表单布局；监听Insets与窗口变化。Android提供getInsetsIgnoringVisibility取得忽略当前可见性的系统区域，IME不能用这个接口直接推算；具体接入须按Godot Android桥接实现验证。[Android官方WindowInsets](https://developer.android.com/reference/android/view/WindowInsets)，[Godot DisplayServer安全区说明](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area)。

复测：三键、手势、临时唤出、通知栏、后台恢复、键盘与顶部挖孔组合；主城、地图、背包、设置、登录都必须保持按钮可触摸。不要写死126像素。证据：[普通入口截图](normal_flow/home_threebutton_native.png)、[系统窗口](normal_flow/home_threebutton_window.txt)、[游戏安全区](home_threebutton_probe/result.json)。

### N06 运行中切换导航模式后退出

优先级P1，关联M04，原因待定位。地图打开时切换手势为三键后PID消失；本次ApplicationExitInfo记录reason SIGNALED、status9即SIGKILL，没有本次原生Fatal signal证据。因此本次只能记录“切换后退出”，不能直接写成Godot或Scudo崩溃。

此前另一轮存在独立Scudo InputEventReceiver abort日志，保留于上一份报告，不能用来替代本次退出原因。应围绕窗口重建、输入接收器销毁、Activity生命周期及系统杀进程原因另取完整trace；先在同版本普通包稳定复现，再确定工程或引擎层修复。

复测：地图、主城、输入框聚焦时分别切换导航，确认应用保持或按系统策略重建后恢复存档与画面。证据：[本次操作](navigation_change.json)、[系统退出信息](android_exit_info.txt)、[日志](navigation_change_logcat.txt)。

## 手机适配应如何继续修改

先完成N05的统一安全区数据，否则页面各自留边仍会漏掉临时系统栏。随后把页面分成“整页”和“弹窗”两种明确规则：整页头尾锚定安全区，中段自动布局或滚动；弹窗受可用高度约束，允许设计留白。加载插画保持比例覆盖，进度与提示单独锚定，不把整页按高度拉伸。

优先迁移誓约、商店、召唤和演武等残留固定画布页面，统一文字自动测高和触控区域；保留已经通过的货币及战报页面作回归样本。最后逐一核验图样、场景状态与听感，避免把“资源能加载”“声音有事件”写成美术和音色验收完成。

建议修复顺序：N05安全区与N02音频优先级 → N06退出定位 → N01文字布局与M03整页规则 → N03焦点与N04触控 → M02/M06/M08/A07的目标图样、场景状态及音色验收。每项修复后都使用对应Android操作复验，再更新状态。

## 普通入口与动态检查记录

普通入口实际走过加载、标题、登录密码输入、收起键盘、序章跳过、地图、营帐确认、主城、设置、重启及桌面图标。这里的输入账号来自测试存档，密码为专用虚拟测试字符串。静音重启前后存档audio.mute均为true，随后恢复关闭。

正常移动与疾行各15秒Android系统录屏，另有逐物理帧位置、速度、步态相位和蹄声时间戳。内部混音与系统视频分别保存，不把合成到一起的音视频伪装成物理声路同步证据。诊断独立运行的一场自动战斗实际在约8秒获胜并出现可滚动战报；它不能替代所有战斗技能和关卡操作验收。[实际战斗](battle_android/battle_initial.png)，[战后当帧](battle_android/battle_after8s.png)。

18图静态取样冻结过程以免巡检被怪物接触战斗打断；部分早期未冻结取样进入了真实战斗，已保留原记录但不算该区域素材验收。地图样本使用定点定位，不能据此判断实际通行和碰撞是否正确。宠物页的补充截图出现首次帮助弹窗，遮挡的底层页面未计入完整布局验收。

本轮还遇到一次模拟器整体无响应，连ADB echo都超时，重启自有模拟器后恢复；该环境异常单独保留，不归为游戏卡死。宿主音频故障日志同样单独保留。[宿主音频日志](emulator_host_audio_failure.log)。

## 待补验收项

- 用户实际ARM64手机的安装包和厂商系统行为，以及旧存档覆盖安装后的连续游玩。
- M02选定图标母版、主题图标和其他桌面遮罩。
- M06全部任务分支、两类旗帜状态和场景交互通行；静态抽样不等于全部道具台账。
- M08长时间动态美术与全部其他坐骑；M09/A05手机物理声路的声画时差。
- A04全部领取、失败、取消与复杂返回链；A06来电、耳机与蓝牙切换。
- A07手机外放、耳机的主观试听，逐条记录需替换素材及目标音色。

## 结果文件索引

[机器可读问题清单](issue_results.json)，[所有取证文件索引](evidence_index.json)，[屏幕与音视频浏览页](index.html)。

核心数据：四屏比例目录portrait_16_9、portrait_18_9、portrait_20_9、tablet_10_16；资源resources；地图maps_android；骑乘mounts_android；音频audio_android与audio_catalog_android；移动motion_normal_15s与motion_sprint_15s；普通入口normal_flow。每个诊断目录内都有result.json及对应截图，音视频目录另有WAV或MP4。

