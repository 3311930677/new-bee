#!/usr/bin/env bash
# 第四批：长屏逻辑视口 480×1067（对应 720×1600 的宽度归一化比例）。
# 只拍「竖屏拉伸会改变布局」的场景：主世界 HUD 贴底、战斗人物与指令页下移、
# 浮层在长屏里居中。纯静态面板（图鉴/抽卡等）在 480×800 已能验收，不重复。
GODOT="D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd "D:/new bee/远征" || exit 1
OUT=res://shots/all_scenes_20261001/long_480x1067
LOG=shots/all_scenes_20261001/_run.log
SIZE=480x1067
SAVE=res://tools/_logs/curriculum_accept_zs_fs/save_playthrough_zs_a.json

shot() {
  local scene="$1"; local name="$2"; local frames="${3:-45}"
  shift 3 2>/dev/null || shift $#
  local out
  out=$(timeout 240 "$GODOT" --path . --position -4000,-4000 res://tools/OffscreenShotRunner.tscn -- \
        --scene="$scene" --size="$SIZE" --frames="$frames" --out="$OUT/$name.png" \
        --source-save="$SAVE" "$@" 2>&1)
  if echo "$out" | grep -q "SHOT_SAVED"; then
    echo "OK   long/$name" >> "$LOG"
  else
    echo "FAIL long/$name :: $(echo "$out" | grep -iE 'error|failed|SCRIPT ERROR' | head -2 | tr '\n' ' ')" >> "$LOG"
  fi
}

# ---------- 主世界 14 张地图（HUD 贴底 / 小地图贴边） ----------
for m in lorin_wilds maple_road broken_slope old_salt_road shenyuan_port tideflat \
         tidal_gate stele_cavern red_sand_route frost_post rift_mine_road \
         rift_mine_vault frost_pass frost_boardwalk; do
  shot "mw_$m" "mw_$m"
done

# ---------- 城内 ----------
for s in city city_all city_shop city_notice city_guests; do
  shot "$s" "$s"
done

# ---------- 战斗（人物 / 指令页 / 技能页下移） ----------
for s in battle battle_cast battle_low main_world_battle main_world_battle_commands \
         main_world_battle_skills; do
  shot "$s" "$s"
done

# ---------- 秘境路线与地区图 ----------
for s in route_forest map map_boss; do
  shot "$s" "$s"
done

# ---------- 浮层在长屏里居中 ----------
for s in home growth talent equip bag bag_full settings settings2 gacha exchange \
         codex worlds arena quests deploy avatar forge_enhance forge_gem forge_refine \
         picker mentor_choice order_preview; do
  shot "$s" "$s"
done

echo "---- batch4 done ----" >> "$LOG"
echo "OK   $(grep -c '^OK   ' "$LOG")" >> "$LOG"
echo "FAIL $(grep -c '^FAIL ' "$LOG")" >> "$LOG"
