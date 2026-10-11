# WeatherVFX.gd —— 环境天气粒子与氛围光影系统（移动端轻量级 TA 实现）
# 为二级野外地图提供：飘雪系统（寒冷地图）、落叶风沙系统（森林/荒坡地图）、幽深薄雾层（山谷/矿洞地图）
# 纯 CanvasItem 批量绘制，零 GPU 体积雾负担，低端移动设备稳定 60 FPS，首张主城保持原貌不添加扰动。
class_name WeatherVFX
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

var map_id := ""
var weather_type := "clear"

var _particles: Array[Dictionary] = []
var _clock := 0.0
var _mist_offset_1 := 0.0
var _mist_offset_2 := 0.0


func _init(p_map_id: String = "") -> void:
	map_id = p_map_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_weather()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8 # 高于地面地块与建筑，低于玩家交互/名签与全屏HUD


func _setup_weather() -> void:
	if map_id == "lorin_wilds" or map_id.is_empty():
		# 遵循规范：第一个主城保持明亮原貌，不添加风雪浓雾
		weather_type = "none"
		return

	if map_id in ["frost_post", "frost_boardwalk", "frost_pass"]:
		weather_type = "snow"
		_init_snow()
	elif map_id in ["broken_slope", "old_salt_road", "stele_cavern", "rift_mine_vault", "abyss_ring", "rift_mine_road"]:
		weather_type = "leaves"
		_init_leaves()
	else:
		weather_type = "mist"


func _init_snow() -> void:
	_particles.clear()
	for i in 42:
		_particles.append({
			"pos": Vector2(randf() * VIEW_W, randf() * VIEW_H),
			"vel": Vector2(randf_range(-14.0, -4.0), randf_range(28.0, 52.0)),
			"size": randf_range(1.5, 3.2),
			"alpha": randf_range(0.35, 0.85),
			"sway_speed": randf_range(1.5, 3.0),
			"sway_amp": randf_range(6.0, 14.0),
			"phase": randf() * TAU
		})


func _init_leaves() -> void:
	_particles.clear()
	var leaf_colors := [
		Color("d47c3e", 0.75), # 丹枫红
		Color("c49646", 0.70), # 枯草金
		Color("9e6a38", 0.65), # 褐石叶
		Color("b05a30", 0.80)  # 枫叶深赤
	]
	for i in 22:
		_particles.append({
			"pos": Vector2(randf() * VIEW_W, randf() * VIEW_H),
			"vel": Vector2(randf_range(-26.0, -12.0), randf_range(18.0, 36.0)),
			"size": randf_range(3.0, 5.0),
			"rot": randf() * TAU,
			"rot_speed": randf_range(-2.2, 2.2),
			"color": leaf_colors[randi() % leaf_colors.size()],
			"sway_speed": randf_range(1.2, 2.4),
			"phase": randf() * TAU
		})


func _process(delta: float) -> void:
	if weather_type == "none":
		return

	_clock += delta
	_mist_offset_1 = fmod(_mist_offset_1 + delta * 9.0, VIEW_W)
	_mist_offset_2 = fmod(_mist_offset_2 - delta * 6.0, VIEW_W)

	match weather_type:
		"snow":
			for p in _particles:
				p.pos.y += float(p.vel.y) * delta
				p.pos.x += float(p.vel.x) * delta + sin(_clock * float(p.sway_speed) + float(p.phase)) * 0.4
				if p.pos.y > VIEW_H + 10.0:
					p.pos.y = -10.0
					p.pos.x = randf() * VIEW_W
				elif p.pos.x < -10.0:
					p.pos.x = VIEW_W + 10.0

		"leaves":
			for p in _particles:
				p.pos.y += float(p.vel.y) * delta
				p.pos.x += float(p.vel.x) * delta + cos(_clock * float(p.sway_speed) + float(p.phase)) * 0.6
				p.rot += float(p.rot_speed) * delta
				if p.pos.y > VIEW_H + 10.0:
					p.pos.y = -10.0
					p.pos.x = randf() * (VIEW_W + 60.0)
				elif p.pos.x < -20.0:
					p.pos.x = VIEW_W + 20.0

	queue_redraw()


func _draw() -> void:
	if weather_type == "none":
		return

	# 1. 幽深薄雾流动层（双层柔和渐变水平带）
	_draw_mist_bands()

	# 2. 粒子渲染
	match weather_type:
		"snow":
			for p in _particles:
				var pos: Vector2 = p.pos
				var sz: float = p.size
				var c := Color(0.94, 0.97, 1.0, float(p.alpha))
				draw_circle(pos, sz * 0.5, c)
				# 较大雪花带有柔和微晕
				if sz > 2.5:
					draw_circle(pos, sz, Color(0.85, 0.92, 1.0, float(p.alpha) * 0.25))

		"leaves":
			for p in _particles:
				var pos: Vector2 = p.pos
				var sz: float = p.size
				var c: Color = p.color
				var angle: float = p.rot
				var dir := Vector2.from_angle(angle)
				var normal := Vector2(-dir.y, dir.x)
				var leaf_pts := PackedVector2Array([
					pos + dir * sz,
					pos + normal * (sz * 0.4),
					pos - dir * sz,
					pos - normal * (sz * 0.4)
				])
				draw_colored_polygon(leaf_pts, c)


func _draw_mist_bands() -> void:
	var mist_color := Color(0.08, 0.12, 0.16, 0.08) if weather_type == "snow" else Color(0.12, 0.09, 0.06, 0.07)
	# 上中下两道轻柔流动的透明雾气带，增加纵深感
	var y1 := 180.0
	var y2 := 520.0
	draw_rect(Rect2(0, y1, VIEW_W, 64.0), mist_color)
	draw_rect(Rect2(0, y2, VIEW_W, 80.0), mist_color * 0.8)
