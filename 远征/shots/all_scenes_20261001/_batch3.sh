#!/usr/bin/env bash
# 第三批：同一场景的不同站位／构图变体（城镇北中南×左中右、霜关各点、地形快照、风格基线）。
# 这些用例都必须用 --source-save 喂真实进度档，否则城内建筑与故事状态是空态。
GODOT="D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd "D:/new bee/远征" || exit 1
OUT=res://shots/all_scenes_20261001
LOG=shots/all_scenes_20261001/_run.log
SAVE=res://tools/_logs/curriculum_accept_zs_fs/save_playthrough_zs_a.json

shot() {
  local scene="$1"; local name="$2"; local frames="${3:-45}"
  shift 3 2>/dev/null || shift $#
  local out
  out=$(timeout 200 "$GODOT" --path . res://tools/ShotRunner.tscn -- \
        --scene="$scene" --frames="$frames" --out="$OUT/$name.png" \
        --source-save="$SAVE" "$@" 2>&1)
  if echo "$out" | grep -q "SHOT_SAVED"; then
    echo "OK   $name" >> "$LOG"
  else
    echo "FAIL $name :: $(echo "$out" | grep -iE 'error|failed|SCRIPT ERROR' | head -2 | tr '\n' ' ')" >> "$LOG"
  fi
}

# ---------- 城内三区 × 左中右站位 ----------
for s in town_north town_north_left town_north_right \
         town_middle town_middle_left town_middle_right \
         town_south town_south_left town_south_right; do
  shot "$s" "$s"
done

# ---------- 霜关各点（南/北 × 左右 + 火盆抉择 + 三名 NPC 对话） ----------
for s in frost_art_north frost_art_north_left frost_art_north_right \
         frost_art_south frost_art_south_left frost_art_south_right \
         frost_art_coal frost_art_shield \
         frost_art_envoy frost_art_guard frost_art_miner; do
  shot "$s" "$s"
done

# ---------- 地形快照（港口 / 霜关 × 南北） ----------
for s in terrain_port terrain_port_south terrain_frost terrain_frost_south; do
  shot "$s" "$s"
done

# ---------- 风格基线（城 / 战 / 锻造 / 背包） ----------
for s in style_city style_battle style_forge style_bag; do
  shot "$s" "$s"
done

echo "---- batch3 done ----" >> "$LOG"
echo "OK   $(grep -c '^OK   ' "$LOG")" >> "$LOG"
echo "FAIL $(grep -c '^FAIL ' "$LOG")" >> "$LOG"
