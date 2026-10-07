# 营帐图标与入口组件统一

## 设计决策

旧版货币、几何入口、底部像素小器物混用，轮廓重量与材质不一致。采用暗青黑铁、旧金、象牙白为界面基调；紫色仅用于魂晶/召唤，绿色用于养成。金币、行旅令牌、荣誉勋章采用不同轮廓，活动以封蜡请柬表达。

参考资料：Game-icons.net 的统一、简洁且有表达力的轮廓原则（https://game-icons.net/about.html）；Kenney Game Icons 的 CC0 素材方案（https://kenney.nl/assets/game-icons）；Supergiant UI Illustrator 工作流中的成套图标与可分层按钮（https://www.supergiantgames.com/blog/job-opportunity-ui-illustrator-for-hades-ii/）。仅作为设计/资源评估参考，没有接入其图案或游戏素材。

## 生产资源

内置 imagegen 模式，分别生成 13 个透明器物 PNG 和 1 个空底板。完整提示词与来源在 `assets/ui/illustrated_icons_20261007/generation_manifest.json`，切图区域在 `regions.json`。

原图完整保留。Godot 导入纹理上限 256px，并生成 mipmaps；AtlasTexture 使用对应缩放后的正方形区域，固定安全留白，避免各原图空边造成重量差异。图标采用 LINEAR_WITH_MIPMAPS，避免高清图缩到 24px 时的碎纹闪烁。缓存底板，防止绘制指令执行前纹理释放形成白块。

共享入口：UIIcons.resource_path 使四币在所有 G.res_tex 使用处保持一致；UIIcons.image 与 FieldUI.Prop 共用目录，保留旧键回退。未改变资源数值、红点、点击热区或自定义头像逻辑。

右侧入口：68×78 原生逻辑尺寸，统一 58px 黑铁旧金盾形底板、40px 主体、56px 文字基线。活动改为暗青旧金铆钉按钮。底部导航：112×72 热区、38px 图标与固定文字基线，普通态降低亮度，选中/悬停/聚焦亮起旧金装饰线，按下/禁用反馈可复用。营帐不伪装成某个底部栏目。

## 实际截图与验证

`shots/icons_20261007/home_800.png`、`home_1067.png` 为游戏实际渲染，`before_after.png` 为前后截图并排。`icon_sizes.png` 在暗/亮底色展示 40px 和 24px；`component_states.png` 验证普通、选中、按下、禁用与共享入口底板。四张标题/营帐截图的文字审计无裁切与文本过滤问题。

资源接入先截图，发现白块与未导入图鉴图标后修复，再截图；之后调整导入大小与 mipmaps，复查轮廓及重量。最后活动按钮统一色彩并重拍。

严格回归 VerifyAssets、VerifyGameHome、VerifySafeArea、VerifyPerf 通过（exit 0、自己的完成标志、无未允许错误）。性能记录：营帐 132ms/200ms，世界首次 28ms/100ms，图鉴首次 19ms/100ms。

另外运行的 VerifyUiLayout 与 VerifyNav 未通过：前者当前加载页 `_bar_fill` 已不存在导致空引用，后者新 LoadingRelic 非交互绘图组件被当作独立浮层要求 ESC。两项与本次图标接入无关，保留日志，不改动加载页或放宽检查规则，不宣称全项目全部通过。
