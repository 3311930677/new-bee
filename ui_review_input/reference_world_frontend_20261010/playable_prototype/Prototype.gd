extends Node2D
const EXTENT:=Vector2(512,1067)
const ZOOMS:=[1.0,1.15,1.25]
var asset_root:String
var world:Node2D
var actor:CharacterBody2D
var actor_art:AnimatedSprite2D
var camera:Camera2D
var label:Label
var hint:Label
var trees:Array=[]
var obstacles:Array=[]
var hall:StaticBody2D
var mode:="field"
var zoom_index:=1
var movement_override:=Vector2.ZERO
var target:=Vector2.INF
var debug_shapes:=false
var textures:Dictionary={}
var hero_frames:SpriteFrames
var test_mode:=false
var direction:="down"
var world_extent:=EXTENT
var neighborhood:Dictionary={}
var buildings:Array=[]
var interactables:Array=[]
var exit_marker:Node2D
var exit_plate:Label
var interaction_focus:Dictionary={}
var interaction_button:Button
var travel_log:Array=[]
func texture(path:String)->Texture2D:
	if not textures.has(path):
		var image:=Image.load_from_file(path)
		assert(image!=null,path)
		textures[path]=ImageTexture.create_from_image(image)
	return textures[path]
func _ready()->void:
	asset_root=ProjectSettings.globalize_path("res://../../../远征/assets/world/reference_playable_20261010/ready/")
	test_mode="--capture" in OS.get_cmdline_user_args()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	build_hero_frames()
	build_hud()
	neighborhood=JSON.parse_string(FileAccess.get_file_as_string("res://town_neighborhood_layout.json"))
	switch_map("field" if test_mode else "neighborhood")
	if test_mode:
		call_deferred("run_checks")
func build_hero_frames()->void:
	hero_frames=SpriteFrames.new()
	hero_frames.remove_animation("default")
	var role_root:=ProjectSettings.globalize_path("res://../../../远征/image/role/zs/")
	var idle:=texture(role_root+"pojun_idle_video_v19.png")
	var walk:=texture(role_root+"pojun_walk_video_v19.png")
	var ids:=["down","left","right","up"]
	var counts:=[24,30,28,27]
	for row in 4:
		var id:String=ids[row]
		hero_frames.add_animation("idle_"+id)
		hero_frames.set_animation_loop("idle_"+id,false)
		var at:=AtlasTexture.new()
		at.atlas=idle
		at.region=Rect2(row*128,0,128,128)
		hero_frames.add_frame("idle_"+id,at)
		hero_frames.add_animation("walk_"+id)
		hero_frames.set_animation_speed("walk_"+id,24)
		for i in counts[row]:
			var frame:=AtlasTexture.new()
			frame.atlas=walk
			frame.region=Rect2(i*128,row*128,128,128)
			hero_frames.add_frame("walk_"+id,frame)
func build_hud()->void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme:=Theme.new()
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	theme.default_font=font
	theme.default_font_size=16
	root.theme=theme
	var header:=PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom=74
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("2b241de0")
	style.border_color=Color("a18348")
	style.border_width_bottom=2
	header.add_theme_stylebox_override("panel",style)
	root.add_child(header)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	header.add_child(margin)
	label=Label.new()
	label.add_theme_color_override("font_color",Color("eee2c6"))
	margin.add_child(label)
	var footer:=PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top=-116
	footer.add_theme_stylebox_override("panel",style)
	root.add_child(footer)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	footer.add_child(box)
	hint=Label.new()
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.text="方向键 / WASD 移动 · 点击地面行走 · E 进入"
	hint.add_theme_color_override("font_color",Color("eee2c6"))
	box.add_child(hint)
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",8)
	box.add_child(row)
	for title in ["切换场景","视距","长屏","交互","碰撞"]:
		var button:=Button.new()
		button.text=title
		button.custom_minimum_size=Vector2(104 if title=="切换场景" else 72,42)
		row.add_child(button)
		match title:
			"切换场景":button.pressed.connect(cycle_map)
			"视距":button.pressed.connect(cycle_zoom)
			"长屏":button.pressed.connect(toggle_tall)
			"交互":
				interaction_button=button
				button.pressed.connect(activate_interaction)
			"碰撞":button.pressed.connect(func():debug_shapes=not debug_shapes;queue_redraw())
func switch_map(next_mode:String)->void:
	mode=next_mode
	trees.clear()
	obstacles.clear()
	buildings.clear()
	interactables.clear()
	exit_marker=null
	exit_plate=null
	interaction_focus={}
	hall=null
	target=Vector2.INF
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world=Node2D.new()
	world.y_sort_enabled=true
	add_child(world)
	world_extent=Vector2(neighborhood.world_size[0],neighborhood.world_size[1]) if mode=="neighborhood" else EXTENT
	if mode=="neighborhood":
		buildings=preload("res://Neighborhood.gd").build(self,neighborhood)
	else:
		build_local_world()
	for wall_spec in [
		[Vector2(-12,world_extent.y*.5),Vector2(24,world_extent.y+96)],
		[Vector2(world_extent.x+12,world_extent.y*.5),Vector2(24,world_extent.y+96)],
		[Vector2(world_extent.x*.5,-12),Vector2(world_extent.x+96,24)],
		[Vector2(world_extent.x*.5,world_extent.y+12),Vector2(world_extent.x+96,24)]]:
		static_rectangle(wall_spec[0],wall_spec[1],Vector2.ZERO)
	build_actor()
	queue_redraw()
func build_local_world()->void:
	var floor:=Sprite2D.new()
	floor.texture=texture(asset_root+("meadow" if mode=="field" else "plaza")+".png")
	floor.centered=false
	floor.z_index=-10
	world.add_child(floor)
	# Temporary mirrored edge continuation; production core remains 512x768 at 1:1 scale.
	var continuation:=Sprite2D.new()
	var continuation_texture:=AtlasTexture.new()
	continuation_texture.atlas=floor.texture
	continuation_texture.region=Rect2(0,469,512,299)
	continuation.texture=continuation_texture
	continuation.centered=false
	continuation.flip_v=true
	continuation.position=Vector2(0,768)
	continuation.z_index=-10
	world.add_child(continuation)
	if mode=="field":
		for p in [Vector2(92,220),Vector2(420,280),Vector2(80,510),Vector2(438,670)]:
			add_tree(p)
		for p in [Vector2(135,330),Vector2(407,435),Vector2(102,675)]:
			add_prop("bush",p,false)
		add_prop("rock",Vector2(414,550),true)
		add_prop("log",Vector2(95,410),true)
		preload("res://Neighborhood.gd").add_exit(self,neighborhood.prototype_field_exit,false)
	else:
		hall=static_rectangle(Vector2(256,325),Vector2(380,48),Vector2(0,-32))
		var visual:=Sprite2D.new()
		visual.texture=texture(asset_root+"hall.png")
		visual.position=Vector2(0,-float(visual.texture.get_height())*.5)
		hall.add_child(visual)
		add_tree(Vector2(424,493))
		add_tree(Vector2(83,650))
		add_prop("bush",Vector2(72,420),false)
		add_prop("bush",Vector2(451,619),false)
		add_prop("rock",Vector2(60,530),true)
func build_actor()->void:
	actor=CharacterBody2D.new()
	actor.collision_layer=2
	actor.collision_mask=1
	actor.position=Vector2(264,560) if mode=="field" else Vector2(258,441)
	if mode=="neighborhood":actor.position=Vector2(neighborhood.spawn[0],neighborhood.spawn[1])
	world.add_child(actor)
	var shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=10
	shape.shape=circle
	actor.add_child(shape)
	var shadow:=Polygon2D.new()
	var points:=PackedVector2Array()
	for i in 20:
		var angle:=TAU*float(i)/20.0
		points.append(Vector2(cos(angle)*15,sin(angle)*5))
	shadow.polygon=points
	shadow.color=Color(0.16,0.13,0.09,.35)
	actor.add_child(shadow)
	actor_art=AnimatedSprite2D.new()
	actor_art.sprite_frames=hero_frames
	actor_art.scale=Vector2.ONE*.65
	actor_art.position=Vector2(0,-37.05)
	actor.add_child(actor_art)
	actor_art.play("idle_down")
	camera=Camera2D.new()
	camera.zoom=Vector2.ONE*ZOOMS[zoom_index]
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=int(world_extent.x)
	camera.limit_bottom=int(world_extent.y)
	actor.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	queue_redraw()
func static_rectangle(at:Vector2,size:Vector2,offset:Vector2)->StaticBody2D:
	var body:=StaticBody2D.new()
	body.position=at
	world.add_child(body)
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=size
	shape.shape=rect
	shape.position=offset
	body.add_child(shape)
	obstacles.append({"position":at+offset,"size":size,"type":"rect"})
	return body
func add_tree(at:Vector2)->void:
	var body:=StaticBody2D.new()
	body.position=at
	world.add_child(body)
	var shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=14
	shape.shape=circle
	body.add_child(shape)
	obstacles.append({"position":at,"radius":14.0,"type":"circle"})
	var source:=texture(asset_root+"tree.png")
	var split:=144
	var crown_tex:=AtlasTexture.new()
	crown_tex.atlas=source
	crown_tex.region=Rect2(0,0,source.get_width(),split)
	crown_tex.filter_clip=true
	var crown:=Sprite2D.new()
	crown.texture=crown_tex
	crown.position=Vector2(0,-192+split*.5)
	body.add_child(crown)
	var trunk_tex:=AtlasTexture.new()
	trunk_tex.atlas=source
	trunk_tex.region=Rect2(0,split,source.get_width(),192-split)
	trunk_tex.filter_clip=true
	var trunk:=Sprite2D.new()
	trunk.texture=trunk_tex
	trunk.position=Vector2(0,-(192-split)*.5)
	body.add_child(trunk)
	trees.append({"root":body,"crown":crown,"trunk":trunk,"bounds":Rect2(-float(source.get_width())*.5,-192,source.get_width(),144)})
func add_prop(id:String,at:Vector2,solid:bool)->void:
	var body:Node2D
	if solid:
		body=static_rectangle(at,Vector2(48,16),Vector2(0,-8))
	else:
		body=Node2D.new()
		body.position=at
		world.add_child(body)
	var pic:=Sprite2D.new()
	pic.texture=texture(asset_root+id+".png")
	pic.position=Vector2(0,-float(pic.texture.get_height())*.5)
	body.add_child(pic)
func _physics_process(_delta:float)->void:
	if not is_instance_valid(actor):return
	var move:=movement_override if test_mode else Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if not test_mode and move.is_zero_approx() and target!=Vector2.INF:
		if actor.position.distance_to(target)<5:
			target=Vector2.INF
		else:
			move=actor.position.direction_to(target)
	if not move.is_zero_approx():
		if absf(move.x)>absf(move.y):direction="right" if move.x>0 else "left"
		else:direction="down" if move.y>0 else "up"
	actor.velocity=move.normalized()*135
	actor.move_and_slide()
	actor_art.play(("idle_" if move.is_zero_approx() else "walk_")+direction)
	interaction_focus=interaction_candidate(actor.position)
	interaction_button.disabled=interaction_focus.is_empty()
	for tree in trees:
		var relative:=actor.position-(tree.root as Node2D).position
		var fade:bool=tree.bounds.has_point(relative)
		(tree.crown as Sprite2D).modulate.a=.45 if fade else 1.0
	if is_instance_valid(label):
		label.text="%s · 二维可行走样板\n视距 %.2f　主角约 %.0f 屏幕像素" % ["草甸" if mode=="field" else "广场",ZOOMS[zoom_index],71.5*ZOOMS[zoom_index]]
	if mode=="town":
		hint.text="E：议事厅入口" if actor.position.distance_to(Vector2(256,343))<58 else "方向键 / WASD 移动 · 点击地面行走"
	elif mode=="neighborhood":
		label.text="左右建筑 · 草坪主路布局样板\n沿主路向北出城 · 人物与设施为点位占位"
		for record in buildings:
			var plate:=record.plate as Label
			var is_overview:=camera.zoom.x<1
			plate.text=String(record.data.name) if is_overview else String(record.data.name)+(" · 新素材" if record.data.id=="hall" else " · 尺寸占位")
			plate.add_theme_font_size_override("font_size",roundi(16.0/camera.zoom.x))
			plate.visible=is_overview or String(interaction_focus.get("id",""))==String(record.data.id)
			if record.data.id=="gate":
				var root_point:=Vector2(record.data.anchor[0],record.data.anchor[1])
				var in_passage:=absf(actor.position.x-root_point.x)<float(record.data.portal_width)*.5 and actor.position.y>root_point.y-float(record.data.size[1]) and actor.position.y<root_point.y
				(record.node as Node2D).modulate.a=.45 if in_passage else 1.0
		for record in interactables:
			(record.plate as Label).visible=String(interaction_focus.get("id",""))==String(record.data.id)
	if exit_plate!=null:
		exit_plate.add_theme_font_size_override("font_size",roundi(16.0/camera.zoom.x))
		exit_plate.visible=interaction_focus.get("type","")!="exit"
	if not interaction_focus.is_empty():
		hint.text="E / 交互："+String(interaction_focus.name)
	elif mode=="field":hint.text="沿路向南返回城镇 · 方向键 / WASD 移动"
	elif mode=="neighborhood":hint.text="沿路向北出城 · 靠近人物或门口后交互"
func _unhandled_input(event:InputEvent)->void:
	if test_mode:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		target=get_global_mouse_position()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:cycle_map()
			KEY_E:
				activate_interaction()
			KEY_EQUAL,KEY_MINUS:cycle_zoom()
func cycle_zoom()->void:
	zoom_index=(zoom_index+1)%ZOOMS.size()
	camera.zoom=Vector2.ONE*ZOOMS[zoom_index]
	camera.force_update_scroll()
func toggle_tall()->void:
	get_window().size=Vector2i(480,1067 if get_window().size.y==800 else 800)
func cycle_map()->void:
	var modes:=["field","neighborhood"]
	switch_map(modes[(modes.find(mode)+1)%modes.size()])
func interaction_candidate(at:Vector2)->Dictionary:
	var candidates:Array=[]
	if mode=="town":
		candidates.append({"id":"hall","name":"议事厅入口","type":"building","position":Vector2(256,343),"radius":58.0})
	else:
		var exit_data:Dictionary=neighborhood.exit if mode=="neighborhood" else neighborhood.prototype_field_exit
		candidates.append({"id":exit_data.id,"name":exit_data.label,"type":"exit","position":Vector2(exit_data.at[0],exit_data.at[1]),"radius":float(exit_data.radius),"data":exit_data})
	if mode=="neighborhood":
		for record in buildings:
			var b:Dictionary=record.data
			candidates.append({"id":b.id,"name":String(b.name)+("访客簿" if b.id=="gate" else "入口"),"type":"building","position":Vector2(b.approach[0],b.approach[1]),"radius":58.0})
		for record in interactables:
			var item:Dictionary=record.data
			candidates.append({"id":item.id,"name":item.name,"type":item.kind,"position":Vector2(item.position[0],item.position[1]),"radius":float(item.radius)})
	var best:Dictionary={}
	var best_distance:=INF
	for candidate:Dictionary in candidates:
		var distance:=at.distance_to(candidate.position)
		if distance<=candidate.radius and distance<best_distance:
			best=candidate
			best_distance=distance
	return best
func activate_interaction()->void:
	var chosen:=interaction_candidate(actor.position)
	if chosen.is_empty():return
	if chosen.type=="exit":
		travel_log.append({"id":chosen.id,"to":chosen.data.to,"arrival":chosen.data.arrival})
		if mode=="neighborhood":
			switch_map("field")
			actor.position=Vector2(neighborhood.prototype_field_arrival[0],neighborhood.prototype_field_arrival[1])
		else:
			switch_map("neighborhood")
			actor.position=Vector2(neighborhood.arrival_from_field[0],neighborhood.arrival_from_field[1])
		camera.force_update_scroll()
		return
	show_entry(String(chosen.name),String(chosen.type))
func show_entry(building_name:="议事厅",kind:="building")->void:
	var dialog:=AcceptDialog.new()
	dialog.title=building_name+"入口样板"
	dialog.dialog_text=("这里是人物对话位置示意。" if kind=="npc" else "这里是设施或物件交互位置示意。")+"\n本样板不改变正式游戏的任务或存档。"
	add_child(dialog)
	dialog.popup_centered(Vector2i(360,150))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
func _draw()->void:
	if not debug_shapes:return
	for item in obstacles:
		if item.type=="circle":draw_circle(item.position,item.radius,Color(1,.4,.2,.4))
		else:draw_rect(Rect2(item.position-item.size*.5,item.size),Color(1,.4,.2,.4))
func wait_frames(count:int)->void:
	for i in count:await get_tree().physics_frame
func snap(name:String)->void:
	await wait_frames(3)
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path("res://screenshots/"+name+".png")
	assert(get_viewport().get_texture().get_image().save_png(path)==OK)
func run_checks()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var results:Array=[]
	await wait_frames(4)
	var tree:Dictionary=trees[0]
	actor.position=tree.root.position+Vector2(0,48)
	movement_override=Vector2.UP
	await wait_frames(40)
	results.append({"test":"tree trunk blocks walking","pass":actor.position.distance_to(tree.root.position)>=23.0})
	movement_override=Vector2.ZERO
	actor.position=tree.root.position+Vector2(0,-85)
	await wait_frames(4)
	results.append({"test":"canopy fades while trunk stays opaque","pass":is_equal_approx(tree.crown.modulate.a,.45) and is_equal_approx(tree.trunk.modulate.a,1.0)})
	await snap("field_canopy_behind")
	actor.position=Vector2(264,560)
	direction="down"
	await wait_frames(3)
	results.append({"test":"canopy restores when actor leaves","pass":is_equal_approx(tree.crown.modulate.a,1.0)})
	await snap("field_front")
	for i in 3:
		zoom_index=i
		camera.zoom=Vector2.ONE*ZOOMS[i]
		camera.force_update_scroll()
		await snap("field_zoom_"+str(ZOOMS[i]).replace(".","_"))
		results.append({"test":"camera zoom "+str(ZOOMS[i]),"pass":absf(get_viewport().get_canvas_transform().x.length()-ZOOMS[i])<.001})
	zoom_index=1
	switch_map("town")
	await wait_frames(4)
	actor.position=Vector2(256,400)
	movement_override=Vector2.UP
	await wait_frames(45)
	movement_override=Vector2.ZERO
	results.append({"test":"hall facade blocks walking","pass":actor.position.y>=326.0})
	results.append({"test":"hall entry is reachable","pass":actor.position.distance_to(Vector2(256,343))<58.0})
	await snap("town_door")
	actor.position=Vector2(258,441)
	await snap("town_front")
	get_window().size=Vector2i(480,1067)
	await wait_frames(8)
	await snap("town_tall")
	results.append({"test":"tall viewport follows keep_width","pass":absf(get_viewport_rect().size.y-1067)<2})
	results.append({"test":"tall view fits painted world without blank margins","pass":get_viewport_rect().size.y/camera.zoom.y<=EXTENT.y})
	switch_map("field")
	await wait_frames(4)
	await snap("field_tall")
	actor.position=Vector2(256,30)
	movement_override=Vector2.UP
	await wait_frames(35)
	results.append({"test":"world edge blocks walking","pass":actor.position.y>=9})
	movement_override=Vector2.ZERO
	switch_map("neighborhood")
	get_window().size=Vector2i(480,800)
	await wait_frames(5)
	for record in buildings:
		var point:=Vector2(record.data.approach[0],record.data.approach[1])
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=(actor.get_child(0) as CollisionShape2D).shape
		query.transform=Transform2D(0,point)
		query.collision_mask=1
		results.append({"test":"neighborhood "+String(record.data.id)+" approach is physically clear","pass":get_world_2d().direct_space_state.intersect_shape(query).is_empty()})
	actor.position=Vector2(552,780)
	await snap("neighborhood_north_street")
	actor.position=Vector2(552,1120)
	await snap("neighborhood_hall_side_street")
	actor.position=Vector2(240,1260)
	await snap("neighborhood_hall_door")
	actor.position=Vector2(552,1650)
	await snap("neighborhood_south_quarter")
	actor.position=Vector2(world_extent.x*.5,1800)
	await snap("town_south_end")
	var south_floor:Node=world.get_child(0)
	results.append({"test":"natural painted ground matches current world extent","pass":south_floor.painted_ground!=null and south_floor.painted_ground.get_size()==world_extent})
	results.append({"test":"south road is configured to dissolve into grass before map edge","pass":neighborhood.south_ground.fade_end<world_extent.y and neighborhood.south_ground.fade_start>1700})
	get_window().size=Vector2i(480,1067)
	await snap("town_south_tall")
	get_window().size=Vector2i(480,800)
	for record in buildings:
		var point:=Vector2(record.data.approach[0],record.data.approach[1])
		results.append({"test":String(record.data.id)+" selects its original facility ID","pass":String(interaction_candidate(point).get("id",""))==String(record.data.id)})
	for record in interactables:
		var item:Dictionary=record.data
		var point:=Vector2(item.position[0],item.position[1])
		if item.kind=="npc":point.y+=36
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=(actor.get_child(0) as CollisionShape2D).shape
		query.transform=Transform2D(0,point)
		query.collision_mask=1
		results.append({"test":String(item.id)+" interaction stand is physically clear","pass":get_world_2d().direct_space_state.intersect_shape(query).is_empty()})
		results.append({"test":String(item.id)+" selects the matching original interaction ID","pass":String(interaction_candidate(point).get("id",""))==String(item.id)})
	var steward:Dictionary=interactables.filter(func(r):return r.data.id=="npc_steward")[0]
	actor.position=Vector2(steward.data.position[0],steward.data.position[1]+36)
	await snap("neighborhood_npc_interaction")
	activate_interaction()
	await wait_frames(2)
	var opened:=false
	for node in get_children():
		if node is AcceptDialog:
			opened=true
			node.queue_free()
	results.append({"test":"NPC interaction opens its sample dialog","pass":opened})
	actor.position=Vector2(neighborhood.exit.at[0]-64,neighborhood.exit.at[1]+225)
	movement_override=Vector2.UP
	await wait_frames(100)
	movement_override=Vector2.ZERO
	results.append({"test":"main road reaches roadside exit sign without a wall","pass":String(interaction_candidate(actor.position).get("id",""))=="north_gate"})
	results.append({"test":"exit has one sign and no gatehouse","pass":buildings.filter(func(r):return r.data.id=="gate").is_empty() and exit_marker.art!=null})
	await snap("neighborhood_north_exit")
	activate_interaction()
	await wait_frames(3)
	results.append({"test":"north exit opens field with original target and arrival","pass":mode=="field" and travel_log[-1].to=="maple_road" and travel_log[-1].arrival=="from_city"})
	await snap("field_after_city_exit")
	results.append({"test":"field arrival does not immediately return to town","pass":interaction_candidate(actor.position).is_empty()})
	movement_override=Vector2.DOWN
	await wait_frames(45)
	movement_override=Vector2.ZERO
	results.append({"test":"field south return is reachable","pass":String(interaction_candidate(actor.position).get("id",""))=="south_gate"})
	activate_interaction()
	await wait_frames(3)
	results.append({"test":"field return opens town with original arrival ID","pass":mode=="neighborhood" and travel_log[-1].to=="lorin_wilds" and travel_log[-1].arrival=="from_maple_road"})
	results.append({"test":"town return does not immediately send player back out","pass":String(interaction_candidate(actor.position).get("type",""))!="exit"})
	await snap("town_after_field_return")
	get_window().size=Vector2i(480,1067)
	camera.zoom=Vector2.ONE*(480.0/world_extent.x)
	actor.position=world_extent*.5
	camera.force_update_scroll()
	await snap("neighborhood_overview")
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(int(world_extent.x),int(world_extent.y))
	viewport.world_2d=get_world_2d()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://screenshots/neighborhood_plan.png")==OK)
	viewport.queue_free()
	var road_view:=SubViewport.new()
	road_view.size=Vector2i(int(world_extent.x),int(world_extent.y))
	road_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(road_view)
	var road_ground:=preload("res://Neighborhood.gd").GroundGuide.new()
	road_ground.geometry_only=true
	road_ground.layout=neighborhood
	road_view.add_child(road_ground)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(road_view.get_texture().get_image().save_png("res://screenshots/town_road_geometry_guide.png")==OK)
	road_view.queue_free()
	var class_list:=[world.get_class(),actor.get_class(),camera.get_class()]
	results.append({"test":"pure 2D scene nodes","pass":class_list==["Node2D","CharacterBody2D","Camera2D"]})
	var failures:=0
	for result in results:
		if not bool(result.pass):failures+=1
	FileAccess.open("res://checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("REFERENCE_PLAYABLE_CHECKS=",results.size()," failures=",failures)
	get_tree().quit(failures)

