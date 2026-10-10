extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
var host:Control
var shell:Control
var _chapter:Label
var _art:Control
var _counter:Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("远征手记",424)
	shell.closed=func():host.closed.emit()
	add_child(shell)
	host._deck=Flow.Selection.new()
	host._deck.page_count=3
	host._deck.page_changed.connect(func(_i:int):refresh())
	add_child(host._deck)
	for i in 3:
		var index:=i
		shell.tab(["世界","旅人","启程"][i],func():host._deck.go(index))
	shell.footer.add_child(Flow.button("上一章",func():host._deck.go(host._deck.current-1)))
	_counter=UI.label("1 / 3","number",UI.AGED)
	_counter.custom_minimum_size.x=80
	_counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shell.footer.add_child(_counter)
	shell.footer.add_child(Flow.button("下一章",func():host._deck.go(host._deck.current+1)))
	get_viewport().size_changed.connect(layout)
	shell.body.minimum_size_changed.connect(_fit_reading)
	refresh()
func refresh() -> void:
	Page.clear(shell.stage)
	Page.clear(shell.body)
	var i:int=host._deck.current
	_counter.text="%d / 3"%(i+1)
	for j in shell.tabs.get_child_count():shell.tabs.get_child(j).selected=j==i;shell.tabs.get_child(j).queue_redraw()
	if i==0:
		_art=Page.picture(load(host.WORLD_ART),Vector2(480,264))
		_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shell.stage.add_child(_art)
		shell.body.add_child(Flow.text("世界卷 · 01","caption",UI.AGED))
		shell.body.add_child(Flow.text("裂隙之下","title"))
		shell.body.add_child(Flow.text("大陆历947年，北境裂隙撕开。\n亡国皇子与旅人在灰烬中相遇。"))
		shell.body.add_child(Flow.text("从昭元出发，沿行旅册认识这片大陆。","body",UI.AGED))
	elif i==1:
		_art=Control.new()
		shell.stage.add_child(_art)
		for j in G.roles.size():
			var role:Dictionary=G.roles[j]
			var portrait:=Page.picture(load(G.role_icon_path(String(role.id))),Vector2(72,96))
			portrait.position=Vector2(24+(j%2)*216,(j/2)*128)
			_art.add_child(portrait)
			var label:=UI.label(String(role.name)+"\n"+String(role.job),"section")
			label.position=portrait.position+Vector2(84,12)
			label.size=Vector2(120,72)
			_art.add_child(label)
		shell.body.add_child(Flow.text("旅人卷 · 02","caption",UI.AGED))
		shell.body.add_child(Flow.text("四位旅人","title"))
		shell.body.add_child(Flow.text("剑、弓、冰霜与灯火。\n选择职业，结识伙伴，组成远征队伍。"))
	else:
		_art=host._Route.new()
		host._route_preview=_art
		shell.stage.add_child(_art)
		_art.play()
		shell.body.add_child(Flow.text("启程卷 · 03","caption",UI.AGED))
		shell.body.add_child(Flow.text("沿先王的足迹","title"))
		shell.body.add_child(Flow.text("穿越森林、雪原、火山与墓穴。\n构筑词条，挑战首领，失败后重整旗鼓。"))
	layout()
func layout(safe_override:Rect2=Rect2()) -> void:
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var text_height:=maxf(180,shell.body.get_combined_minimum_size().y)
	var art_height:=maxf(240,safe.size.y-112-text_height-116)
	shell.tray_height=safe.size.y-112-art_height
	shell.layout(safe_override)
	_fit_reading()
	if is_instance_valid(_art):
		Page.place(_art,Vector2((shell.stage.size.x-380)*.5,0) if host._deck.current==2 else Vector2.ZERO,Vector2(380,240) if host._deck.current==2 else shell.stage.size)
func _fit_reading() -> void:
	if not is_instance_valid(shell):return
	var desired:=maxf(180,shell.body.get_combined_minimum_size().y)+116
	if absf(shell.tray_height-desired)>1 and shell.safe.has_area():
		shell.tray_height=desired;shell.layout(shell.safe)
		if is_instance_valid(_art):Page.place(_art,Vector2((shell.stage.size.x-380)*.5,0) if host._deck.current==2 else Vector2.ZERO,Vector2(380,240) if host._deck.current==2 else shell.stage.size)
	var available:float=shell.safe.end.y-shell.scroll.position.y-92
	var body_height:=minf(available,maxf(112,shell.body.get_combined_minimum_size().y))
	shell.scroll.size.y=body_height
	shell.footer.position.y=minf(shell.safe.end.y-68,shell.scroll.position.y+body_height+24)
	shell.tray.size.y=get_viewport_rect().size.y-shell.tray.position.y
	shell.footer.position.y=shell.safe.end.y-68
	shell.scroll.size.y=maxf(40,shell.footer.position.y-shell.scroll.position.y-24)
