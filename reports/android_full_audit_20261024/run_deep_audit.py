"""Drive the Android-only diagnostic entry on the owned emulator."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parent
ADB = Path(r"D:\new-bee\tools\android-sdk-mobile\platform-tools\adb.exe")
SERIAL = "emulator-5554"
PACKAGE = "org.yuanzheng.singleplayer"
COMPONENT = PACKAGE + "/com.godot.game.GodotAppLauncher"
CASES = {"portrait_16_9": (720, 1280, False, "gestural"),
         "portrait_18_9": (1080, 2160, False, "threebutton"),
         "portrait_20_9": (1080, 2400, True, "gestural"),
         "tablet_10_16": (1600, 2560, False, "threebutton"),
         "long_cutout": (1080, 2424, True, "threebutton")}

def adb(*args, timeout=90, data=None):
    return subprocess.run([str(ADB), "-s", SERIAL, *args], input=data, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout).stdout

def text(*args):
    return adb(*args).decode("utf-8", errors="replace").strip()

def prepare_touch():
    assert text("shell", "getprop", "ro.kernel.qemu") == "1"
    adb("root"); adb("wait-for-device")
    driver = "/sys/bus/serio/drivers/atkbd/"
    if "serio0" in text("shell", "ls", driver):
        assert text("shell", "readlink", "-f", driver + "serio0") == "/sys/devices/platform/i8042/serio0"
        adb("shell", "sh", "-c", '"echo serio0 > ' + driver + 'unbind"')

def launch(case=None, install=False):
    adb("shell", "am", "force-stop", PACKAGE)
    if install:
        apk_name = "Yuanzheng-deep-audit-final.apk" if "--final" in sys.argv else "Yuanzheng-deep-audit-extended.apk" if "--extended" in sys.argv else "Yuanzheng-deep-audit.apk"
        print(text("install", "-r", str(ROOT / apk_name)), flush=True)
    prepare_touch()
    if case:
        width, height, cutout, nav = CASES[case]
        adb("shell", "wm", "size", f"{width}x{height}")
        adb("shell", "cmd", "overlay", "enable" if cutout else "disable", "--user", "0",
            "com.android.internal.display.cutout.emulation.hole")
        adb("shell", "cmd", "overlay", "enable-exclusive", "--category", "--user", "0",
            "com.android.internal.systemui.navbar." + nav)
        time.sleep(1)
    adb("shell", "run-as", PACKAGE, "rm", "-f", "files/android_full_audit/ready.json")
    adb("logcat", "-c")
    adb("shell", "am", "start", "-n", COMPONENT)
    for _ in range(60):
        try:
            ready = json.loads(adb("exec-out", "run-as", PACKAGE, "cat", "files/android_full_audit/ready.json"))
            assert ready["os"] == "Android"
            print("READY", ready, flush=True)
            return ready
        except (subprocess.CalledProcessError, ValueError):
            time.sleep(.5)
    raise RuntimeError("Diagnostic entry did not start")

def command(identifier, suite, **options):
    assert identifier.isidentifier() and identifier.isascii()
    payload = {"id": identifier, "suite": suite, **options}
    adb("shell", "run-as", PACKAGE, "rm", "-f", "files/android_full_audit/" + identifier + "/result.json")
    adb("exec-in", "run-as", PACKAGE, "tee", "files/android_full_audit/request.json",
        data=json.dumps(payload).encode())
    started = time.monotonic()
    last_progress = ""
    while time.monotonic() - started < 600:
        try:
            raw = adb("exec-out", "run-as", PACKAGE, "cat", "files/android_full_audit/" + identifier + "/result.json")
            result = json.loads(raw)
            failures = [row for row in result["checks"] if not row["ok"]]
            print("COMPLETE", identifier, "checks", len(result["checks"]), "failures", len(failures), "photos", len(result["photos"]), flush=True)
            for row in failures: print("FAIL", json.dumps(row, ensure_ascii=True), flush=True)
            return result
        except (subprocess.CalledProcessError, ValueError):
            pass
        log = text("logcat", "-d", "-s", "godot:I", "AndroidRuntime:E", "libc:F")
        if "SCRIPT ERROR" in log or "FATAL EXCEPTION" in log or "Fatal signal" in log:
            (ROOT / (identifier + "_failed_logcat.txt")).write_text(log, encoding="utf-8")
            raise RuntimeError("Android error while running " + identifier + "; see saved log")
        progress = [line for line in log.splitlines() if "ANDROID_DEEP_PHOTO" in line]
        if progress and progress[-1] != last_progress:
            last_progress = progress[-1]
            print(last_progress, flush=True)
        time.sleep(.6)
    raise TimeoutError(identifier)

def pull(identifier):
    archive = ROOT / (identifier + ".tar")
    with archive.open("wb") as stream:
        subprocess.run([str(ADB), "-s", SERIAL, "exec-out", "run-as", PACKAGE,
                        "tar", "-C", "files/android_full_audit", "-cf", "-", identifier],
                       stdout=stream, stderr=subprocess.PIPE, check=True, timeout=180)
    with tarfile.open(archive) as tar:
        for member in tar:
            # Android permits ':' in a diagnostic page label; Windows does not.
            target = (ROOT / member.name.replace(":", "_")).resolve()
            if not target.is_relative_to(ROOT) or member.issym() or member.islnk():
                raise ValueError("Unsafe archive member " + member.name)
            if member.isdir(): target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with tar.extractfile(member) as source, target.open("wb") as dest:
                    shutil.copyfileobj(source, dest)
    # Verified extraction; remove only this exact generated regular file.
    archive.unlink()
    (ROOT / identifier / "logcat.txt").write_bytes(adb("logcat", "-d"))
    (ROOT / identifier / "adb_screen.png").write_bytes(adb("exec-out", "screencap", "-p"))

def main():
    mode = sys.argv[1]
    if mode == "launch":
        launch(sys.argv[2] if len(sys.argv) > 2 else None, "--install" in sys.argv)
    elif mode == "run":
        identifier, suite = sys.argv[2:4]
        options = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        command(identifier, suite, **options); pull(identifier)
    elif mode == "matrix":
        for case in ["portrait_16_9", "portrait_18_9", "portrait_20_9", "tablet_10_16"]:
            launch(case); command(case, "pages"); pull(case)
    else:
        raise ValueError(mode)

if __name__ == "__main__":
    main()
