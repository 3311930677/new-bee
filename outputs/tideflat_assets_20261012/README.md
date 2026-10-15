# 潮痕滩素材交付 · 2026-10-12

本轮使用内置 imagegen 生成，原始 PNG 全部保留，未进行截图、JPEG 转换、裁切或缩放。只修改需求文档并重新生成参考图；未改游戏代码。

## 建议使用的源图

| 编号 | 文件 | 内容 |
|---|---|---|
| TF-G01 | `TF-G01_ground_v3.png` | 1024×1536 地面；已修正北堤视角、减少开放区域杂物并校正北堤高度 |
| TF-P01 | `TF-P01_boats.png` | 旧渔船×1、小划艇×1 |
| TF-P02 | `TF-P02_driftwood.png` | 大漂木×2、小漂木×3 |
| TF-P03 | `TF-P03_posts.png` | 标尺×2、断桩群×3、系船柱×2 |
| TF-P04 | `TF-P04_fishing_props_v2.png` | 渔网架×1、蟹笼×2、货箱×1、木桶×2；已修正侧面视角 |
| TF-P05 | `TF-P05_rocks.png` | 大礁石×2、中×4、小×4 |
| TF-P06 | `TF-P06_grass.png` | 滩草×4、海蓬子×3 |
| TF-P07 | `TF-P07_boardwalk.png` | 西口栈道段×1，中央通行位置没有木桩 |
| TF-P08 | `TF-P08_water_animation_v2.png` | 上排潮池4帧、下排浪花4帧；动画美术源图 |

精灵实际原始尺寸为 1254×1254，均为 RGBA、具有真实透明通道。提示词中的画布尺寸和物件缩放没有被生成工具严格遵守，因此应按需求文档的目标物件尺寸单独拆图缩放，不能将整张图统一按提示词中倍数缩小。

`TF-G01_ground_v1.png`、`TF-G01_ground_v2.png`、`TF-P04_fishing_props.png`、`TF-P08_water_animation_v1.png` 是保留的早期版本，不是建议接入版本。

## 参考与复核

- `tideflat_guide_annotated.png`：960×1248，世界坐标核对版，出生点、出口、怪物、Boss、20个实体点及路网直接取自当前游戏配置。
- `tideflat_guide_gpt.png`：1024×1536，无文字色块版；顶部102行和底部103行的每一个像素都已验证为纯地面色 `(196,186,150)`。
- `style_ref_old_salt_road.png`：现有旧盐道风格参考。仅用于画工参考。
- `tideflat_design.json`：新潮池、盐壳、草地、北堤、海面布局。
- `tideflat_cfg_verified.json`：本次核对的完整地图配置快照。
- `TIDEFLAT_IMAGE_REQUIREMENTS.md`：需求文档，新增了准确裁切坐标、北堤开口边界及程序叠加层审计说明。
- `generation_prompts.json` 与 `revision_prompts.json`：实际使用的初始和修正提示词。
- `asset_manifest.json`：源图尺寸、透明通道检查与建议文件清单。

裁切约定：`[0,102,1024,1433]`，右/下边界不含。裁出1024×1331后缩为960×1248，禁止直接将1024×1536整图缩为地图尺寸。整数舍入误差小于1px。

## 后续接入注意

生成素材通过人工视觉检查，尚未完成游戏内接入验收，也未测定所有道路中心点是否满足16px偏差阈值。参考图与游戏坐标一致不意味着生成图每个像素都完全服从参考图。

TF-P08目前属于动画源图：数量正确，但帧间轮廓、裁切基准和左右拼接边缘还不是经过逐像素锁定的生产动画。拆帧时应统一固定轮廓和锚点，验证循环抖动及浪花横向拼接；不建议直接用整图的等分格导入 AnimatedSprite2D。

后续按需求文档关闭 TideflatGround 原水池与标尺、检查重复装饰层，并为北堤两段及东海增加碰撞。北侧到达点 `(480,200)` 保持开放。任务和怪物坐标保持原配置。

## 标注版实体编号

| 标注 | 实体 | 世界坐标 |
|---|---|---|
| P01 | 潮印货堆 (`tide_cargo`) | (410,700) |
| P02 | 潮痕浅池 · 垂钓 (`fish_tide_pool`) | (310,560) |
| P03 | 避风浅池 · 漂羽 (`a2_drift_feather`) | (625,850) |
| P04 | 北浅水 · 潮草 (`a2_tide_grass_a`) | (580,380) |
| P05 | 南盐纹 · 潮草 (`a2_tide_grass_b`) | (585,1015) |
| P06 | 南滩新芽 (`a4_tidebud_south`) | (480,390) |
| P07 | 北滩新芽 (`a4_tidebud_north`) | (480,810) |
| P08 | 船运潮线 (`herb_ship_tide_aid`) | (750,665) |
| P09 | 高水痕 (`a2_secret_tide_clock_step_1`) | (390,970) |
| P10 | 低水痕 (`a2_secret_tide_clock_step_2`) | (570,790) |
| P11 | 回潮线 (`a2_secret_tide_clock_step_3`) | (390,610) |
| P12 | 编排闸门时序 (`a2_secret_tide_clock_step_4`) | (570,900) |
| P13 | 巢位与浅痕 (`a2_eco_driftwood_step_1`) | (580,1000) |
| P14 | 搬开第一块漂木 (`a2_eco_driftwood_step_2`) | (390,900) |
| P15 | 搬开第二块漂木 (`a2_eco_driftwood_step_3`) | (580,740) |
| P16 | 沿浅线送木回岸 (`a2_eco_driftwood_step_4`) | (390,1060) |
| P17 | 未受扰动的巢边 (`a2_eco_driftwood_feedback_0`) | (580,990) |
| P18 | 观察潮芽根际 (`a4_eco_returnpath_step_1`) | (390,1020) |
| P19 | 设立轻触观察标记 (`a4_eco_returnpath_step_3`) | (580,1040) |
| P20 | 复苏观察标记 (`a4_eco_returnpath_feedback_0`) | (580,1020) |
