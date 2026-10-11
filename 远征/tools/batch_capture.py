import subprocess, os, sys, shutil, base64

GODOT = r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
PROJ = r"D:\new bee\远征"
ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity\brain\5af44a56-5425-4bb8-8b64-cf82d0333bfe"
OUT_DIR = os.path.join(PROJ, "shots", "rounds")

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(ARTIFACT_DIR, exist_ok=True)

def capture_scene(scene_name, output_filename, extra_args=None):
    out_path = os.path.join(OUT_DIR, output_filename)
    args = [
        GODOT,
        "--path", PROJ,
        "res://tools/ShotRunner.tscn",
        "--",
        f"--scene={scene_name}",
        f"--out={out_path}"
    ]
    if extra_args:
        args.extend(extra_args)
    
    print(f"Capturing {scene_name} -> {output_filename}...")
    res = subprocess.run(args, cwd=PROJ, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=60)
    if os.path.exists(out_path):
        size = os.path.getsize(out_path)
        print(f"Captured: {output_filename} ({size} bytes)")
        # Copy to artifact dir as well
        art_path = os.path.join(ARTIFACT_DIR, output_filename)
        shutil.copyfile(out_path, art_path)
        return out_path
    else:
        print(f"FAILED to capture {output_filename}: {res.stdout}\n{res.stderr}")
        return None

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        scene = sys.argv[1]
        out_fn = sys.argv[2]
        extra = sys.argv[3:] if len(sys.argv) > 3 else None
        capture_scene(scene, out_fn, extra)
    else:
        print("Usage: python batch_capture.py <scene> <output_filename> [extra_args...]")
