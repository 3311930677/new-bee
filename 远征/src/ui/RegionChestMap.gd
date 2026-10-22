extends Control
signal closed
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
var _visual:Dictionary
var _edge_tags:Control
var _locator:Button
const Flow:=preload("res://src/ui/FlowChestUI.gd")
static var _visual_cache:Dictionary={}
static func warm() -> void:
	if _visual_cache.is_empty():
		_visual_cache=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/next_review_20261009/map_layout.json"))
	for row in TableCache.main_world_config().get("regions",[]):
		TableCache.main_world_map(String(row.id))
	for m in ["town","maple","stele","cavern","salt","port","marsh","sluice","sand","frost","mine","pass"]:
		Flow.texture(m)
const Journey:=preload("res://src/world/JourneyService.gd")
var _shell:Control
var _map:Control
var _graph:Control
var _positions:Dictionary={}
var _nodes:Dictionary={}
var _rows:Array=[]
var _routes:Array=[]
var _reachable:Dictionary={}
var _reasons:Dictionary={}
var _current:=""
var _selected:=""
var _dragging:=false
var _velocity:=Vector2.ZERO
var _last:=Vector2.ZERO
var _center_tween:Tween
var _zoom:=.5
var _zoom_button:Button
var _quest_button:Button
var _travel_button:Button
var _bounds:=Rect2()
var _press:=Vector2.ZERO
var _moved:=false
var _hint:Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell=Flow.Shell.new("地区行路图",196)
	_shell.closed=func():closed.emit()
	add_child(_shell)
	_map=Control.new()
	_map.mouse_filter=Control.MOUSE_FILTER_STOP
	_map.clip_contents=true
	_shell.stage.add_child(_map)
	_graph=_MapGraph.new()
	_map.add_child(_graph)
	_rows=TableCache.main_world_config().get("regions",[])
	if _visual_cache.is_empty():
		_visual_cache=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/next_review_20261009/map_layout.json"))
	_visual=_visual_cache
	_current=String(G.prog.get("main_world",{}).get("map_id","lorin_wilds"))
	_selected=_current
	var ext:=Vector2(1440,1600)
	for row in _rows:
		var point:=Vector2(row.point[0],row.point[1])
		for node in _visual.nodes:
			if String(node.id)==String(row.id):point=Vector2(node.point[0],node.point[1]);break
		_positions[String(row.id)]=point
	_graph.size=ext
	_graph.map_ref=self
	for row in _rows:
		var id:=String(row.id)
		for exit in TableCache.main_world_map(id).get("exits",[]):
			var to:=String(exit.get("to",""))
			if not _positions.has(to):continue
			_routes.append({"from":id,"to":to,"gate":exit})
			var reason:=_gate(exit)
			if not reason.is_empty():_reasons[to]=reason
	_reachable[_current]=true
	for iteration in _rows.size():
		for route in _routes:
			if _reachable.has(route.from) and _gate(route.gate).is_empty():_reachable[route.to]=true
	var visited:Array=G.prog.get("main_world",{}).get("visited_maps",[])
	for row in _rows:
		var id:=String(row.id)
		var node:=_MapNode.new()
		node.position=_positions[id]-Vector2(48,42)
		node.size=Vector2(96,80)
		node.name="Map_"+id
		node.words=String(row.name)
		node.levels="Lv%d–%d"%[row.level[0],row.level[1]]
		node.marker=_landmark(id)
		node.current=id==_current
		node.visited=id==_current or visited.has(id) or (G.has_method("world_gate_open") and G.world_gate_open())
		node.reachable=_reachable.has(id)
		node.quest_badges=_quest_badges_for(id)
		node.condition=false
		for route in _routes:
			if route.to==id and _reachable.has(route.from) and not _gate(route.gate).is_empty():node.condition=true;break
		node.mouse_filter=Control.MOUSE_FILTER_PASS
		node.pressed.connect(func():if not _moved:select(id))
		_graph.add_child(node)
		_nodes[id]=node
		var point:Vector2=_positions[id]
		_bounds=Rect2(point,Vector2.ONE) if not _bounds.has_area() else _bounds.expand(point)
	_map.gui_input.connect(_drag)
	_edge_tags=Control.new();_edge_tags.mouse_filter=Control.MOUSE_FILTER_IGNORE;_map.add_child(_edge_tags)
	var border:=_MapBorder.new();border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_map.add_child(border)
	_quest_button=Flow.button("寻迹",_focus_quest_target);_quest_button.tooltip_text="定位当前主线或追踪任务所在地区";_map.add_child(_quest_button)
	_locator=Flow.button("⌖",func():select(_current));_locator.tooltip_text="回到当前位置";_map.add_child(_locator)
	_bounds=_bounds.grow(160)
	_zoom_button=Flow.button("详图",toggle_zoom);_zoom_button.tooltip_text="切换全览与详图";_map.add_child(_zoom_button)
	_hint=UI.label("拖动查看 · 点已访地点可乘驿车直达","tag",UI.PAPER);_hint.position=Vector2(16,16);_map.add_child(_hint)
	get_tree().create_timer(2.5).timeout.connect(func():if is_instance_valid(_hint):_hint.hide())
	var info:=Flow.button("图例",_show_legend)
	info.size=Vector2(64,44)
	info.position=Vector2(404,6)
	add_child(info)
	_shell.header_actions.append(info)
	get_viewport().size_changed.connect(layout)
	layout()
	select(_current,false)
func _quest_badges_for(id:String) -> Array[String]:
	var badges:Array[String]=[]
	var story:Dictionary=G.story_current()
	if not story.is_empty() and String(story.get("map",""))==id:
		badges.append("主线")
	var tracked_side:String=String(G.side_tracked_id()) if G.has_method("side_tracked_id") else ""
	if not tracked_side.is_empty():
		var srow:Dictionary=G.side_quest_def(tracked_side) if G.has_method("side_quest_def") else {}
		var smap:=String(srow.get("map",""))
		if smap==id and not badges.has("支线"):
			badges.append("支线")
	for row_v in TableCache.side_quests_config().get("quests",[]):
		var row:Dictionary=row_v
		var qid:=String(row.get("id",""))
		var st:String=String(G.side_status_of(qid)) if G.has_method("side_status_of") else ""
		if st in ["active","ready"]:
			var target_map:=String(row.get("map","")) if st=="active" else String(row.get("turn_in_map",row.get("map","lorin_wilds")))
			if target_map==id and not badges.has("支线"):
				badges.append("支线")
	return badges
func _focus_quest_target() -> void:
	var story:Dictionary=G.story_current()
	var target_map:=String(story.get("map",""))
	if target_map.is_empty() or not _positions.has(target_map):
		for id in _nodes:
			if not (_nodes[id].quest_badges as Array).is_empty():
				target_map=id
				break
	if not target_map.is_empty() and _positions.has(target_map):
		select(target_map,true)
	else:
		select(_current,true)
func _gate(row:Dictionary) -> String:
	if G.has_method("world_gate_open") and G.world_gate_open():return ""
	var story:=String(row.get("requires_story",""))
	if not story.is_empty() and not G.story_step_done(story):return String(row.get("locked_hint","先完成当前道路的主线"))
	for flag in row.get("requires_flags",[]):
		if not G.prog.get("flags",{}).get(String(flag),false):return String(row.get("locked_hint","先完成入口机关"))
	return ""
func _show_legend() -> void:
	var modal:=UI.Modal.new();modal.heading="行路图图例";modal.lines=["当前位置 · 可达 · 锁定 · 条件受限","旅人旗标记当前位置，金标「主」/蓝标「支」指引任务所在地。","已探索且无货运限制的地区，可直接点击「乘驿车前往」免费直达。","首次探索未知地区请沿相邻路牌步行前往。"]
	modal.closed.connect(modal.queue_free);add_child(modal)
	var column:VBoxContainer
	for child in modal.get_children():
		if child.has_node("BodyScroll"):column=child.get_node("BodyScroll").get_child(0)
	if column==null:return
	Page.clear(column)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",4);column.add_child(row)
	for state in ["当前","可达","锁定","条件受限"]:
		var sign:=_MapNode.new();sign.words=state;sign.marker="town";sign.current=state=="当前";sign.reachable=state in ["当前","可达"];sign.condition=state=="条件受限";sign.overview=true;sign.disabled=true;sign.custom_minimum_size=Vector2(90,84);row.add_child(sign)
	column.add_child(Flow.text("金签「主线」与蓝签「支线」标识当前任务目标地区。","caption",UI.AGED))
	column.add_child(Flow.text("已到访的驿路站点可直接乘驿车前往；未知区域沿相邻路牌探索。","caption",UI.AGED))
func _landmark(id:String) -> String:
	return {"lorin_wilds":"town","maple_road":"maple","broken_slope":"stele","stele_cavern":"cavern","old_salt_road":"salt","shenyuan_port":"port","tideflat":"marsh","tidal_gate":"sluice","red_sand_route":"sand","frost_post":"frost","rift_mine_road":"mine","rift_mine_vault":"mine","frost_boardwalk":"pass","frost_pass":"pass","abyss_ring":"cavern","stele_entry":"stele","stele_resonance":"cavern","stele_core":"cavern"}.get(id,"cavern")
func layout(safe_override:Rect2=Rect2()) -> void:
	_shell.layout(safe_override)
	Page.place(_map,Vector2.ZERO,_shell.stage.size)
	if _quest_button!=null:
		Page.place(_quest_button,Vector2(_map.size.x-168,_map.size.y-56),Vector2(54,44))
	Page.place(_locator,Vector2(_map.size.x-108,_map.size.y-56),Vector2(44,44))
	Page.place(_zoom_button,Vector2(_map.size.x-56,_map.size.y-56),Vector2(44,44))
	_apply_zoom()
	_clamp()
	_update_edges()
func select(id:String,animate:bool=true) -> void:
	if not _positions.has(id):return
	_selected=id
	Page.clear(_shell.body)
	var cfg:=TableCache.main_world_map(id)
	var row:Dictionary={}
	for entry in _rows:
		if String(entry.id)==id:row=entry;break
	var head_row:=HBoxContainer.new()
	head_row.add_theme_constant_override("separation",8)
	_shell.body.add_child(head_row)
	var title_box:=VBoxContainer.new()
	title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation",2)
	head_row.add_child(title_box)
	var badges:Array=_nodes[id].quest_badges if _nodes.has(id) else []
	var badge_suffix:="" if badges.is_empty() else "  ["+" · ".join(PackedStringArray(badges))+"]"
	title_box.add_child(Flow.text(String(row.get("name",id))+badge_suffix,"object"))
	var visited_tag:=" · 已探索" if (_nodes.has(id) and _nodes[id].visited) else " · 未踏足"
	title_box.add_child(Flow.text("Lv%d–%d · %s%s"%[row.get("level",[1,12])[0],row.get("level",[1,12])[1],"当前位置" if id==_current else "路线可达" if _reachable.has(id) else "条件受限" if _nodes[id].condition else "锁定",visited_tag],"caption",UI.AGED))
	var j_status:=Journey.status(G,id)
	if id!=_current:
		var can_travel:=bool(j_status.get("ok",false))
		var btn_text:="乘驿车前往" if can_travel else "暂不可乘车"
		_travel_button=Flow.button(btn_text,func():_on_travel_pressed(id))
		_travel_button.name="TravelToRegionButton"
		_travel_button.custom_minimum_size=Vector2(132,42)
		_travel_button.disabled=not can_travel
		_travel_button.caption.add_theme_font_size_override("font_size",G.FS_XS)
		head_row.add_child(_travel_button)
	else:
		var j_btn:=Flow.button("驿路与传世",_open_journey_modal)
		j_btn.name="OpenJourneyPanelButton"
		j_btn.custom_minimum_size=Vector2(132,42)
		j_btn.caption.add_theme_font_size_override("font_size",G.FS_XS)
		head_row.add_child(j_btn)
	var travel_line:="驿路已通：可点击右上「乘驿车前往」直达，或沿相邻路牌步行。" if bool(j_status.get("ok",false)) and id!=_current else (String(j_status.get("line","沿相邻路牌步行前往")) if id!=_current else "点击右上「驿路与传世」可打开驿站列表与传世首领挑战。")
	var note:=String(cfg.get("goal","沿道路探索"))+"\n"+(String(_reasons.get(id,"沿相邻路牌步行前往")) if not _reachable.has(id) else travel_line)
	if id=="lorin_wilds":note+="\n界碑历练从巡界厅进入。"
	if id in ["broken_slope","stele_cavern"] and G.prog.get("flags",{}).get("act1_stele_repaired",false):note+="\n图志新录 · "+G.restored_stele_name()
	_shell.body.add_child(Flow.text(note,"caption",UI.AGED))
	for key in _nodes:_nodes[key].selected=key==id;_nodes[key].queue_redraw()
	_graph.queue_redraw()
	_velocity=Vector2.ZERO
	var target:=_bounded(Vector2(_map.size.x*.5,_map.size.y*.42)-_positions[id]*_zoom)
	if _center_tween!=null and _center_tween.is_valid():_center_tween.kill()
	if animate:_center_tween=create_tween();_center_tween.tween_property(_graph,"position",target,.24).set_trans(Tween.TRANS_QUAD)
	else:_graph.position=target
func _on_travel_pressed(id:String) -> void:
	if not G.can_go("res://src/explore/MapScene.tscn"):return
	var res:=Journey.travel(G,id)
	if bool(res.get("ok",false)):
		Audio.sfx("ui_confirm")
		closed.emit()
		G.enter_main_world(id)
	else:
		Audio.sfx("ui_locked")
		UI.toast(self,String(res.get("line","暂不可前往")))
func _open_journey_modal() -> void:
	var jp:Control=preload("res://src/ui/JourneyPanel.gd").new()
	add_child(jp)
	jp.travel_requested.connect(func(map_id:String):
		if not G.can_go("res://src/explore/MapScene.tscn"):return
		var res:=Journey.travel(G,map_id)
		if bool(res.get("ok",false)):
			Audio.sfx("ui_confirm")
			jp.queue_free()
			closed.emit()
			G.enter_main_world(map_id)
		else:
			jp.show_message(String(res.get("line","暂不可前往"))))
func toggle_zoom() -> void:
	_zoom=1.0 if _zoom<1 else .5
	_apply_zoom();select(_selected,false)
func _apply_zoom() -> void:
	_graph.scale=Vector2.ONE*_zoom
	if _zoom_button!=null:_zoom_button.caption.text="详图" if _zoom<1 else "全览"
	for id in _nodes:
		var node=_nodes[id];node.scale=Vector2.ONE/_zoom;node.position=_positions[id]-Vector2(48,24)/_zoom;node.overview=_zoom<1;node.queue_redraw()
func _bounded(at:Vector2) -> Vector2:
	var low:=_map.size-(_bounds.end.min(_graph.size))*_zoom
	var high:=-( _bounds.position.max(Vector2.ZERO))*_zoom
	return Vector2(clampf(at.x,minf(low.x,high.x),maxf(low.x,high.x)),clampf(at.y,minf(low.y,high.y),maxf(low.y,high.y)))
func _clamp() -> void:_graph.position=_bounded(_graph.position)

func _drag(e:InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		if e.pressed and e.double_click:
			toggle_zoom();_dragging=false;return
		_dragging=e.pressed
		_last=e.position
		if e.pressed:_press=e.position;_moved=false;_velocity=Vector2.ZERO
		if _center_tween!=null and _center_tween.is_valid():_center_tween.kill()
	elif e is InputEventMouseMotion and _dragging:
		var delta:Vector2=e.position-_last
		_last=e.position
		_moved=_moved or e.position.distance_to(_press)>6
		_graph.position+=delta
		_velocity=delta*30
		_clamp()
	elif e is InputEventScreenTouch:
		_dragging=e.pressed;_last=e.position
		if e.pressed:_press=e.position;_moved=false;_velocity=Vector2.ZERO
	elif e is InputEventScreenDrag and _dragging:_moved=true;_graph.position+=e.relative;_velocity=e.relative*30;_clamp()
func _process(delta:float) -> void:
	_update_edges()
	if not _dragging and _velocity.length()>1:
		_graph.position+=_velocity*delta
		_velocity=_velocity.move_toward(Vector2.ZERO,1400*delta)
		_clamp()

func _update_edges() -> void:
	if _edge_tags==null:return
	var adjacent:Array[String]=[]
	for route in _routes:
		var id:=String(route.to) if String(route.from)==_current else String(route.from) if String(route.to)==_current else ""
		if not id.is_empty() and not adjacent.has(id):adjacent.append(id)
	var desired:Dictionary={}
	for id in adjacent:
		var point:Vector2=_positions[id]*_zoom+_graph.position
		if Rect2(Vector2(24,24),_map.size-Vector2(48,48)).has_point(point):continue
		desired[id]=point
	for child in _edge_tags.get_children():
		if not desired.has(String(child.get_meta("map_id",""))):child.queue_free()
	for id in desired:
		var button:Button=null
		for child in _edge_tags.get_children():
			if not child.is_queued_for_deletion() and child.get_meta("map_id","")==id:button=child;break
		if button==null:
			var target:String=id
			button=Flow.button("",func():select(target));button.set_meta("map_id",id);button.caption.add_theme_font_size_override("font_size",G.FS_XS);_edge_tags.add_child(button)
		var point:Vector2=desired[id]
		var arrow:="←" if point.x<24 else "→" if point.x>_map.size.x-24 else "↑" if point.y<24 else "↓"
		button.caption.text=arrow+" "+String(TableCache.main_world_map(id).get("name",id))
		Page.place(button,(point-Vector2(48,16)).clamp(Vector2(8,48),_map.size-Vector2(104,48)),Vector2(96,44))

class _MapNode extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Flow=preload("res://src/ui/FlowChestUI.gd")
	var words:=""
	var levels:=""
	var marker:=""
	var current:=false
	var visited:=false
	var selected:=false
	var reachable:=true
	var condition:=false
	var overview:=false
	var quest_badges:Array[String]=[]
	var name_l:Label
	var lv:Label
	func _ready() -> void:
		for s in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(s,StyleBoxEmpty.new())
		for event in [resized,focus_entered,focus_exited,mouse_entered,mouse_exited]:event.connect(queue_redraw)
		name_l=UI.label(words,"caption")
		name_l.position=Vector2(6,49)
		name_l.size=Vector2(84,22)
		name_l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_l)
		lv=UI.label(levels,"tag",UI.AGED)
		lv.position=Vector2(6,65)
		lv.size=Vector2(84,22)
		lv.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		add_child(lv)
	func _draw() -> void:
		var tex:=Flow.texture(marker)
		name_l.add_theme_font_size_override("font_size",G.FS_XS)
		name_l.add_theme_color_override("font_color",UI.ASH if not reachable and not condition else UI.PAPER)
		lv.visible=not overview or current or selected
		name_l.position.y=42 if overview else 49
		lv.position.y=60 if overview else 65
		if current:
			var pool:=preload("res://src/ui/TravelChestUI.gd").texture("stage_pool")
			if pool!=null:draw_texture_rect(pool,Rect2(0,28,96,24),false,Color(1,1,1,.25))
		if tex!=null:draw_texture_rect(tex,Rect2(32,8,32,32) if overview else Rect2(24,0,48,48),false,Color.WHITE if reachable or condition else Color(.35,.35,.35))
		UI.surface(self,Rect2(6,42 if overview else 48,84,38 if lv.visible else 22),Color("17141a",.85),UI.COPPER if current else UI.BRONZE)
		if not reachable and not condition:
			draw_rect(Rect2(9,53,8,7),UI.AGED);draw_arc(Vector2(13,53),3,PI,TAU,12,UI.AGED,1)
		if condition:
			draw_rect(Rect2(6,42 if overview else 51,4,22),UI.RED)
			draw_rect(Rect2(10,44 if overview else 52,12,12),UI.RED,false,2)
			draw_line(Vector2(13,48 if overview else 56),Vector2(19,48 if overview else 56),UI.RED,1)
			draw_line(Vector2(16,46 if overview else 54),Vector2(16,54 if overview else 62),UI.RED,1)
		if selected:draw_arc(Vector2(48,24),29,0,TAU,48,UI.GOLD,2,true)
		if current:draw_line(Vector2(20,0),Vector2(20,30),UI.GOLD,2);draw_colored_polygon(PackedVector2Array([Vector2(20,0),Vector2(32,4),Vector2(20,8)]),UI.GOLD)
		elif visited:
			draw_circle(Vector2(76,12),4.5,Color("17141a",.85))
			draw_circle(Vector2(76,12),3.0,Color("7cd49b"))
		if not quest_badges.is_empty():
			var is_story:=quest_badges.has("主线")
			var badge_col:=UI.GOLD if is_story else Color("6bc1ff")
			draw_circle(Vector2(76,26),7.5,Color("17141a",.92))
			draw_arc(Vector2(76,26),7.5,0,TAU,16,badge_col,1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(76,20.5),Vector2(81.5,26),Vector2(76,31.5),Vector2(70.5,26)]),badge_col)

class _MapBorder extends Control:
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		for i in 24:
			var color:=Color("17141a",.6*(1-float(i)/24))
			draw_rect(Rect2(i,0,1,size.y),color);draw_rect(Rect2(size.x-i-1,0,1,size.y),color)
			draw_rect(Rect2(0,i,size.x,1),color);draw_rect(Rect2(0,size.y-i-1,size.x,1),color)

class _MapGraph extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Flow=preload("res://src/ui/FlowChestUI.gd")
	const ART=preload("res://assets/ui/next_review_20261009/map.png")
	var map_ref:Control
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		draw_texture_rect(ART,Rect2(Vector2.ZERO,size),false,Color(.78,.78,.78))
		if map_ref==null:return
		var drawn:Dictionary={}
		for route in map_ref._routes:
			var a_id:=String(route.from)
			var b_id:=String(route.to)
			var pair_key:=a_id+"|"+b_id if a_id<b_id else b_id+"|"+a_id
			if drawn.has(pair_key):continue
			drawn[pair_key]=true
			if not map_ref._positions.has(a_id) or not map_ref._positions.has(b_id):continue
			var p1:Vector2=map_ref._positions[a_id]
			var p2:Vector2=map_ref._positions[b_id]
			var open:bool=map_ref._reachable.has(a_id) and map_ref._reachable.has(b_id)
			var active_edge:bool=(a_id==map_ref._current or b_id==map_ref._current) and (a_id==map_ref._selected or b_id==map_ref._selected)
			draw_line(p1,p2,Color("17141a",.65),6.0)
			draw_line(p1,p2,UI.GOLD if active_edge else (Color("e3c588",.78) if open else Color("8a7060",.45)),3.0 if active_edge else 2.0)

