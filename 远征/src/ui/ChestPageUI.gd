extends RefCounted
## Shared B2 page furniture. The owning panel retains every game operation.
const UI := preload("res://src/ui/TravelChestUI.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const ROOT := "res://assets/ui/travel_chest_b2/"
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func title_badge_tex(tid: String) -> Texture2D:
	var all_titles: Array = G.titles_cfg()
	var idx := 0
	for i in all_titles.size():
		if String((all_titles[i] as Dictionary).get("id", "")) == tid:
			idx = i
			break
	var badge_num := clampi(idx + 1, 1, 25)
	var tex := KitV4.commercial_tex("title_badge_%d" % badge_num)
	if tex != null:
		return tex
	return preload("res://src/ui/ReviewFixUI.gd").texture("crown")

static func talent_icon_tex(nid: String) -> Texture2D:
	if nid.begins_with("fury_"):
		var tier := clampi(int(nid.substr(5)), 1, 10)
		var t1 := KitV4.commercial_tex("talent_berserk_%d" % tier)
		if t1 != null: return t1
	elif nid.begins_with("guard_"):
		var tier := clampi(int(nid.substr(6)), 1, 10)
		var t2 := KitV4.commercial_tex("talent_guard_%d" % tier)
		if t2 != null: return t2
	elif nid.begins_with("spirit_"):
		var tier := clampi(int(nid.substr(7)), 1, 10)
		var t3 := KitV4.commercial_tex("talent_command_%d" % tier)
		if t3 != null: return t3
	elif nid == "fury":
		var tf := KitV4.commercial_tex("talent_berserk_1")
		if tf != null: return tf
	elif nid == "guard":
		var tg := KitV4.commercial_tex("talent_guard_1")
		if tg != null: return tg
	elif nid == "spirit":
		var ts := KitV4.commercial_tex("talent_command_1")
		if ts != null: return ts
	return null

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if _regions.is_empty(): _regions = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"regions.json"))
	if not _regions.has(id):
		var ctex := KitV4.commercial_tex(id)
		if ctex != null:
			_textures[id] = ctex
			return ctex
		return null
	var data: Dictionary = _regions[id]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ROOT+String(data.file))
	var scaling := atlas.atlas.get_size()/Vector2(data.source_size[0],data.source_size[1])
	atlas.region = Rect2(Vector2(data.rect[0],data.rect[1])*scaling,Vector2(data.rect[2],data.rect[3])*scaling)
	_textures[id] = atlas
	return atlas

static func place(node: Control, pos: Vector2, extent: Vector2) -> void:
	node.position = pos
	node.size = extent

static func picture(tex: Texture2D, extent: Vector2) -> TextureRect:
	var p := TextureRect.new()
	p.texture = tex
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size = extent
	p.size = extent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex!=null and tex.get_meta("pixel_art",false) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return p

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func scroll() -> ScrollContainer:
	var s := preload("res://src/ui/TouchScroll.gd").new()
	s.follow_keyboard_focus = true
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.follow_focus = true
	var rail:=StyleBoxFlat.new()
	rail.bg_color=Color(UI.NIGHT,.65)
	rail.content_margin_left=3; rail.content_margin_right=3
	var grip:=StyleBoxFlat.new()
	grip.bg_color=UI.BRONZE
	grip.content_margin_left=3; grip.content_margin_right=3
	grip.set_corner_radius_all(2)
	var bar:=s.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll",rail)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:bar.add_theme_stylebox_override(state,grip)
	return s

static func line(words: String, role: String = "body", color: Color = UI.PAPER) -> Label:
	var l := UI.label(words,role,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func affix_label(a: Dictionary) -> String:
	var id:=String(a.get("stat",""))
	var names: Dictionary={"atk_pct":"攻击","def_pct":"防御","maxhp_pct":"生命","crit_add":"暴击","spd_pct":"速度"}
	return "%s +%.1f%%" % [String(names.get(id,id)),float(a.get("v",0))*100] if not id.is_empty() else "空词条"

static func confirm(parent: Node, title: String, words: String, callback: Callable) -> Control:
	var d := UI.Modal.new()
	d.heading = title
	d.lines = [words]
	d.choices = ["取消","确认"]
	d.z_index = UI.Z_MODAL
	d.closed.connect(d.queue_free)
	d.selected.connect(func(index: int):
		d.queue_free()
		if index==1: callback.call())
	parent.add_child(d)
	if not d._buttons.is_empty():d._buttons[0].grab_focus()
	return d

class Stage extends Control:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var background: TextureRect
	var sky: TextureRect
	var shade: ColorRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		background = TextureRect.new()
		background.texture = load("res://image/background/art_v2/camp_bluehour.png")
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(background)
		sky = TextureRect.new()
		sky.texture = load(UI.ROOT+"camp_sky.png")
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform sampler2D original:filter_nearest; uniform float extra=0.0; uniform float height=307.0; void fragment(){float y=UV.y*height; vec4 s=texture(TEXTURE,vec2(UV.x,UV.y*0.30)); vec4 b=texture(original,vec2(UV.x,clamp((y-extra)/800.0,0.0,1.0))); COLOR=mix(s,b,smoothstep(extra-40.0,extra+40.0,y));}"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("original",background.texture)
		sky.material = mat
		add_child(sky)
		shade = ColorRect.new()
		shade.color = Color("120e0c",.48)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		resized.connect(layout)
		layout()
	func layout() -> void:
		if background==null: return
		var extra := maxf(0,size.y-800)
		var sky_extra := minf(84.0, extra * 0.32)
		background.position = Vector2(0,sky_extra)
		background.size = Vector2(size.x,maxf(800,size.y-sky_extra))
		sky.visible = sky_extra>0
		sky.size = Vector2(size.x,sky_extra+40)
		(sky.material as ShaderMaterial).set_shader_parameter("extra",sky_extra)
		(sky.material as ShaderMaterial).set_shader_parameter("height",sky.size.y)
		shade.size = size

class ItemCell extends Button:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	const Page = preload("res://src/ui/ChestPageUI.gd")
	const KitV4 = preload("res://src/ui/KitV4.gd")
	var selected := false
	var rarity := Color("77705f")
	var item_image: TextureRect
	var heading: Label
	var amount: Label
	var flag: Label
	var rarity_rank:=1
	var show_name:=false
	var image_px:=60.0
	var locked:=false
	var worn:=false
	var fresh:=false
	func _init() -> void:
		custom_minimum_size = Vector2(84,84)
		item_image = Page.picture(null,Vector2(40,40))
		add_child(item_image)
		heading = UI.label("","tag")
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.clip_text = true
		add_child(heading)
		amount = UI.label("","tag",UI.AGED)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(amount)
		flag = UI.label("","tag",UI.COPPER)
		add_child(flag)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for event in [resized,mouse_entered,mouse_exited,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if disabled and item_image.texture == null:
			var empty_tex := KitV4.commercial_tex("slot_empty")
			if empty_tex != null:
				G.Visuals.nine_slice(self, empty_tex, Rect2(Vector2.ZERO, size), 10.0, 10.0)
			else:
				UI.surface(self, Rect2(Vector2.ZERO, size), Color("0c0908", 0.72), Color("382e22", 0.45), 2.0)
			var c := size * 0.5
			draw_line(Vector2(c.x - 4, c.y), Vector2(c.x + 4, c.y), Color("584836", 0.65), 1.0)
			draw_line(Vector2(c.x, c.y - 4), Vector2(c.x, c.y + 4), Color("584836", 0.65), 1.0)
			return
		var slot_key := KitV4.slot_key(rarity_rank)
		var slot_tex := KitV4.commercial_tex(slot_key)
		if slot_tex != null:
			G.Visuals.nine_slice(self, slot_tex, Rect2(Vector2.ZERO, size), 10.0, 10.0)
		else:
			UI.surface(self,Rect2(Vector2.ZERO,size),UI.SELECTED if selected else Color("120e0c",.94),UI.GOLD if selected or has_focus() else UI.BRONZE)
		if selected:
			var sel_tex := KitV4.commercial_tex("slot_selected")
			if sel_tex != null:
				G.Visuals.nine_slice(self, sel_tex, Rect2(Vector2.ZERO, size), 10.0, 10.0)
			else:
				draw_rect(Rect2(1,1,size.x-2,size.y-2),UI.GOLD,false,2)
		if fresh:
			draw_circle(Vector2(size.x-7,7),3,UI.GOLD)
		var px:=minf(image_px,minf(size.x,size.y)-16)
		item_image.size=Vector2(px,px)
		item_image.custom_minimum_size=Vector2(px,px)
		item_image.position=(size-Vector2(px,px))*.5
		if item_image.texture!=null and item_image.texture.get_meta("pixel_art",false):item_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		heading.visible=show_name
		heading.position = Vector2(4,size.y-30)
		heading.size = Vector2(size.x-8,22)
		amount.position = Vector2(4,4)
		amount.size = Vector2(size.x-10,22)
		flag.position = Vector2(5,size.y-24)
		flag.size = Vector2(30,22)
		flag.text="装" if worn else ""
		if locked:
			var p:=Vector2(size.x-17,size.y-15)
			draw_rect(Rect2(p,Vector2(10,8)),UI.AGED)
			draw_arc(p+Vector2(5,0),3,PI,TAU,12,UI.AGED,2)

class GemSocket extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const KitV4=preload("res://src/ui/KitV4.gd")
	var item_image:TextureRect
	var hint_label:Label
	func _init(tex:Texture2D=null) -> void:
		custom_minimum_size=Vector2(56,56)
		item_image=preload("res://src/ui/ChestPageUI.gd").picture(tex,Vector2(28,28))
		item_image.position=Vector2(14,8)
		add_child(item_image)
		hint_label=UI.label("点击镶嵌" if tex==null else "已镶嵌","tag",KitV4.MUTED if tex==null else KitV4.BRIGHT)
		hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size",G.FS_XS)
		hint_label.position=Vector2(0,36)
		hint_label.size=Vector2(56,18)
		hint_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(hint_label)
	func _ready() -> void:
		for s in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(s,StyleBoxEmpty.new())
		for e in [resized,focus_entered,focus_exited,mouse_entered,mouse_exited]:e.connect(queue_redraw)
	func _draw() -> void:
		var c:=Vector2(size.x*.5, 22.0)
		var r:=16.0
		var pts:=PackedVector2Array()
		for k in 6:
			var ang:=deg_to_rad(60.0*float(k)-30.0)
			pts.append(c+Vector2(cos(ang),sin(ang))*r)
		draw_colored_polygon(pts, KitV4.INSET)
		var pts_closed:=pts.duplicate()
		pts_closed.append(pts[0])
		draw_polyline(pts_closed, KitV4.BRIGHT if (has_focus() or is_hovered() or item_image.texture!=null) else KitV4.TRIM, 2.0, true)
		if item_image!=null:
			item_image.position=c-Vector2(14,14)
		if hint_label!=null:
			hint_label.text="已镶嵌" if (item_image!=null and item_image.texture!=null) else "点击镶嵌"
			hint_label.position=Vector2(0,size.y-18)
			hint_label.size=Vector2(size.x,18)

class GrowthRow extends Button:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	const Page = preload("res://src/ui/ChestPageUI.gd")
	const KitV4 = preload("res://src/ui/KitV4.gd")
	var image: TextureRect
	var heading: Label
	var status: Label
	var next_action: Label
	var actionable := false

	func _init(words: String, id_or_tex: Variant = "") -> void:
		text = words
		custom_minimum_size = Vector2(0, 52)
		var tex: Texture2D = null
		if id_or_tex is Texture2D:
			tex = id_or_tex
		elif id_or_tex is String:
			var s_id: String = String(id_or_tex)
			if s_id.begins_with("pet_"):
				tex = preload("res://src/ui/ReviewFixUI.gd").pet(s_id)
			elif s_id in ["fury", "guard", "spirit"] or s_id.begins_with("fury_") or s_id.begins_with("guard_") or s_id.begins_with("spirit_"):
				tex = Page.talent_icon_tex(s_id)
				if tex == null:
					var talent_map := {
						"fury": "zs_pozhen", "fury_1": "zs_lieshan", "fury_2": "zs_pozhen", "fury_3": "zs_zhanhou",
						"fury_4": "zs_huifeng", "fury_5": "zs_duanzui", "fury_6": "fs_yanmie", "fury_7": "ck_duopo",
						"fury_8": "ck_qingxie", "fury_9": "zs_zhanhou", "fury_10": "zs_pozhen",
						"guard": "fs_midun", "guard_1": "fs_midun", "guard_2": "fz_shengyu", "guard_3": "fz_zhudao",
						"guard_4": "fz_jinghua", "guard_5": "fs_midun", "guard_6": "fz_zhudao", "guard_7": "fs_midun",
						"guard_8": "fz_poxiao", "guard_9": "fz_shengyu", "guard_10": "fz_poxiao",
						"spirit": "ck_dunying", "spirit_1": "ck_dunying", "spirit_2": "ck_guanjia", "spirit_3": "ck_lianzhu",
						"spirit_4": "ck_dunying", "spirit_5": "fz_puzhao", "spirit_6": "fs_tianyun", "spirit_7": "ck_qingxie",
						"spirit_8": "fs_shuanghuan", "spirit_9": "fs_shuangren", "spirit_10": "fs_tianyun"
					}
					var k: String = String(talent_map.get(s_id, "zs_pozhen"))
					tex = preload("res://src/ui/ReviewFixUI.gd").texture(k)
			elif s_id in ["horse", "bear", "griffin", "nightmare", "sandlizard", "woolyrhino"]:
				tex = G.res_tex("mount_" + s_id)
			elif s_id.begins_with("t_") or s_id.begins_with("title_"):
				tex = Page.title_badge_tex(s_id)
			elif s_id in ["equip", "talent", "skill", "pet", "mount", "title", "titles"]:
				var tab_key := "tab_title" if s_id == "titles" else ("tab_" + s_id)
				tex = KitV4.commercial_tex(tab_key)
				if tex == null and s_id in ["title", "titles"]:
					tex = Page.title_badge_tex("t_rookie")
			if tex == null and not s_id.is_empty():
				tex = Page.texture(s_id)
		image = Page.picture(tex if tex != null else Page.texture("talent"), Vector2(40, 40))
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		heading = UI.label(words, "section")
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(heading)
		status = UI.label("", "caption", UI.AGED)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(status)
		next_action = UI.label("", "tag", UI.GOLD)
		next_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(next_action)

	func _ready() -> void:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for property in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			add_theme_color_override(property, Color.TRANSPARENT)
		for event in [resized, mouse_entered, mouse_exited, focus_entered, focus_exited]:
			event.connect(queue_redraw)

	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		UI.surface(self, Rect2(Vector2.ZERO, size), UI.SELECTED if is_hovered() else UI.FACE, UI.COPPER if (has_focus() or actionable) else Color("4a3d33"))
		if actionable:
			draw_rect(Rect2(0, 5, 3.0, size.y - 10), UI.GOLD)

		var icon_box := Rect2(Vector2(10, 4), Vector2(44, 44))
		var slot_tex := KitV4.commercial_tex("slot_selected" if actionable else "slot_rare")
		if slot_tex != null:
			G.Visuals.nine_slice(self, slot_tex, icon_box, 8.0, 8.0)
		else:
			draw_rect(icon_box, Color("0c0908"))
			draw_rect(icon_box, Color("c9a45c" if actionable else "4a3d33"), false, 1.0)
		image.position = Vector2(12, 6)

		var badge_w := minf(96.0,maxf(66,size.x*.22))
		var text_w := maxf(40.0, size.x-64.0-(badge_w+36.0 if not next_action.text.is_empty() else 24.0))
		heading.clip_text=true
		heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		status.clip_text=true
		status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.position = Vector2(64, 2)
		heading.size = Vector2(text_w, 26)
		if get_meta("recommendation", false):
			heading.size = Vector2(size.x - 88, 44)
		status.position = Vector2(64, 26)
		status.size = Vector2(text_w, 22)

		var badge_h := 26.0
		var badge_x := size.x - badge_w - 28.0
		var badge_y := (size.y - badge_h) * 0.5
		var badge_rect := Rect2(badge_x, badge_y, badge_w, badge_h)

		if not next_action.text.is_empty():
			var act_text := next_action.text
			if act_text.contains("已选") or act_text.contains("佩戴中"):
				UI.surface(self, badge_rect, Color("282015"), Color("c29a5b"))
				next_action.add_theme_color_override("font_color", Color("ebd197"))
			elif act_text.contains("可强化") or act_text.contains("可领取"):
				UI.surface(self, badge_rect, Color("2e1c10"), Color("e28b38"))
				next_action.add_theme_color_override("font_color", Color("f7b565"))
			elif act_text.contains("分配天赋"):
				UI.surface(self, badge_rect, Color("0f241e"), Color("38bca8"))
				next_action.add_theme_color_override("font_color", Color("5de4ce"))
			elif actionable:
				UI.surface(self, badge_rect, UI.NIGHT, UI.BRONZE)
				next_action.add_theme_color_override("font_color", UI.GOLD)
			else:
				UI.surface(self, badge_rect, Color("120e0c", 0.7), Color("4a3d33"))
				next_action.add_theme_color_override("font_color", Color("8f8376"))

			next_action.position = Vector2(badge_x, badge_y - 1.0)
			next_action.size = Vector2(badge_w, badge_h)

		draw_polyline(PackedVector2Array([
			Vector2(size.x - 18, size.y * 0.5 - 5),
			Vector2(size.x - 13, size.y * 0.5),
			Vector2(size.x - 18, size.y * 0.5 + 5)
		]), UI.COPPER if actionable else Color("5a4e46"), 1.5)
