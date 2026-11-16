"""Install official portable runtimes inside the ignored workspace tools tree."""
import argparse
import binascii
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import threading
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / "tools" / "online-runtime"
GO_URL = "https://dl.google.com/go/go1.27.4.windows-amd64.zip"
GO_SHA = "178ab98950ac69ab25069307dc6ade79f3816e414cce95b4da166a115cde1e7e"
PG_URL = "https://get.enterprisedb.com/postgresql/postgresql-18.7-1-windows-x64-binaries.zip"
CHUNK = 2 * 1024 * 1024


class Ranges:
    def __init__(self, name, url, proxy):
        self.url = url
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({"http": proxy, "https": proxy})
            if proxy else urllib.request.ProxyHandler()
        )
        with self.opener.open(urllib.request.Request(url, method="HEAD"), timeout=20) as r:
            self.size = int(r.headers["Content-Length"])
        self.parts = RUNTIME / (name + "-parts")
        self.parts.mkdir(parents=True, exist_ok=True)
        self.locks = [threading.Lock() for _ in range((self.size + CHUNK - 1) // CHUNK)]

    def chunk(self, index):
        with self.locks[index]:
            path = self.parts / str(index)
            start = index * CHUNK
            end = min(self.size, start + CHUNK) - 1
            if path.exists() and path.stat().st_size == end - start + 1:
                return path.read_bytes()
            for attempt in range(5):
                try:
                    req = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}", "Cache-Control": "no-cache"})
                    with self.opener.open(req, timeout=15) as r:
                        if r.status != 206 or r.headers.get("Content-Range") != f"bytes {start}-{end}/{self.size}":
                            raise RuntimeError("invalid range response")
                        deadline = time.monotonic() + 25
                        data = bytearray()
                        while len(data) < end - start + 1:
                            block = r.read(min(65536, end - start + 1 - len(data)))
                            if not block:
                                break
                            data.extend(block)
                            if time.monotonic() > deadline:
                                raise TimeoutError("range exceeded wall time")
                    if len(data) != end - start + 1:
                        raise RuntimeError("incomplete range")
                    path.write_bytes(data)
                    return bytes(data)
                except Exception:
                    if attempt == 4:
                        raise
                    time.sleep(attempt + 1)

    def read(self, offset, size):
        end = min(self.size, offset + size)
        out = bytearray()
        while offset < end:
            index, inside = divmod(offset, CHUNK)
            block = self.chunk(index)
            count = min(len(block) - inside, end - offset)
            out.extend(block[inside:inside + count])
            offset += count
        return bytes(out)


class RemoteFile(io.RawIOBase):
    def __init__(self, ranges):
        self.ranges, self.position = ranges, 0

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.ranges.size + offset
        return self.position

    def tell(self):
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.ranges.size - self.position
        data = self.ranges.read(self.position, size)
        self.position += len(data)
        return data


def sha_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as src:
        while data := src.read(1024 * 1024):
            digest.update(data)
    return digest.hexdigest()


def extract(z, members):
    def canonical(path):
        value = str(path.resolve())
        # Windows may return its extended-length namespace for an in-flight path.
        # Compare both paths in the same namespace without weakening containment.
        if value.startswith("\\\\?\\"):
            value = value[4:]
        return Path(value)
    runtime_root = canonical(RUNTIME)
    def one(info):
        target = canonical(RUNTIME / info.filename)
        if not target.is_relative_to(runtime_root):
            raise RuntimeError(f"Archive path escapes runtime directory: {info.filename!r} -> {str(target)!r}; root={str(runtime_root)!r}")
        if info.is_dir():
            return
        if target.exists() and target.stat().st_size == info.file_size:
            if binascii.crc32(target.read_bytes()) & 0xffffffff == info.CRC:
                return
        data = z.read(info)  # ZipFile verifies each member CRC.
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        list(pool.map(one, members))


def install_go(proxy):
    marker = RUNTIME / "go-ready.json"
    if marker.exists():
        return json.loads(marker.read_text(encoding="utf-8"))
    archive = RUNTIME / "go.zip"
    if not archive.exists() or sha_file(archive) != GO_SHA:
        ranges = Ranges("go", GO_URL, proxy)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(ranges.chunk, range(len(ranges.locks))))
        with archive.open("wb") as out:
            for i in range(len(ranges.locks)):
                out.write(ranges.chunk(i))
    sha = sha_file(archive)
    if sha != GO_SHA:
        raise RuntimeError("Go official checksum mismatch")
    with zipfile.ZipFile(archive) as z:
        # Standard-library source and prebuilt tools suffice for application builds/tests.
        # Go compiler sources, SDK test fixtures and documentation are not runtime dependencies.
        members = [i for i in z.infolist() if (
            i.filename.startswith(("go/bin/", "go/pkg/", "go/lib/")) or
            i.filename in ("go/VERSION", "go/go.env", "go/LICENSE", "go/PATENTS") or
            (i.filename.startswith("go/src/") and not i.filename.startswith("go/src/cmd/") and "/testdata/" not in i.filename and not i.filename.endswith("_test.go"))
        )]
        print(f"Go: verifying/extracting {len(members)} build runtime members", flush=True)
        extract(z, members)
    result = {"name": "go", "version": "1.27.4", "url": GO_URL, "sha256": sha, "upstream_checksum": True}
    marker.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("Go installed and official SHA256 verified", flush=True)
    return result


def install_postgres(proxy):
    marker = RUNTIME / "postgres-ready.json"
    if marker.exists():
        return json.loads(marker.read_text(encoding="utf-8"))
    # EDB's archive includes pgAdmin and installer extras; only runtime files are needed.
    ranges = Ranges("postgres", PG_URL, proxy)
    with zipfile.ZipFile(RemoteFile(ranges)) as z:
        members = [i for i in z.infolist() if i.filename.startswith(("pgsql/bin/", "pgsql/lib/", "pgsql/share/"))]
        if not any(i.filename == "pgsql/bin/postgres.exe" for i in members):
            raise RuntimeError("Official PostgreSQL archive layout changed")
        needed = set()
        for i in members:
            if i.is_dir():
                continue
            start = i.header_offset
            end = min(ranges.size - 1, start + i.compress_size + len(i.filename.encode()) + 4096)
            needed.update(range(start // CHUNK, end // CHUNK + 1))
        print(f"PostgreSQL: {len(members)} runtime members need {len(needed)} archive ranges", flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(ranges.chunk, sorted(needed)))
        extract(z, members)
        fingerprint = hashlib.sha256("\n".join(f"{i.filename}:{i.CRC}:{i.file_size}" for i in members).encode()).hexdigest()
    result = {"name": "postgres", "version": "18.7", "url": PG_URL, "archive_members_sha256": fingerprint, "member_crc_verified": True, "upstream_checksum": False, "selection": ["pgsql/bin/", "pgsql/lib/", "pgsql/share/"]}
    marker.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("PostgreSQL runtime installed; member CRCs verified", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proxy", default=None, help="Use an existing configured proxy without changing global settings")
    args = parser.parse_args()
    RUNTIME.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        pending = [pool.submit(install_go, args.proxy), pool.submit(install_postgres, args.proxy)]
        results = [f.result() for f in pending]
    (RUNTIME / "manifest.json").write_text(json.dumps({"runtimes": results}, indent=2), encoding="utf-8")
    print("ONLINE_RUNTIME_READY", flush=True)


if __name__ == "__main__":
    main()
