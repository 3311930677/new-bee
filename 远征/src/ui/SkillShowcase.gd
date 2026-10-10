extends Control
## Isolated cosmetic preview; does not create BattleSim or mutate player state.
const Craft := preload("res://src/ui/CraftUI.gd")
const Effects := preload("res://src/battle/BattleEffects.gd")
const Props := preload("res://src/world/WorldPropArt.gd")
const ART_BY_ROLE := {
	"zs":["gold_holy_slash","red_claw_marks","gold_sword_rain","area_spell_circle","gold_holy_slash"],
	"ck":["white_lightning","white_lightning","red_claw_marks","purple_void","white_lightning"],
	"fs":["blue_ice_burst","blue_ice_burst","blue_ice_burst","area_spell_circle","purple_void"],
	"fz":["area_spell_circle","area_spell_circle","green_vine_ring","area_spell_circle","area_spell_circle"]}
var skill_id := ""
var role_id := "fs"
var _actor: AnimatedSprite2D
var _target: Node2D
var _effects: Control
var _illustration: TextureRect
var _age := 0.0
var _tint := Color("8ed8f2")
var _data: Dictionary
var _support := false
var _self_target := false
var _group := false
var _scene:Node2D
var _play_button:Control

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene=Node2D.new();add_child(_scene)
	_data = TableCache.get_skill(skill_id)
	var target_name := String(_data.get("target",""))
	_support = target_name.begins_with("ally")
	_self_target = target_name=="self"
	_group = target_name in ["enemy_all","enemy_front_all","enemy_random","ally_all"]
	_tint = Craft.ROLE_COLORS.get(role_id,Craft.GOLD)
	var floor_art := TextureRect.new()
	floor_art.texture = load("res://image/battle/art_v2/forest_clearing.png")
	floor_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	floor_art.position = Vector2(0,-235)
	floor_art.size = Vector2(size.x,600)
	floor_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_art.modulate = Color(.5,.5,.5)
	_scene.add_child(floor_art)
	var sheet: Texture2D = load(G.role_dir(role_id)+G.role_art_name(role_id)+"_spritesheet.png")
	# The legacy priest combat atlas clips limbs and depicts a different portrait.
	# Keep the actual field character intact and animate a casting gesture instead.
	var field_sheet: Texture2D = load(G.role_dir(role_id)+G.role_art_name(role_id)+"_idle.png") if role_id=="fz" else null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in [["idle",0,true,5.0],["attack",1,false,11.0],["cast",2,false,8.0]]:
		frames.add_animation(row[0])
		frames.set_animation_loop(row[0],row[2])
		frames.set_animation_speed(row[0],row[3])
		for col in 4:
			var frame := AtlasTexture.new()
			frame.atlas = field_sheet if field_sheet!=null else sheet
			frame.region = Rect2(col*128,0,128,128) if field_sheet!=null else Rect2(col*128,int(row[1])*128,128,128)
			frames.add_frame(row[0],frame)
	_actor = AnimatedSprite2D.new()
	_actor.sprite_frames = frames
	_actor.position = Vector2(100,123)
	_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actor.animation_finished.connect(func(): _actor.play(&"idle"))
	_actor.play(&"idle")
	_scene.add_child(_actor)
	_target = PracticeTarget.new()
	_target.position = Vector2(280,180)
	_scene.add_child(_target)
	if _group and not _support:
		for at in [Vector2(236,177),Vector2(316,176)]:
			var additional := PracticeTarget.new()
			additional.position = at
			additional.scale = Vector2.ONE*.68
			_scene.add_child(additional)
	if _self_target: _target.visible=false
	if _support:
		_target.visible = false
		var companion := Sprite2D.new()
		companion.texture = G.res_tex("pet_rockturtle")
		companion.position = Vector2(275,145)
		companion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if companion.texture != null:
			companion.scale = Vector2.ONE*(75.0/companion.texture.get_height())
		_scene.add_child(companion)
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_effects)
	_illustration = TextureRect.new()
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var index := (G.get_role(role_id).get("skills",[]) as Array).find(skill_id)
	var art_name := String(ART_BY_ROLE.get(role_id,ART_BY_ROLE.fs)[clampi(index,0,4)])
	_illustration.texture = load("res://image/generated_362_xajh/ready/fx/e_effect_%s.png" % art_name)
	_illustration.position = Vector2(208,66)
	if _self_target: _illustration.position = Vector2(33,66)
	_illustration.size = Vector2(134,134)
	_illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_illustration.material = additive
	_scene.add_child(_illustration)
	var play := Craft.action("▶",Vector2(size.x-56,size.y-56),Vector2(44,44))
	play.tooltip_text = "播放招式预览"
	play.activated.connect(_play)
	add_child(play)
	_play_button=play
	resized.connect(_layout)
	_layout()
	_play()

func _layout() -> void:
	# Fit the whole cosmetic stage while keeping its replay touch target at 44px.
	var factor:=minf(1,minf(size.x/352.0,size.y/224.0))
	_scene.scale=Vector2.ONE*factor
	_scene.position=(size-Vector2(352,224)*factor)*.5
	_play_button.position=size-Vector2(48,48)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_age += delta
	if role_id=="fz": _actor.position.y = 123-sin(minf(_age/.65,1.0)*PI)*4
	_illustration.modulate.a = .90 if _age<.60 else maxf(.10,.90-(_age-.60)*1.9)
	if _age>=2.4: _play()

func _play() -> void:
	_age = 0
	for fx in _effects.get_children(): fx.queue_free()
	var heavy := int(_data.get("cost",0))>=50 or String(_data.get("target","")) in ["enemy_all","enemy_front_all","enemy_random"]
	_actor.play(&"cast" if heavy or float(_data.get("k",0))<=0 else &"attack")
	var effect: Dictionary = _data.get("effect",{}) if _data.get("effect") is Dictionary else {}
	var effect_type := String(effect.get("type",""))
	var kind: String = {"zs":"slash","ck":"pierce","fs":"arcane","fz":"heal"}.get(role_id,"arcane")
	if effect_type in ["heal","invincible_heal","cleanse"]: kind="heal"
	elif effect_type in ["shield","atk_up","lurk"]: kind="arcane"
	elif effect_type=="taunt": kind="hammer"
	var impact_at := Vector2(100,136) if _self_target else Vector2(275,128)
	Effects.impact(_effects,impact_at,kind,_tint,heavy)
	if _group:
		if _support: Effects.impact(_effects,Vector2(100,136),kind,_tint)
		else:
			Effects.impact(_effects,Vector2(236,134),kind,_tint)
			Effects.impact(_effects,Vector2(316,134),kind,_tint)
	if int(_data.get("hits",1))>1:
		Effects.impact(_effects,Vector2(264,152),kind,_tint)

class PracticeTarget extends Node2D:
	func _draw() -> void:
		Props.supplementary(self,"dummy",72)
