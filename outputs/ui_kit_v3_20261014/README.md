# 远征 UI v3 生图交付

日期：2026-10-14。按 UI_KIT_V3_IMAGE_REQUIREMENTS.md，使用内置 image_gen 生图工具生成，附对应布局图和主页、设置风格参考。共 8 张素材表、41 件，画布均为 1536×1024。

交付 PNG 直接复制自生图工具输出，未截图、未转 JPG、未改图像像素。每张的完整首轮提示词见同名 `.prompt.txt`，选入交付的修订提示词见 `.revision.prompt.txt`。源文件路径记录在 `generation_manifest.json`。替换前的初稿保存在 `drafts/`。

| 素材表 | 件数 | PNG 原图 |
|---|---:|---|
| 主按钮三态 | 3 | [UI3-01_primary.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-01_primary.png) |
| 按钮、页签、胶囊 | 7 | [UI3-02_buttons.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-02_buttons.png) |
| 面板与组标题 | 3 | [UI3-03_panels.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-03_panels.png) |
| 标题牌、名牌、分隔线 | 4 | [UI3-04_plaques.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-04_plaques.png) |
| 开关、滑条、步进器 | 6 | [UI3-05_controls.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-05_controls.png) |
| 稀有度格子 | 7 | [UI3-06_slots.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-06_slots.png) |
| 底栏、图标座、出征圆章 | 6 | [UI3-07_nav.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-07_nav.png) |
| 条、货币、任务条 | 5 | [UI3-08_bars.png](D:/new-bee/outputs/ui_kit_v3_20261014/UI3-08_bars.png) |

## 检查结果和未通过项

格式、画布和数量已通过检查：8 张 PNG、41 个可分离主体，无缺件、无主体粘连。目视未发现文字、人物或功能图标；滑块的小十字星刻纹按该表专门要求保留。

严格像素验收未通过，不能将原图视为已经完成游戏接入的素材：

- 背景看起来是品红，但生图输出存在 RGB 波动，不是每个背景像素都等于 #FF00FF。多次强调纯色后仍未得到精确纯色，交付保留原图，如实记录。
- 素材大体沿布局摆放，部分圆章、细条和胶囊仍有尺寸、比例、位置偏差；明细见 `generation_qa.json` 中的 source_box、aspect_error 和 overflow_px。aspect_error 是比例偏差的绝对值（0.1 表示 10%）。
- 同组状态的轮廓接近，但未经像素掩模统一，不保证逐像素完全相同。
- 装饰已经尽量收回端部和角区，但九宫格切线内的严格装饰限制以及中段无缝平铺仍需逐件复核，不能仅凭画面判断为完全合格。

检查复用了现有 restore_ui_kit.py 的品红识别和主体检测逻辑，仅读取图片并写检查数据，没有执行还原，也没有替换游戏资源。背景属于现有还原脚本可识别的品红色域。

`ui_kit_spec.json` 是需求配套规格的原样副本。按需求第 6 节，后续还原、preview/report 复核、备份旧素材和游戏接入留给用户执行。
