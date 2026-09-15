extends Node2D

const Actor = preload("res://src/preview/WalkActor.gd")
const FRAME_PATHS = [
	"res://image/role/zs/pojun_walk_frames.tres",
	"res://image/role/ck/chuanyang_walk_frames.tres",
	"res://image/role/fs/shuangyu_walk_frames.tres",
	"res://image/role/fz/chenxing_walk_frames.tres",
]
const NAMES = ["破军", "穿杨", "霜语", "晨星"]
const SPEEDS = [1.0, 1.2, 0.9, 1.0]
var actors: Array = []
var selected := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("222732"))
	var title := Label.new()
	title.position = Vector2(24, 20)
	title.text = "四方向行走预览\n点击人物按钮 / 数字1–4选择，方向键移动\n每行8帧：下、左、右、上；停下保留方向"
	title.add_theme_font_size_override("font_size", 17)
	add_child(title)
	for i in range(4):
		var button := Button.new()
		button.position = Vector2(20 + i * 115, 108)
		button.size = Vector2(105, 40)
		button.text = "%d %s" % [i + 1, NAMES[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(i))
		add_child(button)
		var actor := Actor.new()
		actor.configure(load(FRAME_PATHS[i]) as SpriteFrames, SPEEDS[i])
		actor.position = Vector2(135 + (i % 2) * 210, 370 + floori(i / 2.0) * 240)
		actors.append(actor)
		add_child(actor)
	_select(0)


func _select(index: int) -> void:
	selected = index
	for i in range(actors.size()):
		actors[i].controlled = i == selected
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_select(event.keycode - KEY_1)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for x in range(0, 481, 32):
		draw_line(Vector2(x, 180), Vector2(x, 740), Color("303744"))
	for y in range(180, 741, 32):
		draw_line(Vector2(0, y), Vector2(480, y), Color("303744"))
	if not actors.is_empty():
		draw_arc(actors[selected].position, 17, 0, TAU, 32, Color("e5bd6e"), 2)
