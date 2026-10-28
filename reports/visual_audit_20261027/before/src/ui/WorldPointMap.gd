extends Control
## World-coordinate map with fixed-size touch markers and one destination record.
signal closed
signal destination_selected(id: String)
signal region_requested
var standalone := false
var live_map: Node = null
const Points := preload("res://src/world/WorldPoints.gd")
const View := preload("res://src/ui/ShowcaseUI.gd")
var map_id := "lorin_wilds"
var _frame: PanelContainer
var _canvas: MapCanvas
var _title: Label
var _note: Label
var _go: Button
var _cancel: Button
var _zoom_in: Button
var _zoom_out: Button
var _selected := ""
var _filter := "all"
var _picker: Control
var _picker_frame: PanelContainer
var _picker_count := 0
var _filter_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("safe_layout_exempt",true)
	var veil := ColorRect.new()
	veil.color = View.INK
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_frame = View.frame(14)
	add_child(_frame)
	var body := View.column(8)
	_frame.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",4)
	body.add_child(top)
	var heading:=View.text(String(TableCache.main_world_map(map_id).get("name",map_id)),"body",View.GOLD)
	heading.max_lines_visible=1
	heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(heading)
	_zoom_out=View.button("−")
	_zoom_out.name="ZoomOut"
	_zoom_in=View.button("＋")
	_zoom_in.name="ZoomIn"
	var locate:=View.button("定位")
	locate.name="LocatePlayer"
	for control in [_zoom_out,_zoom_in,locate]:
		control.custom_minimum_size=Vector2(44,44)
		control.add_theme_font_size_override("font_size",16)
		top.add_child(control)
	_zoom_out.tooltip_text="缩小地图"
	_zoom_in.tooltip_text="放大地图"
	locate.tooltip_text="回到我的位置"
	_zoom_out.pressed.connect(func():_canvas.set_zoom(_canvas.zoom/1.35);_sync_zoom())
	_zoom_in.pressed.connect(func():_canvas.set_zoom(_canvas.zoom*1.35);_sync_zoom())
	locate.pressed.connect(func():_canvas.locate_player();_sync_zoom())
	var filters:=GridContainer.new()
	filters.columns=3
	filters.add_theme_constant_override("h_separation",6)
	filters.add_theme_constant_override("v_separation",4)
	body.add_child(filters)
	for pair in [["all","全部"],["fishing","垂钓"],["shop","商店"],["station","驿站"],["npc","人物"],["landmark","设施"]]:
		var key: String = pair[0]
		var count:=0
		for point in Points.rows(map_id):
			if key=="all" or point.kind==key:count+=1
		var b := View.button("%s %d"%[pair[1],count])
		b.name="Filter_"+key
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size",15)
		b.custom_minimum_size=Vector2(44,44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(key==_filter)
		b.disabled=count==0
		b.tooltip_text="本区域没有此类地点" if count==0 else "显示"+String(pair[1])+"地点"
		b.pressed.connect(_set_filter.bind(key))
		filters.add_child(b)
		_filter_buttons[key]=b
	_canvas = MapCanvas.new()
	_canvas.map_id=map_id
	_canvas.live_map=live_map
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size.y = 96
	_canvas.point_selected.connect(select_point)
	_canvas.cluster_selected.connect(_choose_cluster)
	_canvas.zoom_changed.connect(_sync_zoom)
	body.add_child(_canvas)
	if G.ui_safe_rect(self).size.y>=720:body.add_child(View.text("拖动浏览 · 缩小看全图 · 北向朝上","tag",View.MUTED))
	_title = View.text("选择地点","section",View.GOLD)
	_title.max_lines_visible=1
	_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_title)
	_note = View.text("点击图标或地点列表选点，再设为目的地。","caption",View.MUTED)
	_note.max_lines_visible=2
	_note.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.custom_minimum_size.y = 44
	body.add_child(_note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	body.add_child(actions)
	_go = View.button("设为目的地",true)
	_go.name="TrackDestination"
	_go.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_go.disabled=true
	_go.pressed.connect(_track)
	actions.add_child(_go)
	_cancel=View.button("取消追踪")
	_cancel.name="CancelTracking"
	_cancel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(_cancel_tracking)
	actions.add_child(_cancel)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",8)
	body.add_child(navigation)
	var locations:=View.button("地点列表")
	locations.name="LocationList"
	locations.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	locations.pressed.connect(_show_locations)
	navigation.add_child(locations)
	if standalone:
		var overview := View.button("世界总览")
		overview.name="WorldOverview"
		overview.pressed.connect(func():region_requested.emit())
		overview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		navigation.add_child(overview)
	var back := View.button("返回探索" if standalone else "返回地区")
	back.name="ReturnFromMap"
	back.pressed.connect(func():closed.emit())
	back.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	navigation.add_child(back)
	for button in navigation.get_children():
		button.add_theme_font_size_override("font_size",15)
		button.custom_minimum_size=Vector2(44,48)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()
	_sync_zoom()
	_cancel.disabled=Points.target().is_empty()
	var target := Points.target()
	if not target.is_empty() and target.map==map_id:select_point(String(target.id))

func layout() -> void:
	var safe := G.ui_safe_rect(self)
	_frame.size=Vector2(minf(680,safe.size.x-16),safe.size.y-16)
	_frame.position=safe.get_center()-_frame.size*.5
	_layout_picker()

func select_point(id: String) -> void:
	var point := Points.find(id)
	if point.is_empty() or point.map!=map_id:return
	_selected=id
	_canvas.selected=id
	_canvas.update_route(point)
	_canvas.queue_redraw()
	_title.text=String(point.name)
	var state := Points.status(point)
	_note.text=String(Points.LABELS.get(point.kind,"地点"))+" · "+state
	if point.kind=="fishing":
		var fishing := G.fishing_spot(String(point.entity))
		_note.text+="\n"+String(fishing.get("fish_name",""))+" · 今日余 %d 竿"%G.fishing_remaining(String(point.entity))
	_go.disabled=state!="可前往"
	_go.text="设为目的地" if _go.disabled==false else "当前不可前往"
	if String(Points.target().get("id",""))==id:
		_go.text="正在追踪"
		_go.disabled=true
	_cancel.disabled=Points.target().is_empty()

func _sync_zoom() -> void:
	_zoom_out.disabled=_canvas.zoom<=_canvas.overview_zoom()+.001
	_zoom_in.disabled=_canvas.zoom>=2.999

func _set_filter(key: String) -> void:
	_filter=key
	_canvas.filter=key
	for item in _filter_buttons:_filter_buttons[item].set_pressed_no_signal(item==key)
	_canvas.queue_redraw()
	var selected:=Points.find(_selected)
	if not selected.is_empty() and key!="all" and selected.kind!=key:
		_selected=""
		_canvas.selected=""
		_go.disabled=true
		_go.text="设为目的地"
		_title.text="选择地点"
		_note.text="点击图标或地点列表，选择本分类的地点。"

func _show_locations() -> void:
	var ids: Array=[]
	for point in Points.rows(map_id):
		if _filter=="all" or point.kind==_filter:ids.append(String(point.id))
	_choose_cluster(ids)

func _cancel_tracking() -> void:
	if Points.cancel():
		_cancel.disabled=true
		if not _selected.is_empty():select_point(_selected)
		_note.text="追踪已取消，可重新选择目的地。"
		_canvas.queue_redraw()
	else:_note.text="取消未能保存，请重试"

func _choose_cluster(ids: Array) -> void:
	_close_picker()
	_picker_count=ids.size()
	_picker=Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter=Control.MOUSE_FILTER_STOP
	_picker.z_index=30
	add_child(_picker)
	var veil := ColorRect.new()
	veil.color=Color(0,0,0,.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(veil)
	_picker_frame=View.frame(16)
	_picker.add_child(_picker_frame)
	var body := View.column(10)
	_picker_frame.add_child(body)
	var heading:=View.text("地点列表 · %d"%ids.size(),"section",View.GOLD)
	heading.autowrap_mode=TextServer.AUTOWRAP_OFF
	heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(heading)
	var hint:=View.text("请选择具体地点查看。","caption",View.MUTED)
	hint.max_lines_visible=2
	body.add_child(hint)
	var scroll := View.scroll()
	body.add_child(scroll)
	var list := View.column(8)
	scroll.add_child(list)
	for value in ids:
		var id := String(value)
		var point := Points.find(id)
		var choice := View.button(String(point.name))
		choice.tooltip_text=String(point.name)
		choice.set_meta("point_id",id)
		choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		choice.clip_text=true
		choice.pressed.connect(func():_close_picker();select_point(id))
		list.add_child(choice)
	var back := View.button("返回地图")
	back.pressed.connect(_close_picker)
	body.add_child(back)
	_layout_picker()
	if list.get_child_count()>0:list.get_child(0).grab_focus()

func _layout_picker() -> void:
	if not is_instance_valid(_picker_frame):return
	var safe := G.ui_safe_rect(self)
	_picker_frame.size=Vector2(minf(420,safe.size.x-28),minf(safe.size.y-32,176+_picker_count*60))
	_picker_frame.position=safe.get_center()-_picker_frame.size*.5

func _close_picker() -> void:
	if is_instance_valid(_picker):
		remove_child(_picker)
		_picker.queue_free()
	_picker=null
	_picker_frame=null

func _track() -> void:
	var result := Points.track(_selected)
	_note.text=String(result.get("line",""))
	if bool(result.get("ok",false)):
		_go.text="正在追踪"
		_go.disabled=true
		_cancel.disabled=false
		_canvas.queue_redraw()
		Audio.sfx("ui_confirm")
		destination_selected.emit(_selected)

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_picker):_close_picker()
		else:closed.emit()
		get_viewport().set_input_as_handled()

class MapCanvas extends Control:
	signal point_selected(id: String)
	signal cluster_selected(ids: Array)
	signal zoom_changed
	const Points = preload("res://src/world/WorldPoints.gd")
	const View = preload("res://src/ui/ShowcaseUI.gd")
	var map_id := ""
	var selected := ""
	var filter := "all"
	var _main_cfg: Dictionary = {}
	var _main_map_id := ""
	var _city_content: Node = null
	var live_map: Node = null
	var route_points := PackedVector2Array()
	var extent := Vector2.ONE
	var zoom := 1.0
	var pan := Vector2.ZERO
	var press := Vector2.ZERO
	var last := Vector2.ZERO
	var dragging := false
	var moved := false
	var pointer := -2
	var texture: Texture2D
	var points: Array[Dictionary] = []
	var scenery: Array[Dictionary] = []
	var _camera_ready := false
	const KIND_COLORS := {"shop":Color("edbf69"),"station":Color("9fb9e5"),"fishing":Color("8cd9e5"),"npc":Color("93ccac"),"landmark":Color("eadbc0")}
	func _ready() -> void:
		clip_contents=true
		mouse_filter=Control.MOUSE_FILTER_STOP
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_main_cfg=TableCache.main_world_map(map_id)
		_main_map_id=map_id
		extent=Vector2(float(_main_cfg.get("map_cols",20))*48,float(_main_cfg.get("map_rows",26))*48)
		points=Points.rows(map_id)
		if ReferenceWorldArt.active(map_id):texture=ReferenceWorldArt.texture(map_id+"_floor")
		elif not String(_main_cfg.get("background","")).is_empty():texture=G.visual_texture(preload("res://src/world/WorldPresentation.gd").background_path(String(_main_cfg.background)))
		if texture==null:texture=preload("res://src/explore/MinimapCartography.gd").new().terrain_thumbnail(self)
		_load_scenery()
		resized.connect(_resize_camera)
		_resize_camera.call_deferred()
	func overview_zoom() -> float:
		return clampf((size.y/extent.y)/maxf(.001,size.x/extent.x),.05,1.0)
	func _resize_camera() -> void:
		if size.x<1 or size.y<1:return
		zoom=maxf(overview_zoom(),zoom)
		if not _camera_ready:
			_camera_ready=true
			var at:=player_at()
			if at==Vector2.INF:at=extent*.5
			pan=(extent*.5-at)*_scale()
		_clamp_pan()
		zoom_changed.emit()
		queue_redraw()
	func _load_scenery() -> void:
		for id in _main_cfg.get("city_building_positions",{}):
			var at: Array=_main_cfg.city_building_positions[id]
			var dimensions: Array=_main_cfg.get("city_building_sizes",{}).get(id,[240,180])
			var path:=ReferenceWorldArt.ROOT+("ledger" if id=="gate" else String(id))+".png" if ReferenceWorldArt.active(map_id) else "res://image/main_world/city_%s_reference_v2.png"%String(id)
			var art: Texture2D=G.visual_texture(path) if ResourceLoader.exists(path) else null
			scenery.append({"at":Vector2(at[0],at[1]),"size":Vector2(dimensions[0],dimensions[1])*preload("res://src/world/WorldPresentation.gd").BUILDING_ENLARGEMENT,"art":art})
		for row in _main_cfg.get("illustrated_scenery",[]):
			var art: Texture2D=G.visual_texture(String(row.texture))
			scenery.append({"at":Vector2(row.at[0],row.at[1]),"size":Vector2(row.size[0],row.size[1]),"art":art})
		for row in _main_cfg.get("reference_scenery",[]):
			var group:=String(row.get("group","foliage"))
			scenery.append({"at":Vector2(row.at[0],row.at[1]),"size":ReferenceWorldArt.dimensions(group,String(row.id)),"art":ReferenceWorldArt.texture(String(row.id))})
		scenery.sort_custom(func(a,b):return a.at.y<b.at.y)
	func update_route(point: Dictionary) -> void:
		route_points.clear()
		# The exploration navigator still finds a path; the map shows markers only.
	func _map_extent() -> Vector2:return extent
	func toggle_zoom() -> void:
		set_zoom(1.0 if zoom>1.1 else 1.8)
	func set_zoom(value: float,anchor := Vector2(-1,-1)) -> void:
		if anchor.x<0:anchor=size*.5
		var world_at: Vector2=(anchor-_rect().position)/_scale()
		zoom=clampf(value,overview_zoom(),3)
		pan=anchor-(size-extent*_scale())*.5-world_at*_scale()
		_clamp_pan()
		zoom_changed.emit()
		queue_redraw()
	func player_at() -> Vector2:
		if is_instance_valid(live_map) and String(live_map._main_map_id)==map_id:return live_map._player.position
		var state: Dictionary=G.prog.get("main_world",{})
		if String(state.get("map_id","lorin_wilds"))!=map_id:return Vector2.INF
		var saved: Array=state.get("position",_main_cfg.get("spawn",[480,900]))
		return Vector2(saved[0],saved[1]) if saved.size()>=2 else Vector2.INF
	func locate_player() -> void:
		var at:=player_at()
		if at==Vector2.INF:at=extent*.5
		zoom=maxf(1.8,zoom)
		pan=(extent*.5-at)*_scale()
		_clamp_pan()
		zoom_changed.emit()
		queue_redraw()
	func _scale() -> float:return maxf(.001,size.x/extent.x)*zoom
	func _rect() -> Rect2:
		var dimensions := extent*_scale()
		return Rect2((size-dimensions)*.5+pan,dimensions)
	func screen_at(at: Vector2) -> Vector2:return _rect().position+at*_scale()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				set_zoom(zoom*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .87),event.position)
			elif event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:_begin(event.position,-1)
				elif pointer==-1:_end(event.position)
		elif event is InputEventMouseMotion and pointer==-1:_drag(event.position)
		elif event is InputEventScreenTouch:
			if event.pressed:_begin(event.position,event.index)
			elif event.index==pointer:_end(event.position)
		elif event is InputEventScreenDrag and event.index==pointer:_drag(event.position)
		accept_event()
	func _begin(at: Vector2,id: int) -> void:
		if pointer!=-2:return
		pointer=id
		press=at
		last=at
		moved=false
	func _drag(at: Vector2) -> void:
		moved=moved or at.distance_to(press)>8
		if moved:pan+=at-last
		last=at
		_clamp_pan()
		queue_redraw()
	func _markers() -> Array[Dictionary]:
		var groups: Array[Dictionary] = []
		for point in points:
			if filter!="all" and point.kind!=filter:continue
			var at := screen_at(Points.position(point))
			var merged := false
			for group in groups:
				if String(group.kind)==String(point.kind) and at.distance_to(group.at)<(54 if point.kind=="npc" else 34):
					var count: int=group.ids.size()
					group.at=(group.at*count+at)/(count+1)
					group.ids.append(String(point.id))
					merged=true
					break
			if not merged:groups.append({"at":at,"ids":[String(point.id)],"kind":String(point.kind)})
		var occupied: Array[Vector2]=[]
		var player:=player_at()
		if player!=Vector2.INF:occupied.append(screen_at(player))
		var visible: Array[Dictionary]=[]
		for group in groups:
			var original: Vector2=group.at
			if not Rect2(Vector2(16,28),size-Vector2(32,44)).has_point(original):continue
			for offset in [Vector2.ZERO,Vector2(28,0),Vector2(-28,0),Vector2(0,32),Vector2(0,-32),Vector2(28,32),Vector2(-28,-32)]:
				var proposed: Vector2=original+offset
				if not occupied.any(func(p):return p.distance_to(proposed)<32):group.at=proposed;break
			occupied.append(group.at)
			visible.append(group)
		visible.sort_custom(func(a,b):return ["shop","station","fishing","landmark","npc"].find(a.kind)<["shop","station","fishing","landmark","npc"].find(b.kind))
		return visible
	func _end(at: Vector2) -> void:
		pointer=-2
		if moved:return
		var closest := 25.0
		var picked: Dictionary={}
		for marker in _markers():
			var distance := at.distance_to(marker.at)
			if distance<closest:
				closest=distance
				picked=marker
		if picked.is_empty():return
		if picked.ids.size()>1:cluster_selected.emit(picked.ids)
		else:point_selected.emit(String(picked.ids[0]))
	func _clamp_pan() -> void:
		var overflow := (extent*_scale()-size).max(Vector2.ZERO)*.5
		pan=pan.clamp(-overflow,overflow)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("14171c"))
		if texture!=null:draw_texture_rect(texture,_rect(),false,Color(.70,.72,.68))
		for prop in scenery:
			var dimensions: Vector2=prop.size*_scale()
			var rect:=Rect2(screen_at(prop.at)-Vector2(dimensions.x*.5,dimensions.y),dimensions)
			if prop.art!=null:draw_texture_rect(prop.art,rect,false,Color(.85,.86,.81))
			else:
				draw_rect(rect,Color("382f29"))
				draw_rect(rect,Color("bda073"),false,1)
		for exit in _main_cfg.get("exits",[]):
			var at: Array=exit.get("sign_at",exit.get("at",[]))
			if at.size()<2:continue
			var p := screen_at(Vector2(at[0],at[1]))
			draw_circle(p,5,View.JADE if Points.gate_reason(exit).is_empty() else View.MUTED)
		var target := Points.target()
		var label_rects: Array[Rect2]=[]
		var markers:=_markers()
		var icon_rects: Array[Rect2]=[]
		for marker in markers:icon_rects.append(Rect2(marker.at-Vector2(18,18),Vector2(36,36)))
		var player_point:=player_at()
		if player_point!=Vector2.INF:icon_rects.append(Rect2(screen_at(player_point)-Vector2(15,15),Vector2(30,30)))
		for marker in markers:
			var p: Vector2=marker.at
			var active: bool=marker.ids.has(selected) or (not target.is_empty() and marker.ids.has(String(target.id)))
			if not Rect2(Vector2(-24,-24),size+Vector2(48,48)).has_point(p):continue
			var tint: Color=KIND_COLORS.get(String(marker.kind),View.GOLD)
			draw_circle(p,16,Color("15171d",.97))
			draw_arc(p,16,0,TAU,32,View.GOLD if active else tint,2,true)
			var point := Points.find(String(marker.ids[0]))
			var icon := Points.icon(String(marker.kind))
			if icon!=null:draw_texture_rect(icon,Rect2(p-Vector2(10,10),Vector2(20,20)),false)
			if marker.ids.size()>1:
				draw_circle(p+Vector2(13,-12),8,tint)
				draw_string(G.font_bold,p+Vector2(9,-8),str(marker.ids.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,11,View.INK)
			var words:=String(point.name).split("·")[0].strip_edges().left(6) if marker.ids.size()==1 else String(Points.LABELS.get(marker.kind,"地点"))+"·%d"%marker.ids.size()
			if active:draw_arc(p,20,0,TAU,32,View.GOLD,1,true)
			if marker.kind=="npc" and filter=="all" and zoom<1.5 and not active:continue
			var width:=G.font_bold.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
			var label_rect:=Rect2(Vector2(clampf(p.x-width*.5,3,maxf(3,size.x-width-3)),p.y+19),Vector2(width,21))
			for offset in [Vector2.ZERO,Vector2(0,-58),Vector2(width*.5+22,-29),Vector2(-width*.5-22,-29),Vector2(0,24),Vector2(0,-82)]:
				var candidate:=Rect2(label_rect.position+offset,label_rect.size)
				if Rect2(Vector2(2,26),size-Vector2(4,30)).encloses(candidate) and not label_rects.any(func(r):return r.grow(2).intersects(candidate)) and not icon_rects.any(func(r):return r.intersects(candidate)):
					label_rect=candidate
					label_rects.append(label_rect)
					draw_rect(label_rect,Color("14141a",.94))
					draw_rect(label_rect,Color(tint,.65),false,1)
					draw_string(G.font_bold,label_rect.position+Vector2(6,15),words,HORIZONTAL_ALIGNMENT_LEFT,-1,12,tint)
					break
		var player:=player_at()
		if player!=Vector2.INF:
			var p:=screen_at(player)
			draw_circle(p,12,Color("0c191f"))
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(6,7),p,p+Vector2(-6,7)]),View.GOLD)
		draw_string(G.font_bold,Vector2(size.x-26,22),"北",HORIZONTAL_ALIGNMENT_LEFT,-1,16,View.GOLD)
		draw_string(G.font_bold,Vector2(10,22),"%.1f×"%zoom,HORIZONTAL_ALIGNMENT_LEFT,-1,14,View.GOLD)
