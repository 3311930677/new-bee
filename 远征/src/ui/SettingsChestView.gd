extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
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
		shell.tab(["常规","旅人","存档"][i],func():host._deck.go(index))
		var box:=VBoxContainer.new()
		box.add_theme_constant_override("separation",12)
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		shell.body.add_child(box)
		_pages.append(box)
	_common(_pages[0])
	_profile(_pages[1])
	_save(_pages[2])
	var help:=Flow.button("说明",func():Flow.info(self,"键位与说明",["WASD / 方向键：移动；左右切换卡片。","Esc：关闭当前浮层，设置里的重选角色不会删除其他存档数据。","F10 / `：开发者控制台。 "]))
	help.position=Vector2(404,6)
	help.size=Vector2(64,44)
	add_child(help)
	shell.header_actions.append(help)
	_select(0)
	shell.layout()
func _select(index:int) -> void:
	for i in _pages.size():_pages[i].visible=i==index;shell.tabs.get_child(i).selected=i==index;shell.tabs.get_child(i).queue_redraw()
	shell.scroll.scroll_vertical=0
	Flow.wire_focus(self)
func _section(parent:Control,words:String) -> void:parent.add_child(Flow.text(words,"section",UI.AGED))
func _volume(parent:Control,words:String,value:float,callback:Callable) -> void:
	var row:=HBoxContainer.new()
	row.custom_minimum_size.y=52
	parent.add_child(row)
	var title:=UI.label(words,"body")
	title.custom_minimum_size.x=88
	row.add_child(title)
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.01
	slider.value=value
	slider.custom_minimum_size=Vector2(220,52)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host._style_slider(slider)
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
	host._mute_btn=Flow.Switch.new("静音",Audio.muted())
	host._mute_btn.pressed.connect(func():Audio.set_mute(not Audio.muted());sync())
	parent.add_child(host._mute_btn)
	host._mute_hint=Flow.text("","caption",UI.AGED)
	parent.add_child(host._mute_hint)
	_section(parent,"战斗与演出")
	host._shake_btn=Flow.Switch.new("震屏",bool(G.setting_get("shake",true)))
	host._shake_btn.pressed.connect(func():G.setting_set("shake",not bool(G.setting_get("shake",true)));sync())
	parent.add_child(host._shake_btn)
	host._story_btn=Flow.Switch.new("剧情演出",not bool(G.setting_get("skip_story",false)),"播放","省略")
	host._story_btn.pressed.connect(func():G.setting_set("skip_story",not bool(G.setting_get("skip_story",false)));sync())
	parent.add_child(host._story_btn)
	var row:=HBoxContainer.new()
	row.custom_minimum_size.y=52
	parent.add_child(row)
	var title:=UI.label("战斗倍速","body")
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var prev:=Flow.button("‹",func():G.setting_set("battle_speed",1.0);sync())
	_speed_prev=prev
	prev.custom_minimum_size.x=44
	prev.size_flags_horizontal=Control.SIZE_SHRINK_END
	row.add_child(prev)
	_speed_value=UI.label("","number")
	_speed_value.custom_minimum_size.x=52
	_speed_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_speed_value)
	host._speed_btn=Flow.button("›",func():G.setting_set("battle_speed",2.0);sync())
	host._speed_btn.custom_minimum_size.x=44
	host._speed_btn.size_flags_horizontal=Control.SIZE_SHRINK_END
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
	parent.add_child(host._name_edit)
	parent.add_child(Flow.button("保存昵称",host._save_name))
	host._name_hint=Flow.text("","caption",UI.AGED)
	parent.add_child(host._name_hint)
	parent.add_child(Flow.button("更换头像",host._open_avatar))
	_section(parent,"旅程")
	parent.add_child(Flow.button("重看序章",func():G.go("res://src/ui/Prologue.tscn")))
	parent.add_child(Flow.button("重选角色",func():G.go("res://src/ui/CreateRole.tscn")))
	if not host.standalone:parent.add_child(Flow.button("回标题",host._on_title))
func _save(parent:Control) -> void:
	_section(parent,"备份")
	parent.add_child(Flow.button("复制存档码",host._on_export))
	host._note1=Flow.text("复制后可备份保存","caption",UI.AGED)
	parent.add_child(host._note1)
	_section(parent,"恢复存档")
	host._code=Flow.field("粘贴备份存档码")
	parent.add_child(host._code)
	parent.add_child(Flow.button("粘贴码",host._on_paste))
	parent.add_child(Flow.button("导入",func():
		if host._code.text.strip_edges().is_empty():host._on_import()
		else:Page.confirm(self,"导入存档","将替换本机当前进度，原档会先备份。确认继续？",host._on_import)))
	host._hint2=Flow.text("导入成功后返回标题","caption",UI.AGED)
	parent.add_child(host._hint2)
	_section(parent,"重置")
	host._reset_btn=Flow.button("重置存档",host._on_reset_click)
	host._reset_btn.caption.add_theme_color_override("font_color",UI.RED)
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
