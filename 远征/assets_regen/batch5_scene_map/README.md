# Batch 5：场景与地图素材

本批素材依据原版实机截图的色板、像素颗粒、地图密度和层次感重新生成，原版图片仅作为风格参考，不作为游戏素材使用。

## Ready 成品

- `ready/backgrounds/g_main_city_v2_768x1024.png`：主城背景
- `ready/backgrounds/g_lorin_wilds_v2_768x1024.png`：洛林郊野背景
- `ready/backgrounds/g_mountain_pass_v2_768x1024.png`：山道关隘背景
- `ready/backgrounds/g_black_wind_camp_v2_768x1024.png`：黑风寨背景
- `ready/map/h2_grass_tileset_v2_256x256.png`：4×4 地表图集，逻辑单元 64×64
- `ready/map/h3_map_deco_atlas_v2_256x256.png`：4×4 装饰散件图集，逻辑单元 64×64，黑底待抠图

## 处理记录

- 生成原图保存在 `raw/`，未覆盖。
- 背景统一裁切为 3:4，降到 384×512 逻辑像素，再 nearest 放大到 768×1024。
- 两张图集统一降到 128×128 逻辑像素，再 nearest 放大到 256×256。
- 输出已做无抖动色彩量化；H3 接入地图前仍需按格切片并将黑底转透明。

