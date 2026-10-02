#!/usr/bin/env bash
# 第二批：依赖「已通关存档」的界面用例（伙伴训练 / 导师课业 / 战利品 / 旅途补记）。
# 这些用例必须用 --source-save 喂真实进度档，否则面板是空态。
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

# ---------- 伙伴协同（面板 / 世界 / 战斗特效） ----------
for s in companion_locked companion_first companion_second companion_help \
         companion_world companion_lodge companion_guard companion_pursuit \
         companion_resonance; do
  shot "$s" "$s"
done

# ---------- 导师课业 ----------
for s in curriculum_list curriculum_detail curriculum_branch; do
  shot "$s" "$s"
done

# ---------- 战利品与旅途补记 ----------
for s in gear_pending gear_preview gear_detail campaign_catchup campaign_mine campaign_return; do
  shot "$s" "$s"
done

echo "---- batch2 done ----" >> "$LOG"
echo "OK   $(grep -c '^OK' "$LOG")" >> "$LOG"
echo "FAIL $(grep -c '^FAIL' "$LOG")" >> "$LOG"
