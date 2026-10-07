"""One-time configuration migration; preserve all unrelated current map fields."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "data/main_world_maps.json"
data = json.loads(path.read_text(encoding="utf-8"))

def route(points, width=144):
    return {"points": points, "width": width}

axis = [[480, 1152], [480, 1040], [440, 850], [515, 640], [450, 400], [480, 185], [480, 96]]
straight = [[480, 1152], [480, 1050], [480, 700], [480, 400], [480, 96]]
routes = {
    "lorin_wilds": [route(straight)],
    "maple_road": [route(axis, 162), route([[515, 640], [675, 665], [864, 660]], 144),
                   route([[470, 400], [590, 325], [685, 310]], 110)],
    "broken_slope": [route([[480, 1152], [480, 1040], [475, 930], [525, 735], [415, 560], [505, 330], [480, 185], [480, 96]], 162),
                     route([[475, 930], [355, 950], [255, 950]], 112)],
    "old_salt_road": [route([[90, 660], [160, 660], [345, 625], [530, 680], [715, 625], [864, 660]], 168),
                      route([[460, 660], [455, 560], [480, 500]], 112)],
    "shenyuan_port": [route([[480, 1152], [480, 940], [480, 700], [480, 450], [480, 96]], 168),
                      route([[90, 660], [210, 660], [480, 675], [690, 700], [864, 700]], 150),
                      route([[300, 372], [480, 400], [650, 400]], 130),
                      route([[300, 870], [480, 890], [650, 870]], 130)],
    "tideflat": [route([[90, 700], [165, 700], [320, 730], [480, 650], [510, 470], [455, 270], [480, 185], [480, 96]], 170),
                 route([[480, 650], [455, 850], [480, 1060]], 154)],
    "tidal_gate": [route(straight, 228)],
    "stele_cavern": [route(straight, 160), route([[205, 970], [480, 970], [755, 970]], 274),
                     route([[290, 645], [480, 645], [670, 645]], 154),
                     route([[335, 300], [480, 300], [625, 300]], 264)],
    "red_sand_route": [route([[480, 1152], [480, 1050], [450, 860], [515, 680], [450, 465], [480, 220], [480, 96]], 170)],
    "frost_post": [route(straight, 160), route([[480, 700], [660, 725], [864, 710]], 140),
                   route([[335, 450], [480, 450], [630, 450]], 124), route([[335, 860], [480, 860], [630, 860]], 124)],
    "rift_mine_road": [route(straight, 176), route([[90, 710], [160, 710], [315, 710], [480, 700]], 122)],
    "rift_mine_vault": [route(straight, 184), route([[365, 990], [480, 990], [595, 990]], 266),
                        route([[345, 635], [480, 635], [615, 635]], 206), route([[375, 295], [480, 295], [585, 295]], 246)],
    "frost_pass": [route([[480, 1152], [480, 1050], [465, 850], [480, 660], [455, 390], [480, 165]], 180),
                   route([[480, 660], [675, 645], [864, 660]], 144)],
    "frost_boardwalk": [route(straight, 166)],
    "abyss_ring": [route(axis, 188)],
    "stele_entry": [route(axis, 172)],
    "stele_resonance": [route(straight, 178), route([[480, 880], [405, 895], [335, 880]], 148),
                        route([[480, 625], [550, 640], [625, 625]], 148), route([[480, 375], [405, 390], [335, 375]], 148)],
    "stele_core": [route(straight, 178), route([[375, 570], [480, 570], [585, 570]], 330)],
}
palettes = {
    "maple_road": ["a1a34e", "adb35b", "829347", "e7d490", "cfbc75", "grass"],
    "broken_slope": ["7d8069", "8b8e75", "686f5b", "cec8a5", "b9b394", "stone"],
    "old_salt_road": ["afa17b", "bcad85", "958c6b", "e9dbb5", "cdbf9b", "sand"],
    "shenyuan_port": ["708f88", "819c92", "5c7d76", "cbd0b7", "b1bca7", "stone"],
    "tideflat": ["829b82", "92ab8d", "6b8976", "d9d4ae", "bdc09e", "sand"],
    "tidal_gate": ["537f84", "628d90", "426f77", "b7c7b6", "9eafa4", "stone"],
    "stele_cavern": ["525c59", "606b65", "434f4d", "adb6a1", "939e8c", "stone"],
    "red_sand_route": ["a47756", "b5845d", "8d644d", "dcc19a", "c3a57f", "sand"],
    "frost_post": ["94aeb3", "a3bbc0", "7e9da5", "e1e8dc", "c3d3cd", "snow"],
    "rift_mine_road": ["6b6561", "7a7269", "575859", "b7ae94", "9c947e", "stone"],
    "rift_mine_vault": ["5e5758", "6d6461", "4d4b50", "b2a591", "958d7e", "stone"],
    "frost_pass": ["79a4b2", "88b1bc", "66909f", "d6e7e8", "b7d3db", "snow"],
    "frost_boardwalk": ["8da9b4", "9cb7bf", "7695a3", "e0e9df", "c4d6d1", "snow"],
    "abyss_ring": ["565365", "635e72", "444557", "aca7b9", "9390a5", "stone"],
    "stele_entry": ["606572", "6e7380", "4f5665", "bbb9bb", "a1a3a9", "stone"],
    "stele_resonance": ["656474", "757185", "525565", "c3bacd", "a79fb2", "stone"],
    "stele_core": ["5a616f", "687281", "495261", "b7c6c6", "99adaf", "stone"],
}
for mid, cfg in data["maps"].items():
    cfg["ground_style"] = "reference_flat" if mid == "lorin_wilds" else "flat"
    cfg["flat_routes"] = routes[mid]
    if mid in palettes: cfg["flat_palette"] = palettes[mid]
    if mid in {"tidal_gate", "stele_cavern", "rift_mine_vault", "frost_pass", "abyss_ring", "stele_entry", "stele_resonance", "stele_core"}:
        cfg["decos"] = []
    if mid in {"maple_road", "broken_slope", "old_salt_road", "tideflat", "red_sand_route", "rift_mine_road", "frost_boardwalk"}:
        cfg["deco_density"] = 0.095
    cfg["deco_tint"] = "ffffff"
    materials = {"maple_road": "forest", "broken_slope": "stone", "old_salt_road": "salt",
                 "shenyuan_port": "wet", "tideflat": "wet", "tidal_gate": "wet",
                 "stele_cavern": "stone", "red_sand_route": "desert", "frost_post": "snow",
                 "rift_mine_road": "stone", "rift_mine_vault": "stone", "frost_pass": "snow",
                 "frost_boardwalk": "snow", "abyss_ring": "abyss", "stele_entry": "abyss",
                 "stele_resonance": "abyss", "stele_core": "abyss"}
    if mid in materials: cfg["flat_material"] = materials[mid]
    cfg["surface_tint"] = {"maple_road": "fff2d6", "stele_cavern": "ccd6d8",
                           "rift_mine_vault": "c3b6be", "frost_pass": "dcefff",
                           "stele_entry": "dce5eb", "stele_resonance": "ece0f7",
                           "stele_core": "d6f0ed"}.get(mid, "ffffff")
text = json.dumps(data, ensure_ascii=False, indent=2)
# Keep route coordinates compact enough to edit and review beside existing map anchors.
decoder = json.JSONDecoder()
for field in ("flat_routes", "flat_palette"):
    marker = f'"{field}": '
    start = 0
    while (key := text.find(marker, start)) != -1:
        at = key + len(marker)
        value, length = decoder.raw_decode(text[at:])
        compact = json.dumps(value, ensure_ascii=False)
        if field == "flat_routes":
            compact = '[\n' + ',\n'.join('        '+json.dumps(r, ensure_ascii=False) for r in value) + '\n      ]'
        text = text[:at] + compact + text[at+length:]
        start = at + len(compact)
path.write_text(text + "\n", encoding="utf-8")
