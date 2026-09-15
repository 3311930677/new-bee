# 001–050 图片生成批次

来源：`docs/2026-09-15-图片提示词总库.md` 的总序号 001–050。

实际完成001–047，共47张。048–050因内置生图额度耗尽未生成。用户已扩大目标至前100条；续跑清单见相邻目录`../generated_001_100/jobs.json`，共53条待生成。

总览：`overview_001_024.png`（地面）、`overview_025_047.png`（连接套件与散件）。尺寸、模式、色数检查见`qa.json`。当前20张散件中10张有透明通道，另10张为RGB背景图，仍需去背。

使用内置 imagegen，逐条生成。`source/` 保存原始输出；文件名使用总序号与素材 ID。025–027 各为一张 4×4 连接套件母稿，内含 16 个地块。

原始输出不等于已通过游戏素材验收：尺寸、固定色板、像素网格、透明通道与跨边连接须检查。现有项目素材不被覆盖。

| 序号 | ID | 内容 |
|---|---|---|
| 001 | `tile_forest_1` | 森林草地·基础 |
| 002 | `tile_forest_2` | 森林草地·稀疏点缀 |
| 003 | `tile_forest_3` | 森林草地·局部磨损 |
| 004 | `tile_snow_1` | 雪原·基础 |
| 005 | `tile_snow_2` | 雪原·稀疏点缀 |
| 006 | `tile_snow_3` | 雪原·局部磨损 |
| 007 | `tile_volcano_1` | 火山焦土·基础 |
| 008 | `tile_volcano_2` | 火山焦土·稀疏点缀 |
| 009 | `tile_volcano_3` | 火山焦土·局部磨损 |
| 010 | `tile_tomb_1` | 墓穴石砖·基础 |
| 011 | `tile_tomb_2` | 墓穴石砖·稀疏点缀 |
| 012 | `tile_tomb_3` | 墓穴石砖·局部磨损 |
| 013 | `tile_desert_1` | 荒漠·基础 |
| 014 | `tile_desert_2` | 荒漠·稀疏点缀 |
| 015 | `tile_desert_3` | 荒漠·局部磨损 |
| 016 | `tile_glacier_1` | 冰川·基础 |
| 017 | `tile_glacier_2` | 冰川·稀疏点缀 |
| 018 | `tile_glacier_3` | 冰川·局部磨损 |
| 019 | `tile_abyss_1` | 深渊黑曜地·基础 |
| 020 | `tile_abyss_2` | 深渊黑曜地·稀疏点缀 |
| 021 | `tile_abyss_3` | 深渊黑曜地·局部磨损 |
| 022 | `tile_castle_1` | 王城石板·基础 |
| 023 | `tile_castle_2` | 王城石板·稀疏点缀 |
| 024 | `tile_castle_3` | 王城石板·局部磨损 |
| 025 | `tile_forest_path_{00..15}` | 森林土路·16块套件 |
| 026 | `tile_snow_path_{00..15}` | 雪原踩开雪径·16块套件 |
| 027 | `tile_volcano_lava_{00..15}` | 火山熔岩沟·16块套件 |
| 028 | `deco_forest_tree` | 森林大树，192×192 |
| 029 | `deco_forest_deadtree` | 森林枯树，96×96 |
| 030 | `deco_forest_rocks` | 森林岩组，96×96 |
| 031 | `deco_forest_shrub` | 森林灌木，96×96 |
| 032 | `deco_forest_grass` | 森林草丛，96×96 |
| 033 | `deco_forest_ruin` | 森林遗迹断柱，96×96 |
| 034 | `deco_forest_bones` | 森林骸骨，96×96 |
| 035 | `deco_snow_pine` | 雪原针叶松，192×192 |
| 036 | `deco_snow_icecrystal` | 雪原冰晶簇，96×96 |
| 037 | `deco_snow_snowdrift` | 雪原雪堆，96×96 |
| 038 | `deco_volcano_lavarock` | 火山熔岩岩，96×96 |
| 039 | `deco_volcano_bones` | 火山焦骨，96×96 |
| 040 | `deco_volcano_geyser` | 火山喷气孔，96×96 |
| 041 | `deco_tomb_gravestone` | 墓穴墓碑，96×96 |
| 042 | `deco_tomb_coffin` | 墓穴石棺，96×96 |
| 043 | `deco_tomb_brazier` | 墓穴幽火盆，96×96 |
| 044 | `deco_desert_cactus` | 荒漠仙人柱，96×96 |
| 045 | `deco_desert_sandstone` | 荒漠风蚀岩，192×192 |
| 046 | `deco_desert_drywell` | 荒漠枯井，96×96 |
| 047 | `deco_glacier_icespire` | 冰川冰刺，192×192 |
| 048 | `deco_glacier_frozenknight` | 冰封骑士，96×96 |
| 049 | `deco_glacier_crevasse` | 冰川裂缝标记，96×96 |
| 050 | `deco_abyss_obelisk` | 深渊黑曜碑，192×192 |
