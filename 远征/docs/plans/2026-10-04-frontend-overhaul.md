# 远征前端视觉更新 · 2026-10-04

## 已落地的方向

标题改用马善政书法字体；主要按钮和数字显示采用站酷庆科黄油体。正文保留清晰的常规黑体，辅助信息使用宋体。标题工厂改为开放题签，字体入树后重新校准位置，避免新字体行高造成遮挡。

公共纸页、按钮、标题和浮层按照所在功能选择主题。营帐首页重做入口的大小、层级、配色和图标；世界 HUD、NPC 名牌、建筑标牌、对话、战斗指令、养成入口和登录流程同时更新。

| 主题 | 使用范围 | 视觉细节 |
|---|---|---|
| 行路图志 | 世界、地区地图、筹备、机关 | 蓝灰、淡青纸页、制图刻度 |
| 钢铁工坊 | 装备、强化、宝石、精炼、背包、技能书 | 钢蓝、银灰纸页、双边线和铆钉 |
| 草木养成 | 天赋、伙伴、坐骑、垂钓 | 苔绿、浅草纸页、细小叶饰 |
| 星砂灵契 | 图鉴、召唤、词条、灵契 | 紫灰、浅紫纸页、细线和符文 |
| 绛红演武 | 竞技、战斗、称号 | 酒红、浅绛纸页、侧边嵌条 |
| 皮革商旅 | 兑换、交易、港务、物资 | 栗棕、象牙纸页、皮革缝线 |
| 行旅书册 | 任务、邮驿、剧情、登录、城内对话 | 炭褐、书册纸页、装订细节 |
| 素纸设置 | 设置、头像、姓名恢复 | 蓝灰、素白纸页、简洁细边 |

同一页的主要行动和返回、关闭等次要行动有不同层级。登录、头像及建筑服务使用的原生按钮也随页面主题调整，保留原来的点击与键盘行为。

## 像素资产与降噪

- 原创 24 枚 32 × 32 彩色像素图标，采用有限色阶和硬边，运行时使用最近邻采样。保留 SVG 回退。
- 3 张页面风景制作 240 × 400 逻辑网格版本，放大到 480 × 800；使用中值过滤、无抖动调色板和近色合并。
- 43 张地表、地砖、道路和伙伴素材制作独立精修版本。大地表统一到 2 像素网格，图集保持原尺寸、切片位置与碰撞布局。
- 使用 Pixel Art Studio 完成像素绘制和清理。`despeckle` 负责去除小的透明轮廓孤岛；不把它作为不透明图片的颜色噪点过滤。后者使用中值过滤与调色板收敛。
- 原素材保留；有精修版本时才替换显示路径。角色行走素材与正在进行的角色动画工作不在本次修改范围内。
- 赤尾狐、夜猫、石龟、雪团等非人物头像继续可用，自定义上传和旧存档头像迁移保留。

资源目录：`assets/ui/pixel_icons`、`image/background/refined`、`image/map_proc/refined`、`image/main_world/refined`、`image/generated_362_xajh/ready/pet/refined`。

可再生成的源文件：`../pixel-art/expedition-ui/build.py` 与 `tools/refine_interface_art.py`。清理报告见 `frontend-refined-art.json`，像素图标尺寸与颜色报告见 `frontend-pixel-icons.json`。

## 动效与布局细节

- 页面和入口分次浮现、轻微缩放；营帐图标悬停上移。
- 卡页滑动和淡入；选中标题短暂提亮。
- 对话逐字呈现：第一次轻点补全当前句，下一次轻点继续。
- 生命、经验条平滑变化；场景只保留少量慢速微光。
- 保留已有战斗施法、受击、震动与结算演出。
- 长对话根据完整换行高度向上展开，页脚独立；任务提示避让对话框。
- 港务船单长文在独立阅读区滚动，接单及返回按钮不被文字遮挡。
- 长屏跟随自己的视口定位；嵌套页和弹窗保持可点击区域。

真实运行的动画帧由 `MotionPreviewRunner.gd` 记录，`build_frontend_motion.py` 使用固定调色板制作三段 GIF。预览与游戏使用同一套界面。

## 字体来源与许可

- [马善政 / Google Fonts](https://github.com/google/fonts/tree/main/ofl/mashanzheng)，`assets/fonts/MaShanZheng-Regular.ttf`，许可随附 `mashanzheng-OFL.txt`。
- [站酷庆科黄油体 / Google Fonts](https://github.com/google/fonts/tree/main/ofl/zcoolqingkehuangyou)，`assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf`，许可随附 `zcoolqingkehuangyou-OFL.txt`。
- 两者均为 SIL Open Font License，未安装到系统字体目录。
- 原有正文及回退字体继续保留，玩家姓名及非核心字符使用字体回退。

## 验证与查看

预览入口：`shots/frontend_overhaul_20261004/index.html`。包含精选页面、全页面图库、标准屏与长屏切换、放大查看、真实动效及前后对比。总览图为同目录 `overview.png`。

检查使用 Godot 4.7.2，在隔离存档目录中运行；没有写入玩家真实存档。

章节、课程和补领奖励的预览使用显式构图存档，由 `VisualSourceFixture.gd` 生成并通过真实存档写入、回读校验。它们用于检查界面布局，不代表自然通关证明。截图工具会拒绝缺失存档、JSON 错误、脚本错误、非零退出和只有单色的空白渲染；已重新捕获原来缺少测试源档的页面。

- 完整界面矩阵：273 个场景、子页面及状态，含 480 × 800 和 480 × 1067 两种比例。
- 精选界面：35 个代表状态，每个比例各一份，共 70 张完整截图。
- 相关回归 16 项：BattleScene、UiLayout、VisualRefresh、City、GameHome、MapScene、MainWorld、Workshop、Gacha、Panels、Growth、Perf、Transit、Arena、Avatar、Nav。
- 有效检查包含导航闭环、嵌套视口、长文保留、长对话页脚、船单阅读区、提示避让、按钮可点击性、名牌避让、字体核心字形、八种主题正文及主要动作对比度。
- 最后针对演武标题和原生按钮调整复查 Arena、Avatar、Nav、Perf、VisualRefresh。
- 修复章节预览源档后，另外通过 Curriculum 和 CampaignGear 两项课程及补领交互回归。总计 18 项不同的相关回归检查通过。
- 检查结果、日志与捕获清单分别保存在预览目录的 `verification`、`verification_final_polish`、`results.json`、`matrix/results.json`。

本轮验证是实际游戏的桌面离屏渲染和输入回归，尚未进行手机真机触控测试。引擎已有的 Windows 根证书读取及退出时资源诊断继续按回归工具原有规则单独记录；脚本错误和其他运行错误不作为通过。

再现截图：`tools/capture_crafted_game.py`、`tools/capture_visual_matrix.py --extras`；生成审阅页：`tools/build_frontend_review.py`。截图工具需要传入本机 Godot 路径，并使用本次预览目录作为输出。
