extends Control
## Visual-only command deck for the existing continuous BattleSim.
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
var host:Control
var tray:Control
var commands:Control
var _buttons:Dictionary={}
var _now:Label
var _hp:Label
var _pet:Label
var _energy:Label
var _page:Control
var _page_title:Label
var _page_back:Button
var _page_scroll:ScrollContainer
var _page_body:VBoxContainer
var _modal:Control
var _safe:=Rect2()
var _acting_uid:=-1
var _acting_until:=0
var _title:Label
var _enemy_strip:HBoxContainer
var _hp_graph:Control
var _pet_graph:Control
var _energy_graph:Control
var _page_energy_graph:Control
var _enemy_key:=""
var _auto_focus_uid:=-1
var _portraits:Dictionary={}
var _badges:Dictionary={}
var _numbers:Dictionary={}
var _target_subtitle:Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=UI.theme()
	tray=UI.Tray.new()
	add_child(tray)
	_now=UI.label("","caption")
	add_child(_now)
	host._cmd_info_l=_now
	_hp=UI.label("","tag")
	add_child(_hp)
	_pet=UI.label("","tag",UI.AGED)
	add_child(_pet)
	_energy=UI.label("","tag",UI.BLUE)
	add_child(_energy)
	for label in [_now,_hp,_pet,_energy]:label.visible=false
	_enemy_strip=HBoxContainer.new();_enemy_strip.add_theme_constant_override("separation",4);add_child(_enemy_strip)
	_hp_graph=Fix.Gauge.new("旅人");add_child(_hp_graph)
	_pet_graph=Fix.Gauge.new("伙伴");add_child(_pet_graph)
	_energy_graph=Fix.Gauge.new("能量",UI.BLUE);add_child(_energy_graph)
	commands=Control.new()
	commands.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(commands)
	host._cmd_root=commands
	_add("attack","攻击",host._command_attack,true)
	_add("skill","技能",host._show_command_skills)
	_add("item","道具",host._command_item)
	_add("partner","伙伴",host._command_swap_pet)
	_add("target","换目标",host._command_attack)
	_target_subtitle=_buttons.target.subtitle
	_add("flee","撤退",retreat)
	_add("speed","×1",func():host.speed=2.0 if host.cur_speed()<1.5 else 1.0;refresh())
	_add("auto","自动",func():host.sim.auto_mode=not host.sim.auto_mode;refresh())
	host._auto_btn=_buttons.auto
	host._speed_btn=_buttons.speed
	_buttons.attack.tooltip_text="普通攻击持续进行；点击切换集火目标"
	_buttons.target.tooltip_text="循环选择可攻击的敌方目标"
	var title:=UI.label({"normal":"遭遇战","elite":"精英战","boss":"首领战"}.get(String(host._cfg.get("enemy",{}).get("node_type","normal")),"遭遇战"),"section")
	_title=title
	title.position=Vector2(160,12)
	title.size=Vector2(150,36)
	add_child(title)
	_page=UI.Tray.new()
	_page.mouse_filter=Control.MOUSE_FILTER_STOP
	_page.z_index=UI.Z_TRAY
	_page.visible=false
	add_child(_page)
	host._page_panel=_page
	_page_title=UI.label("技能","section")
	_page.add_child(_page_title)
	_page_back=Flow.button("‹",func():host._close_page())
	_page_back.skin="back"
	_page_back.tooltip_text="返回战场指令"
	_page.add_child(_page_back)
	_page_scroll=Page.scroll()
	_page.add_child(_page_scroll)
	_page_body=VBoxContainer.new()
	_page_body.add_theme_constant_override("separation",4)
	_page_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(_page_body)
	host._page_energy_l=UI.label("","caption",UI.BLUE)
	_page.add_child(host._page_energy_l)
	host._page_energy_l.visible=false
	_page_energy_graph=Fix.Gauge.new("能量",UI.BLUE);_page.add_child(_page_energy_graph)
	host._cast_tip=UI.label("","body",UI.PAPER)
	host._cast_tip.modulate.a=0
	add_child(host._cast_tip)
	host._combo_tip=UI.label("","caption",UI.GOLD)
	host._combo_tip.modulate.a=0
	add_child(host._combo_tip)
	host._flee_blocked=String(host._cfg.get("flee_rule",""))=="blocked"
	host._set_radial_hint("flee","首领战不可撤退" if host._flee_blocked else "退出本节点，保留战损与进度")
	if host._flee_blocked:host._set_radial_disabled("flee",true)
	host._build_boss_bar()
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
func _add(id:String,words:String,callback:Callable,main:bool=false) -> void:
	var b:Button=Attack.new() if main else TargetButton.new() if id=="target" else UI.action(words,"rail")
	b.text=words
	b.caption.text=words
	b.set_meta("command",id)
	b.pressed.connect(callback)
	if id in ["flee","speed","auto"]:add_child(b)
	else:commands.add_child(b)
	var icon:=Page.picture(Flow.texture({"attack":"attack_icon","skill":"skill","item":"potion","partner":"partner","target":"attack_icon","flee":"retreat","speed":"speed","auto":"auto_off"}[id]),Vector2(40,40) if main else Vector2(28,28))
	icon.name="CommandIcon"
	b.add_child(icon)
	if id in ["attack","target"]:
		icon.visible=false
		var glyph:=CommandGlyph.new();glyph.cycle=id=="target";glyph.name="CommandGlyph";glyph.size=Vector2(28,28) if glyph.cycle else Vector2(40,40);b.add_child(glyph)
	_buttons[id]=b
	if id in ["attack","skill","item","flee"]:host._cmd_btns.append({"key":id,"root":b,"label":b.caption})
func layout(safe_override:Rect2=Rect2()) -> void:
	_safe=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x:=_safe.position.x
	var bottom:=_safe.end.y
	Page.place(_title,Vector2(x+160,_safe.position.y+12),Vector2(150,36))
	Page.place(tray,Vector2(x,bottom-216),Vector2(_safe.size.x,216))
	Page.place(_enemy_strip,Vector2(x+12,bottom-208),Vector2(_safe.size.x-24,44))
	var gauge_width:=(_safe.size.x-40)
	var hp_width:=floorf(gauge_width*.38)
	var pet_width:=floorf(gauge_width*.29)
	Page.place(_hp_graph,Vector2(x+12,bottom-156),Vector2(hp_width,28))
	Page.place(_pet_graph,Vector2(x+20+hp_width,bottom-156),Vector2(pet_width,28))
	Page.place(_energy_graph,Vector2(x+28+hp_width+pet_width,bottom-156),Vector2(gauge_width-hp_width-pet_width,28))
	Page.place(_now,Vector2(x+16,bottom-200),Vector2(_safe.size.x-32,24))
	Page.place(_hp,Vector2(x+16,bottom-172),Vector2(200,32))
	Page.place(_pet,Vector2(x+220,bottom-172),Vector2(120,32))
	Page.place(_energy,Vector2(x+348,bottom-172),Vector2(112,32))
	Page.place(commands,Vector2(x+12,bottom-120),Vector2(_safe.size.x-24,104))
	var column:=floorf((commands.size.x-12-152)/2)
	for id in ["partner","target","skill","item","attack"]:
		var p:=Vector2(0,0) if id=="partner" else Vector2(0,54) if id=="target" else Vector2(column+6,0) if id=="skill" else Vector2(column+6,54) if id=="item" else Vector2((column+6)*2,0)
		Page.place(_buttons[id],p,Vector2(commands.size.x-2*column-12 if id=="attack" else column,104 if id=="attack" else 50))
		if id!="attack":_buttons[id].caption.add_theme_font_size_override("font_size",15)
	for item in [["flee",12,76],["speed",324,68],["auto",400,68]]:
		var id:String=item[0]
		Page.place(_buttons[id],Vector2(x+float(item[1])+(_safe.size.x-480 if id!="flee" else 0),_safe.position.y+8),Vector2(item[2],44))
	for id in _buttons:
		var b:Button=_buttons[id]
		var icon:TextureRect=b.get_node("CommandIcon")
		icon.position=Vector2((b.size.x-icon.size.x)*.5,16 if id=="attack" else 4)
		if b.has_node("CommandGlyph"):b.get_node("CommandGlyph").position=Vector2(4,2) if id=="target" else Vector2((b.size.x-40)*.5,16)
	Page.place(_page,Vector2(x,bottom-416),Vector2(_safe.size.x,416))
	Page.place(_page_back,Vector2(8,12),Vector2(44,44))
	Page.place(_page_title,Vector2(64,12),Vector2(200,32))
	Page.place(host._page_energy_l,Vector2(_safe.size.x-144,14),Vector2(128,28))
	Page.place(_page_energy_graph,Vector2(_safe.size.x-156,10),Vector2(144,34))
	Page.place(_page_scroll,Vector2(12,64),Vector2(_safe.size.x-24,336))
	Page.place(host._cast_tip,Vector2(x+16,bottom-256),Vector2(_safe.size.x-32,40))
	Page.place(host._combo_tip,Vector2(x+16,bottom-280),Vector2(_safe.size.x-32,24))
func refresh() -> void:
	var role:Combatant=host.sim.role_unit()
	var sim:BattleSim=host.sim
	var usable:=0
	if role!=null:
		for skill in role.skills:
			if int(skill.cd_left)<=0 and int(skill.def.get("cost",0))<=role.energy:usable+=1
		var display:=String(host._cfg.get("player_name","旅人")) if host._classic_presentation() else role.name
		_hp.text="%s %d/%d"%[display.left(6),role.hp,role.get_max_hp()]
		_hp.add_theme_color_override("font_color",UI.RED if float(role.hp)/maxi(1,role.get_max_hp())<.25 else UI.PAPER)
		_energy.text="能量 %d/100"%role.energy
		_hp_graph.update(role.hp,role.get_max_hp());_hp_graph.tint=UI.RED if float(role.hp)/maxi(1,role.get_max_hp())<.25 else UI.JADE
		_energy_graph.update(role.energy,Combatant.MAX_ENERGY)
		_energy_graph.markers=role.skills.map(func(s):return int(s.def.get("cost",0)))
	var partners:Array=sim.alive_units("ally")
	_pet.text=""
	for unit in partners:
		if unit.kind=="pet":_pet.text="%s %d/%d"%[unit.name.left(4),unit.hp,unit.get_max_hp()];_pet_graph.caption.text=unit.name.left(4);_pet_graph.update(unit.hp,unit.get_max_hp());break
	var target:Combatant=sim.unit_by_uid(sim.role_focus_target_uid)
	var actor:Combatant=sim.unit_by_uid(_acting_uid) if Time.get_ticks_msec()<_acting_until else null
	var actor_name:=String(host._cfg.get("player_name","旅人")) if actor!=null and actor.kind=="role" and host._classic_presentation() else actor.name if actor!=null else ""
	_now.text=(actor_name.left(6)+"行动" if actor!=null else "连续战斗")+(" · 自动中" if sim.auto_mode else "")+" · 目标："+(target.name if target!=null and target.alive else "自动选敌")
	_buttons.skill.caption.text="可放 %d"%usable
	_buttons.item.caption.text="道具 %d"%sim.potions_left
	_buttons.partner.disabled=sim.pet_bench_id.is_empty() or sim.pet_swap_used
	_buttons.partner.tooltip_text="本场已换过" if sim.pet_swap_used else "没有替补伙伴" if sim.pet_bench_id.is_empty() else "换上替补伙伴 · 每场一次"
	_buttons.speed.caption.text="×%d"%int(host.cur_speed())
	_buttons.auto.caption.text="自动中" if sim.auto_mode else "自动"
	_buttons.auto.get_node("CommandIcon").texture=Flow.texture("auto_on" if sim.auto_mode else "auto_off")
	_enemy_cards(sim)
	_buttons.attack.subtitle.text="集火 · "+target.name.left(5) if target!=null and target.alive else "自动选敌"
	var next:Combatant=_next_target(role)
	_buttons.target.caption.text="换目标"
	_target_subtitle.text="下个 · "+_enemy_name(next) if next!=null else "没有目标"
	_target_subtitle.position=Vector2(2,29);_target_subtitle.size=Vector2(_buttons.target.size.x-4,20)
	_buttons.target.caption.position=Vector2(30,1);_buttons.target.caption.size=Vector2(_buttons.target.size.x-34,28)
	_buttons.target.get_node("CommandIcon").position=Vector2(4,2)
	_sync_badges(sim)
	if _page.visible:update_page()
	var candidates:Array=[]
	for uid in host._views:
		var view=host._views[uid]
		var unit:Combatant=sim.unit_by_uid(int(uid))
		if unit==null or not unit.alive:continue
		if unit.side=="enemy":
			var crowded:=false
			var area:Rect2=view._actor_rect()
			for other_uid in host._views:
				if other_uid==uid:continue
				var other:Combatant=sim.unit_by_uid(int(other_uid))
				if other!=null and other.side=="enemy" and other.alive and area.intersects(host._views[other_uid]._actor_rect()):crowded=true;break
			view.name_l.visible=not crowded;view.hp_value.visible=not crowded
			view.compact_health(crowded)
			for bar in [view.hp_bg,view.hp_fg,view.hp_ghost]:bar.visible=not crowded or unit.uid==sim.role_focus_target_uid
		if view.hp_value!=null:candidates.append({"label":view.hp_value,"priority":0})
		if view.name_l!=null:candidates.append({"label":view.name_l,"priority":1 if unit.kind=="role" else 2 if int(uid)==sim.role_focus_target_uid else 3})
	var exclusions:Array[Rect2]=[tray.get_global_rect()]
	if _page.visible:exclusions.append(_page.get_global_rect())
	preload("res://src/ui/NameTagLayout.gd").resolve(candidates,exclusions)
	for entry in candidates:
		if entry.label.self_modulate.a<1:entry.label.self_modulate.a=0
func show_page(id:String) -> void:
	host._command_page=id
	_page.visible=true
	host._page_energy_l.visible=false
	commands.visible=false
	Page.clear(_page_body)
	_page_title.text="技能" if id=="skills" else "道具与伙伴"
	var role:Combatant=host.sim.role_unit()
	if id=="skills" and role!=null:
		for skill in role.skills:
			var sid:=String(skill.def.get("id",""))
			_row(String(skill.def.get("name",sid)),"",host._cast_command_skill.bind(sid),sid)
	else:
		_row("药剂 ×%d"%host.sim.potions_left,"恢复 %d%% 生命"%roundi(BattleSim.POTION_HEAL_PCT*host.sim.potion_effect_mult*100),host._command_use_potion)
		if not host.sim.pet_bench_id.is_empty():_row("换宠",String(TableCache.get_pet(host.sim.pet_bench_id).get("name",""))+" · 每场一次",host._command_swap_pet)
	update_page()
func _row(words:String,detail:String,callback:Callable,sid:String="") -> void:
	var row:Button=Fix.SkillRow.new(words,Fix.skill(sid)) if not sid.is_empty() else Page.GrowthRow.new(words,"")
	row.heading.name="NameText"
	row.status.name="DetailText"
	row.image.texture=Fix.skill(sid) if not sid.is_empty() else Flow.texture("potion")
	row.custom_minimum_size.y=64
	row.heading.position.x=12
	row.status.text=detail
	row.next_action.text="施放" if not sid.is_empty() else "使用"
	if not sid.is_empty():row.set_meta("skill_id",sid)
	row.pressed.connect(callback)
	_page_body.add_child(row)
func update_page() -> void:
	var role:Combatant=host.sim.role_unit()
	if role==null:return
	host._page_energy_l.text="能量 %d/%d"%[role.energy,Combatant.MAX_ENERGY]
	_page_energy_graph.update(role.energy,Combatant.MAX_ENERGY)
	for row in _page_body.get_children():
		if row.has_meta("skill_id"):
			var sid:=String(row.get_meta("skill_id"))
			var def:Dictionary=host._command_skill_def(role,sid)
			var cd:int=host._skill_cd(role,sid)
			var cost:=int(def.get("cost",0))
			row.status.text="Lv%d · 耗能%d · %s · %s"%[host._skill_lv(sid),cost,"冷却 %.1f秒"%(cd/30.0) if cd>0 else "冷却就绪",host._range_text(String(def.get("target","")))]
			row.next_action.text="能量不足" if cost>role.energy else "冷却中" if cd>0 else "施放"
			row.actionable=cd<=0 and cost<=role.energy
			row.disabled=cd>0 or cost>role.energy or host.sim.finished
			row.cooldown=cd/30.0;row.cooldown_max=maxf(1,float(skill_duration(role,sid)))
			row.missing=maxi(0,cost-role.energy)
			row.tooltip_text="需要 %d 能量，当前 %d"%[cost,role.energy] if cost>role.energy else "冷却还有 %.1f 秒"%(cd/30.0) if cd>0 else "点击施放"
			row.queue_redraw()
func skill_duration(role:Combatant,sid:String) -> float:
	return float(host._command_skill_def(role,sid).get("cd",1))
func _next_target(role:Combatant) -> Combatant:
	var enemies:Array=host.sim.alive_units("enemy")
	if role!=null and role.attack_range=="melee":
		var front:=enemies.filter(func(u):return u.row==Combatant.ROW_FRONT)
		if not front.is_empty():enemies=front
	if enemies.is_empty():return null
	var current:=-1
	for i in enemies.size():
		if enemies[i].uid==host.sim.role_focus_target_uid:current=i;break
	return enemies[(current+1)%enemies.size()]
func _portrait(uid:int) -> Texture2D:
	if _portraits.has(uid):return _portraits[uid]
	var view=host._views.get(uid)
	if view==null or view.sprite==null:return null
	var source:Texture2D=view.sprite.texture if view.sprite is Sprite2D else view.sprite.sprite_frames.get_frame_texture(view.sprite.animation,view.sprite.frame) if view.sprite is AnimatedSprite2D else null
	if source==null:return null
	var used:=source.get_image().get_used_rect()
	var atlas:=AtlasTexture.new();atlas.atlas=source
	atlas.region=Rect2(Vector2(used.position)+Vector2(used.size.x*.2,0),Vector2(used.size.x*.6,used.size.y*.65))
	_portraits[uid]=atlas;return atlas
func _enemy_cards(sim:BattleSim) -> void:
	var units:Array=sim.units.filter(func(u):return u.side=="enemy")
	var key:=str(units.map(func(u):return u.uid))
	if key!=_enemy_key:
		_enemy_key=key;Page.clear(_enemy_strip)
		for i in mini(4,units.size()):
			var chip:=Fix.EnemyChip.new(_portrait(units[i].uid));_enemy_strip.add_child(chip)
			if i==3 and units.size()>4:chip.extra=units.size()-3
	for i in _enemy_strip.get_child_count():
		var chip=_enemy_strip.get_child(i);chip.unit=units[i];chip.number=i+1;chip.display_name=_enemy_name(units[i])
		# The deck is built before UnitViews finish spawning; retry missing portraits.
		if chip.portrait.texture==null:chip.portrait.texture=_portrait(units[i].uid)
		chip.focused=units[i].uid==sim.role_focus_target_uid or (sim.role_focus_target_uid<0 and units[i].uid==_auto_focus_uid)
		chip.automatic=sim.role_focus_target_uid<0;chip.queue_redraw()
func _enemy_name(unit:Combatant) -> String:
	if unit==null:return ""
	var enemies:Array=host.sim.units.filter(func(u):return u.side=="enemy")
	var duplicate:=enemies.filter(func(u):return u.name==unit.name).size()>1
	return unit.name+"·%d"%(enemies.find(unit)+1) if duplicate else unit.name
func _sync_badges(sim:BattleSim) -> void:
	var enemies:Array=sim.units.filter(func(u):return u.side=="enemy")
	var occupied:Array[Vector2]=[]
	var center:=Vector2.ZERO
	for unit in enemies:
		if host._views.has(unit.uid):center+=host._views[unit.uid]._actor_rect().get_center()
	center/=maxi(1,enemies.size())
	for i in enemies.size():
		var unit:Combatant=enemies[i]
		var view=host._views.get(unit.uid)
		if view==null:continue
		if not _badges.has(unit.uid):
			var badge:=NumberBadge.new();badge.number=i+1;view.add_child(badge);badge.z_index=10;_badges[unit.uid]=badge
		var badge:Node2D=_badges[unit.uid]
		badge.visible=unit.alive
		badge.focused=unit.uid==sim.role_focus_target_uid
		var rect:Rect2=view._actor_rect()
		var foot:=Vector2(rect.get_center().x,rect.end.y)
		var at:=foot+Vector2(0,12)
		for attempt in 2:
			var conflict:=false
			for point in occupied:if point.distance_to(at)<18:conflict=true;break
			if not conflict:break
			at.x+=12 if at.x>=center.x else -12
		occupied.append(at)
		badge.global_position=at;badge.queue_redraw()
		badge.z_as_relative=false;badge.z_index=26
		view._target_ring.global_position=foot
		view._target_ring.z_as_relative=false;view._target_ring.z_index=25
		if view._target_mark!=null:
			view._target_mark.global_position=Vector2(rect.get_center().x,rect.position.y-4);view._target_mark.z_as_relative=false;view._target_mark.z_index=27
		view.set_focused(badge.focused)
func retreat() -> void:
	if host._flee_blocked:host._show_tip("首领战不可撤退");return
	_modal=Page.confirm(self,"撤退确认","退出本节点，保留战损与节点进度，确定撤退？",func():host._flee_armed=true;host._on_flee())
func _unhandled_input(e:InputEvent) -> void:
	if G.ui_blocked:return
	if e.is_action_pressed("ui_cancel"):
		if _page.visible:host._close_page()
		elif not is_instance_valid(_modal):retreat()
		get_viewport().set_input_as_handled()

class Attack extends UI.ChestButton:
	const Flow=preload("res://src/ui/FlowChestUI.gd")
	func _init() -> void:super("攻击","primary")
	func _layout() -> void:
		caption.position=Vector2(0,size.y-55)
		caption.size=Vector2(size.x,32)
		caption.add_theme_font_size_override("font_size",22)
		subtitle.position=Vector2(5,size.y-24)
		subtitle.size=Vector2(size.x-10,20)
		subtitle.add_theme_font_size_override("font_size",12)
	func _draw() -> void:
		UI.nine(self,Flow.texture("attack"),size)
		if is_pressed():draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.2))
		if has_focus():draw_rect(Rect2(2,2,size.x-4,size.y-4),UI.GOLD,false,2)
		_layout()

class TargetButton extends UI.ChestButton:
	func _init() -> void:super("换目标","rail")
	func _layout() -> void:
		caption.position=Vector2(32,0);caption.size=Vector2(size.x-36,28)
		subtitle.position=Vector2(2,29);subtitle.size=Vector2(size.x-4,20);subtitle.add_theme_font_size_override("font_size",12)
class CommandGlyph extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var cycle:=false
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if cycle:
			draw_arc(Vector2(14,14),9,-PI*.8,PI*.2,12,UI.COPPER,3)
			draw_arc(Vector2(14,14),9,PI*.2,PI*1.2,12,UI.COPPER,3)
			draw_colored_polygon(PackedVector2Array([Vector2(25,12),Vector2(25,21),Vector2(17,16)]),UI.COPPER)
			draw_colored_polygon(PackedVector2Array([Vector2(3,16),Vector2(3,7),Vector2(11,12)]),UI.COPPER)
		else:
			draw_arc(Vector2(18,20),16,-PI*.8,PI*.1,16,UI.GOLD,3)
			var blade:=PackedVector2Array([Vector2(7,29),Vector2(25,7),Vector2(34,3),Vector2(31,13),Vector2(12,34)])
			draw_colored_polygon(blade,Color("d7e0e5"));draw_polyline(blade+PackedVector2Array([blade[0]]),UI.NIGHT,2)
			draw_line(Vector2(5,27),Vector2(16,36),UI.COPPER,4);draw_line(Vector2(8,32),Vector2(3,38),UI.COPPER,4)
class NumberBadge extends Node2D:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var number:=1
	var focused:=false
	func _draw() -> void:
		draw_circle(Vector2.ZERO,8,UI.GOLD if focused else UI.NIGHT)
		draw_arc(Vector2.ZERO,8,0,TAU,24,UI.COPPER,1)
		var words:=str(number)
		var width:=G.font_bold.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(G.font_bold,Vector2(-width*.5,4),words,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.NIGHT if focused else UI.PAPER)
class TargetRing extends Node2D:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,.25))
		draw_arc(Vector2.ZERO,28,0,TAU,48,Color("17141a"),4,true)
		draw_arc(Vector2.ZERO,28,0,TAU,48,UI.GOLD,2,true)
