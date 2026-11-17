"""Install pinned official Prometheus tools into the ignored workspace runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

from dev import RUNTIME

VERSION = "3.16.0"
ARCHIVE = f"prometheus-{VERSION}.windows-amd64.zip"
ARCHIVE_SHA256 = "89c03c2f24400fb58668440b6d7226f68564acda27d657e77acfbda42be32cb3"
BASE = f"https://github.com/prometheus/prometheus/releases/download/v{VERSION}/"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proxy")
    args = parser.parse_args()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": args.proxy, "https": args.proxy}) if args.proxy else urllib.request.ProxyHandler())
    with opener.open(BASE + "sha256sums.txt", timeout=30) as response:
        checksums = response.read(1024 * 1024).decode("utf-8")
    expected = next(line.split()[0] for line in checksums.splitlines() if line.split()[-1].lstrip("*") == ARCHIVE)
    if expected != ARCHIVE_SHA256:
        raise RuntimeError("Official checksums differ from the pinned release digest")
    archive = RUNTIME / ARCHIVE
    def digest(path):
        checksum = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                checksum.update(block)
        return checksum.hexdigest()
    if not archive.is_file() or digest(archive) != expected:
        archive.parent.mkdir(parents=True, exist_ok=True)
        with opener.open(BASE + ARCHIVE, timeout=45) as response, archive.open("wb") as target:
            shutil.copyfileobj(response, target, 1024 * 1024)
    if digest(archive) != expected:
        raise RuntimeError("Official Prometheus archive SHA256 mismatch")
    target = RUNTIME / ("prometheus-" + VERSION)
    target.mkdir(parents=True, exist_ok=True)
    prefix = f"prometheus-{VERSION}.windows-amd64/"
    with zipfile.ZipFile(archive) as bundle:
        for name in ("prometheus.exe", "promtool.exe", "LICENSE", "NOTICE"):
            # Fixed member names, never arbitrary archive paths.
            data = bundle.read(prefix + name)
            (target / name).write_bytes(data)
    record = {"version": VERSION, "source": BASE + ARCHIVE, "sha256": expected,
              "checksums_source": BASE + "sha256sums.txt", "location": str(target),
              "executables_sha256": {name: digest(target / name) for name in ("prometheus.exe", "promtool.exe")}}
    (target / "provenance.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(record, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
