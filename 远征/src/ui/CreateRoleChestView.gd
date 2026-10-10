extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
var host:Control
var shell:Control
var _name:Label
var _job:Label
var _tags:Label
var _desc:Label
var _pool:TextureRect
var _prev:Button
var _next:Button
var _rule:Label
var _sex:HBoxContainer
var _confirm:Button
var _touch:Control
var _swipe_at:=Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("创建角色",332)
	shell.closed=func():G.go("res://src/ui/Login.tscn")
	add_child(shell)
	_name=UI.label("","hero")
	_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_name)
	_job=UI.label("","caption",UI.AGED)
	_job.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_job)
	_tags=UI.label("","caption",UI.AGED)
	_tags.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_tags)
	_pool=Page.picture(UI.texture("stage_pool"),Vector2(256,60))
	_pool.modulate.a=.35
	shell.stage.add_child(_pool)
	host._anim=AnimatedSprite2D.new()
	host._anim.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	host._anim.scale=Vector2(2,2)
	shell.stage.add_child(host._anim)
	_prev=Flow.button("‹",func():host._switch_role(host._role_idx-1,true))
	_next=Flow.button("›",func():host._switch_role(host._role_idx+1,true))
	shell.stage.add_child(_prev)
	shell.stage.add_child(_next)
	_sex=HBoxContainer.new()
	shell.body.add_child(_sex)
	for i in host.GENDERS.size():
		var index:int=i
		_sex.add_child(Flow.button(host.GENDERS[i],func():host._gender_idx=index;refresh()))
		_sex.get_child(i).skin="tab"
	_desc=Flow.text("","body",UI.AGED)
	shell.body.add_child(_desc)
	shell.body.add_child(Flow.text("角色昵称","caption",UI.AGED))
	var row:=HBoxContainer.new()
	shell.body.add_child(row)
	host._name_edit=Flow.field("输入角色昵称")
	host._name_edit.max_length=12
	row.add_child(host._name_edit)
	var random:=Flow.button("随机",func():host._name_edit.text=G.random_name();_sync_name())
	random.custom_minimum_size.x=100
	random.size_flags_horizontal=Control.SIZE_SHRINK_END
	row.add_child(random)
	_rule=Flow.text("昵称最长 12 个字符","caption",UI.AGED)
	shell.body.add_child(_rule)
	_confirm=Flow.button("确定",host._confirm,true)
	shell.footer.add_child(_confirm)
	host._name_edit.text_changed.connect(func(_words:String):_sync_name())
	_touch=Control.new()
	_touch.mouse_filter=Control.MOUSE_FILTER_PASS
	shell.stage.add_child(_touch)
	_touch.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed:_swipe_at=e.position
			elif absf(e.position.x-_swipe_at.x)>48:host._switch_role(host._role_idx+(-1 if e.position.x>_swipe_at.x else 1),true))
	get_viewport().size_changed.connect(layout)
	layout()
func refresh() -> void:
	var role:Dictionary=G.roles[host._role_idx]
	_name.text=String(role.name)
	_job.text="%s · %s"%[role.job,role.weapon]
	_tags.text=String(role.get("tags",""))
	_desc.text=String(role.get("desc",""))
	for i in _sex.get_child_count():
		_sex.get_child(i).selected=i==host._gender_idx
		_sex.get_child(i).queue_redraw()
func error(words:String) -> void:
	_rule.text=words
	_rule.add_theme_color_override("font_color",UI.RED)
	_confirm.disabled=host._name_edit.text.strip_edges().is_empty()
func _sync_name() -> void:
	_confirm.disabled=host._name_edit.text.strip_edges().is_empty()
	_rule.text="请输入角色昵称" if _confirm.disabled else "昵称最长 12 个字符"
	_rule.add_theme_color_override("font_color",UI.RED if _confirm.disabled else UI.AGED)
func layout(safe_override:Rect2=Rect2()) -> void:
	shell.layout(safe_override)
	var width:float=shell.stage.size.x
	var height:float=shell.stage.size.y
	Page.place(_name,Vector2(72,4),Vector2(width-144,44))
	Page.place(_job,Vector2(72,48),Vector2(width-144,24))
	Page.place(_tags,Vector2(48,74),Vector2(width-96,24))
	host._anim.position=Vector2(width*.5,height-32-118)
	Page.place(_pool,Vector2(width*.5-128,height-72),Vector2(256,60))
	Page.place(_prev,Vector2(8,maxf(116,height*.5-32)),Vector2(44,64))
	Page.place(_next,Vector2(width-52,maxf(116,height*.5-32)),Vector2(44,64))
	Page.place(_touch,Vector2(56,100),Vector2(width-112,maxf(1,height-100)))
