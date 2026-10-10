extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
var host:Control
var shell:Control
var _art:TextureRect
var _night:ColorRect
var _fade:Control
var _name:Label
var _description:Label
var _index:Label
var _prev:Button
var _next:Button
var _go:Button
var _model:Control
var _choice:=""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("出征筹备",352)
	shell.closed=func():host.canceled.emit()
	add_child(shell)
	shell.background.visible=false
	_night=ColorRect.new();_night.color=UI.NIGHT;_night.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.add_child(_night);shell.move_child(_night,0)
	host._content=shell.body
	_model=Flow.Selection.new()
	_model.page_changed.connect(func(_i:int):_changed())
	add_child(_model)
	host._deck=_model
	for i in 3:
		var index:int=i
		host._tab_btns.append(shell.tab("%d %s"%[i+1,host.STEPS[i]],func():host._goto_step(index)))
	_art=Page.picture(null,Vector2(448,224))
	shell.stage.add_child(_art)
	_fade=ArtFade.new();shell.stage.add_child(_fade)
	_name=UI.label("","title")
	shell.stage.add_child(_name)
	_description=Flow.text("","body",UI.AGED)
	_description.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	_description.max_lines_visible=3
	shell.stage.add_child(_description)
	_index=UI.label("","caption",UI.AGED)
	shell.stage.add_child(_index)
	_prev=Flow.button("‹",func():_model.go(_model.current-1))
	_next=Flow.button("›",func():_model.go(_model.current+1))
	shell.stage.add_child(_prev)
	shell.stage.add_child(_next)
	host._sweep_btn=Flow.button("扫荡 ×%d"%G.item_count("ticket_sweep"),host._on_sweep)
	host._sweep_btn.custom_minimum_size.x=140
	host._sweep_btn.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	shell.footer.add_child(host._sweep_btn)
	_go=Flow.button("出征",host._on_confirm,true)
	shell.footer.add_child(_go)
	var info:=Flow.button("说明",func():Flow.info(self,"出征筹备",host.TIPS))
	info.position=Vector2(404,6)
	info.size=Vector2(64,44)
	add_child(info)
	shell.header_actions.append(info)
	host._help_btn=info
	G.tip_once.call_deferred("deploy","出征筹备 · 怎么操作",host.TIPS,host)
	get_viewport().size_changed.connect(layout)
	step()
func step() -> void:
	match host._step:
		0:_model.page_count=G.theme_order().size();_model.current=maxi(0,G.theme_order().find(host._theme))
		1:
			_model.page_count=G.roles.size()
			for i in G.roles.size():
				if String(G.roles[i].id)==host._role:_model.current=i
		2:
			_model.page_count=TableCache.pets().size()
			for i in TableCache.pets().size():
				if String(TableCache.pets()[i].id)==host._active_pet:_model.current=i
	_changed(false)
func _changed(select:bool=true) -> void:
	match host._step:
		0:
			_choice=String(G.theme_order()[_model.current])
			if select and G.is_world_unlocked(_choice):host._theme=_choice
		1:
			_choice=String(G.roles[_model.current].id)
			if select:host._role=_choice
		2:_choice=String(TableCache.pets()[_model.current].id)
	refresh()
func refresh() -> void:
	Page.clear(shell.body)
	for i in host._tab_btns.size():host._tab_btns[i].selected=i==host._step;host._tab_btns[i].queue_redraw()
	var labels:=""
	match host._step:
		0:
			_art.texture=G.res_tex("world_"+_choice+"_art")
			if _art.texture==null:_art.texture=G.res_tex("world_"+_choice)
			_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_name.text=G.world_name(_choice)
			var open:=G.is_world_unlocked(_choice)
			_art.modulate=Color.WHITE if open else Color(.45,.45,.45)
			_description.text="「%s」\n%s"%[G.theme_lore(_choice).get("epigraph",""),"首领已讨伐" if G.is_world_cleared(_choice) else "首领未讨伐 · 通关开启下一片" if open else "尚未解锁 · 先通关前一片"]
			labels="秘境"
		1:
			_art.texture=G.res_tex("role_"+_choice)
			if _art.texture==null:_art.texture=G.res_tex("role_"+_choice+"_art")
			_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_art.modulate=Color.WHITE
			var cfg:=G.get_role(_choice)
			_name.text=String(cfg.name)
			_description.text="%s · %s\n%s"%[cfg.job,cfg.weapon,cfg.get("desc","")]
			labels="人物"
		2:
			var cfg:=TableCache.get_pet(_choice)
			_art.texture=preload("res://src/ui/ReviewFixUI.gd").pet(_choice)
			_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_art.modulate=Color.WHITE if G.owns_pet(_choice) else Color("17141a")
			_name.text=String(cfg.name) if G.owns_pet(_choice) else "？？？"
			_description.text=G.pet_unlock_text(_choice)+"\n"+("出战主力" if host._active_pet==_choice else "替补伙伴" if host._bench_pet==_choice else "点击伙伴画像选择；再次点击按现有规则切换")
			labels="宠物"
			var choose:=Flow.button("选择当前伙伴",func():host._select_pet(_choice))
			choose.disabled=not G.owns_pet(_choice)
			shell.body.add_child(choose)
	_index.text="%s %02d / %02d"%[labels,_model.current+1,_model.page_count]
	var cards:=HBoxContainer.new();cards.add_theme_constant_override("separation",8);shell.body.add_child(cards)
	var role:=G.get_role(host._role)
	cards.add_child(SetupCard.new("人物",String(role.get("name","")),"Lv%d · %s"%[int(G.prog.get("level",1)),role.get("job","")],G.res_tex("role_"+host._role),func():host._goto_step(1)))
	var pet:=TableCache.get_pet(host._active_pet)
	var bench:=String(TableCache.get_pet(host._bench_pet).get("name",""))
	cards.add_child(SetupCard.new("伙伴",String(pet.get("name","未选择")),"替补 · "+bench if not bench.is_empty() else "选择同行伙伴",preload("res://src/ui/ReviewFixUI.gd").pet(host._active_pet),func():host._goto_step(2)))
	var supply:=HBoxContainer.new();supply.add_theme_constant_override("separation",8);shell.body.add_child(supply)
	var summary:=VBoxContainer.new();summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;supply.add_child(summary)
	summary.add_child(Flow.text("补给 · 药剂 %d 瓶"%(G.run_potions_base()+host._extra_potions),"body"))
	summary.add_child(Flow.text("%d 金/瓶 · 加带 %d · 合计 %d 金"%[G.run_supply_price(host._extra_potions),host._extra_potions,host._supply_total()],"caption",UI.AGED))
	var minus:=Flow.button("−",func():host._extra_potions=maxi(0,host._extra_potions-1);refresh());minus.set_meta("supply_step",-1);minus.disabled=host._extra_potions<=0;minus.custom_minimum_size.x=44;minus.size_flags_horizontal=Control.SIZE_SHRINK_END;supply.add_child(minus)
	host._supply_btn=Flow.button("+",func():host._add_supply());host._supply_btn.set_meta("supply_step",1)
	host._supply_btn.disabled=host._extra_potions>=G.run_potions_max()-G.run_potions_base() or host._supply_total()+G.run_supply_price(host._extra_potions)>int(G.wallet.get("gold",0));host._supply_btn.custom_minimum_size.x=44;host._supply_btn.size_flags_horizontal=Control.SIZE_SHRINK_END;supply.add_child(host._supply_btn)
	host._supply_btn.tooltip_text="金币不足" if host._supply_total()+G.run_supply_price(host._extra_potions)>int(G.wallet.get("gold",0)) else "加带一瓶 · %d 金"%G.run_supply_price(host._extra_potions)
	host._ascetic_btn=Flow.Switch.new("苦行 · 敌人 ×%.2f / 收益 ×%.2f"%[float(G.ascetic_cfg().get("enemy_mult",1)),float(G.ascetic_cfg().get("reward_mult",1))],host._ascetic)
	host._ascetic_btn.pressed.connect(func():host._toggle_ascetic();refresh())
	shell.body.add_child(host._ascetic_btn)
	host._hint=Flow.text("补给在出征时结算；返回不扣金币。","caption",UI.AGED)
	shell.body.add_child(host._hint)
	_go.disabled=not G.is_world_unlocked(host._theme) or (host._step==0 and not G.is_world_unlocked(_choice)) or host._active_pet.is_empty() or not G.owns_pet(host._active_pet)
	host._sweep_btn.caption.text="扫荡 ×%d"%G.item_count("ticket_sweep")
	host._sweep_btn.disabled=G.item_count("ticket_sweep")<=0 or not G.is_world_cleared(host._theme)
	host._sweep_btn.subtitle.text="扫荡券不足" if G.item_count("ticket_sweep")<=0 else "先通关首领" if not G.is_world_cleared(host._theme) else "快速结算"
	host._sweep_btn.tooltip_text=host._sweep_btn.subtitle.text
	layout()
func layout(safe_override:Rect2=Rect2()) -> void:
	shell.layout(safe_override)
	Page.place(_night,Vector2.ZERO,get_viewport_rect().size)
	var w:float=shell.stage.size.x
	var h:float=shell.stage.size.y
	var art_h:=minf(360,maxf(80,h-116))
	Page.place(_art,Vector2(0,0),Vector2(w,art_h))
	Page.place(_fade,Vector2(0,art_h-48),Vector2(w,48))
	Page.place(_index,Vector2(28,8),Vector2(w-56,24))
	Page.place(_name,Vector2(16,art_h+8),Vector2(w-32,40))
	Page.place(_description,Vector2(16,art_h+52),Vector2(w-32,h-art_h-52))
	_description.max_lines_visible=3
	_description.clip_text=true
	Page.place(_prev,Vector2(16,art_h*.5-28),Vector2(44,56))
	Page.place(_next,Vector2(w-60,art_h*.5-28),Vector2(44,56))

class SetupCard extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var image:TextureRect
	var heading:Label
	var detail:Label
	func _init(kind:String,words:String,note:String,tex:Texture2D,callback:Callable) -> void:
		custom_minimum_size=Vector2(0,96);size_flags_horizontal=Control.SIZE_EXPAND_FILL;text=kind+" · "+words
		image=Page.picture(tex,Vector2(48,64));add_child(image)
		heading=UI.label(kind+" · "+words,"caption");add_child(heading)
		detail=UI.label(note,"tag",UI.AGED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(detail)
		pressed.connect(callback)
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:add_theme_color_override(state,Color.TRANSPARENT)
		resized.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE,UI.COPPER if has_focus() else UI.BRONZE)
		image.position=Vector2(8,14);heading.position=Vector2(64,8);heading.size=Vector2(size.x-70,32);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		detail.position=Vector2(64,44);detail.size=Vector2(size.x-70,44)
		draw_string(G.font_reg,Vector2(size.x-16,size.y-10),"›",HORIZONTAL_ALIGNMENT_LEFT,-1,16,UI.AGED)
class ArtFade extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		for i in 24:draw_rect(Rect2(0,i*2,size.x,2),Color(UI.NIGHT,float(i)/23.0))
