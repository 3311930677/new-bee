extends RefCounted
static var _opaque_cache:Dictionary={}
static func clear_cache() -> void:
	_opaque_cache.clear()
static func opaque_bounds(texture:Texture2D) -> Rect2i:
	if texture == null: return Rect2i()
	var key:=texture.get_instance_id()
	if _opaque_cache.has(key):return _opaque_cache[key]
	var pixels:=texture.get_image()
	if pixels == null or pixels.is_empty():
		_opaque_cache[key]=Rect2i()
		return Rect2i()
	var box:=pixels.get_used_rect()
	if not box.has_area():
		_opaque_cache[key]=box
		return box
	if pixels.is_compressed():
		pixels.decompress()
	if pixels.get_format() != Image.FORMAT_RGBA8:
		pixels.convert(Image.FORMAT_RGBA8)
	var data:PackedByteArray=pixels.get_data()
	var w:int=pixels.get_width()
	var x0:int=box.position.x
	var y0:int=box.position.y
	var x1:int=box.end.x
	var y1:int=box.end.y
	var top:int=y1
	for y in range(y0,y1):
		var row_base:int=y*w*4
		var hit:=false
		for x in range(x0,x1):
			if data[row_base+x*4+3]>=128:
				top=y;hit=true;break
		if hit:break
	if top>=y1:
		_opaque_cache[key]=box
		return box
	var bottom:int=top
	for y in range(y1-1,top-1,-1):
		var row_base:int=y*w*4
		var hit:=false
		for x in range(x0,x1):
			if data[row_base+x*4+3]>=128:
				bottom=y+1;hit=true;break
		if hit:break
	var left:int=x1
	for x in range(x0,x1):
		var col_off:int=x*4+3
		var hit:=false
		for y in range(top,bottom):
			if data[y*w*4+col_off]>=128:
				left=x;hit=true;break
		if hit:break
	var right:int=left
	for x in range(x1-1,left-1,-1):
		var col_off:int=x*4+3
		var hit:=false
		for y in range(top,bottom):
			if data[y*w*4+col_off]>=128:
				right=x+1;hit=true;break
		if hit:break
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
