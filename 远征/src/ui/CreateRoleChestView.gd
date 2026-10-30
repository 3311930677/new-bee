extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const KitV4:=preload("res://src/ui/KitV4.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const FixUI:=preload("res://src/ui/ReviewFixUI.gd")
const POSES:=[
	["朝南",&"walk_down"],
	["朝西",&"walk_left"],
	["朝东",&"walk_right"],
	["朝北",&"walk_up"],
]
const ROLE_RATINGS := {
	"zs": [5, 4, 2, 3],
	"ck": [2, 5, 4, 2],
	"fs": [2, 5, 3, 4],
	"fz": [4, 2, 3, 5],
}
const RATING_NAMES := ["生存", "输出", "操作", "团队"]

var host:Control
var shell:Control
var _name:Label
var _job:Label
var _tags:Label
var _desc:Label
var _combat_line:Label
var _pool:TextureRect
var _portrait:TextureRect
var _mini_card:Panel
var _mini_tag:Label
var _shadow:Node2D
var _prev:Button
var _next:Button
var _rule:Label
var _role_tabs:HBoxContainer
var _pose_tabs:HBoxContainer
var _rating_bars:Array = []
var _skill_row:HBoxContainer
var _sex:HBoxContainer
var _confirm:Button
var _touch:Control
var _swipe_at:=Vector2.ZERO
var _pose_idx:=0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reselect:bool=bool(host.get("_reselect_mode"))
	shell=Flow.Shell.new("易职整备" if reselect else "创建角色",416)
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
	# §4.3-3 角色半身立绘（B-01..B-04）+ 右下角像素小人预览与旋转圆台
	_portrait=TextureRect.new()
	_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shell.stage.add_child(_portrait)
	_mini_card=Panel.new()
	var mc_sb:=StyleBoxFlat.new()
	mc_sb.bg_color=Color(0.08,0.06,0.05,0.86)
	mc_sb.border_color=KitV4.TRIM
	mc_sb.set_border_width_all(1)
	mc_sb.set_corner_radius_all(4)
	_mini_card.add_theme_stylebox_override("panel",mc_sb)
	_mini_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shell.stage.add_child(_mini_card)
	_mini_tag=UI.label("滑动旋转","caption",KitV4.MUTED)
	_mini_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_mini_tag.add_theme_font_size_override("font_size",G.FS_XS)
	_mini_card.add_child(_mini_tag)
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
	# §4.3-1 隐藏调试感朝向页签，改为在角色区左右滑动旋转朝向
	_pose_tabs=HBoxContainer.new()
	_pose_tabs.visible=false
	shell.stage.add_child(_pose_tabs)
	for p in POSES:
		var pose_name:StringName=p[1]
		var pb:=Flow.button(String(p[0]),func():host.set_preview_pose(pose_name))
		pb.skin="tab"
		_pose_tabs.add_child(pb)

	# §4.3-2 四个职业徽记卡（B-06），横排，选中金框加上浮
	_role_tabs=HBoxContainer.new()
	_role_tabs.add_theme_constant_override("separation",6)
	shell.body.add_child(_role_tabs)
	for i in G.roles.size():
		var r_idx:int=i
		var r_row:Dictionary=G.roles[i]
		var rid_str:=String(r_row.get("id","zs"))
		var rb:=Flow.button("%s·%s"%[String(r_row.get("name","")),String(r_row.get("job",""))],func():host._switch_role(r_idx,true))
		rb.name="RoleTab_"+rid_str
		rb.skin="tab"
		rb.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size=Vector2(0,56)
		rb.caption.add_theme_font_size_override("font_size",G.FS_XS)
		var emb_tex:=KitV4.commercial_tex("emblem_"+rid_str)
		if emb_tex!=null:
			var emb:=TextureRect.new()
			emb.name="EmblemIcon"
			emb.texture=emb_tex
			emb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			emb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			emb.set_anchors_preset(Control.PRESET_CENTER_TOP)
			emb.offset_left=-12
			emb.offset_right=12
			emb.offset_top=3
			emb.offset_bottom=27
			emb.mouse_filter=Control.MOUSE_FILTER_IGNORE
			rb.add_child(emb)
			rb.caption.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
			rb.caption.offset_bottom=-4
		_role_tabs.add_child(rb)

	# §4.3-5,6 性别两枚小号切换钮放在昵称行左侧 + 凹槽昵称框 + 骰子随机按钮
	var name_label:=Flow.text("角色昵称与称谓","caption",UI.AGED)
	shell.body.add_child(name_label)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	shell.body.add_child(row)
	_sex=HBoxContainer.new()
	_sex.add_theme_constant_override("separation",4)
	row.add_child(_sex)
	for i in host.GENDERS.size():
		var index:int=i
		var sb_sex:=Flow.button(host.GENDERS[i],func():host._gender_idx=index;refresh())
		sb_sex.skin="tab"
		sb_sex.custom_minimum_size=Vector2(40,44)
		_sex.add_child(sb_sex)
	host._name_edit=Flow.field("输入角色昵称")
	host._name_edit.max_length=12
	host._name_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(host._name_edit)
	var random:=Flow.button("🎲 随机",func():host._name_edit.text=G.random_name();_sync_name())
	random.custom_minimum_size=Vector2(68,44)
	random.size_flags_horizontal=Control.SIZE_SHRINK_END
	row.add_child(random)
	_rule=Flow.text("昵称最长 12 个字符","caption",UI.AGED)
	shell.body.add_child(_rule)

	# §4.3-4 四维职业定位条（生存/输出/操作/团队，每项 5 格）
	var rating_grid:=GridContainer.new()
	rating_grid.columns=2
	rating_grid.add_theme_constant_override("h_separation",8)
	rating_grid.add_theme_constant_override("v_separation",6)
	shell.body.add_child(rating_grid)
	_rating_bars.clear()
	for r_i in RATING_NAMES.size():
		var r_box:=HBoxContainer.new()
		r_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		r_box.add_theme_constant_override("separation",3)
		var r_lbl:=UI.label(RATING_NAMES[r_i],"caption",KitV4.CREAM)
		r_lbl.custom_minimum_size=Vector2(34,20)
		r_box.add_child(r_lbl)
		var pips:Array=[]
		for p_i in 5:
			var pip:=Panel.new()
			pip.custom_minimum_size=Vector2(12,10)
			pip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			pip.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			r_box.add_child(pip)
			pips.append(pip)
		rating_grid.add_child(r_box)
		_rating_bars.append(pips)

	# §4.3-4 五个招牌技能图标横排（点击查看详情）
	_combat_line=Flow.text("","caption",UI.GOLD)
	shell.body.add_child(_combat_line)
	_skill_row=HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation",4)
	_skill_row.alignment=BoxContainer.ALIGNMENT_CENTER
	shell.body.add_child(_skill_row)

	_desc=Flow.text("","body",UI.PAPER)
	shell.body.add_child(_desc)

	_confirm=Flow.button("确认易职 · 返回主城" if reselect else "踏入昭元 · 开启征途",host._confirm,true)
	shell.footer.add_child(_confirm)
	host._name_edit.text_changed.connect(func(_words:String):_sync_name())
	_touch=Control.new()
	_touch.mouse_filter=Control.MOUSE_FILTER_PASS
	shell.stage.add_child(_touch)
	_touch.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed:_swipe_at=e.position
			elif absf(e.position.x-_swipe_at.x)>28:
				var step := 1 if e.position.x < _swipe_at.x else -1
				_pose_idx = wrapi(_pose_idx + step, 0, POSES.size())
				host.set_preview_pose(POSES[_pose_idx][1]))
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()
func _role_skills(role_id:String) -> Array:
	var out:Array=[]
	for sk_v in TableCache.skills():
		var sk:Dictionary=sk_v
		if String(sk.get("role",""))==role_id:
			out.append(sk)
	return out

func _role_skill_summary(role_id:String) -> String:
	var names:Array[String]=[]
	for sk in _role_skills(role_id):
		names.append(String(sk.get("name","")))
	if names.is_empty():return ""
	return "招牌武学（点按图标查看详述）："+" / ".join(names.slice(0,3))

func refresh() -> void:
	var role:Dictionary=G.roles[host._role_idx]
	var rid:=String(role.get("id","zs"))
	_name.text=String(role.name)
	_job.text="%s · 兵刃：%s"%[role.job,role.weapon]
	_tags.text=String(role.get("tags",""))
	_desc.text=String(role.get("desc",""))
	if _portrait!=null:
		var ptex:=KitV4.commercial_tex("%s_portrait"%rid)
		_portrait.texture=ptex
		_portrait.visible=ptex!=null
	if _combat_line!=null:
		_combat_line.text=_role_skill_summary(rid)
	# 更新四维定位条
	var ratings:Array=ROLE_RATINGS.get(rid,[3,3,3,3])
	for r_i in _rating_bars.size():
		var pips:Array=_rating_bars[r_i]
		var val:int=int(ratings[r_i]) if r_i<ratings.size() else 3
		for p_i in pips.size():
			var pip:Panel=pips[p_i]
			var psb:=StyleBoxFlat.new()
			var lit:=p_i<val
			psb.bg_color=KitV4.BRIGHT if lit else KitV4.INSET
			psb.border_color=KitV4.TRIM if lit else Color(KitV4.TRIM,0.35)
			psb.set_border_width_all(1)
			psb.set_corner_radius_all(2)
			pip.add_theme_stylebox_override("panel",psb)
	# 更新 5 个招牌技能图标横排
	if _skill_row!=null:
		for c in _skill_row.get_children():
			c.queue_free()
		for sk_v in _role_skills(rid):
			var sk:Dictionary=sk_v
			var sid:=String(sk.get("id",""))
			var sname:=String(sk.get("name",""))
			var sdesc:=String(sk.get("desc",""))
			var s_col:=VBoxContainer.new()
			s_col.add_theme_constant_override("separation",2)
			var s_btn:=Button.new()
			s_btn.custom_minimum_size=Vector2(44,44)
			s_btn.focus_mode=Control.FOCUS_NONE
			var s_sb:=KitV4.style("slot_common",4)
			for st in ["normal","hover","pressed"]:
				s_btn.add_theme_stylebox_override(st,s_sb)
			s_btn.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
			var ic_tex:Texture2D=FixUI.texture(sid)
			if ic_tex!=null:
				var tr:=TextureRect.new()
				tr.texture=ic_tex
				tr.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.position=Vector2(4,4)
				tr.size=Vector2(36,36)
				tr.mouse_filter=Control.MOUSE_FILTER_IGNORE
				s_btn.add_child(tr)
			s_btn.pressed.connect(func():
				G.show_info_popup(host,sname,[sdesc if not sdesc.is_empty() else "本职业招牌武学招式。"]))
			s_col.add_child(s_btn)
			var s_lbl:=UI.label(sname,"caption",KitV4.CREAM)
			s_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			s_lbl.add_theme_font_size_override("font_size",G.FS_XS)
			s_col.add_child(s_lbl)
			_skill_row.add_child(s_col)
	if _role_tabs!=null:
		for i in _role_tabs.get_child_count():
			var rb:Control=_role_tabs.get_child(i)
			rb.selected=i==host._role_idx
			rb.position.y=-4.0 if i==host._role_idx else 0.0
			rb.queue_redraw()
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
	shell.tray_height=minf(416,safe.size.y-284)
	shell.layout(safe_override)
	var width:float=shell.stage.size.x
	var height:float=shell.stage.size.y
	Page.place(_name,Vector2(72,2),Vector2(width-144,38))
	Page.place(_job,Vector2(72,40),Vector2(width-144,20))
	Page.place(_tags,Vector2(48,62),Vector2(width-96,20))
	var feet_y:float=height-20.0
	var has_port:bool=_portrait!=null and _portrait.texture!=null
	if has_port:
		var port_h:=maxf(140.0,height-92.0)
		var port_w:=port_h*(256.0/384.0)
		Page.place(_portrait,Vector2((width-port_w)*.5,82.0),Vector2(port_w,port_h))
		Page.place(_pool,Vector2(width*.5-128,feet_y-36.0),Vector2(256,52))
		var mini_sz:=Vector2(88,92)
		var mini_pos:=Vector2(width-mini_sz.x-54.0,maxf(86.0,height-mini_sz.y-12.0))
		Page.place(_mini_card,mini_pos,mini_sz)
		Page.place(_mini_tag,Vector2(0,mini_sz.y-20.0),Vector2(mini_sz.x,18.0))
		_mini_card.visible=true
		host._anim.scale=Vector2(0.58,0.58)
		var foot_pos:=mini_pos+Vector2(mini_sz.x*.5,mini_sz.y-24.0)
		host._anim.position=foot_pos-Vector2(0,32.0)
		if _shadow!=null:_shadow.position=foot_pos
	else:
		if _mini_card!=null:_mini_card.visible=false
		var factor:=minf(1.0,maxf(.35,(height-124.0)/224.0))
		host._anim.scale=Vector2.ONE*2.0*factor
		host._anim.position=Vector2(width*.5,feet_y-112.0*factor)
		if _shadow!=null:_shadow.position=Vector2(width*.5,feet_y)
		Page.place(_pool,Vector2(width*.5-128,feet_y-30.0),Vector2(256,60))
	Page.place(_prev,Vector2(8,maxf(104,height*.5-32)),Vector2(44,64))
	Page.place(_next,Vector2(width-52,maxf(104,height*.5-32)),Vector2(44,64))
	Page.place(_touch,Vector2(56,88),Vector2(width-112,maxf(1,height-104)))

class _StageShadow extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.24))
		draw_circle(Vector2(0,2),28.0,Color(0.03,0.02,0.04,0.42))
		draw_circle(Vector2.ZERO,18.0,Color(0.01,0.01,0.02,0.62))
		draw_arc(Vector2.ZERO,24.0,0.0,TAU,24,Color(0.95,0.78,0.42,0.28),1.5)

