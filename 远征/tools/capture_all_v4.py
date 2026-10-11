import os
import subprocess
import time

godot = r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
proj = r"d:\new bee\远征"
out_dir = r"d:\new bee\远征\shots\round4_pure2d"
os.makedirs(out_dir, exist_ok=True)

maps = [
    "lorin_wilds", "maple_road", "broken_slope", "old_salt_road",
    "shenyuan_port", "tideflat", "tidal_gate", "stele_cavern", "red_sand_route",
    "frost_post", "rift_mine_road", "rift_mine_vault", "frost_pass", "frost_boardwalk",
    "abyss_ring", "stele_entry", "stele_resonance", "stele_core"
]

print(f"Starting capture for {len(maps)} maps...")
start_t = time.time()

for mid in maps:
    out_png = os.path.join(out_dir, f"map_{mid}_v4.png")
    cmd = [godot, "--path", proj, "res://tools/ShotRunner.tscn", "--", f"--scene=mw_{mid}", f"--out={out_png}", "--frames=45"]
    try:
        t0 = time.time()
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
        dt = time.time() - t0
        if os.path.exists(out_png) and os.path.getsize(out_png) > 10000:
            print(f"[{mid}] SUCCESS ({dt:.1f}s) -> {os.path.basename(out_png)} ({os.path.getsize(out_png)} bytes)")
        else:
            print(f"[{mid}] FAILED or EMPTY ({dt:.1f}s):\nSTDOUT: {res.stdout[-200:]}\nSTDERR: {res.stderr[-200:]}")
    except Exception as e:
        print(f"[{mid}] ERROR: {e}")

total_dt = time.time() - start_t
print(f"Finished capturing all maps in {total_dt:.1f}s!")
