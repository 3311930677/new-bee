# P09-B 渊口外环地面与程序碑座

本批使用内置 imagegen 创建一张原创地面，生成后原文件直接复制入运行时目录，没有图像编辑。运行时地图保留角色、敌影、路牌与任务实体独立层。新增地貌不会把人物和文字烧进背景。

| 项目 | 记录 |
| --- | --- |
| 资源 | `image/main_world/abyss_ring_ground_reference_v1.png` |
| 实际母图 | 1100×1430，PNG，不透明，约3.5MB |
| 地图 | `abyss_ring`，960×1248；最近邻，按整图纵横比覆盖 |
| 动态实体 | `breach_resonance`，坐标480,625；三地色环与碑座轮廓由MapScene绘制 |
| 几何 | 中轴连续可走；左右185px外缘有独立阻挡体；任务/出口/巡逻区域沿表声明 |
| 来源 | 项目自产，内置imagegen；未取用第三方图 |
| QA | 短屏480×800及长屏480×1067的实际Godot画面，道路、脚点、标签、UI与动态碑座已查看；见`shots/fourth_front_20261002/` |

生成完整提示词如下。

```text
Use case: stylized-concept. Asset type: a complete walkable overhead RPG map ground texture for the original Chinese fantasy game 远征, region 渊口外环, for runtime under small sprites. Create one portrait bitmap approximately aspect ratio 960:1248. Subject: an ancient basalt plateau approaching a sealed magical breach. Style: highly crafted 2D overhead/three-quarter RPG game ground, clear pixels and crisp edges, detailed delicate stone grains, restrained antique fantasy palette matching warm stone towns and cool snowy roads. Composition is critical: a continuous straight walkable pale ash stone causeway lies exactly on the vertical center, spanning from bottom to top, roughly 18% of image width, fully unobstructed and relatively flat. At 50% width and 50% height, leave a flat open courtyard about 28% of width, for a separate in-game resonance plinth. At left and right far edges, eroded basalt shelves, old broken engraved stones, shallow purple seams and dormant fissures create depth. These are low-relief edge ornament; do not let deep-looking fissures cross the central walking corridor. The bottom center is a broad entry apron. The upper center is a narrowing stone threshold, without a door or wall. Fine organic wear, ash moss, lichen, slate strata, tiny fossil shapes, violet mineral threads, three subtle weathered stone motifs suggesting forest stone, harbor sediment and frost. Lighting: soft diffuse moonlit ambient, low contrast in walking areas, muted gray mauve and green-gray basalt with warm sand stone causeway, restrained faint purple seam light. Texture is rich and finished, not coarse large flat blocks. No figures, NPCs, monsters, statues, buildings, large opaque objects, text, letters, UI, arrows, grid, map border, vignette, fog, interface or sky. No perspective horizon; the entire image is visible walkable ground. No blurry or photographic surfaces, no smooth 3D rendering. Output one coherent region texture, no captions.
```

`rift_echo`复用已有界碑碎片图标，`stele_key`复用原创关闸印图标；物品ID、名称与首通事务独立。没有把复用图标或单张地面记作S7全动画完成。后续界碑深处、两名第四幕首领及结局美术单独登记。
