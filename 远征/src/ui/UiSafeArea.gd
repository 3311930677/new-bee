extends RefCounted

static func from_screen(view:Rect2,screen_safe:Rect2,screen_transform:Transform2D)->Rect2:
	if not screen_safe.has_area() or absf(screen_transform.determinant())<.0001:return view
	var safe:Rect2=(screen_transform.affine_inverse()*screen_safe).intersection(view)
	return safe if safe.has_area() else view

static func fit_page(parent:Control,safe:Rect2,base:=Vector2(480,800))->void:
	var factor:=minf(1.0,minf(safe.size.x/base.x,safe.size.y/base.y))
	var origin:=safe.position+(safe.size-base*factor)*.5
	for child in parent.get_children():
		if not (child is Control or child is Node2D) or child.name in ["Veil","PageBackground","BackgroundShade","SceneryMotion"]:continue
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
