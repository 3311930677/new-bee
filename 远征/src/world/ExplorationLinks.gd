extends RefCounted

static func config()->Dictionary:
	return TableCache._load("res://data/exploration_links.json")

static func trait_for(mount:String,map_id:String)->Dictionary:
	var row:Dictionary=config().get("mount_traits",{}).get(mount,{})
	return row if String(row.get("map",""))==map_id else {}

static func speed_mult(mount:String,map_id:String,at:Vector2,riding:bool)->float:
	if not riding:return 1.0
	var row:=trait_for(mount,map_id)
	if row.is_empty():return 1.0
	var rect:Array=row.rect
	return float(row.speed_mult) if Rect2(rect[0],rect[1],rect[2],rect[3]).has_point(at) else 1.0

static func pet_hint(host:Object,pet:String,map_id:String,kind:String)->String:
	if not host.owns_pet(pet) or kind not in ["puzzle","quest","side","story"]:return ""
	var row:Dictionary=config().get("pet_hints",{}).get(pet,{})
	return String(row.get("line","")) if (row.get("maps",[]) as Array).has(map_id) else ""

class Trail extends Node2D:
	var area:=Rect2()
	func _draw()->void:
		draw_rect(area,Color(.57,.84,.88,.07))
		for i in 6:
			var p:=Vector2(area.get_center().x,area.position.y+30+i*(area.size.y-60)/5)
			draw_circle(p+Vector2(-8,-5),4,Color(.67,.95,.95,.6))
			draw_circle(p+Vector2(8,5),4,Color(.67,.95,.95,.6))
