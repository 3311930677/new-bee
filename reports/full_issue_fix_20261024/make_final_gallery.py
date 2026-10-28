from pathlib import Path
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parent
paths=[root/'final_phone20'/name for name in ['login.png','pet_1_owned.png','currency_honor.png','exchange.png','curio_lore.png','curio_appraise.png']]
gallery=Image.new('RGB',(6*240,560),'#25343b')
for i,path in enumerate(paths):
    with Image.open(path) as image:
        image.thumbnail((230,520))
        gallery.paste(image,(i*240+(240-image.width)//2,32))
    ImageDraw.Draw(gallery).text((i*240+8,10),path.stem,fill='white')
gallery.save(root/'final_ui_gallery.jpg',quality=94)
paths=[root/'final_android_maps'/name for name in ['map_stele_cavern_0.png','map_tidal_gate_0.png','map_rift_mine_vault_0.png','map_stele_entry_0.png','map_stele_resonance_2.png','map_stele_core_2.png']]
gallery=Image.new('RGB',(6*240,450),'#25343b')
for i,path in enumerate(paths):
    with Image.open(path) as image:
        image.thumbnail((230,400))
        gallery.paste(image,(i*240+(240-image.width)//2,32))
    ImageDraw.Draw(gallery).text((i*240+4,10),path.stem.removeprefix('map_'),fill='white')
gallery.save(root/'final_map_gallery.jpg',quality=94)
print('FINAL_GALLERIES_OK')
