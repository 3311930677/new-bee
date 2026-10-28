extends RefCounted

## Android can change insets without resizing the logical viewport (system bars,
## keyboard, focus). Observe the actual safe rect, rather than just window size.
static func watch(parent: Control, callback: Callable) -> void:
	var key := "SafeObserver_" + String(callback.get_method())
	if parent.has_node(NodePath(key)): return
	var observer := SafeObserver.new()
	observer.name = key
	observer.target = parent
	observer.callback = callback
	# The first sample also fits controls after their initial container pass.
	# Wrapped text can change a panel's minimum size after its owner's _ready.
	parent.add_child(observer)

class SafeObserver extends Node:
	var target: Control
	var callback: Callable
	var previous := Rect2(-1,-1,-1,-1)
	var wait := 0.0
	func _process(delta: float) -> void:
		wait -= delta
		if wait > 0 or not is_instance_valid(target) or not target.is_visible_in_tree(): return
		wait = .15
		var safe := G.ui_safe_rect(target)
		if not safe.is_equal_approx(previous):
			previous = safe
			callback.call_deferred()

static func from_screen(view:Rect2,screen_safe:Rect2,screen_transform:Transform2D,cutouts:Array=[])->Rect2:
	if not screen_safe.has_area() or absf(screen_transform.determinant())<.0001:return view
	var inverse:=screen_transform.affine_inverse()
	var safe:Rect2=(inverse*screen_safe).intersection(view)
	if not safe.has_area(): safe=view
	# Some devices report their display cutout separately from system-bar insets.
	# Convert both from physical screen pixels before clipping interactive content.
	for cutout in cutouts:
		var hole:Rect2=(inverse*Rect2(cutout)).intersection(view)
		if not hole.has_area() or not safe.intersects(hole): continue
		if hole.position.y<=view.position.y+1:
			var bottom:=safe.end.y
			safe.position.y=maxf(safe.position.y,hole.end.y)
			safe.size.y=bottom-safe.position.y
		elif hole.end.y>=view.end.y-1:
			safe.size.y=minf(safe.end.y,hole.position.y)-safe.position.y
		elif hole.position.x<=view.position.x+1:
			var right:=safe.end.x
			safe.position.x=maxf(safe.position.x,hole.end.x)
			safe.size.x=right-safe.position.x
		elif hole.end.x>=view.end.x-1:
			safe.size.x=minf(safe.end.x,hole.position.x)-safe.position.x
	return safe if safe.has_area() else view

static func fit_page(parent:Control,safe:Rect2,base:=Vector2(480,800))->void:
	var factor:=minf(1.0,minf(safe.size.x/base.x,safe.size.y/base.y))
	var origin:=safe.position+(safe.size-base*factor)*.5
	for child in parent.get_children():
		if not (child is Control or child is Node2D) or child.name in ["Veil","PageBackground","BackgroundShade","SceneryMotion","DisplayAtmosphere"] or child.get_meta("safe_layout_exempt",false):continue
		if child is Control and child.anchor_right==1.0 and child.anchor_bottom==1.0:continue
		if not child.has_meta("safe_base_position"):
			child.set_meta("safe_base_position",child.position)
			child.set_meta("safe_base_scale",child.scale)
		child.position=origin+Vector2(child.get_meta("safe_base_position"))*factor
		child.scale=Vector2(child.get_meta("safe_base_scale"))*factor

static func restore_page(parent:Control)->void:
	for child in parent.get_children():
		if child.has_meta("safe_base_position"):
			child.position=child.get_meta("safe_base_position")
			child.scale=child.get_meta("safe_base_scale")
			child.remove_meta("safe_base_position")
			child.remove_meta("safe_base_scale")

## A fixed illustration/card keeps its own design coordinates; only its outer
## frame is fitted. Recompute from design dimensions to avoid cumulative shrink.
static func fit_card(card:Control,safe:Rect2,design:Vector2,margin:=12.0)->void:
	var available:=(safe.size-Vector2.ONE*margin*2).max(Vector2.ONE)
	var factor:=minf(1.0,minf(available.x/design.x,available.y/design.y))
	card.size=design
	card.scale=Vector2.ONE*factor
	card.position=(safe.get_center()-design*factor*.5).round()

static func fit_hud(layer:CanvasLayer,safe:Rect2,view:Rect2)->void:
	var insets:=Vector4(safe.position.x-view.position.x,safe.position.y-view.position.y,view.end.x-safe.end.x,view.end.y-safe.end.y)
	for child in layer.get_children():
		if not child is Control:continue
		if child.size.x>=view.size.x and child.size.y>=view.size.y:continue
		if not child.has_meta("safe_hud_position"):child.set_meta("safe_hud_position",child.position)
		var at:Vector2=child.get_meta("safe_hud_position")
		at.x+=insets.x if at.x<view.size.x*.5 else -insets.z
		at.y+=insets.y if at.y<view.size.y*.5 else -insets.w
		child.position=at
