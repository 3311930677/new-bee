"""Package generated blank artwork into the game's independent journal skin."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/ui/introduction_20261015'
SOURCE = Path(r'C:/Users/tsz/.codex/generated_images/01a13ba9-cbac-7f02-9e61-78c2b134a066')
SOURCES = {
    'world': 'exec-a8bfc296-de2d-4a29-8466-434b7eb0302e.png',
    'travelers': 'exec-434ad66d-bf9d-4d26-9eb0-8b1ce506a598.png',
    'route': 'exec-2a8740d1-31ad-421f-8348-6cf3ffc989bf.png',
    'travelers_tall': 'exec-cfea0023-37f4-4dea-aa58-961ad1b2fcec.png',
    'route_tall': 'exec-2f8c3680-76b8-4652-a912-9d92f2388a28.png',
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    blank = Image.open(SOURCE / SOURCES['world']).convert('RGBA')
    def crop(name, rect, width):
        im = blank.crop(rect)
        im = im.resize((width, round(im.height * width / im.width)), Image.Resampling.LANCZOS)
        im.save(OUT / (name + '.png'))
    crop('header', (0, 0, 971, 128), 960)
    crop('world', (0, 220, 971, 1090), 960)
    crop('button_dark', (26, 1452, 396, 1569), 370)
    crop('button_red', (574, 1452, 946, 1569), 372)
    # The generated blank tabs provide clean top/bottom rails and a repeatable
    # center strip. Package those regions without baking pictograms into buttons.
    for name, rect in [('tab_red', (20, 127, 343, 220)), ('tab_dark', (344, 127, 643, 220))]:
        source = blank.crop(rect)
        tile = Image.new('RGBA', (320, source.height))
        tile.paste(source.crop((0, 0, 30, source.height)), (0, 0))
        tile.paste(source.crop((source.width-30, 0, source.width, source.height)), (290, 0))
        strip_x = 210 if name == 'tab_red' else 160
        tile.paste(source.crop((strip_x, 0, strip_x+20, source.height)).resize((260, source.height)), (30, 0))
        tile.save(OUT / (name + '.png'))
    panel = blank.crop((0, 1056, 971, 1438))
    mask = Image.new('L', panel.size)
    ImageDraw.Draw(mask).polygon([(0, 6), (78, 6), (108, 35), (861, 35), (890, 6), (971, 6), (971, 382), (0, 382)], fill=255)
    panel.putalpha(mask)
    panel.resize((480, 189), Image.Resampling.LANCZOS).save(OUT / 'reading_panel.png')
    for name in ['travelers', 'route', 'travelers_tall', 'route_tall']:
        art = Image.open(SOURCE / SOURCES[name]).convert('RGB')
        art.resize((960, round(art.height * 960 / art.width)), Image.Resampling.LANCZOS).save(OUT / (name + '.png'))
    icons = [
        ('world', blank, (70, 141, 126, 198)),
        ('travelers', blank, (400, 152, 448, 195)),
        ('route', blank, (700, 149, 740, 194)),
    ]
    for name, im, rect in icons:
        if (OUT / ('icon_' + name + '.png')).exists():
            continue
        icon = im.crop(rect).convert('RGBA')
        pixels = icon.load()
        for y in range(icon.height):
            for x in range(icon.width):
                r, g, b, a = pixels[x, y]
                pixels[x, y] = (r, g, b, a if g > 45 and r > g and g > b * 1.12 else 0)
        icon.save(OUT / ('icon_' + name + '.png'))
    divider = Image.new('RGBA', (380, 12))
    draw = ImageDraw.Draw(divider)
    draw.line((0, 6, 165, 6), fill='#bb8747', width=1)
    draw.polygon([(69, 6), (75, 1), (81, 6), (75, 11)], outline='#dfb875', width=1)
    draw.polygon([(73, 6), (75, 4), (77, 6), (75, 8)], fill='#dfb875')
    divider.save(OUT / 'divider.png')
    (OUT / 'source_manifest.json').write_text(json.dumps({
        'tool': 'built-in image_gen', 'sources': SOURCES,
        'prompts': {
            'world': 'Remove all Chinese text and digits from the complete reference UI; preserve landscape, gold frames, red active tab, pictograms, banners and compass watermark; reconstruct blank dark backgrounds.',
            'travelers': 'Extract the central castle illustration; preserve all four characters and weapons; remove Chinese character names/jobs and all surrounding UI.',
            'route': 'Extract the central parchment-map courtyard illustration; remove glowing route, nodes and Chinese text; retain blank parchment plaques, geography, lanterns and banners.',
            'tall_variants': 'Outpaint each illustration to portrait 2:3; preserve characters/map in the central full-width band; add naturally continuing moonlit sky/castle above and courtyard/street/table foreground below; no duplicated or reflected elements, no stretched bodies, no text.',
        },
        'packaging': 'Crop/resize art; isolate existing tab pictograms; extract panel alpha; code-native divider.'
    }, ensure_ascii=False, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
