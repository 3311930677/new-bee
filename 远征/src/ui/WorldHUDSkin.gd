extends RefCounted
## Exploration-only skin. Integer pixels keep the HUD crisp at the game's native 480px width.
const INK := Color("171c1b", 0.95)
const FACE := Color("202724", 0.95)
const DARK := Color("0c1010")
const BRONZE := Color("89603b")
const GOLD := Color("d0a164")
const LIGHT := Color("f3d29b")
const JADE := Color("74c99b")

static func plate(c: CanvasItem, rect: Rect2, face := INK, trim := BRONZE, ornate := true, pressed := false) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	var p := r.position
	var e := r.end
	# Two stepped silhouettes produce a metal lip with a recessed lacquer face.
	_cut(c, Rect2(p + Vector2(0,2),r.size), DARK, 3)
	_cut(c, r, DARK, 3)
	_cut(c, r.grow(-1), trim.darkened(0.25), 2)
	_cut(c, r.grow(-2), GOLD if trim == BRONZE else trim.lightened(0.25), 2)
	_cut(c, r.grow(-3), DARK, 1)
	_cut(c, r.grow(-4), face.darkened(0.16) if pressed else face, 1)
	c.draw_rect(Rect2(p + Vector2(6,1), Vector2(r.size.x-12,1)), Color(LIGHT,0.8))
	c.draw_rect(Rect2(p + Vector2(5,4), Vector2(r.size.x-10,1)), Color(0,0,0,0.55))
	c.draw_rect(Rect2(p.x+5,e.y-5,r.size.x-10,1), Color(GOLD,0.16))
	# Sparse, deterministic grain; kept below the typography contrast.
	for row in range(8, int(r.size.y)-6, 5):
		var offset := (row * 17) % maxi(1,int(r.size.x)-22)
		c.draw_rect(Rect2(p.x+7+offset,p.y+row,minf(12,r.size.x-14-offset),1), Color("809180",0.06))
	if ornate and r.size.x >= 70:
		for corner in [p+Vector2(3,3),Vector2(e.x-4,p.y+3),Vector2(p.x+3,e.y-4),e-Vector2(4,4)]:
			var dx := 1 if corner.x < r.get_center().x else -1
			var dy := 1 if corner.y < r.get_center().y else -1
			c.draw_rect(Rect2(corner.x + mini(0,dx*5),corner.y,6,1),GOLD)
			c.draw_rect(Rect2(corner.x,corner.y + mini(0,dy*5),1,6),GOLD)
			c.draw_rect(Rect2(corner,Vector2.ONE*2),LIGHT)

static func _cut(c: CanvasItem, r: Rect2, col: Color, cut: float) -> void:
	if not r.has_area(): return
	c.draw_rect(Rect2(r.position+Vector2(cut,0),r.size-Vector2(cut*2,0)),col)
	c.draw_rect(Rect2(r.position+Vector2(0,cut),r.size-Vector2(0,cut*2)),col)

static func diamond(c: CanvasItem, at: Vector2, radius := 3.0, col := GOLD) -> void:
	var p := at.round()
	for y in range(-int(radius),int(radius)+1):
		var half := int(radius)-absi(y)
		c.draw_rect(Rect2(p.x-half,p.y+y,half*2+1,1),col)
	if radius >= 3:
		c.draw_rect(Rect2(p-Vector2.ONE,Vector2(2,1)),col.lightened(0.4))

static func _disc(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	# Row spans, no antialiasing: real stair-step pixels rather than a blurred vector circle.
	var r := floorf(radius)
	for y in range(-int(r),int(r)+1):
		var x := floorf(sqrt(maxf(0,r*r-float(y*y))))
		c.draw_rect(Rect2(center.x-x,center.y+y,x*2+1,1),col)

static func ring(c: CanvasItem, center: Vector2, radius: float, trim := BRONZE, face := INK, pressed := false, ornaments := true, upper_gold := Color(0, 0, 0, 0), split_y := 9999.0) -> void:
	var p := center.floor()
	_disc(c,p+Vector2(0,2),radius,DARK)
	_disc(c,p,radius,DARK)
	_disc(c,p,radius-1,trim.darkened(0.2))
	_disc(c,p,radius-2,trim.lightened(0.35))
	_disc(c,p,radius-3,trim)
	_disc(c,p,radius-4,DARK)
	_disc(c,p,radius-5,face.darkened(0.16) if pressed else face)
	if upper_gold.a > 0.0:
		var inner_r := floorf(radius - 5.0)
		var rim_col := upper_gold.lightened(0.24)
		var fill_col := upper_gold.darkened(0.10) if pressed else upper_gold
		for y in range(-int(inner_r), int(inner_r) + 1):
			if p.y + y >= split_y:
				continue
			var x := floorf(sqrt(maxf(0.0, inner_r * inner_r - float(y * y))))
			c.draw_rect(Rect2(p.x - x, p.y + y, x * 2.0 + 1.0, 1.0), rim_col)
			var ix := floorf(sqrt(maxf(0.0, pow(maxf(0.0, inner_r - 2.0), 2.0) - float(y * y))))
			if y >= -int(inner_r) + 2 and ix > 0.0:
				c.draw_rect(Rect2(p.x - ix, p.y + y, ix * 2.0 + 1.0, 1.0), fill_col)
	# Light catches the upper bevel, a darker lower rim gives the disc weight.
	for y in range(-int(radius)+3,-int(radius*0.55)):
		var x := floorf(sqrt(maxf(0,pow(radius-2,2)-float(y*y))))
		if x > 0: c.draw_rect(Rect2(p.x-x,p.y+y,2,1),LIGHT)
	if ornaments:
		for direction in [Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN]:
			diamond(c,p+direction*(radius-2),3,DARK)
			diamond(c,p+direction*(radius-2),2,GOLD)
	# Small diagonal lacquer hatching stays away from the outer rim.
	if upper_gold.a <= 0.0:
		for row in range(-int(radius)+10,int(radius)-9,6):
			var sx := floorf(sqrt(maxf(0,pow(radius-8,2)-float(row*row))))
			if sx > 3:
				c.draw_line(p+Vector2(-sx,row),p+Vector2(-sx+6,row+2),Color("789080",0.07),1,false)

static func medallion(c: CanvasItem, rect: Rect2) -> void:
	var p := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var outline := PackedVector2Array([p+Vector2(8,0),p+Vector2(w-8,0),p+Vector2(w,8),p+Vector2(w,h-10),p+Vector2(w*.5,h),p+Vector2(0,h-10),p+Vector2(0,8)])
	c.draw_colored_polygon(outline,DARK)
	outline.append(outline[0])
	c.draw_polyline(outline,GOLD,1,false)
	c.draw_line(p+Vector2(4,20),p+Vector2(w-4,20),Color(BRONZE,0.8),1)
	diamond(c,p+Vector2(w*.5,h-2),2,LIGHT)

static func joystick(c: CanvasItem, center: Vector2, radius: float, vector: Vector2, active: bool) -> void:
	# An open ring and a translucent well preserve the terrain under the left thumb.
	_disc(c,center,radius+1,Color(DARK,0.72 if active else 0.55))
	_disc(c,center,radius,Color(GOLD if active else BRONZE,0.88 if active else 0.72))
	_disc(c,center,radius-2,Color(DARK,0.62 if active else 0.44))
	for direction in [Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN]:
		diamond(c,center+direction*(radius-1),2,GOLD)
		diamond(c,center+direction*(radius-13),2,Color(GOLD,0.52))
	var thumb := (center+vector*44).round()
	_disc(c,thumb,22,DARK)
	_disc(c,thumb,21,GOLD if active else LIGHT)
	_disc(c,thumb,19,INK)
	_disc(c,thumb-Vector2.ONE,17,FACE)
	diamond(c,thumb,3,Color(GOLD,0.55))
