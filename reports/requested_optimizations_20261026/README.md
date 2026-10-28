# 背包 地图与场景优化完成说明

2026 年 10 月 26 日，版本 0.2.3-optimization。

已落实附件中的四项反馈，并生成 Android ARM64 安装包。修改基于当前工作区，保留此前未提交的界面、玩法与素材改动。

## 安装包

[下载 Android ARM64 安装包](./Yuanzheng-0.2.3-optimization-arm64.apk)

包名为 `org.yuanzheng.singleplayer`，版本号为 5，使用本项目既有调试签名。最终体积、SHA-256、签名与包内核验结果见 [安装包核验记录](./package_verification.json)。

## 四项修改

| 附件反馈 | 已完成的行为 |
| --- | --- |
| 背包所有物品能查看详情或说明 | 装备点击后显示属性、当前装备比较、装备条件、词条与宝石孔；材料、券、任务物品、鱼获、商货显示对应用途；宝石显示具体属性数值及合成说明，最高级宝石单独提示。待领取装备可先点图标预览，领取与预览分开。物品格增加名称，宝石格使用“生命·5级”等短名称保留属性和等级。 |
| NPC 和景物跟随人物放大，空旷地图补素材 | NPC 形象增加 18%，房屋增加 10%，已有独立景物增加 12%；脚点和名牌随形象校准。十八张地图共补充 211 处地貌装饰，沙漠使用仙人掌和砂岩，雪地使用雪松、雪堆与冰晶，港口使用货箱、灯具和桌案，洞窟与碑阵使用石块、残碑。补景使用独立固定种子，避让出入口、交互点、建筑、主路与敌人，不改变玩法随机数和碰撞配置。 |
| 地图不好用，检查按钮并取消中间线条 | 去掉地理详图中的程序道路线及导航折线；保留地表、方位、玩家与地点标记。加入分级放大和缩小、定位、六类带数量的筛选、可滚动地点列表和聚合点选择。无地点分类置灰，追踪中禁用重复提交，无追踪时禁用取消。地点选择、追踪保存、取消、世界总览和返回保持独立功能。 |
| 去掉背景像素过滤查看效果 | 找回十五张地图未经降采样的原始高清图片，直接按原世界范围显示，跳过旧的 480×624 降采样再放大版本与 refined 像素清理副本。关闭平铺材质中额外的像素网格、颗粒抖动和暗角分支，以及旧地表颗粒层。环境景物使用平滑采样。素材原本画出的像素笔触仍属于原画。 |

地图标记分类参考了 [GTA / FiveM 的公开图标资料](https://docs.fivem.net/docs/game-references/blips/)，实际图标和地图素材使用项目已有资源。

## 实际截图

- [装备详情与比较](../../远征/shots/requested_optimizations_20261026/bag_equipment.png)
- [材料用途说明](../../远征/shots/requested_optimizations_20261026/bag_material.png)
- [宝石属性和等级说明](../../远征/shots/requested_optimizations_20261026/bag_gem.png)
- [待领取装备预览](../../远征/shots/requested_optimizations_20261026/bag_pending.png)
- [地理详图与功能按钮](../../远征/shots/requested_optimizations_20261026/map_480x1067.png)
- [320 宽度地点列表](../../远征/shots/requested_optimizations_20261026/map_list_320x640.png)
- [十八张地图画面](../../远征/shots/requested_optimizations_20261026/worlds_contact.png)
- [NPC 与房屋比例](../../远征/shots/requested_optimizations_20261026/world_lorin_wilds.png)

相同地图、人物位置及装饰下的背景对照：

| 场景 | 原稿显示 | 此前降采样版本 |
| --- | --- | --- |
| 旧盐道 | [当前原稿效果](../../远征/shots/requested_optimizations_20261026/world_old_salt_road_middle.png) | [旧处理对照](../../远征/shots/requested_optimizations_20261026/world_old_salt_road_processed_comparison.png) |
| 赤砂商路 | [当前原稿效果](../../远征/shots/requested_optimizations_20261026/world_red_sand_route_middle.png) | [旧处理对照](../../远征/shots/requested_optimizations_20261026/world_red_sand_route_processed_comparison.png) |

## 验证与边界

专项完整验收通过 478 项检查，覆盖十八张地图；追加的界面检查通过 331 项，覆盖真实触摸选物、滑动不误选、待领取预览、地图标记点击、分类、缩放、定位、拖动、追踪、取消及三档窗口布局。背包原有回归最终通过 518 项，相关页面与实际导航回归通过 78 项，十八图原有回归通过 123 项。完整专项记录见 [世界与界面验收](./world_acceptance.json)，其余日志保存在本目录。

安装包中的编译代码另行运行核验 60 项；十五张原始地表均能从包内读取，57 份数据文件与工程一致，APK 签名核验通过。包内运行使用桌面 Godot，不代表 Android 真机测试。当前未连接 Android 设备，手机触摸手感、系统栏安全区和性能仍需安装复验。

引擎在本机启动时报告系统证书存储读取错误；相关保存失败测试还会主动触发锁写警告。上述记录与功能断言分开保留。

五个现有着色器均通过编译检查，包含本轮修改的地表材质；本轮源码差异检查通过。

## 修改记录

- [本轮源码清单](./source_manifest.json)
- [相对实施前工作区的增量修改](./changes.patch)
- [十五张高清原稿的来源和哈希](./original_art_manifest.json)
- [安装包核验脚本](./VerifyPackage.ps1)

实施前源码存于本目录本地忽略的 backup，临时测试和解包目录位于 runtime。新增原稿保存在正式工程 `assets/world/original_backgrounds_20261026/`，不依赖工程外的图片路径运行。
