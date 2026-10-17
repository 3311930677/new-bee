# 《远征》素材来源与授权记录（ASSET_LICENSES）

## 一、项目内建与自研素材
1. **角色与怪物像素精灵**（`res://image/role/`、`res://assets/sprites/`、`res://assets/monsters/`、`res://assets/pets/`）：
   - 项目自有像素图集资源（破军 `pojun`、穿杨 `chuanyang`、霜语 `shuangyu`、晨星 `chenxing` 四方向行走与待机帧，以及主世界怪物与灵宠精灵）。
2. **装备与道具图标资源**（`res://assets/icons/`、`res://assets/ui/`）：
   - 第四阶段新增的 6 件 24 级史诗神兵（`tpl_sword_starfall`、`tpl_spear_windpiercer`、`tpl_staff_glacierheart`、`tpl_hammer_dawnlight`、`tpl_armor_expedition`、`tpl_acc_archery_ring`）复用项目内建高阶像素武器/护甲/饰品图标资源，保证视觉语言与图集采样规范 100% 统一。
3. **程序化绘制与合成视觉参考图板**（`res://src/ui/ArcheryPanel.gd`、`res://docs/agent_iteration/references/`）：
   - `ArcheryPanel.gd` 的暮色演武靶场、风向标、五环箭靶、蓄力槽及箭矢落点采用 Godot `CanvasItem._draw` 程序化像素级绘制；
   - `docs/agent_iteration/references/ref_role_select_concepts.png`、`ref_world_map_hud_concepts.png`、`ref_archery_curio_concepts.png` 由项目实机渲染帧与自研脚本合成生成，版权归属本项目工程，无任何第三方商业侵权风险。
4. **字体资源**（`res://assets/fonts/NotoSerifSC-Bold.otf`）：
   - 采用 SIL Open Font License 1.1 (OFL-1.1) 开源商用授权的思源宋体（Noto Serif SC Bold），可自由用于商业发行。
