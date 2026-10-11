import subprocess

godot = r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
proj = r"d:\new bee\远征"

tests = [
    "VerifyTradeWorld.gd",
    "VerifySecondAct.gd",
    "VerifyThirdAct.gd",
    "VerifyNav.gd",
    "VerifyMapScene.gd",
    "VerifyStory.gd"
]

all_pass = True
for t in tests:
    cmd = [godot, "--path", proj, "--headless", "-s", f"tools/{t}"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
        lines = res.stdout.splitlines()
        errors = [l for l in lines if "ERROR:" in l or "SCRIPT ERROR:" in l or "FAIL" in l]
        if errors:
            print(f"[{t}] -> FAIL")
            for e in errors[:5]:
                print(f"   {e}")
            all_pass = False
        else:
            print(f"[{t}] -> PASS")
    except Exception as ex:
        print(f"[{t}] -> TIMEOUT/EXCEPTION: {ex}")
        all_pass = False

print("\nOVERALL TEST RESULT:", "ALL PASS" if all_pass else "SOME FAILED")
