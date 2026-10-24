"""Reproduce page captures on the owned Android emulator, never a phone."""
from pathlib import Path
import json
import subprocess
import sys
import time
from adb_capture import adb, ADB, SERIAL

ROOT = Path(__file__).resolve().parent
PACKAGE = "org.yuanzheng.singleplayer"
COMPONENT = PACKAGE + "/com.godot.game.GodotAppLauncher"
CASES = {
    "long_cutout": (1080, 2424, True, "threebutton"),
    "classic_gesture": (720, 1280, False, "gestural"),
}

def main():
    case = sys.argv[1]
    width, height, cutout, navigation = CASES[case]
    output = ROOT / case
    output.mkdir(exist_ok=True)
    adb("shell", "am", "force-stop", PACKAGE)
    if "--touch-only" in sys.argv:
        assert adb("shell", "getprop", "ro.kernel.qemu").strip() == b"1"
        adb("root")
        adb("wait-for-device")
        # The x86 AOSP kernel retains an AT keyboard even with hw.keyboard=no.
        # Detach only that identified emulated device; reboot/bind restores it.
        driver = "/sys/bus/serio/drivers/atkbd/"
        if b"serio0" in adb("shell", "ls", driver):
            assert b"/devices/platform/i8042/serio0" in adb("shell", "readlink", "-f", driver + "serio0")
            adb("shell", "sh", "-c", '"echo serio0 > ' + driver + 'unbind"')
    if "--install" in sys.argv:
        print(adb("install", "-r", str(ROOT / "Yuanzheng-android-audit.apk"), timeout=180).decode(), flush=True)
    # Changing overlays during play currently crashes the native engine. Preserve
    # that finding; configure each cold-start scenario while the app is stopped.
    adb("shell", "wm", "size", f"{width}x{height}")
    adb("shell", "cmd", "overlay", "enable" if cutout else "disable", "--user", "0",
        "com.android.internal.display.cutout.emulation.hole")
    adb("shell", "cmd", "overlay", "enable-exclusive", "--category", "--user", "0",
        "com.android.internal.systemui.navbar." + navigation)
    time.sleep(2)
    adb("shell", "run-as", PACKAGE, "rm", "-f", "files/android_ui_audit/runtime.json")
    adb("logcat", "-c")
    adb("shell", "am", "start", "-n", COMPONENT)
    deadline = time.monotonic() + 90
    keyboard_recorded = False
    while time.monotonic() < deadline:
        log = adb("logcat", "-d").decode("utf-8", errors="replace")
        if not keyboard_recorded and "ANDROID_IME feature=" in log:
            time.sleep(.4)
            (output / "native_keyboard.png").write_bytes(adb("exec-out", "screencap", "-p"))
            (output / "native_keyboard_status.txt").write_bytes(adb("shell", "dumpsys", "input_method"))
            keyboard_recorded = True
        if "ANDROID_UI_AUDIT_COMPLETE" in log:
            break
        time.sleep(.3)
    else:
        (output / "logcat.txt").write_text(log, encoding="utf-8")
        raise RuntimeError("Android audit did not finish; inspect logcat")
    (output / "logcat.txt").write_text(log, encoding="utf-8")
    runtime = adb("exec-out", "run-as", PACKAGE, "cat", "files/android_ui_audit/runtime.json")
    data = json.loads(runtime)
    assert data["os"] == "Android" and len(data["screens"]) == 15
    (output / "runtime.json").write_bytes(runtime)
    for row in data["screens"]:
        name = row["id"]
        assert name.replace("_", "").isalnum()
        (output / (name + ".png")).write_bytes(adb("exec-out", "run-as", PACKAGE, "cat",
            "files/android_ui_audit/" + name + ".png"))
    (output / "adb_screen.png").write_bytes(adb("exec-out", "screencap", "-p"))
    metadata = {"serial": SERIAL, "android_release": adb("shell", "getprop", "ro.build.version.release").decode().strip(),
        "android_api": adb("shell", "getprop", "ro.build.version.sdk").decode().strip(),
        "wm_size": adb("shell", "wm", "size").decode().strip(),
        "navigation": navigation, "cutout_overlay": cutout,
        "touch_only": "--touch-only" in sys.argv,
        "pages": len(data["screens"]), "outliers": sum(len(row["outliers"]) for row in data["screens"])}
    (output / "device.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False), flush=True)

if __name__ == "__main__":
    main()
