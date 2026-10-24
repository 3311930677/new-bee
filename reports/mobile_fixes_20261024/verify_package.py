"""Verify the delivered APK itself, rather than relying on exporter exit status."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
import sys

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "远征"
APK = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).with_name("Yuanzheng-mobile-fixed-final.apk")

def digest(data):
    return hashlib.sha256(data).hexdigest()

with zipfile.ZipFile(APK) as archive:
    names = set(archive.namelist())
    assert archive.testzip() is None, "ZIP CRC failure"
    assert archive.read("assets/project.binary")[:4] == b"ECFG"
    manifest = json.loads((PROJECT / "data/resource_manifest.json").read_text(encoding="utf-8"))
    audio_script = (PROJECT / "src/autoload/Audio.gd").read_text(encoding="utf-8")
    effect_names = json.loads(re.search(r"const SFX_NAMES := (\[.*?\])", audio_script).group(1))
    music_names = ["bgm_title", "bgm_home", "bgm_city", "bgm_map", "bgm_battle", "bgm_route"]
    checked = set()
    for resource in list(manifest.values()) + [f"res://assets/audio/{name}.wav" for name in effect_names + music_names]:
        imported = "assets/" + resource.removeprefix("res://") + ".import"
        assert imported in names, imported
        mappings = re.findall(r'"(res://\.godot/imported/[^"\r\n]+)"', archive.read(imported).decode("utf-8"))
        assert mappings, imported
        for mapping in mappings:
            packaged_path = "assets/" + mapping.removeprefix("res://")
            assert packaged_path in names, packaged_path
            local = PROJECT / mapping.removeprefix("res://")
            assert digest(archive.read(packaged_path)) == digest(local.read_bytes()), packaged_path
            checked.add(packaged_path)
    data_count = 0
    for data_file in (PROJECT / "data").rglob("*.json"):
        packaged = "assets/" + data_file.relative_to(PROJECT).as_posix()
        assert archive.read(packaged) == data_file.read_bytes(), packaged
        data_count += 1
    assert not any(name.startswith(tuple("assets/" + folder + "/" for folder in ["tools", "docs", "shots", "exports"])) for name in names)
    result = {
        "apk": APK.name,
        "apk_bytes": APK.stat().st_size,
        "apk_sha256": digest(APK.read_bytes()),
        "project_header": "ECFG",
        "manifest_paths": len(manifest),
        "sound_effects": len(effect_names),
        "music_loops": len(music_names),
        "imported_payloads_match_current_source": len(checked),
        "json_files_match_current_source": data_count,
        "work_files_excluded": True,
        "zip_crc": True,
    }
APK.with_name("package_verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
