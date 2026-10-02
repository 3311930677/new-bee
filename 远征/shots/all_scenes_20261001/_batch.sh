#!/usr/bin/env bash
# 全量场景截图批处理。重跑：bash shots/all_scenes_20261001/_batch.sh
# 产物：shots/all_scenes_20261001/*.png，逐项结果见 _run.log
GODOT="D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd "D:/new bee/远征" || exit 1
OUT=res://shots/all_scenes_20261001
LOG=shots/all_scenes_20261001/_run.log
: > "$LOG"

shot() {
  local scene="$1"; local name="$2"; local frames="${3:-45}"
  shift 3 2>/dev/null || shift $#
  local out
  out=$(timeout 200 "$GODOT" --path . res://tools/ShotRunner.tscn -- \
        --scene="$scene" --frames="$frames" --out="$OUT/$name.png" "$@" 2>&1)
  if echo "$out" | grep -q "SHOT_SAVED"; then
    echo "OK   $name" >> "$LOG"
  else
    echo "FAIL $name :: $(echo "$out" | grep -iE 'error|failed|SCRIPT ERROR' | head -2 | tr '\n' ' ')" >> "$LOG"
  fi
}

# ---------- 启动与流程 ----------
shot load load 30
shot title title
shot title_settings title_settings
shot login login
shot namerecover namerecover
shot prologue prologue
shot createrole createrole
shot home home

# ---------- 主界面与功能浮层 ----------
shot avatar avatar
shot deploy deploy
shot deploy_role deploy_role
shot deploy_pet deploy_pet
shot worlds worlds
shot codex codex
shot arena arena
shot gacha gacha
shot exchange exchange
shot settings settings
shot settings2 settings2
shot growth growth
shot bag bag
shot bag_full bag_full
shot quests quests
shot city_deploy city_deploy
shot gm gm
shot gm_open gm_open

# ---------- 养成子页 ----------
shot talent talent
shot equip equip
shot pet_raise pet_raise
shot skillbook skillbook
shot mount mount
shot titles titles

# ---------- 工坊 ----------
shot forge_enhance forge_enhance
shot forge_gem forge_gem
shot forge_refine forge_refine
shot workshop_low workshop_low
shot workshop_progress workshop_progress

# ---------- 城内 ----------
shot city city
shot city_repair city_repair
shot city_built city_built
shot city_all city_all
shot city_mix city_mix
shot city_shop city_shop
shot city_notice city_notice
shot city_guests city_guests
shot city_build_panel city_build_panel
shot city_built_panel city_built_panel
shot city_frost_choice city_frost_choice
shot city_tide_choice city_tide_choice
shot port_services port_services
shot side_city_accept side_city_accept
shot beast_notice beast_notice
shot mentor_choice mentor_choice
shot order_preview order_preview
shot trade_warden_dialog trade_warden_dialog
shot mount_claim mount_claim
shot pet_claim pet_claim

# ---------- 主世界 14 张地图 ----------
for m in lorin_wilds maple_road broken_slope old_salt_road shenyuan_port tideflat \
         tidal_gate stele_cavern red_sand_route frost_post rift_mine_road \
         rift_mine_vault frost_pass frost_boardwalk; do
  shot "mw_$m" "mw_$m"
done

# ---------- 随机秘境路线图 ----------
for t in forest snow volcano tomb desert glacier abyss castle; do
  shot "route_$t" "route_$t"
done
shot map map
shot map_boss map_boss

# ---------- 主世界场景与支线 ----------
shot main_world main_world
shot mentor_world mentor_world
shot chapter_archive chapter_archive
shot chapter_gate chapter_gate
shot waystone_world waystone_world
shot beast_world beast_world
shot side_world_chime side_world_chime
shot side_world_tracks side_world_tracks
shot trade_slope_world trade_slope_world
shot trade_slope_panel trade_slope_panel

# ---------- 战斗 ----------
shot battle battle
shot battle_cast battle_cast
shot battle_low battle_low
for t in snow volcano tomb desert glacier abyss castle; do
  shot "battlebg_$t" "battlebg_$t"
done
shot main_world_battle main_world_battle
shot main_world_battle_commands main_world_battle_commands
shot main_world_battle_skills main_world_battle_skills
shot main_world_battle_projectile main_world_battle_projectile
shot main_world_pet_guard main_world_pet_guard
shot beast_windup beast_windup
shot beast_break beast_break
shot picker picker
shot picker_school picker_school
shot story_intro story_intro
shot story_outro story_outro

# ---------- 第一幕 · 四职业蓝武器 ----------
for r in zs ck fs fz; do
  shot act1_blue_weapon "act1_blue_weapon_$r" 45 --role="$r"
done

# ---------- 第二幕 · 盐路 ----------
for s in second_salt second_port second_port_south second_hatch second_relation \
         second_shipping second_fishing second_tideflat second_gate \
         second_gate_battle second_gate_windup second_gate_ebb second_crab_battle \
         second_side_rope second_side_choice second_side_grass second_side_courier \
         second_side_repaired; do
  shot "$s" "$s"
done

# ---------- 第三幕 · 霜关（前段） ----------
for s in third_route third_post third_post_south third_mine third_dialog \
         third_regions third_items; do
  shot "$s" "$s"
done

# ---------- 第三幕 · 霜关（后段） ----------
for s in third_vault third_vault_windup third_boardwalk third_pass third_eye \
         third_break third_choice third_merchant third_wardens third_market \
         third_back_regions; do
  shot "$s" "$s"
done

# ---------- 第三幕 · 支线纵切 ----------
for s in third_side_choice third_side_coal third_side_shield third_side_nameplate \
         third_side_lichen third_side_vents third_side_parcel third_side_echo; do
  shot "$s" "$s"
done

echo "DONE" >> "$LOG"
echo "---- summary ----" >> "$LOG"
echo "OK   $(grep -c '^OK' "$LOG")" >> "$LOG"
echo "FAIL $(grep -c '^FAIL' "$LOG")" >> "$LOG"
