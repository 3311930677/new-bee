extends SceneTree
const ROOT:="res://assets/ui/next_review_20261009/"
func _initialize() -> void:
	var equipment:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/equip.json"))
	var skills:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	var regions:Dictionary={}
	var jobs:=[["items_a.png",4,4,equipment.templates.slice(0,16)],["items_b.png",4,4,equipment.templates.slice(16,32)],["items_c.png",4,3,equipment.templates.slice(32,44)],["skills.png",5,4,skills]]
	for job in jobs:
		var source:=Image.load_from_file(ROOT+job[0])
		var columns:int=job[1];var rows:int=job[2]
		var atlas:=Image.create(columns*60,rows*60,false,Image.FORMAT_RGBA8)
		for i in job[3].size():
			var left:=roundi(float(i%columns)*source.get_width()/columns)
			var top:=roundi(float(i/columns)*source.get_height()/rows)
			var right:=roundi(float(i%columns+1)*source.get_width()/columns)
			var bottom:=roundi(float(i/columns+1)*source.get_height()/rows)
			var cell:=source.get_region(Rect2i(left,top,right-left,bottom-top))
			var used:=cell.get_used_rect()
			if not used.has_area():push_error("EMPTY_ICON "+str(job[3][i].id));quit(1);return
			cell=cell.get_region(used)
			var factor:=54.0/maxi(cell.get_width(),cell.get_height())
			cell.resize(maxi(1,roundi(cell.get_width()*factor)),maxi(1,roundi(cell.get_height()*factor)),Image.INTERPOLATE_NEAREST)
			var at:=Vector2i(i%columns*60,i/columns*60)
			atlas.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),at+(Vector2i(60,60)-cell.get_size())/2)
			regions[String(job[3][i].id)]={"file":"pixel_"+job[0],"source_size":[columns*60,rows*60],"rect":[at.x,at.y,60,60]}
		var result:=atlas.save_png(ROOT+"pixel_"+job[0]);if result!=OK:quit(1);return
	var out:=FileAccess.open(ROOT+"regions.json",FileAccess.WRITE);out.store_string(JSON.stringify(regions,"\t"))
	print("NEXT_ICONS_OK 44 equipment, 20 skills, native 60px nearest import");quit()
