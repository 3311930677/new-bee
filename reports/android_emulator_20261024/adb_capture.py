"""Capture emulator pixels without shell text conversion."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
ADB = Path(r"D:\new-bee\tools\android-sdk-mobile\platform-tools\adb.exe")
SERIAL = "emulator-5554"

def adb(*arguments, timeout=60):
    return subprocess.check_output([str(ADB), "-s", SERIAL, *arguments], timeout=timeout)

if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "screen"
    if not name.replace("_", "").replace("-", "").isalnum():
        raise ValueError("Use a simple capture label")
    data = adb("exec-out", "screencap", "-p")
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Android did not return a PNG")
    path = ROOT / (name + ".png")
    path.write_bytes(data)
    print(path)
