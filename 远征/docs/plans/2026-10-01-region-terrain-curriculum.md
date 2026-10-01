# P08-E5 区域地面与后三式技能

## 本轮范围

主角色重绘后置。先统一沉渊港、霜关驿地面，保持实际道路、出口、实体碰撞与剧情地貌回应；随后接通四职业后三式的正常取得路径。整体重构未完成，第四幕、副本、多种成长路线及 Android 验收继续保留。

## 地貌规则与素材登记

新增 `shenyuan_port_ground_reference_v2`、`frost_post_ground_reference_v2`，仅替换地面画面。原生 Godot 渲染底图保存于 assets/source，旧地砖和程序几何保留作回退。生成使用内置 imagegen，每项独立调用。洛林 v6 仅供细腻纹理风格参考；实际通行几何以原生底图为准。背景不烧入建筑、人物、文字、HUD 或可变剧情物件。动态船缆、供货船/粮袋、旗帜与火盆保留运行时层。

### 港口完整提示词

Edit image 1, the actual 960×1248 full-map terrain of Shenyuan Port, into a refined readable classic Chinese fantasy 2D RPG ground background. Image 2 is ONLY the style reference: fine, crisp hand-painted pixel details and restrained low-contrast surface texture, not chunky block pixels. Keep the exact terrain plan and proportions of image 1: central paved vertical street x408–552 runs full height, narrow ground banks x320–408 and x552–640, blue-green water outside x320 and x640; upper crossbridge x315–645 y372–450, lower crossbridge x315–645 y838–916; western exit jetty x0–408 y640–702; eastern exit jetty x552–960 y675–737; four existing rectangular timber platforms at x270–405 y222–382, x555–690 y352–512, x270–405 y855–1039, x555–690 y852–1057. Preserve all path centers and width and empty platform footprints. Replace large plain stone blocks with fine small weathered pale limestone paving and subtly irregular seams, keep a clearly open central street. Paint fine wood grain, small plank joints, worn edges on the same bridges and platforms. Add subtle flowing teal water ripples and tiny shoreline foam with no large waves. Understated sage ground banks, moss only at shore edges. Two existing simple tide marker posts remain understated. Strict flat top-down gameplay ground, no horizon, no perspective camera, no buildings, no people, no trees, no ships, no crates, no new obstacles, no text, no UI, no border, no vignette, no chunky outlines, no highly noisy surface or photorealism. Match the style reference's fine texture density and readable subdued palette. Fill the whole portrait image with this map; preserve composition of image 1 exactly. Opaque background.

## 技能规则（实施前登记）

沿用每职业现有五式 ID 和原有战斗机制，前两式取得、熟练与分支保留。后三式按角色技能表第 3/4/5 项依序学习：等级 12/25/35，已完成 s12/s20/s24，并学会前一式；学费分别 100/160/240 金。导师在原实体入口提供后续招式，显示条件、费用和技能实际效果，不自动赠送或替玩家装备。

每招在不同遭遇内产生真实效果 2/2/3 次后可选两条分支；同场多次施法计一次，遭遇 ID 重放不增加。命中伤害、实际治疗/护盾、成功清除负面或真正施加增益/控制均可计入；空目标、零清除、满血且未附加效果不计。分支仅采用已实现的消耗、冷却、倍率/效果修正，每项文案与实际规则一致。重置分支 120 金，保留熟练。学习/分支/重置/战后计入均须写档成功，失败回滚，受存档锁保护。

存档沿用当前 v6（装备实例容器仍延续 v5 结构），新增可选 skill_curriculum 状态；旧档缺键正常，已有技能等级、装备、伙伴、前两式与钱包不重置。保存解锁、熟练、分支、已计入遭遇；读档严格校验无效技能/角色/数值/分支。正式回归新增独立用例，另以四职业真实输入和 A/B 独立读档验证。

## 已交付与验收

- 两张背景已复制入 `image/main_world` 并配置运行时使用，不留在生成目录。最终尺寸1100×1430、不透明、单张约2.5MB；960×1248原地图比例一致。原底图与旧几何保留，布局配置仅变两个背景字段。港口基础地貌与动态供货/船缆分层，霜关已绘栈道/石头不叠加旧粗块，动态旗帜和火盆继续绘制。
- 四职业后三式全部接通。导师表和研习页展示实际任务名称、等级、前式与学费；学会后即进真实技能列表。稳式降低能量、延长2秒冷却；疾式增加能量、缩短2秒冷却，伤害招基础倍率另乘1.15，条件增伤仍采用原技能规则。增益/控制/驱散使用独立 `curriculum_effective` 事件；原导师 `skill_effective` 的伤害/治疗/护盾口径保持。
- 最终全量 `curriculum_region_accept.log` **43/43**；新增 VerifyCurriculum 覆盖12招真实效果、旧档只读不赠送、等级/剧情/前式/学费守卫、每遭遇去重、满熟练截断、分支入战斗副本、重置、读档校验、四项写失败/锁保护以及实际导师学习/选分支/重置回调。回归表 `Expected=43`；运行器故障注入 **11/11**。
- 四职业从已验收的E4三幕旧档副本继续：霜关→赤砂→沉渊港→旧盐道→枫林→昭元，真实接近岳教头、点招式表及三次学习按钮。各100/160/240金，全部1665→1165。A/B独立进程状态、原始存档字节一致；装备/技能等级/伙伴/坐骑/道具/前两式不变，旧主线和已有支线不重置。沿途正常接受 `a3_eco_lichen`，进度0、无奖励。两个终态日志分别为 `curriculum_accept_zs_fs.log`、`curriculum_accept_ck_fz.log`。
- 18张普通屏/长屏图目检与尺寸检查通过，哈希清单 `shots/curriculum_region_20261001/acceptance.json`。原玩家存档SHA256仍为 C5D29EE55C033619C4F5232D55A6C4F186D40ADD556DB61EE0D776B9FDA2660C；主角素材/动画、道路与碰撞均未修改。

失败记录保留在 tools/_logs：初次新测试静态类型推断已修正；全量首轮发现无prog旧档访问与增益实效侵入原事件，分别修正守卫、拆分事件后最终43项通过。真实输入首轮斜穿枫林树丛阻挡、误把路边弹窗当导师；回放改沿现有横路/主街、关闭其他对话后继续移动，最终四职业通过。这些失败日志不计为通过证据，退出资源诊断仍按既有问题43追踪。

## 下一包与整体剩余门槛

先替换霜关 `frost_lodge` / `frost_supply` / `frost_guardhouse` 三建筑，宁砚/岑雪/陶铎三NPC及火盆占位，统一新背景与实体的画风；主角重绘继续后置。其他地区、怪物与登录/营帐画风仍待续。

本包真实输入证明取得12招并重启保留，未证明自然实战练满12招全部分支；分支效果、计数和失败回滚有正式测试。完整养成经济、伙伴成长素材/突破/进化、六坐骑、阵营关系/延迟合约/誓约、第四幕s29–s36和两首领、18条剩余支线、12种委托模板、多房间副本机关、全程时长/难度人工验收与Android仍须继续。内容数仍主线28/36、支线18/36、首领6/8、地图14；整体目标保持进行中，未启动联机阶段。

### 霜关完整提示词

Edit image 1, the actual 960×1248 terrain layout of Frost Post, into a fine, polished classic Chinese fantasy 2D RPG winter ground background. Image 2 is ONLY the surface texture/style reference: delicate crisp pixel painting with small natural details, a quiet readable background, not coarse square pixels. Preserve image 1's precise plan and proportions: central vertical timber boardwalk x426–534 y80–1180; upper horizontal boardwalk x335–595 y420–480; lower horizontal boardwalk x335–635 y840–900; eastern exit boardwalk x480–878 y680–740. Keep walkway centers and widths exactly unchanged and intersections fully open. Repaint wood with fine worn grain, small plank divisions and a thin dusting of snow at the edges. Surround with gentle blue-white snow, subtle wind sweeps, tiny sparse ice crystals, softly packed patches, and restrained small tufts at far edges. Replace high-frequency noisy repeating snow tiles with finely detailed but calm natural texture. The two angular rocks on the left at (165,245) and (165,1040) should become understated small natural snow-dusted stones in exactly those locations. REMOVE the two simple yellow lamp/post drawings centered around (365,630) and (595,935), leaving clean snow there: lamps are separate dynamic game objects drawn at runtime. Do not invent buildings or physical obstacles in the open snow; runtime houses and NPCs occupy it. Strict flat top-down game terrain, no horizon, no perspective, no characters, no trees, no buildings, no flags, no lanterns, no footprints that look like characters, no text or UI, no border, no vignette. Whole image filled with this map, opaque portrait background, exactly the composition of image 1. Fine readable pixel-art texture density matching image 2, understated pale winter colors and earthy timber.
