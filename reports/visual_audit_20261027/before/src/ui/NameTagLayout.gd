extends RefCounted
static var _opaque_cache:Dictionary={}
static func opaque_bounds(texture:Texture2D) -> Rect2i:
	var key:=texture.get_instance_id()
	if _opaque_cache.has(key):return _opaque_cache[key]
	var pixels:=texture.get_image();var box:=pixels.get_used_rect();var left:=box.end.x;var top:=box.end.y;var right:=box.position.x;var bottom:=box.position.y
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			if pixels.get_pixel(x,y).a>=.5:left=mini(left,x);top=mini(top,y);right=maxi(right,x+1);bottom=maxi(bottom,y+1)
	var result:=Rect2i(left,top,right-left,bottom-top) if right>left and bottom>top else box
	_opaque_cache[key]=result;return result
## Resolve nameplate paint only, in screen space; no world or collision mutations.
static func screen_rect(node: Control) -> Rect2:
	var xf := node.get_global_transform_with_canvas()
	return xf*Rect2(Vector2.ZERO,node.size)

static func resolve(candidates: Array, exclusions: Array[Rect2]) -> void:
	candidates.sort_custom(func(a,b): return int(a.priority)<int(b.priority))
	var occupied: Array[Rect2] = []
	for entry in candidates:
		var label := entry.label as Control
		if not is_instance_valid(label): continue
		if entry.has("alternatives"):
			if not label.has_meta("tag_home"):label.set_meta("tag_home",label.position)
			label.position=label.get_meta("tag_home")
		var box := screen_rect(label).grow(3)
		var obstructed := false
		for rect in exclusions:
			if box.intersects(rect): obstructed=true; break
		if not obstructed:
			for rect in occupied:
				if box.intersects(rect): obstructed=true; break
		if obstructed and entry.has("alternatives"):
			for offset in entry.alternatives:
				label.position=label.get_meta("tag_home")+offset
				box=screen_rect(label).grow(3)
				var clear:=true
				for rect in exclusions:
					if box.intersects(rect):clear=false;break
				if clear:
					for rect in occupied:
						if box.intersects(rect):clear=false;break
				if clear:obstructed=false;break
		label.self_modulate.a = .12 if obstructed else float(entry.get("alpha",1.0))
		if entry.has("pad") and is_instance_valid(entry.pad): entry.pad.self_modulate.a = 0.0 if obstructed else 1.0
		if not obstructed and label.is_visible_in_tree() and label.modulate.a>.25: occupied.append(box)
