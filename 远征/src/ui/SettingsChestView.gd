extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const Kit:=preload("res://src/ui/SettingsSkin.gd")
## 分组横幅与行图标都取自设置页参考稿（ic_sec_* / ib_*），"重置"用警示三角，"震屏"用参考稿自带的图标框
const SECTION_ICONS:={"角色与旅程":"sec_journey","声音":"sec_sound","战斗与演出":"sec_battle","昵称":"sec_name","旅程":"sec_journey","备份":"sec_backup","恢复存档":"sec_restore","重置":"sec_reset"}
const TAB_ICONS:=["tab_common","tab_profile","tab_save"]
const ROW_H:=54.0  # 卡片内一行的高度（参考稿约 55）
const TAB_H:=[47.0,50.0]  # 未选 / 选中（tab_normal / tab_selected 原高）：底边对齐，选中的高出一截
var host:Control
var shell:Control
var backdrop:Control
var back:Button
var help:Button
var _pages:Array[Control]=[]
var _sliders:Array[HSlider]=[]
var _speed_value:Label
var _reset_modal:Control
var _speed_prev:Button
var _name_pad:Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("设置",0)
	shell.closed=func():host._on_back()
	add_child(shell)
	# 整页底图换成参考稿夜景：旧舞台与托盘不再画，标题字已画在底图里
	backdrop=Kit.Backdrop.new()
	shell.add_child(backdrop)
	shell.move_child(backdrop,0)
	shell.background.visible=false
	shell.tray.visible=false
	shell.title.visible=false
	shell.back.visible=false
	# 参考稿菱形返回键：普通 Button 只放图标（导航检查按 Button + 提示"返回"识别），按下换暗色贴图并下沉
	back=Button.new()
	back.name="SettingsBack"
	back.icon=Kit.texture("back")
	back.flat=true
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:back.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	back.tooltip_text="返回"
	back.focus_mode=Control.FOCUS_ALL
	back.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	back.button_down.connect(func():back.icon=Kit.texture("back_pressed"))
	back.button_up.connect(func():back.icon=Kit.texture("back"))
	back.pressed.connect(func():if shell.closed.is_valid():shell.closed.call())
	shell.add_child(back)
	shell.skin_layout=_skin_layout
	host._content=shell.body
	host._deck=Flow.Selection.new()
	host._deck.page_count=3
	host._deck.page_changed.connect(_select)
	add_child(host._deck)
	for i in 3:
		var index:int=i
		var tab=shell.tab(["常规","旅人","存档"][i],func():host._deck.go(index))
		tab.plate=Kit.style("tab_normal")
		tab.plate_selected=Kit.style("tab_selected")
		tab.icon_id=""
		tab.size_flags_vertical=Control.SIZE_SHRINK_END
		Kit.button_icon(tab,TAB_ICONS[i],false,16)
		var box:=VBoxContainer.new()
		box.add_theme_constant_override("separation",8)
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		shell.body.add_child(box)
		_pages.append(box)
	_common(_pages[0])
	_profile(_pages[1])
	_save(_pages[2])
	help=Flow.button("说明",func():Flow.info(self,"键位与说明",["WASD / 方向键：移动；左右切换卡片。","Esc：关闭当前浮层，设置里的重选角色不会删除其他存档数据。","F10 / `：开发者控制台。 "]))
	help.plate=Kit.style("btn_small")
	help.custom_minimum_size.y=36
	add_child(help)
	shell.header_actions.append(help)
	_select(0)
	shell.layout()
## 标题栏、页签、滚动区对齐参考稿底图（480 宽美术居中；上段贴安全区顶）
func _skin_layout(safe:Rect2) -> void:
	var factor:=minf(1.0,safe.size.x/480.0)
	var view:=get_viewport_rect().size/factor
	safe=Rect2(safe.position/factor,safe.size/factor)
	var ax:=roundf((view.x-480.0)*.5)
	backdrop.safe=safe
	Page.place(backdrop,Vector2.ZERO,view)
	backdrop.queue_redraw()
	var b:Dictionary=Kit.scene("back")
	Page.place(back,Vector2(ax+b.pos[0],safe.position.y+b.pos[1]),back.icon.get_size())
	var h:Array=Kit.scene("bg_top").help
	Page.place(help,Vector2(ax+h[0],safe.position.y+h[1]),Vector2(h[2],h[3]))
	# 页签带：参考稿选中页签 y 116..166，三格 x 20..460
	Page.place(shell.tabs,Vector2(ax+18,safe.position.y+116),Vector2(446,TAB_H[1]))
	# 滚动区：面板上沿以下到栏杆柱头以上（柱头在底图下段第 27 行）
	var top:=safe.position.y+184
	Page.place(shell.scroll,Vector2(ax+20,top),Vector2(440,maxf(40,backdrop.bottom_y(view.y)+22-top)))
	for control in [backdrop,back,help,shell.tabs,shell.scroll]:
		control.scale=Vector2.ONE*factor
		control.position*=factor
func _select(index:int) -> void:
	for i in _pages.size():
		_pages[i].visible=i==index
		var tab:Button=shell.tabs.get_child(i)
		tab.selected=i==index
		tab.custom_minimum_size.y=TAB_H[1] if i==index else TAB_H[0]
		tab.queue_redraw()
	shell.scroll.scroll_vertical=0
	Flow.wire_focus(self)
func _section(parent:Control,words:String) -> void:parent.add_child(Kit.section(words,String(SECTION_ICONS.get(words,""))))
## 一组行合进同一张卡片、行间 1px 分隔线（参考稿"声音""战斗与演出"各是一张卡）
func _rows_card(parent:Control) -> VBoxContainer:
	var card:=Flow.Card.new()
	card.plate=Kit.style("row_card")
	for side in ["margin_left","margin_right"]:card.add_theme_constant_override(side,0)
	for side in ["margin_top","margin_bottom"]:card.add_theme_constant_override(side,3)
	parent.add_child(card)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",0)
	card.add_child(box)
	return box
func _add_row(box:VBoxContainer,row:Control) -> void:
	if box.get_child_count()>0:
		var inset:=MarginContainer.new()
		for side in ["margin_left","margin_right"]:inset.add_theme_constant_override(side,4)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var line:=ColorRect.new()
		line.color=Color("2a272e")
		line.custom_minimum_size.y=1
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(line)
		box.add_child(inset)
	box.add_child(row)
## 卡片里的一行：左侧图标框 + 内容（左右各留 12，图标框与参考稿同位）
func _plain_row(icon:String) -> Array:
	var wrap:=MarginContainer.new()
	for side in ["margin_left","margin_right"]:wrap.add_theme_constant_override(side,12)
	var row:=HBoxContainer.new()
	row.custom_minimum_size.y=ROW_H
	row.add_theme_constant_override("separation",12)
	wrap.add_child(row)
	row.add_child(Kit.icon_box(icon))
	return [wrap,row]
## 行标题：参考稿用衬线 17 号（G.FS_SM）
func _row_title(words:String) -> Label:
	var title:=UI.label(words,"section")
	title.add_theme_font_size_override("font_size",G.FS_SM)
	return title
## 说明文字前的 ◆（参考稿：棕色菱形，重置提示是红色）。返回原 Label，宿主照常改它的文字
func _caption(parent:Control,label:Label,ink:=Color("8a6a4e")) -> Label:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var dot:=Bullet.new()
	dot.ink=ink
	row.add_child(dot)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var pad:=MarginContainer.new()
	pad.add_theme_constant_override("margin_left",10)
	pad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	parent.add_child(pad)
	return label
## 倍速步进键：粗三角箭头（参考稿），按下下沉 1px，禁用变灰
func _step(words:String,callback:Callable,dir:float) -> Button:
	var b=Flow.button(words,callback)
	b.custom_minimum_size=Vector2(42,34)
	b.plate=Kit.style("step_btn")
	b.size_flags_horizontal=Control.SIZE_SHRINK_END
	b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	b.caption.visible=false
	# 箭头画在子节点上：按钮自己的 draw 信号先于 _draw 发出，直接画会被底板盖住
	var arrow:=StepArrow.new()
	arrow.dir=dir
	b.add_child(arrow)
	b.draw.connect(arrow.queue_redraw)
	return b
class StepArrow extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var dir:=1.0
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var b:=get_parent() as Button
		var c:Vector2=(size*.5).floor()+Vector2(0,1.0 if b.is_pressed() else 0.0)
		var ink:=UI.ASH if b.disabled else Color("f0dcb0")
		draw_colored_polygon(PackedVector2Array([c+Vector2(-4*dir,-6),c+Vector2(4*dir,0),c+Vector2(-4*dir,6)]),ink)
class Bullet extends Control:
	var ink:=Color("8a6a4e")
	func _init() -> void:
		custom_minimum_size=Vector2(8,8)
		size_flags_vertical=Control.SIZE_SHRINK_CENTER
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(4,0),Vector2(8,4),Vector2(4,8),Vector2(0,4)]),ink)
## 多个控件合进同一张卡片（参考稿：昵称框 + 保存昵称；存档码框 + 粘贴码 + 导入）
func _group_card(parent:Control) -> VBoxContainer:
	var card:=Flow.Card.new()
	card.plate=Kit.style("row_card")
	for side in ["margin_top","margin_bottom"]:card.add_theme_constant_override(side,12)
	parent.add_child(card)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	card.add_child(box)
	return box
## 开关行换皮：底板、开关贴图、左侧图标框（作为子节点，随尺寸居中）
func _switch(sw,icon:String) -> Button:
	sw.plate=Kit.style("row_card")
	sw.knob_on=Kit.texture("switch_on")
	sw.knob_off=Kit.texture("switch_off")
	sw.inset=60
	var box:=Kit.icon_box(icon)
	sw.add_child(box)
	sw.resized.connect(func():box.position=Vector2(12,floorf((sw.size.y-box.size.y)*.5)))
	return sw
## 按钮换皮：primary 金框、row 蓝底行按钮（图标在左 + 右侧箭头）、danger 红底；每个按钮都带参考稿图标
func _btn(words:String,callback:Callable,kind:String="row",icon:String="") -> Button:
	var b=Flow.button(words,callback)
	b.plate=Kit.style({"primary":"btn_primary","row":"btn_row","danger":"btn_danger"}[kind])
	b.custom_minimum_size.y=48
	if not icon.is_empty():Kit.button_icon(b,icon,kind=="row")
	return b
func _volume(box:VBoxContainer,words:String,value:float,callback:Callable) -> void:
	var parts:=_plain_row("music" if words=="音乐" else "sound")
	var row:HBoxContainer=parts[1]
	_add_row(box,parts[0])
	var title:=_row_title(words)
	title.custom_minimum_size.x=52
	row.add_child(title)
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.01
	slider.value=value
	slider.custom_minimum_size=Vector2(200,ROW_H)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Kit.slider(slider)
	row.add_child(slider)
	_sliders.append(slider)
	var number:=UI.label("%d%%"%roundi(value*100),"number")
	number.custom_minimum_size.x=48
	number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	slider.value_changed.connect(func(v:float):callback.call(v);number.text="%d%%"%roundi(v*100))
	host._vol_rows.append(row)
## 卡片里的开关行：去掉单独底板，左侧图标框，标题衬线
func _switch_row(box:VBoxContainer,sw,icon:String) -> Button:
	_switch(sw,icon)
	sw.plate=StyleBoxEmpty.new()
	sw.custom_minimum_size.y=ROW_H
	sw.heading.add_theme_font_override("font",G.font_serif)
	sw.heading.add_theme_font_size_override("font_size",G.FS_SM)
	var wrap:=MarginContainer.new()
	for side in ["margin_left","margin_right"]:wrap.add_theme_constant_override(side,0)
	wrap.add_child(sw)
	_add_row(box,wrap)
	return sw
func _reselect_role() -> void:
	G.set_meta("reselect_from_home", not host.standalone)
	G.go("res://src/ui/CreateRole.tscn")
func _common(parent:Control) -> void:
	_section(parent,"角色与旅程")
	var quick_row:=HBoxContainer.new()
	quick_row.add_theme_constant_override("separation",10)
	quick_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(quick_row)
	var reselect_quick:=_btn("重选角色 · 易职",_reselect_role,"primary","btn_role")
	reselect_quick.name="QuickReselectRoleButton"
	reselect_quick.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Kit.ornaments(reselect_quick)
	quick_row.add_child(reselect_quick)
	var tut_quick:=_btn("新手指引 · 教学",host._replay_tutorial,"row","btn_prologue")
	tut_quick.name="QuickTutorialReplayButton"
	tut_quick.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	quick_row.add_child(tut_quick)
	var gm_quick:=_btn("开发者控制台 · 全功能界面解锁",func():
		if GmConsole.has_method("open_unlocked"):
			GmConsole.call("open_unlocked")
		else:
			G.gm_unlocked = true
			GmConsole.open(),"primary","btn_copy")
	gm_quick.name="QuickGmConsoleButton"
	Kit.ornaments(gm_quick)
	parent.add_child(gm_quick)
	_section(parent,"声音")
	var sound:=_rows_card(parent)
	_volume(sound,"音乐",Audio.bgm_vol(),Audio.set_bgm_vol)
	_volume(sound,"音效",Audio.sfx_vol(),Audio.set_sfx_vol)
	host._mute_btn=_switch_row(sound,Flow.Switch.new("静音",Audio.muted()),"mute")
	host._mute_btn.pressed.connect(func():Audio.set_mute(not Audio.muted());sync())
	host._mute_hint=_caption(parent,Flow.text("","caption",UI.AGED))
	_section(parent,"战斗与演出")
	var battle:=_rows_card(parent)
	host._shake_btn=_switch_row(battle,Flow.Switch.new("震屏",bool(G.setting_get("shake",true))),"shake")
	host._shake_btn.pressed.connect(func():G.setting_set("shake",not bool(G.setting_get("shake",true)));sync())
	host._story_btn=_switch_row(battle,Flow.Switch.new("剧情演出",not bool(G.setting_get("skip_story",false)),"播放","省略"),"story")
	host._story_btn.pressed.connect(func():G.setting_set("skip_story",not bool(G.setting_get("skip_story",false)));sync())
	var parts:=_plain_row("speed")
	var row:HBoxContainer=parts[1]
	_add_row(battle,parts[0])
	var title:=_row_title("战斗倍速")
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_speed_prev=_step("‹",func():G.setting_set("battle_speed",BattleScene.step_speed(float(G.setting_get("battle_speed",1.0)),-1));sync(),-1.0)
	row.add_child(_speed_prev)
	_speed_value=UI.label("","number")
	_speed_value.custom_minimum_size.x=52
	_speed_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_speed_value)
	host._speed_btn=_step("›",func():G.setting_set("battle_speed",BattleScene.step_speed(float(G.setting_get("battle_speed",1.0)),1));sync(),1.0)
	row.add_child(host._speed_btn)
	_caption(parent,Flow.text("支持 ×1 / ×2 / ×4 / ×8 四档，战斗中也可随时切换倍速","caption",UI.AGED))
	var version:=Flow.text("版本 "+String(ProjectSettings.get_setting("application/config/version","")),"caption",UI.AGED)
	version.name="BuildVersion"
	parent.add_child(version)
	var diagnostic:=_btn("复制设备与显示信息",func():
		DisplayServer.clipboard_set(preload("res://src/ui/DeviceLayoutInfo.gd").text(self))
		Flow.info(self,"已复制",["设备型号、系统版本和屏幕尺寸已复制，可粘贴到问题反馈中。不包含存档、账号或密码。"]),"row","btn_copy")
	diagnostic.name="CopyDisplayInfo"
	parent.add_child(diagnostic)
	sync()
func sync() -> void:
	host._mute_btn.on=Audio.muted()
	host._shake_btn.on=bool(G.setting_get("shake",true))
	host._story_btn.on=not bool(G.setting_get("skip_story",false))
	for b in [host._mute_btn,host._shake_btn,host._story_btn]:b.queue_redraw()
	for slider in _sliders:slider.editable=not Audio.muted();slider.modulate=Color(.5,.5,.5) if Audio.muted() else Color.WHITE
	var cur_sp := int(round(BattleScene.snap_speed(float(G.setting_get("battle_speed",1.0)))))
	_speed_value.text="×%d"%cur_sp
	_speed_prev.disabled=cur_sp<=1
	host._speed_btn.disabled=cur_sp>=8
	host._mute_hint.text="已静音，音量设置已保留" if Audio.muted() else "音乐与音效已开启"
## 旅人卡：参考稿月夜底板，头像裁成圆放进金环，右侧昵称与职业等级
func _traveller_card() -> Control:
	var info:Dictionary=Kit.scene("profile_card")
	var card:=Panel.new()
	card.name="TravellerCard"
	card.add_theme_stylebox_override("panel",Kit.style("profile_card"))
	card.custom_minimum_size=Vector2(0,info.size[1])
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var ring:Array=info.ring
	var avatar:=Page.picture(G.avatar_texture(),Vector2.ONE*ring[2]*2)
	avatar.name="TravellerAvatar"
	avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.material=Kit.circle_material()
	avatar.position=Vector2(ring[0]-ring[2],ring[1]-ring[2])
	card.add_child(avatar)
	var words:=VBoxContainer.new()
	words.add_theme_constant_override("separation",2)
	words.position=Vector2(info.text[0],info.text[1]+4)
	words.size=Vector2(200,info.size[1]-info.text[1]*2)
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	words.add_child(UI.label(G.display_name(),"title"))
	words.add_child(UI.label("%s · Lv.%d"%[G.get_role(G.selected_role).get("name","旅人"),int(G.prog.get("level",1))],"body"))
	return card
func _profile(parent:Control) -> void:
	parent.add_child(_traveller_card())
	_section(parent,"旅程")
	var reselect_btn:=_btn("重选角色（四大命途易职）",_reselect_role,"primary","btn_role")
	reselect_btn.name="ReselectRoleButton"
	Kit.ornaments(reselect_btn)
	parent.add_child(reselect_btn)
	var tut_btn:=_btn("新手指引（完整流程教学）",host._replay_tutorial,"row","btn_prologue")
	tut_btn.name="TutorialReplayButton"
	parent.add_child(tut_btn)
	parent.add_child(_btn("更换头像",host._open_avatar,"row","btn_avatar"))
	_section(parent,"昵称")
	var name_box:=_group_card(parent)
	host._name_edit=Flow.field("最多 8 个字")
	host._name_edit.text=G.player_name
	host._name_edit.max_length=8
	Kit.field(host._name_edit)
	name_box.add_child(host._name_edit)
	var save_name:=_btn("保存昵称",host._save_name,"primary")
	Kit.ornaments(save_name)
	name_box.add_child(save_name)
	host._name_hint=_caption(parent,Flow.text("","caption",UI.AGED))
	_name_pad=host._name_hint.get_parent().get_parent()
	_name_pad.visible=false
	parent.add_child(_btn("重看序章",func():G.go("res://src/ui/Prologue.tscn"),"row","btn_prologue"))
	if not host.standalone:parent.add_child(_btn("回标题",host._on_title,"row","door"))
func _save(parent:Control) -> void:
	_section(parent,"备份")
	parent.add_child(_btn("复制存档码",host._on_export,"primary","btn_copy"))
	host._note1=_caption(parent,Flow.text("复制后可备份保存","caption",UI.AGED))
	_section(parent,"恢复存档")
	var restore:=_group_card(parent)
	host._code=Flow.field("粘贴备份存档码")
	Kit.field(host._code,true)
	restore.add_child(host._code)
	restore.add_child(_btn("粘贴码",host._on_paste,"primary","btn_paste"))
	restore.add_child(_btn("导入",func():
		if host._code.text.strip_edges().is_empty():host._on_import()
		else:Page.confirm(self,"导入存档","将替换本机当前进度，原档会先备份。确认继续？",host._on_import),"primary","btn_import"))
	host._hint2=_caption(parent,Flow.text("导入成功后返回标题","caption",UI.AGED))
	_section(parent,"重置")
	host._reset_btn=_btn("重置存档",host._on_reset_click,"danger","btn_reset")
	host._reset_btn.caption.add_theme_color_override("font_color",Color("f3c9b8"))
	parent.add_child(host._reset_btn)
	host._reset_hint=_caption(parent,Flow.text("重置会清除本机当前存档","caption",UI.RED),Color("c0453a"))
## 昵称提示只在有话说时占位（参考稿"保存昵称"下面没有空行）
func _process(_delta:float) -> void:
	if _name_pad!=null:_name_pad.visible=not host._name_hint.text.is_empty()
func reset_confirm() -> void:
	host._reset_armed=true
	_reset_modal=Page.confirm(self,"重置存档","此操作会清除本机当前进度，确认继续？",func():host.execute_reset();G.go(host.TITLE_PATH))
	_reset_modal.closed.connect(func():host._reset_armed=false)
	_reset_modal.selected.connect(func(_index:int):host._reset_armed=false)
func disarm() -> void:
	host._reset_armed=false
	if is_instance_valid(_reset_modal):_reset_modal.queue_free()
