"""Foreground local development stack; Ctrl+C stops both services."""
import argparse
from pathlib import Path
import time
import uuid

from dev import LOCAL
from local_stack import LocalStack


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    stack = LocalStack(args.godot, LOCAL / "runs" / uuid.uuid4().hex)
    try:
        stack.start()
        print(f"Online development gateway: {stack.url}", flush=True)
        print("Private world worker and PostgreSQL remain local. Ctrl+C stops the gateway and worker.", flush=True)
        while all(p.poll() is None for p in stack.processes.values()):
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        stack.close()


if __name__ == "__main__":
    main()
