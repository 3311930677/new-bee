extends RefCounted
## Components for the screenshot review. All quantities come from existing controllers.
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const ROOT:="res://assets/ui/full_review_fixes_20261009/"
static var _regions:Dictionary={}
static var _textures:Dictionary={}
static var _pixel_regions:Dictionary={}
static func texture(id:String) -> Texture2D:
	if _textures.has(id):return _textures[id]
	if _pixel_regions.is_empty() and FileAccess.file_exists("res://assets/ui/next_review_20261009/regions.json"):_pixel_regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/next_review_20261009/regions.json"))
	if _pixel_regions.has(id):
		var entry:Dictionary=_pixel_regions[id]
		var pixels:=AtlasTexture.new();pixels.atlas=load("res://assets/ui/next_review_20261009/"+String(entry.file));pixels.region=Rect2(entry.rect[0],entry.rect[1],entry.rect[2],entry.rect[3]);pixels.filter_clip=true
		pixels.set_meta("pixel_art",true);_textures[id]=pixels;return pixels
	if _regions.is_empty() and FileAccess.file_exists(ROOT+"regions.json"):_regions=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"regions.json"))
	if not _regions.has(id):return null
	var entry:Dictionary=_regions[id]
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(ROOT+String(entry.file))
	var scaling:=atlas.atlas.get_size()/Vector2(entry.source_size[0],entry.source_size[1])
	atlas.region=Rect2(Vector2(entry.rect[0],entry.rect[1])*scaling,Vector2(entry.rect[2],entry.rect[3])*scaling)
	_textures[id]=atlas
	return atlas
static func item(id:String) -> Texture2D:
	var tex:=texture(id)
	return tex if tex!=null else G.res_tex(String(G.equip_tpl(id).get("icon","")))
static func shortage(costs:Array) -> String:
	var missing:PackedStringArray=[]
	for cost in costs:
		var gap:=int(cost.need)-int(cost.have)
		if gap>0:missing.append("%s差%d"%[cost.name,gap])
	return " · ".join(missing)
static func pet(id:String) -> Texture2D:
	var tex:=texture(id)
	return tex if tex!=null else G.res_tex(id)
static func skill(id:String) -> Texture2D:
	var tex:=texture(id)
	return tex if tex!=null else preload("res://src/ui/FlowChestUI.gd").texture("skill")

class ContextStage extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Fix=preload("res://src/ui/ReviewFixUI.gd")
	var kind:String
	var picture:TextureRect
	func _init(which:String="chest") -> void:kind=which
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture=TextureRect.new()
		picture.texture=load("res://image/battle/art_v2/forest_clearing.png") if kind=="skill" else Fix.texture(kind)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		picture.modulate=Color(.5,.5,.5) if kind=="skill" else Color.WHITE
		add_child(picture)
		resized.connect(func():picture.size=size;queue_redraw())
		picture.size=size
	func _draw() -> void:draw_rect(Rect2(Vector2.ZERO,size),UI.NIGHT)

class Paper extends PanelContainer:
	func _ready() -> void:
		var box:=StyleBoxFlat.new()
		box.bg_color=Color("e8dcc0")
		box.border_color=Color("b6a27b")
		box.set_border_width_all(1)
		box.content_margin_left=16;box.content_margin_right=16;box.content_margin_top=12;box.content_margin_bottom=12
		add_theme_stylebox_override("panel",box)

class CostChip extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var need:int
	var owned:int
	var picture:TextureRect
	var amount:Label
	var holding:Label
	var heading:Label
	var lacking:Label
	func _init(words:String,required:int,have:int,tex:Texture2D=null) -> void:
		need=required;owned=have
		custom_minimum_size=Vector2(0,56)
		size_flags_horizontal=Control.SIZE_EXPAND_FILL
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		set_meta("cost_need",need);set_meta("cost_owned",owned)
		picture=Page.picture(tex,Vector2(28,28));add_child(picture)
		heading=UI.label(words,"tag",UI.AGED);add_child(heading)
		amount=UI.label(str(need),"number",UI.RED if owned<need else UI.PAPER);amount.add_theme_font_size_override("font_size",20);add_child(amount)
		holding=UI.label("持有 "+UI.format_number(owned),"tag",UI.AGED);add_child(holding)
		lacking=UI.label("不足" if owned<need else "","tag",UI.RED);add_child(lacking)
	func _ready() -> void:resized.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE,UI.RED if owned<need else Color("3a3037"))
		picture.position=Vector2(12,14)
		heading.position=Vector2(52,2);heading.size=Vector2(size.x-80,20)
		amount.position=Vector2(52,20);amount.size=Vector2(64,32)
		holding.position=Vector2(116,25);holding.size=Vector2(maxf(80,size.x-122),22)
		lacking.position=Vector2(size.x-34,2);lacking.size=Vector2(30,20)

class Investment extends VBoxContainer:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var costs:HBoxContainer
	func _init(change:String,delta:String="",probability:String="",rules:Array=[],inline_delta:bool=false) -> void:
		size_flags_horizontal=Control.SIZE_EXPAND_FILL
		add_theme_constant_override("separation",12)
		var title:=Page.line(change,"number",UI.PAPER)
		title.add_theme_font_size_override("font_size",22)
		var title_row:=HBoxContainer.new();add_child(title_row);title_row.add_child(title);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if not delta.is_empty():
			var deltas:=HFlowContainer.new();deltas.add_theme_constant_override("h_separation",8)
			if inline_delta:title_row.add_child(deltas)
			else:add_child(deltas)
			for part in delta.split(" · "):
				var chip:=PanelContainer.new();var box:=StyleBoxFlat.new();box.bg_color=Color("28352c");box.set_content_margin_all(6);chip.add_theme_stylebox_override("panel",box);deltas.add_child(chip)
				chip.add_child(UI.label(part,"caption",UI.JADE))
		if not probability.is_empty():
			var row:=HBoxContainer.new();row.custom_minimum_size.y=44;add_child(row)
			var label:=Page.line(probability,"body",UI.PAPER);row.add_child(label)
			if not rules.is_empty():
				var info:=UI.action("说明","quiet");info.custom_minimum_size=Vector2(56,44);row.add_child(info)
				info.pressed.connect(func():preload("res://src/ui/FlowChestUI.gd").info(self,"投入规则",rules))
		costs=HBoxContainer.new();costs.add_theme_constant_override("separation",8);add_child(costs)

class Gauge extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var current:=0.0
	var maximum:=100.0
	var tint:=UI.JADE
	var markers:Array=[]
	var caption:Label
	var value:Label
	func _init(words:String="",color:Color=UI.JADE) -> void:
		tint=color;mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption=UI.label(words,"tag",UI.AGED);add_child(caption)
		value=UI.label("","tag");value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;add_child(value)
	func _ready() -> void:resized.connect(queue_redraw)
	func update(amount:float,limit:float) -> void:
		current=amount;maximum=maxf(1,limit);value.text="%d/%d"%[amount,limit];queue_redraw()
	func _draw() -> void:
		caption.position=Vector2.ZERO;caption.size=Vector2(size.x*.45,20)
		value.position=Vector2(size.x*.35,0);value.size=Vector2(size.x*.65,20)
		draw_rect(Rect2(0,size.y-7,size.x,6),Color("0a090b"))
		draw_rect(Rect2(1,size.y-6,(size.x-2)*clampf(current/maximum,0,1),4),tint)
		for marker in markers:
			var x:=1+(size.x-2)*clampf(float(marker)/maximum,0,1)
			draw_line(Vector2(x,size.y-10),Vector2(x,size.y-1),Color("f3e8d0",.7),1)

class SkillRow extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var image:TextureRect
	var heading:Label
	var status:Label
	var next_action:Label
	var actionable:=false
	var cooldown:=0.0
	var cooldown_max:=1.0
	var missing:=0
	func _init(words:String,tex:Texture2D) -> void:
		text=words;custom_minimum_size=Vector2(0,64)
		image=Page.picture(tex,Vector2(40,40));add_child(image)
		var state_material:=ShaderMaterial.new();state_material.shader=UI.disabled_shader();image.material=state_material
		heading=UI.label(words,"section");heading.name="NameText";add_child(heading)
		status=UI.label("","caption",UI.AGED);status.name="DetailText";add_child(status)
		next_action=UI.label("","tag");next_action.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(next_action)
	func _ready() -> void:
		for s in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(s,StyleBoxEmpty.new())
		for p in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:add_theme_color_override(p,Color.TRANSPARENT)
		for e in [resized,focus_entered,focus_exited,mouse_entered,mouse_exited]:e.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE,UI.COPPER if has_focus() else Color("3a3037"))
		image.position=Vector2(12,12);image.modulate=Color.WHITE
		(image.material as ShaderMaterial).set_shader_parameter("gray",1.0 if disabled else 0.0)
		heading.position=Vector2(64,1);heading.size=Vector2(size.x-180,28);heading.modulate=Color(.7,.7,.7) if disabled else Color.WHITE
		status.position=Vector2(64,31);status.size=Vector2(size.x-180,26)
		next_action.position=Vector2(size.x-106,18);next_action.size=Vector2(98,28)
		if cooldown>0:
			next_action.text="%.1fs"%cooldown;next_action.add_theme_color_override("font_color",UI.BLUE)
			draw_arc(Vector2(size.x-116,32),9,-PI*.5,-PI*.5+TAU*clampf(cooldown/cooldown_max,0,1),32,UI.BLUE,2,true)
		elif missing>0:next_action.text="差 %d 能量"%missing;next_action.add_theme_color_override("font_color",UI.RED)
		else:
			next_action.text="施放";next_action.add_theme_color_override("font_color",UI.GOLD)
			UI.surface(self,Rect2(size.x-88,18,72,28),UI.SELECTED,UI.COPPER)

class EnemyChip extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var unit:Combatant
	var portrait:TextureRect
	var heading:Label
	var value:Label
	var marker:Label
	var focused:=false
	var automatic:=false
	var extra:=0
	var number:=1
	var display_name:=""
	func _init(tex:Texture2D=null) -> void:
		custom_minimum_size=Vector2(0,44);size_flags_horizontal=Control.SIZE_EXPAND_FILL
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		portrait=Page.picture(tex,Vector2(32,32));portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(portrait)
		heading=UI.label("","tag");heading.clip_text=true;heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(heading)
		value=UI.label("","tag",UI.AGED);add_child(value)
		marker=UI.label("","tag",UI.GOLD);marker.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;add_child(marker)
	func _ready() -> void:resized.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.SELECTED if focused else UI.FACE,UI.GOLD if focused else UI.BRONZE)
		if focused:draw_rect(Rect2(1,1,size.x-2,size.y-2),UI.GOLD,false,2)
		portrait.position=Vector2(5,6)
		heading.position=Vector2(41,0);heading.size=Vector2(size.x-45,20)
		value.position=Vector2(41,21);value.size=Vector2(size.x-45,19)
		# The narrow chip reserves its text area for the name and HP.
		# A focus badge sits over the portrait, never over the name.
		marker.position=Vector2(3,25);marker.size=Vector2(34,18)
		marker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		marker.text=""
		draw_circle(Vector2(10,9),7,UI.GOLD if focused else UI.NIGHT)
		draw_arc(Vector2(10,9),7,0,TAU,24,UI.COPPER,1)
		draw_string(G.font_bold,Vector2(6,13),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.NIGHT if focused else UI.PAPER)

		if extra>0:heading.text="+%d"%extra;value.text="敌人";portrait.visible=false;return
		if unit==null:return
		heading.text=display_name if not display_name.is_empty() else unit.name
		value.text="%d/%d"%[unit.hp,unit.get_max_hp()]
		portrait.modulate=Color.WHITE if unit.alive else Color(.35,.35,.35)
		draw_rect(Rect2(41,20,maxf(4,size.x-46),3),UI.NIGHT)
		draw_rect(Rect2(41,20,maxf(4,size.x-46)*clampf(float(unit.hp)/maxi(1,unit.get_max_hp()),0,1),3),Color("e58a72"))
		if not unit.alive:draw_line(Vector2(42,10),Vector2(size.x-5,10),UI.ASH,1)
