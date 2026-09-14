extends Node

signal mapchange_

const prefix = "MapUtils(log)->"
const drfaule_npc_path = "res://assets/default/npc"

var file: File = null

var parse_all_map_dic = {}

var parse_current_map = {}

var default_npc = null
var collisionTileset = null

var path: String = ""
var fileName: String = ""

var show_log = false

func loadMape(path: String, fileName: String):
	parseDefaultNpc()
	if file != null and not file.is_open(): file.close()
	self.path = path
	self.fileName = fileName
	file = File.new()
	var source_file = str(path, "/", fileName)




	log_info(str(prefix, "打开地图文件状态：", file.file_exists(source_file)))
	if file.open(source_file, File.READ) != OK:
		log_info(str(prefix, source_file, "文件打开失败！！"))
		return null
	parseBase(file)
	file.close()
	parse_current_map["desc"] = fileName.replace(".mape", "")
	if path.find("xq") != - 1:
		parse_current_map["map_mode"] = "xq"
	elif path.find("lord") != - 1:
		parse_current_map["map_mode"] = "lord"
	parse_all_map_dic[source_file] = parse_current_map
	
	var re_map = parse_current_map.duplicate(true)
	emit_signal("mapchange_", re_map)
	
	return re_map



func parseBase(f: File):
	log_info(str(prefix, "未知：%d" % readByte(f)))
	log_info(str(prefix, "目录：%s" % readString(f)))
	log_info(str(prefix, "文件名/疑似本文件的文件名或编号：%s" % readString(f)))
	parse_current_map["bg_color"] = readBgColor(f)
	parse_current_map["x_num"] = readInt(f)
	parse_current_map["y_num"] = readInt(f)
	parse_current_map["cell_h"] = readInt(f)
	parse_current_map["cell_w"] = readInt(f)
	parse_current_map["data_size"] = readInt(f)
	
	for i in parse_current_map["data_size"]:
		var type = readInt(f)
		log_info(str(prefix, "数据块名:%s" % readString(f)))
		
		match type:
			8:
				parseTile(f)
				pass
			9:
				parsePortal(f)
				pass
			6:
				parseBuild(f)
				pass
			5:
				parseNpc(f)
				pass


func parseTile(f: File):
	log_info(str(prefix, "=================================================="))
	log_info(str(prefix, "开始解析地表："))
	log_info(str(prefix, "未知（USERES/是否USERES，在该块貌似一直为USERES）：%s" % readString(f)))
	log_info(str(prefix, "未知数据：%d" % readInt(f)))
	log_info(str(prefix, "未知RES_TYPE/貌似固定为MTileImgRes:%s" % readString(f)))
	var size = readInt(f)
	log_info(str(prefix, "素材文件数量：%d" % size))
	var tileset: TileSet = TileSet.new()
	var imgt = ImageTexture.new()
	var img: Image = Image.new()
	img.create(16, 16, true, Image.FORMAT_RGBA8)
	img.fill(parse_current_map["bg_color"])
	imgt.create_from_image(img)
	tileset.create_tile(0)
	tileset.tile_set_z_index(0, 0)
	tileset.tile_set_texture(0, imgt)
	tileset.tile_set_tile_mode(0, TileSet.SINGLE_TILE)
	tileset.tile_set_region(0, Rect2(0, 0, 16, 16))
	var tile_id = 1
	for i in size:
		
		var name_sub_img = readString(f)
		var w = readInt(f)
		var h = readInt(f)
		log_info(str(prefix, "素材名称:%s" % name_sub_img))
		log_info(str(prefix, "切割宽度:%d" % w))
		log_info(str(prefix, "切割高度:%d" % h))
		var st: StreamTexture = load(str(path, "/", name_sub_img))
		st.flags = 1
		if st == null: continue
		var w_size = st.get_width() / w
		var h_size = st.get_height() / h
		for i_h in range(h_size):
			for j_w in range(w_size):
				tileset.create_tile(tile_id)
				tileset.tile_set_z_index(tile_id, 0)
				tileset.tile_set_texture(tile_id, st)
				tileset.tile_set_tile_mode(tile_id, TileSet.SINGLE_TILE)
				tileset.tile_set_region(tile_id, Rect2(j_w * w, i_h * h, w, h))
				tile_id += 1
	parse_current_map["tileset"] = tileset
	parse_current_map["max_tile_id"] = tile_id
	log_info(str(prefix, "未知：%d" % readInt(f)))
	log_info(str(prefix, "图块宽度: %d" % readInt(f)))
	log_info(str(prefix, "图块高度: %d" % readInt(f)))
	size = readInt(f)
	log_info(str(prefix, "图块数量（%d*%d）:%d" % [parse_current_map["x_num"], parse_current_map["y_num"], size]))
	var mapDataList = []
	for i in range(parse_current_map["x_num"]):
		var list = []
		for j in range(parse_current_map["y_num"]):
			var map_data = readInt(f)
			list.append(map_data)
		mapDataList.append(list)
	parse_current_map["map_data_list"] = mapDataList
	log_info(str(prefix, "地表解析完成"))
	log_info(str(prefix, "=================================================="))


func parsePortal(f: File):
	log_info(str(prefix, "=================================================="))
	log_info(str(prefix, "开始解析传送门"))
	log_info(str(prefix, "未知：%s" % readString(f)))
	var size = readInt(f)
	log_info(str(prefix, "传送门数量：%d" % size))
	parse_current_map["portal_size"] = size
	var portal_list = []
	for i in range(parse_current_map["portal_size"]):
		log_info(str(prefix, "传送门数据:%d" % i))
		var portal = {}
		portal["x1"] = readInt(f)
		portal["y1"] = readInt(f)
		var x2 = readInt(f)
		var y2 = readInt(f)
		portal["x3"] = readInt(f)
		portal["y3"] = readInt(f)
		portal["x2"] = x2
		portal["y2"] = y2
		
		if x2 >= 20:
			
			x2 = x2 - 2
			y2 = y2 + 3
		elif x2 <= 5:
			
			y2 = y2 + 3
		if y2 <= 5:
			
			y2 = y2 + 1
		elif y2 >= 20:
			
			y2 = y2 + 2
		portal["x"] = x2
		portal["y"] = y2
		portal_list.append(portal)
		log_info(str(prefix, "info :%s" % readString(f)))
		log_info(str(prefix, "anim id : %d" % readInt(f)))
	parse_current_map["protal"] = portal_list
	log_info(str(prefix, "传送门解析完成"))
	log_info(str(prefix, "=================================================="))


func parseBuild(f: File):
	log_info(str(prefix, "=================================================="))
	log_info(str(prefix, "开始解析建筑"))
	log_info(str(prefix, "useres:%s" % readString(f)))
	log_info(str(prefix, "资源数量:%d" % readInt(f)))
	log_info(str(prefix, "资源路径[这个值无用]:%s" % readString(f)))
	
	var aef_name = readString(f)
	log_info(str(prefix, "aef资源文件:%s" % aef_name))
	var aefs = parseAef(path, aef_name)
	var pwds = {}
	var pwdSize = readInt(f)
	for i in range(pwdSize):
		var pwd_name = readString(f)
		log_info(str(prefix, "pwd文件", i, ":", pwd_name))
		var pwd_t = parsePwd(path, pwd_name)
		pwds[pwd_t.id] = pwd_t
	var builds_ani = mergePwdWithAef(pwds, aefs)
	var buildSize = readInt(f)
	parse_current_map["build_size"] = buildSize
	log_info(str(prefix, "建筑物数量:%d" % buildSize))
	var names = ["未知", "未知", "(右下角x)", "(右下角y)", "(左上角x)", "(左上角y)"]
	var builds_temp = []
	for i in range(buildSize):
		var x1 = readInt(f)
		var y1 = readInt(f)
		
		var x2 = readInt(f)
		var y2 = readInt(f)
		var x3 = readInt(f)
		var y3 = readInt(f)
		readString(f)
		var anim_id = readInt(f)
		var ans_all = builds_ani.animations
		if anim_id >= ans_all.size(): continue
		var ans = ans_all[anim_id]
		if ans.is_anim:
			
			log_info(str(prefix, "有动画建筑物"))
			pass
		else:
			
			if ans.serise[0] >= builds_ani.frames.size(): continue
			var imgt = ImageTexture.new()
			imgt.create_from_image(builds_ani.frames[ans.serise[0]])
			imgt.flags = 1
			var sp = Sprite.new()
			sp.position = Vector2(x2, y2 - 16 + imgt.get_height() / 2)
			sp.texture = imgt
			sp.offset = Vector2(0, - imgt.get_height() / 2)
			builds_temp.append(sp)
	parse_current_map["builds"] = builds_temp
	log_info(str(prefix, "建筑解析完成"))
	log_info(str(prefix, "=================================================="))
	pass


func parseNpc(f: File):
	log_info(str(prefix, "=================================================="))
	log_info(str(prefix, "开始解析npc"))
	readString(f)
	readInt(f)
	readString(f)
	readInt(f)
	var size = readInt(f)
	for i in range(size): readString(f)
	size = readInt(f)
	log_info(str(prefix, "npc数量", size))
	var npcs = []
	for i in range(size):
		var npc = {}
		npc["x1"] = readInt(f)
		npc["y1"] = readInt(f)
		npc["x2"] = readInt(f)
		npc["y2"] = readInt(f)
		npc["x3"] = readInt(f)
		npc["y3"] = readInt(f)
		npc["info"] = readString(f)
		npcs.append(npc)
		readInt(f)
	parse_current_map["npcs"] = npcs
	log_info(str(prefix, "npc解析完成"))
	log_info(str(prefix, "=================================================="))


func getMaxSmallPic(dic: Dictionary, arr: Array) -> Rect2:
	var x1 = 0
	var y1 = 0
	var x2 = 0
	var y2 = 0
	for r in arr:
		var pid = r.pwd_id
		var imgid = r.img_id - 1
		var dic_pwd = dic[pid]
		var img_pic: Image = dic_pwd["pics"][imgid]
		var width = img_pic.get_width()
		var height = img_pic.get_height()
		if r.x < x1: x1 = r.x
		if r.y < y1: y1 = r.y
		if (r.x + width) > x2: x2 = r.x + width
		if (r.y + height) > y2: y2 = r.y + height
		pass
	x2 = x2 - x1
	y2 = y2 - y1
	x1 = x1
	y1 = y1
	var rec = Rect2(x1, y1, x2, y2)
	return rec


func mergePwdWithAef(dic: Dictionary, manimations: Dictionary):
	var anis_frame = []
	anis_frame.append(null)
	
	
	
	var _frames = manimations.frames
	for temp in _frames:
		
		var rec2 = getMaxSmallPic(dic, temp.imgs)
		
		var ress = temp.imgs
		var temp_img: Image = Image.new()

		temp_img.create(rec2.size.x, rec2.size.y, false, Image.FORMAT_RGBA8)
		
		for r in ress:
			var dic_pwd = dic[r.pwd_id]
			var img_pic = dic_pwd.pics[r.img_id - 1]
			temp_img.blend_rect(img_pic, Rect2(0, 0, img_pic.get_width(), img_pic.get_height()), Vector2(r.x - rec2.position.x, r.y - rec2.position.y))
		
		anis_frame.append(temp_img)
		
	
	var _animations = manimations.animations
	return {"frames": anis_frame, "animations": _animations}


func parsePwd(path: String, fileName: String):
	var t_file = File.new();
	if t_file.open(path + str("/") + fileName, File.READ) != OK:
		log_info(str(prefix, str(path + str("/") + fileName)))
		log_info(str(prefix, "pwd资源文件打开失败！"))
		return null
	var pwd_id = readShort(t_file)
	var pic_length = readInt(t_file)
	var pic_poolData: PoolByteArray = t_file.get_buffer(pic_length)
	var pic_sub_count = readShort(t_file)
	var pics = []
	var p_img: Image = Image.new()
	p_img.load_png_from_buffer(pic_poolData)
	for i in range(pic_sub_count):
		var x = readShort(t_file)
		var y = readShort(t_file)
		var w = readShort(t_file)
		var h = readShort(t_file)
		var rec = Rect2(x, y, w, h)
		pics.append(p_img.get_rect(rec))
	var dics = {"id": pwd_id, "pics": pics, "fileName": fileName}
	return dics

func parseAef(path: String, fileName: String):
	var t_file = File.new();
	if t_file.open(path + str("/") + fileName, File.READ) != OK:
		log_info(str(prefix, "pwd资源文件打开失败！"))
		return null
	var frames_count = readShort(t_file)
	var frames = []
	var frame_id_dic = {}
	for f_i in range(frames_count):
		var frames_id = readShort(t_file)
		var img_count = readInt(t_file)
		var imgs = []
		for img_i in range(img_count):
			var p_id = readShort(t_file)
			var pwd_img_id = readShort(t_file)
			var x = readShort(t_file)
			var y = readShort(t_file)
			if x > 32768:
				x = x - 65535 - 1
			if y > 32768:
				y = y - 65535 - 1
			imgs.append({"pwd_id": p_id, "img_id": pwd_img_id, "x": x, "y": y})
		frames.append({"imgs": imgs, "fid": frames_id})
		frame_id_dic[str(frames_id)] = imgs
	
	var anim_count = readShort(t_file)
	var animations = []
	for anim_i in range(anim_count):
		var f_count = readShort(t_file)
		var serise = []
		for i in range(f_count):
			var f_id = readShort(t_file)
			serise.append(f_id)
		var is_anim = false
		if f_count > 1: is_anim = true
		animations.append({"serise": serise, "is_anim": is_anim})
	return {"frames": frames, "animations": animations, "frame_ids": frame_id_dic}



func parseAllPathPwd(r_path: String):
	var all_pwds = {}
	var path_dir = Directory.new()
	if path_dir.open(r_path) == OK:
		path_dir.list_dir_begin(true, true)
		var f_name = path_dir.get_next()
		while f_name != "":
			if not path_dir.current_is_dir():
				
				if f_name.ends_with(".pwd"):
					var pwds = parsePwd(r_path, f_name)
					if pwds == null:
						f_name = path_dir.get_next()
						continue
					all_pwds[pwds.id] = pwds
			f_name = path_dir.get_next()
	return all_pwds

func parseDefaultNpc():
	if default_npc != null: return default_npc
	
	
	var d_npc_path = drfaule_npc_path
	var all_pwds = parseAllPathPwd(d_npc_path)
	var aefs = parseAef(d_npc_path, "tynpc.aef")
	var npc_anim = mergePwdWithAef(all_pwds, aefs)
	var anim = npc_anim["animations"]
	for a_f in anim:
		if not a_f["is_anim"]:
			var f_id = a_f["serise"][0]
			var imgt = ImageTexture.new()
			imgt.create_from_image(npc_anim["frames"][f_id])
			imgt.flags = 1
			default_npc = imgt;
	return default_npc


func creat_collosion_tilemap():
	if collisionTileset != null: collisionTileset.duplicate(true)
	
	collisionTileset = TileSet.new()
	var col_img: Image = Image.new()
	col_img.create(16, 16, false, Image.FORMAT_RGBA8)
	col_img.fill(Color(1, 1, 0, 0))
	var st = ImageTexture.new()
	st.create_from_image(col_img)
	collisionTileset.create_tile(1)
	collisionTileset.tile_set_z_index(1, 0)
	collisionTileset.tile_set_texture(1, st)
	collisionTileset.tile_set_tile_mode(1, TileSet.SINGLE_TILE)
	collisionTileset.tile_set_region(1, Rect2(0, 0, 16, 16))
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(16, 16)
	collisionTileset.tile_set_shape(1, 1, shape)
	
	var col_img2: Image = Image.new()
	col_img2.create(16, 16, false, Image.FORMAT_RGBA8)
	col_img2.fill(Color(1, 1, 0, 0))
	var st2 = ImageTexture.new()
	st2.create_from_image(col_img2)
	
	collisionTileset.create_tile(0)
	collisionTileset.tile_set_z_index(0, 1)
	collisionTileset.tile_set_texture(0, st2)
	collisionTileset.tile_set_tile_mode(0, TileSet.SINGLE_TILE)
	collisionTileset.tile_set_region(0, Rect2(0, 0, 16, 16))
	var polygon = NavigationPolygon.new()
	var outline = PoolVector2Array([Vector2(0, 0), Vector2(0, 16), Vector2(16, 16), Vector2(16, 0)])
	polygon.add_outline(outline)
	polygon.make_polygons_from_outlines()
	collisionTileset.tile_set_navigation_polygon(0, polygon)
	return collisionTileset.duplicate(true)


func readString(f: File):
	var length = readShort(f)
	var bytePool: PoolByteArray = f.get_buffer(length)
	return bytePool.get_string_from_utf8()

func readShort(f: File):
	var bytePool: PoolByteArray = f.get_buffer(2)
	return byteToShort(bytePool)

func readInt(f: File):
	var bytePool: PoolByteArray = f.get_buffer(4)
	return byteToInt(bytePool)

func readByte(f: File):
	var bytePool: PoolByteArray = f.get_buffer(1)
	return bytePool[0]

func byteToShort(byteP: PoolByteArray):
	return (byteP[0] << 8) | (byteP[1] << 0)

func byteToInt(byteP: PoolByteArray) -> int:
	var int_value = (((byteP[3]) << 0) | ((byteP[2]) << 8) | ((byteP[1]) << 16) | ((byteP[0]) << 24))
	if int_value >= 4026531840:
		return int_value - 4294967295 - 1
	else:
		return int_value
func readBgColor(f: File):
	var a = f.get_8()
	var r = f.get_8()
	var g = f.get_8()
	var b = f.get_8()
	var bg = Color(1, 1, 1, 1)
	bg.a8 = a
	bg.r8 = r
	bg.b8 = b
	bg.g8 = g
	return bg
func log_info(st):
	if show_log:
		print(st)
