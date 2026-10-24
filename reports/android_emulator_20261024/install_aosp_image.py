"""Install a checksum-verified official AOSP image; retain ZIP for diagnostics."""
from pathlib import Path
import hashlib
import json
import zipfile
from xml.dom import minidom

SDK = Path(r"D:\new-bee\tools\android-sdk-mobile").resolve()
ARCHIVE = SDK / "downloads/android17-aosp-x86_64.zip"
PACKAGE = "system-images;android-37.0;default;x86_64"
metadata = minidom.parse(str(SDK / "downloads/sys-img-android.xml"))
remote = next(node for node in metadata.getElementsByTagName("remotePackage") if node.getAttribute("path") == PACKAGE)
complete = remote.getElementsByTagName("complete")[0]
expected_size = int(complete.getElementsByTagName("size")[0].firstChild.data)
expected_sha = complete.getElementsByTagName("checksum")[0].firstChild.data
assert ARCHIVE.stat().st_size == expected_size, "Incomplete download"
sha = hashlib.sha1()
with ARCHIVE.open("rb") as source:
    for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
        sha.update(block)
assert sha.hexdigest() == expected_sha, "Official SDK checksum mismatch"
target = SDK / "system-images/android-37.0/default"
target.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ARCHIVE) as archive:
    for entry in archive.infolist():
        assert (target / entry.filename).resolve().is_relative_to(target), "Archive path escaped image directory"
    assert archive.testzip() is None, "ZIP CRC mismatch"
    archive.extractall(target)
package_dir = target / "x86_64"
assert (package_dir / "system.img").exists()
assert (package_dir / "source.properties").exists()

# sdkmanager normally writes this local package descriptor after extraction.
# Preserve the namespace bindings used by xsi:type in Google's own metadata.
document = minidom.Document()
root = document.createElementNS("http://schemas.android.com/repository/android/common/02", "installed:repository")
for key, value in metadata.documentElement.attributes.items():
    if key.startswith("xmlns"):
        root.setAttribute(key, value)
root.setAttribute("xmlns:installed", "http://schemas.android.com/repository/android/common/02")
document.appendChild(root)
for license_node in metadata.getElementsByTagName("license"):
    root.appendChild(document.importNode(license_node, True))
local = document.createElement("localPackage")
local.setAttribute("path", PACKAGE)
for child in remote.childNodes:
    if child.nodeType == child.ELEMENT_NODE and child.tagName not in ["archives", "channelRef"]:
        local.appendChild(document.importNode(child, True))
root.appendChild(local)
(package_dir / "package.xml").write_bytes(document.toxml(encoding="UTF-8"))
result = {"package": PACKAGE, "size": expected_size, "sha1": sha.hexdigest(), "zip_crc": True}
Path(__file__).with_name("image_verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result))
