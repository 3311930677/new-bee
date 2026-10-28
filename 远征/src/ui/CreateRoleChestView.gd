extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const POSES:=[
	["朝南",&"walk_down"],
	["朝西",&"walk_left"],
	["朝东",&"walk_right"],
	["朝北",&"walk_up"],
]
var host:Control
var shell:Control
var _name:Label
var _job:Label
var _tags:Label
var _desc:Label
var _combat_line:Label
var _pool:TextureRect
var _shadow:Node2D
var _prev:Button
var _next:Button
var _rule:Label
var _role_tabs:HBoxContainer
var _pose_tabs:HBoxContainer
var _sex:HBoxContainer
var _confirm:Button
var _touch:Control
var _swipe_at:=Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reselect:bool=bool(host.get("_reselect_mode"))
	shell=Flow.Shell.new("易职整备" if reselect else "创建角色",396)
	shell.closed=func():host._close_or_cancel()
	add_child(shell)
	_name=UI.label("","hero")
	_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_name)
	_job=UI.label("","caption",UI.AGED)
	_job.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_job)
	_tags=UI.label("","caption",UI.GOLD)
	_tags.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.stage.add_child(_tags)
	_pool=Page.picture(UI.texture("stage_pool"),Vector2(256,60))
	_pool.modulate.a=.85
	shell.stage.add_child(_pool)
	_shadow=_StageShadow.new()
	shell.stage.add_child(_shadow)
	host._anim=AnimatedSprite2D.new()
	host._anim.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	host._anim.scale=Vector2(2,2)
	shell.stage.add_child(host._anim)
	_prev=Flow.button("◀",func():host._switch_role(host._role_idx-1,true))
	_next=Flow.button("▶",func():host._switch_role(host._role_idx+1,true))
	shell.stage.add_child(_prev)
	shell.stage.add_child(_next)
	_pose_tabs=HBoxContainer.new()
	_pose_tabs.alignment=BoxContainer.ALIGNMENT_CENTER
	_pose_tabs.add_theme_constant_override("separation",4)
	shell.stage.add_child(_pose_tabs)
	for p in POSES:
		var pose_name:StringName=p[1]
		var pb:=Flow.button(String(p[0]),func():host.set_preview_pose(pose_name))
		pb.skin="tab"
		pb.custom_minimum_size=Vector2(62,32)
		pb.caption.add_theme_font_size_override("font_size",G.FS_XS)
		_pose_tabs.add_child(pb)
	_role_tabs=HBoxContainer.new()
	_role_tabs.add_theme_constant_override("separation",6)
	shell.body.add_child(_role_tabs)
	for i in G.roles.size():
		var r_idx:int=i
		var r_row:Dictionary=G.roles[i]
		var rb:=Flow.button("%s·%s"%[String(r_row.get("name","")),String(r_row.get("job",""))],func():host._switch_role(r_idx,true))
		rb.name="RoleTab_"+String(r_row.get("id",""))
		rb.skin="tab"
		rb.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size.y=40
		rb.caption.add_theme_font_size_override("font_size",G.FS_XS)
		_role_tabs.add_child(rb)
	_sex=HBoxContainer.new()
	shell.body.add_child(_sex)
	for i in host.GENDERS.size():
		var index:int=i
		_sex.add_child(Flow.button(host.GENDERS[i],func():host._gender_idx=index;refresh()))
		_sex.get_child(i).skin="tab"
	_desc=Flow.text("","body",UI.PAPER)
	shell.body.add_child(_desc)
	_combat_line=Flow.text("","caption",UI.GOLD)
	shell.body.add_child(_combat_line)
	var name_label:=Flow.text("角色昵称","caption",UI.AGED)
	shell.body.add_child(name_label)
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
	# Put required input before the longer lore, so the first short-screen view
	# exposes the name field and its validation beside the fixed confirm button.
	shell.body.move_child(name_label,2)
	shell.body.move_child(row,3)
	shell.body.move_child(_rule,4)
	_confirm=Flow.button("确认易职 · 返回主城" if reselect else "踏入昭元 · 开启征途",host._confirm,true)
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
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()
func _role_skill_summary(role_id:String) -> String:
	var names:Array[String]=[]
	for sk_v in TableCache.skills():
		var sk:Dictionary=sk_v
		if String(sk.get("role",""))==role_id:
			names.append(String(sk.get("name","")))
	if names.is_empty():return ""
	return "招牌武学："+" / ".join(names.slice(0,3))
func refresh() -> void:
	var role:Dictionary=G.roles[host._role_idx]
	var rid:=String(role.get("id","zs"))
	_name.text=String(role.name)
	_job.text="%s · 兵刃：%s"%[role.job,role.weapon]
	_tags.text=String(role.get("tags",""))
	_desc.text=String(role.get("desc",""))
	if _combat_line!=null:
		_combat_line.text=_role_skill_summary(rid)
	if _role_tabs!=null:
		for i in _role_tabs.get_child_count():
			_role_tabs.get_child(i).selected=i==host._role_idx
			_role_tabs.get_child(i).queue_redraw()
	if _pose_tabs!=null:
		for i in _pose_tabs.get_child_count():
			_pose_tabs.get_child(i).selected=POSES[i][1]==host._preview_pose
			_pose_tabs.get_child(i).queue_redraw()
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
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	shell.tray_height=minf(396,safe.size.y-304)
	shell.layout(safe_override)
	var width:float=shell.stage.size.x
	var height:float=shell.stage.size.y
	Page.place(_name,Vector2(72,2),Vector2(width-144,42))
	Page.place(_job,Vector2(72,44),Vector2(width-144,22))
	Page.place(_tags,Vector2(48,68),Vector2(width-96,22))
	var feet_y:float=height-48.0
	# Animated frames have a 112px foot anchor at scale 2. Fit their full body
	# between the identity text and direction controls on short screens.
	var factor:=minf(1.0,maxf(.35,(height-144.0)/224.0))
	host._anim.scale=Vector2.ONE*2.0*factor
	host._anim.position=Vector2(width*.5,feet_y-112.0*factor)
	if _shadow!=null:_shadow.position=Vector2(width*.5,feet_y)
	Page.place(_pool,Vector2(width*.5-128,feet_y-30.0),Vector2(256,60))
	if _pose_tabs!=null:
		Page.place(_pose_tabs,Vector2(16,height-38),Vector2(width-32,34))
	Page.place(_prev,Vector2(8,maxf(108,height*.5-36)),Vector2(44,64))
	Page.place(_next,Vector2(width-52,maxf(108,height*.5-36)),Vector2(44,64))
	Page.place(_touch,Vector2(56,96),Vector2(width-112,maxf(1,height-138)))
class _StageShadow extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.24))
		draw_circle(Vector2(0,2),42.0,Color(0.03,0.02,0.04,0.42))
		draw_circle(Vector2.ZERO,28.0,Color(0.01,0.01,0.02,0.62))

