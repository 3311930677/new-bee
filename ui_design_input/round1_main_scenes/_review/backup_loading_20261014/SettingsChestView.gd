extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const Kit:=preload("res://src/ui/SettingsSkin.gd")
const SECTION_ICONS:={"声音":"sound","战斗与演出":"story","昵称":"person","旅程":"expedition","备份":"save","恢复存档":"ticket_sweep","重置":"close"}
var host:Control
var shell:Control
var _pages:Array[Control]=[]
var _sliders:Array[HSlider]=[]
var _speed_value:Label
var _reset_modal:Control
var _speed_prev:Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("设置",0)
	shell.closed=func():host._on_back()
	add_child(shell)
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
		var box:=VBoxContainer.new()
		box.add_theme_constant_override("separation",12)
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		shell.body.add_child(box)
		_pages.append(box)
	_common(_pages[0])
	_profile(_pages[1])
	_save(_pages[2])
	var help=Flow.button("说明",func():Flow.info(self,"键位与说明",["WASD / 方向键：移动；左右切换卡片。","Esc：关闭当前浮层，设置里的重选角色不会删除其他存档数据。","F10 / `：开发者控制台。 "]))
	help.position=Vector2(404,6)
	help.size=Vector2(64,44)
	help.plate=Kit.style("btn_small")
	add_child(help)
	shell.header_actions.append(help)
	_select(0)
	shell.layout()
func _select(index:int) -> void:
	for i in _pages.size():_pages[i].visible=i==index;shell.tabs.get_child(i).selected=i==index;shell.tabs.get_child(i).queue_redraw()
	shell.scroll.scroll_vertical=0
	Flow.wire_focus(self)
func _section(parent:Control,words:String) -> void:parent.add_child(Kit.section(words,String(SECTION_ICONS.get(words,""))))
## 行卡片换皮，左侧放图标框
func _row_card(icon:String) -> Array:
	var card:=Flow.Card.new()
	card.plate=Kit.style("row_card")
	var row:=HBoxContainer.new()
	row.custom_minimum_size.y=52
	row.add_theme_constant_override("separation",12)
	card.add_child(row)
	row.add_child(Kit.icon_box(icon))
	return [card,row]
## 开关行换皮：底板、开关贴图、左侧图标框（作为子节点，随尺寸居中）
func _switch(sw,icon:String) -> Button:
	sw.plate=Kit.style("row_card")
	sw.knob_on=Kit.texture("switch_on")
	sw.knob_off=Kit.texture("switch_off")
	sw.inset=60
	var box:=Kit.icon_box(icon)
	sw.add_child(box)
	sw.resized.connect(func():box.position=Vector2(12,floorf((sw.size.y-36)*.5));box.size=Vector2(36,36))
	return sw
## 按钮换皮：primary 金框、row 蓝底行按钮、danger 红底
func _btn(words:String,callback:Callable,kind:String="row") -> Button:
	var b=Flow.button(words,callback)
	b.plate=Kit.style({"primary":"btn_primary","row":"btn_row","danger":"btn_danger"}[kind])
	b.custom_minimum_size.y=48
	return b
func _volume(parent:Control,words:String,value:float,callback:Callable) -> void:
	var parts:=_row_card("music" if words=="音乐" else "sound")
	var card:Control=parts[0]
	var row:HBoxContainer=parts[1]
	parent.add_child(card)
	var title:=UI.label(words,"body")
	title.custom_minimum_size.x=52
	row.add_child(title)
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.01
	slider.value=value
	slider.custom_minimum_size=Vector2(220,52)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Kit.slider(slider)
	row.add_child(slider)
	_sliders.append(slider)
	var number:=UI.label("%d%%"%roundi(value*100),"number")
	number.custom_minimum_size.x=52
	row.add_child(number)
	slider.value_changed.connect(func(v:float):callback.call(v);number.text="%d%%"%roundi(v*100))
	host._vol_rows.append(row)
func _common(parent:Control) -> void:
	_section(parent,"声音")
	_volume(parent,"音乐",Audio.bgm_vol(),Audio.set_bgm_vol)
	_volume(parent,"音效",Audio.sfx_vol(),Audio.set_sfx_vol)
	host._mute_btn=_switch(Flow.Switch.new("静音",Audio.muted()),"sound")
	host._mute_btn.pressed.connect(func():Audio.set_mute(not Audio.muted());sync())
	parent.add_child(host._mute_btn)
	host._mute_hint=Flow.text("","caption",UI.AGED)
	parent.add_child(host._mute_hint)
	_section(parent,"战斗与演出")
	host._shake_btn=_switch(Flow.Switch.new("震屏",bool(G.setting_get("shake",true))),"shake")
	host._shake_btn.pressed.connect(func():G.setting_set("shake",not bool(G.setting_get("shake",true)));sync())
	parent.add_child(host._shake_btn)
	host._story_btn=_switch(Flow.Switch.new("剧情演出",not bool(G.setting_get("skip_story",false)),"播放","省略"),"story")
	host._story_btn.pressed.connect(func():G.setting_set("skip_story",not bool(G.setting_get("skip_story",false)));sync())
	parent.add_child(host._story_btn)
	var parts:=_row_card("speed")
	var card:Control=parts[0]
	var row:HBoxContainer=parts[1]
	parent.add_child(card)
	var title:=UI.label("战斗倍速","body")
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var prev=Flow.button("‹",func():G.setting_set("battle_speed",1.0);sync())
	_speed_prev=prev
	prev.custom_minimum_size=Vector2(40,36)
	prev.plate=Kit.style("step_btn")
	prev.size_flags_horizontal=Control.SIZE_SHRINK_END
	prev.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(prev)
	_speed_value=UI.label("","number")
	_speed_value.custom_minimum_size.x=52
	_speed_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_speed_value)
	host._speed_btn=Flow.button("›",func():G.setting_set("battle_speed",2.0);sync())
	host._speed_btn.custom_minimum_size=Vector2(40,36)
	host._speed_btn.plate=Kit.style("step_btn")
	host._speed_btn.size_flags_horizontal=Control.SIZE_SHRINK_END
	host._speed_btn.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	row.add_child(host._speed_btn)
	parent.add_child(Flow.text("战斗中也可随时切换倍速","caption",UI.AGED))
	sync()
func sync() -> void:
	host._mute_btn.on=Audio.muted()
	host._shake_btn.on=bool(G.setting_get("shake",true))
	host._story_btn.on=not bool(G.setting_get("skip_story",false))
	for b in [host._mute_btn,host._shake_btn,host._story_btn]:b.queue_redraw()
	for slider in _sliders:slider.editable=not Audio.muted();slider.modulate=Color(.5,.5,.5) if Audio.muted() else Color.WHITE
	_speed_value.text="×%d"%int(G.setting_get("battle_speed",1))
	_speed_prev.disabled=float(G.setting_get("battle_speed",1))<=1
	host._speed_btn.disabled=float(G.setting_get("battle_speed",1))>=2
	host._mute_hint.text="已静音，音量设置已保留" if Audio.muted() else "音乐与音效正常播放"
func _profile(parent:Control) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	row.add_child(Page.picture(G.avatar_texture(),Vector2(64,64)))
	row.add_child(Flow.text("%s\n%s · Lv.%d"%[G.display_name(),G.get_role(G.selected_role).get("name","旅人"),int(G.prog.get("level",1))],"body"))
	_section(parent,"昵称")
	host._name_edit=Flow.field("最多 8 个字")
	host._name_edit.text=G.player_name
	host._name_edit.max_length=8
	Kit.field(host._name_edit)
	parent.add_child(host._name_edit)
	parent.add_child(_btn("保存昵称",host._save_name,"primary"))
	host._name_hint=Flow.text("","caption",UI.AGED)
	parent.add_child(host._name_hint)
	parent.add_child(_btn("更换头像",host._open_avatar))
	_section(parent,"旅程")
	parent.add_child(_btn("重看序章",func():G.go("res://src/ui/Prologue.tscn")))
	parent.add_child(_btn("重选角色",func():G.go("res://src/ui/CreateRole.tscn")))
	if not host.standalone:parent.add_child(_btn("回标题",host._on_title))
func _save(parent:Control) -> void:
	_section(parent,"备份")
	parent.add_child(_btn("复制存档码",host._on_export,"primary"))
	host._note1=Flow.text("复制后可备份保存","caption",UI.AGED)
	parent.add_child(host._note1)
	_section(parent,"恢复存档")
	host._code=Flow.field("粘贴备份存档码")
	Kit.field(host._code)
	parent.add_child(host._code)
	parent.add_child(_btn("粘贴码",host._on_paste,"primary"))
	parent.add_child(_btn("导入",func():
		if host._code.text.strip_edges().is_empty():host._on_import()
		else:Page.confirm(self,"导入存档","将替换本机当前进度，原档会先备份。确认继续？",host._on_import),"primary"))
	host._hint2=Flow.text("导入成功后返回标题","caption",UI.AGED)
	parent.add_child(host._hint2)
	_section(parent,"重置")
	host._reset_btn=_btn("重置存档",host._on_reset_click,"danger")
	host._reset_btn.caption.add_theme_color_override("font_color",Color("f3c9b8"))
	parent.add_child(host._reset_btn)
	host._reset_hint=Flow.text("重置会清除本机当前存档","caption",UI.RED)
	parent.add_child(host._reset_hint)
func reset_confirm() -> void:
	host._reset_armed=true
	_reset_modal=Page.confirm(self,"重置存档","此操作会清除本机当前进度，确认继续？",func():host.execute_reset();G.go(host.TITLE_PATH))
	_reset_modal.closed.connect(func():host._reset_armed=false)
	_reset_modal.selected.connect(func(_index:int):host._reset_armed=false)
func disarm() -> void:
	host._reset_armed=false
	if is_instance_valid(_reset_modal):_reset_modal.queue_free()
