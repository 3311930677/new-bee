# 全界面视觉复查

当前项目入口：`D:\new bee\远征\project.godot`。运行后经过加载、标题和登录；已有存档进入主世界，点击「营帐」查看整备与养成界面。截图使用演示存档，玩家存档不受影响。

[打开可搜索的前后对照图库](index.html) · [修改及验收记录](../../../docs/plans/2026-10-02-global-visual-refresh.md) · [生成素材及完整提示词](../../../docs/plans/2026-10-02-visual-assets.json)

## 分类总览

- [启动、菜单和功能页](./_overview_1_ui.png)
- [城镇、建筑和居民](./_overview_2_city.png)
- [主世界与战斗](./_overview_3_world.png)
- [历练地图和后续区域](./_overview_4_acts.png)
- [交互、剧情和阶段状态](./_overview_5_staging.png)
- [480×1067 长屏](./_overview_6_long.png)

共 256 个场景与状态：206 张 480×800，50 张 480×1067。每个文件旁有对应运行日志；`manifest.json` 保存复现参数，`results.json` 保存出图结果。出图成功表示场景运行、截图保存及没有脚本错误，不能代替逐像素美术验收。

## 代表画面

[标题](title.png) · [登录](login.png) · [创角](createrole.png) · [营帐](home.png) · [装备](equip.png) · [地区图](worlds.png) · [普通战斗](battle.png) · [长屏营帐](long_480x1067/home.png) · [长屏战斗](long_480x1067/battle.png)

## 验证范围

修改前功能回归 42/44，通过新增视觉检查后的最终回归为 43/45。剩余 `VerifySave` 与 `VerifyStory` 的失败与修改前一致；最后地表补充检查 6/6 通过。回归工具确认玩家存档哈希未变。

长屏经过独立视口渲染和布局检查；手机真机触控尚未验收。原有职业、居民和伙伴动画以及部分旧地图构图继续沿用，具体范围见修改记录。

## 重拍

在项目目录执行 `python tools/capture_visual_matrix.py --godot <Godot console.exe>`。局部重拍增加 `--only 场景名,场景名`，会保留其他场景结果。重拍完成后执行 `python tools/build_visual_gallery.py` 更新图库及总览。
