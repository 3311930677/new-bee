"""Build an isolated headless project from the actual shared simulation sources."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from dev import SERVER, LOCAL

GAME = SERVER.parent
TARGET = LOCAL / "room-project"


def build(godot):
    sources = [(path, Path("src/combat") / path.name) for path in (GAME / "src" / "combat").glob("*.gd")]
    sources += [(path, Path("data") / path.name) for path in (GAME / "data").glob("*.json")]
    sources += [
        (GAME / "src/world/CampaignPressure.gd", Path("src/world/CampaignPressure.gd")),
        (GAME / "src/world/CompanionService.gd", Path("src/world/CompanionService.gd")),
        (GAME / "src/online/OnlineProfile.gd", Path("src/online/OnlineProfile.gd")),
        (SERVER / "room/project.godot", Path("project.godot")),
        (SERVER / "room/AuthorityBattle.gd", Path("AuthorityBattle.gd")),
        (SERVER / "room/RoomHost.gd", Path("RoomHost.gd")),
        (SERVER / "room/WorldAuthority.gd", Path("WorldAuthority.gd")),
    ]
    # Reconcile only this generated project's data copies, including removed tables.
    expected_data = {source.name for source, relative in sources if relative.parent == Path("data")}
    for stale in (TARGET / "data").glob("*.json"):
        if stale.name not in expected_data:
            if not stale.resolve().is_relative_to(TARGET.resolve()):
                raise RuntimeError("Generated room data path escapes build directory")
            stale.unlink()
    fingerprint = hashlib.sha256()
    for source, relative in sorted(sources, key=lambda entry: str(entry[1])):
        data = source.read_bytes()
        fingerprint.update(relative.as_posix().encode() + b"\0" + data)
        target = TARGET / relative
        if not target.exists() or target.read_bytes() != data:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    content = hashlib.sha256()
    for name in sorted(path.name for path in (GAME / "data").glob("*.json")):
        content.update(name.encode() + b"\0" + (GAME / "data" / name).read_bytes())
    manifest = {"verifier_version": 2, "source_sha256": fingerprint.hexdigest(), "content_version": content.hexdigest(), "ruleset_version": "online-0.1", "shared_combat_sources": [str(relative) for _, relative in sources if str(relative).startswith("src")], "autoloads": []}
    previous = TARGET / "build.json"
    changed = not previous.exists() or json.loads(previous.read_text(encoding="utf-8")) != manifest
    if changed:
        log = LOCAL / "verification" / "room-import.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("wb") as output:
            result = subprocess.run([str(godot.resolve()), "--headless", "--path", str(TARGET), "--import"], stdout=output, stderr=subprocess.STDOUT, timeout=120)
        text = log.read_text(encoding="utf-8", errors="replace")
        if result.returncode or any(marker in text for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error")):
            raise RuntimeError(f"Isolated room import failed; inspect {log}")
        with log.open("ab") as output:
            result = subprocess.run([str(godot.resolve()), "--headless", "--path", str(TARGET), "--script", "res://RoomHost.gd", "--check-only"], stdout=output, stderr=subprocess.STDOUT, timeout=60)
        text = log.read_text(encoding="utf-8", errors="replace")
        if result.returncode or any(marker in text for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error")):
            raise RuntimeError(f"Isolated room compile failed; inspect {log}")
        previous.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2), flush=True)
    return TARGET, manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    args = parser.parse_args()
    build(args.godot)
