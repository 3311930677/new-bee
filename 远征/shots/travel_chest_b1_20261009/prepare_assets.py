from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[3]
folder=root/'远征/assets/ui/travel_chest_b1'
regions={}
def add(key,file,box):
    im=Image.open(folder/file).convert('RGBA')
    alpha=im.getchannel('A')
    crop=alpha.crop(box)
    bbox=crop.point(lambda x:255 if x>24 else 0).getbbox()
    assert bbox,key
    x=box[0]+bbox[0];y=box[1]+bbox[1]
    regions[key]={'file':file,'source_size':list(im.size),'rect':[x,y,bbox[2]-bbox[0],bbox[3]-bbox[1]],'alpha_max':crop.getextrema()[1]}
for stem in ['primary','hero']:
    file=stem+'_states.png'
    im=Image.open(folder/file).convert('RGBA')
    alpha=im.getchannel('A')
    bands=[];start=None
    for y in range(im.height):
        n=sum(v>32 for v in alpha.crop((0,y,im.width,y+1)).getdata())
        on=n>im.width*.03
        if on and start is None:start=y
        if not on and start is not None:
            if y-start>20:bands.append((start,y))
            start=None
    if start is not None:bands.append((start,im.height))
    assert len(bands)==3,(file,bands)
    for state,(a,b) in zip(['normal','pressed','disabled'],bands): add(stem+'_'+state,file,(0,max(0,a-2),im.width,min(im.height,b+2)))
im=Image.open(folder/'icons.png')
keys=['world','bag','growth','codex','event','arena','summon','exchange','reunion','settings','back','journey']
for i,key in enumerate(keys):
    x=i%4;y=i//4
    add(key,'icons.png',(round(x*im.width/4),round(y*im.height/3),round((x+1)*im.width/4),round((y+1)*im.height/3)))
for key,file in [('tray_rim','tray_rim.png'),('stage_pool','stage_pool.png')]:
    im=Image.open(folder/file); add(key,file,(0,0,im.width,im.height))
(folder/'regions.json').write_text(json.dumps(regions,ensure_ascii=False,indent=2),encoding='utf-8')
print('Read-only alpha regions:',len(regions),'sprites; generated PNGs unmodified.')
# Replace only the visual build path; keep all existing panel and world callbacks.
p=root/'远征/src/ui/GameHome.gd';s=p.read_text(encoding='utf-8-sig')
s=s.replace('const VIEW_W :=','const ChestUI := preload("res://src/ui/TravelChestUI.gd")\nconst ChestView := preload("res://src/ui/CampChestView.gd")\nconst VIEW_W :=',1)
s=s.replace('var _avatar_frame: Panel = null','var _avatar_frame: Control = null')
s=s.replace('var _wallet_labels: Array = []','var _wallet_labels: Array = []\nvar _chest_view: Control\nvar _chest_dialog: Control\nvar _dialog_return_focus: Control')
a=s.index('func _ready() -> void:');b=s.index('func _clean_home_text',a)
s=s[:a]+'''func _ready() -> void:
\tAudio.play_bgm("bgm_home")
\t_chest_view = ChestView.new()
\t_chest_view.name = "CampChest"
\t_chest_view.host = self
\tadd_child(_chest_view)
\t_prompt_save_locked()

'''+s[b:]
s=s.replace('for child in get_children():\n\t\tif child != _deploy','''for child in get_children():
\t\tif child == _chest_view:
\t\t\t_chest_view.content.visible = visible
\t\t\tif visible:
\t\t\t\t_chest_view.modulate.a = 1
\t\t\t\t_chest_view._hero.disabled = false
\t\t\t\t_chest_view.refresh()
\t\t\tcontinue
\t\tif child != _deploy''',1)
s=s.replace('func _refresh_wallet() -> void:\n','''func _refresh_wallet() -> void:
\tif _chest_view != null:
\t\t_chest_view.refresh()
\t\treturn
''',1)
s=s.replace('func _layout_tall_home() -> void:\n','''func _layout_tall_home() -> void:
\tif _chest_view != null:
\t\t_chest_view.layout()
\t\treturn
''',1)
s=s.replace('func _close_overlay_with_escape() -> bool:\n','''func _close_overlay_with_escape() -> bool:
\tif _chest_dialog != null:
\t\t_close_chest_dialog()
\t\treturn true
''',1)
s+='''
func _show_chest_dialog(title: String, lines: Array, choices: Array = [], cb: Callable = Callable()) -> void:
\tif _chest_dialog != null: return
\t_dialog_return_focus = get_viewport().gui_get_focus_owner()
\tvar dialog := ChestUI.Modal.new()
\tdialog.heading = title
\tdialog.lines = lines
\tdialog.choices = choices
\tdialog.closed.connect(_close_chest_dialog)
\tdialog.selected.connect(func(index: int):
\t\t_close_chest_dialog()
\t\tif cb.is_valid(): cb.call(index))
\t_chest_dialog = dialog
\tadd_child(dialog)

func _close_chest_dialog() -> void:
\tif _chest_dialog == null: return
\t_chest_dialog.queue_free()
\t_chest_dialog = null
\tif is_instance_valid(_dialog_return_focus) and _dialog_return_focus.is_visible_in_tree(): _dialog_return_focus.grab_focus()
'''
p.write_text(s,encoding='utf-8')
