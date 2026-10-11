#!/usr/bin/env bash
# 主要界面重拍（2026-10-07）。UI 于 10-02 整体重做后，10-01 那批全量图已过期。
# 重跑：bash shots/main_ui_20261007/_capture.sh
# 产物：shots/main_ui_20261007/*.png，逐项结果见 _run.log
GODOT="D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
cd "D:/new bee/远征" || exit 1
OUT=res://shots/main_ui_20261007
LOG=shots/main_ui_20261007/_run.log
: > "$LOG"

shot() {
  local scene="$1"; local frames="${2:-60}"
  shift 2 2>/dev/null || shift $#
  local out
  out=$(timeout 240 "$GODOT" --path . res://tools/ShotRunner.tscn -- \
        --scene="$scene" --frames="$frames" --out="$OUT/$scene.png" "$@" 2>&1)
  if echo "$out" | grep -q "SHOT_SAVED"; then
    echo "OK   $scene" >> "$LOG"
  else
    echo "FAIL $scene :: $(echo "$out" | grep -iE 'error|failed|SCRIPT ERROR' | head -2 | tr '\n' ' ')" >> "$LOG"
  fi
}

# ---------- 启动与流程 ----------
for s in load title title_intro title_settings login createrole prologue home; do shot "$s"; done

# ---------- 主界面与功能浮层 ----------
for s in deploy worlds codex arena gacha exchange settings growth bag quests avatar gm gm_open; do shot "$s"; done

# ---------- 养成子页 ----------
for s in talent equip pet_raise skillbook mount titles; do shot "$s"; done

# ---------- 工坊 ----------
for s in forge_enhance forge_gem forge_refine; do shot "$s"; done

# ---------- 城内 ----------
for s in city city_built city_shop city_notice city_guests city_deploy \
         city_build_panel city_built_panel; do shot "$s"; done

# ---------- 主世界与 HUD ----------
for s in main_world world_hud_city world_hud_field world_minimap_expanded \
         mw_lorin_wilds mw_shenyuan_port mw_frost_post mw_rift_mine_vault; do shot "$s"; done

# ---------- 战斗 ----------
for s in battle battle_cast battle_low main_world_battle main_world_battle_skills \
         picker picker_school; do shot "$s"; done

# ---------- 随机秘境 ----------
for s in route_forest map map_boss; do shot "$s"; done

# ---------- 剧情演出 ----------
for s in story_intro story_outro; do shot "$s"; done

# ---------- 第四幕（用默认夹具 shots/fourth_front_20261002/preview_source.json） ----------
for s in fourth_regions fourth_preparation fourth_battle; do shot "$s"; done

echo "---- done ----" >> "$LOG"
echo "OK   $(grep -c '^OK   ' "$LOG")" >> "$LOG"
echo "FAIL $(grep -c '^FAIL ' "$LOG")" >> "$LOG"
