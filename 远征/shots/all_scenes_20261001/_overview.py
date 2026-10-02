# 生成全量场景总览图（按类别分 4 张 contact sheet）。
# 用法：python shots/all_scenes_20261001/_overview.py
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

SRC = os.path.dirname(os.path.abspath(__file__))
CELL_W, CELL_H = 150, 250
LABEL_H = 16
COLS = 8
BG = (26, 24, 20)
FG = (214, 204, 184)

UI = ["load", "title", "title_settings", "login", "namerecover", "prologue", "createrole",
      "home", "avatar", "deploy", "deploy_role", "deploy_pet", "worlds", "codex", "arena",
      "gacha", "exchange", "settings", "settings2", "growth", "bag", "bag_full", "quests",
      "gm", "gm_open", "talent", "equip", "pet_raise", "skillbook", "mount", "titles",
      "forge_enhance", "forge_gem", "forge_refine", "workshop_low", "workshop_progress"]

CITY = ["city", "city_repair", "city_built", "city_all", "city_mix", "city_shop",
        "city_notice", "city_guests", "city_build_panel", "city_built_panel",
        "city_frost_choice", "city_tide_choice", "city_deploy", "port_services",
        "side_city_accept", "beast_notice", "mentor_choice", "order_preview",
        "trade_warden_dialog", "mount_claim", "pet_claim",
        "companion_locked", "companion_first", "companion_second", "companion_help",
        "companion_world", "companion_lodge"]


VARIANTS = ["town_north", "town_north_left", "town_north_right",
            "town_middle", "town_middle_left", "town_middle_right",
            "town_south", "town_south_left", "town_south_right",
            "frost_art_north", "frost_art_north_left", "frost_art_north_right",
            "frost_art_south", "frost_art_south_left", "frost_art_south_right",
            "frost_art_coal", "frost_art_shield",
            "frost_art_envoy", "frost_art_guard", "frost_art_miner",
            "terrain_port", "terrain_port_south", "terrain_frost", "terrain_frost_south",
            "style_city", "style_battle", "style_forge", "style_bag"]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in (r"C:\Windows\Fonts\consola.ttf", r"C:\Windows\Fonts\msyh.ttc"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def sheet(names: list[str], out_name: str, subdir: str = "",
          cell: tuple[int, int] = (CELL_W, CELL_H)) -> None:
    base = os.path.join(SRC, subdir) if subdir else SRC
    names = [n for n in names if os.path.exists(os.path.join(base, n + ".png"))]
    if not names:
        return
    cell_w, cell_h = cell
    rows = (len(names) + COLS - 1) // COLS
    pad = 8
    cw = cell_w + pad
    ch = cell_h + LABEL_H + pad
    out = Image.new("RGB", (COLS * cw + pad, rows * ch + pad), BG)
    draw = ImageDraw.Draw(out)
    font = load_font(13)
    for i, name in enumerate(names):
        img = Image.open(os.path.join(base, name + ".png")).convert("RGB")
        img = img.resize((cell_w, cell_h), Image.LANCZOS)
        x = pad + (i % COLS) * cw
        y = pad + (i // COLS) * ch
        out.paste(img, (x, y))
        draw.text((x, y + cell_h + 2), name[:24], fill=FG, font=font)
    out.save(os.path.join(SRC, out_name))
    print("->", out_name, out.size, len(names), "shots")


def main() -> None:
    all_png = {f[:-4] for f in os.listdir(SRC) if f.endswith(".png") and not f.startswith("_")}
    sheet(UI, "_overview_1_ui.png")
    sheet(CITY, "_overview_2_city.png")
    rest = sorted(all_png - set(UI) - set(CITY) - set(VARIANTS))
    half = (len(rest) + 1) // 2
    sheet(rest[:half], "_overview_3_world.png")
    sheet(rest[half:], "_overview_4_acts.png")
    sheet(VARIANTS, "_overview_5_staging.png")
    long_dir = os.path.join(SRC, "long_480x1067")
    if os.path.isdir(long_dir):
        longs = sorted(f[:-4] for f in os.listdir(long_dir) if f.endswith(".png"))
        sheet(longs, "_overview_6_long.png", subdir="long_480x1067", cell=(120, 267))


if __name__ == "__main__":
    main()
