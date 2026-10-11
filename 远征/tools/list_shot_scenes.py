import re

with open(r"tools/ShotRunner.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

in_setup = False
for idx, line in enumerate(lines, 1):
    if "func _setup()" in line:
        in_setup = True
        continue
    if in_setup:
        m = re.match(r'^\t\t"([^"]+)":', line)
        if m:
            print(f"{idx:4d}: {m.group(1)}")

