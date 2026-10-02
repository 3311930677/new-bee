# 第四幕后半与左右对战交付记录

2026-10-02，P09-C。游戏已续接第四幕后半：持归路凭证进入归路门厅，点亮锚点，在三声共鸣廊依次校准林声、潮声、雪声，进入碑心房击败渊脉化身，返昭元向闻叔交还记录并选择结局。两种结局均到Lv60、结束36步主线，三城有各自回应，世界仍可自由回访。结局后外环可挑战Lv60无名巡界者。

## 玩家可见变化

- 角色与伙伴位于战场左侧，敌人位于右侧；主世界和历练战斗均接入。
- 破军、晨星等近战角色的普攻及直接伤害技能会接近目标，接触时出现命中效果，然后回位。霜语、穿杨等远程角色保留施法/攻击站位，以带拖尾的飞弹命中。
- 斩击、穿刺、法术、锤击使用不同冲击形状，叠加光环、像素碎屑、暴击飘字、短暂后仰及闪烁；治疗有绿色脉冲。
- 命中表现和血条变化等到接触/飞弹到达再显示。动画不消耗战斗随机数，不改变战斗30Hz计算、攻击冷却、目标选择、技能耗费和伤害公式。
- 渊脉化身召出三地余响时分列显示，避免首领立绘和召唤物名牌重叠；破绽、阶段横幅和中文蓄力提示保留。
- 三间副本使用石砖、雕刻通道、柱脚与机关光纹。北门随世界旗解锁，南门始终可返；机关一次触发，进度随存档恢复。
- 新增三个主线固定装备节点；两首领各有固定首胜奖励及原创立绘。昭元图志阁的建筑菜单提供深渊首领图志入口，首胜后解锁对应图鉴。

进入方式：已有32步完成档继续任务，沿霜关驿→冰隘→渊口外环北门进入。完成碑心战后沿原路回昭元，找闻叔选择“封渊留路”或“留声守望”。两条结局均不要求抽取、市场或日常。

## 验证与边界

正式验收日志位于 `shots/fourth_back_20261002/evidence/`；汇总及SHA256见同目录 `acceptance.json` 和 `sha256.json`。

1. 全量回归47项，逐项要求退出0、自己的完成标记、没有脚本或运行时错误。运行器另有11项故障注入自检。原有issue43的引擎退出资源诊断仍单独记录，不能据回归通过宣告泄漏已修。
2. 四职业均从P09-B真实32步档副本完成机关、s35败北/撤退/读档再入/胜利、实际换装、返城实际选择结局。为覆盖败北边界，仅将地图当前生命设为1，日志明确标记；没有增加金币、经验、技能、宠物或装备资源。两种结局分别由破军/霜语与穿杨/晨星覆盖。
3. 穿杨在同一A过程完成主线、可选首领及副本返访，再由B新进程核对完整状态和存档字节。破军/霜语/晨星的原A回放在结局完成后的可选首领导航中暴露问题，保留原失败日志；修正后使用真实36步结局检查点续跑可选首领撤退/胜利、读档及三房返访，并各由B新进程核对。它们属于分段恢复证据，不声称原A整段通过。
4. `VerifyFourthBack` 覆盖锁写、缺任务物、重复结算、机关重复、首通不重刷、双结局和首胜去重；另使用不存在的隔离父目录让真实原子写盘失败，检查首领状态、封记、记录、钱包、背包与账本全部回滚。故障注入时临时关闭引擎错误打印，恢复后执行断言并输出明确的回滚检查标记；没有放宽回归运行器。
5. `VerifyFourthBudget` 从真实32步档读取原有投入，仅通过生产任务/机关/换装接口构建普通路线预算；不带宠物和历练词条，四职业×两首领×10种子共80次均胜利。破军/霜语/穿杨约54–62秒，晨星约130–147秒，不超过五分钟上限。该模型使用满血进场和至多两瓶标准药剂，不等价于人工通关时长。
6. 两种屏高480×800/480×1067的房间、阶段、预兆与结局已截图；近战和法师动画来自实际Godot渲染的逐帧捕获。捕获工具为阶段预置，仅作视觉检查，不能代替真实操作证据。截图日志没有SCRIPT ERROR；退出时仍有字体/RID及OpenGL纹理释放诊断，归入退出资源问题，未宣称干净退出。
7. 所有Godot过程启动前设置隔离APPDATA。正式玩家目录的文件与哈希对比见 `real_user_diff.json`；没有将测试进度写入真实档。旧装备实例、宠物、技能、天赋、坐骑、伙伴、课程与旧世界旗的保留由回放和证据脚本共同检查。

主线数量达到36/36、首领达到8/8，但整体单机目标仍未完成：支线18/36、12委托模板、旧三座副本房间链、坐骑/阵营/合约/誓约、完整经济成长曲线、人工12–18小时体验、安卓实机和声音体验仍是后续门槛。

## 原创素材来源

模式：imagegen `generate`，透明背景。原始输出复制到运行时目录并建立MonsterArt图集区域；没有使用已有游戏IP。像素分辨率由生成工具输出，运行时按角色高度缩放。三地余响为仓库原生SVG，战斗特效为Godot绘制代码。

渊脉化身输出：`image/fourth_act/mon_abyss_avatar_v1.png`。原始生成文件：`C:/Users/Administrator/.codex/generated_images/01a0fca8-a993-73c3-978c-3c75b8e16fd4/exec-2b73a02e-288c-4cbe-af50-31b4975476a4.png`。

实际提示词：

> Create an ORIGINAL full body 2D pixel art JRPG boss sprite, named abyss stele avatar: hulking living basalt guardian, asymmetrical three upright cracked black stone slabs around a floating cyan glowing core, tarnished bronze ring and small crimson binding cords, two heavy stone arms, heavy feet firmly grounded, restrained menace. Same production aesthetic as 1990s detailed hand-pixelled monster battle sprites: clean dark blue outlines, crisp clusters, limited cool slate/cyan/bronze palette, hard pixel shading; front three-quarter facing viewer slightly left. Isolated single character on FULLY TRANSPARENT background. Whole silhouette including feet fully visible, with generous 8 percent clear padding, no environmental ground/shadow plane, no text, no icons, no UI, no watermark, no border. Centered upright silhouette nearly square, art suitable to scale down to 150px high inside a Chinese portrait RPG. Keep luminous cracks sparse and readable, avoid painting/photo/3D rendering. Do not use existing game IP.

无名巡界者输出：`image/fourth_act/mon_nameless_warden_v1.png`。原始生成文件：`C:/Users/Administrator/.codex/generated_images/01a0fca8-a993-73c3-978c-3c75b8e16fd4/exec-29cda6aa-7244-45ac-a361-cade5c19e83e.png`。

实际提示词：

> Create an ORIGINAL full body 2D pixel art JRPG optional endgame boss sprite: nameless boundary wanderer, mysterious human-sized armored sentinel with a battered closed bronze helmet (no face), dark indigo layered cloak, pale weathered steel armor, crimson short cord, holds a long broken ceremonial glaive with a small amber glowing gem. Strong balanced feet planted, windblown short cloak, lean upright silhouette, front three-quarter facing viewer slightly left. Pixel monster sprite aesthetic, crisp dark blue outlines, clustered pixel shading, limited slate/indigo/tarnished bronze/amber palette. FULLY TRANSPARENT background. Whole body, whole weapon, cloak and both feet fully visible, centered with 8 percent clear padding. No ground plane, no environmental shadow, no text, no watermark, no border, no icons, no UI. Suitable for portrait Chinese RPG map and battle scene at 140px high. Not a painting, photograph or 3D render. Distinct readable silhouette. No recognizable existing game IP.
