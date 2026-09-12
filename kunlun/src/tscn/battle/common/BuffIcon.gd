extends Control

var glimmer_time = 0.2
var all_time = 0.0

var buff_data



var remain = 0

var DicStaticGameData

func _ready() -> void :
	DicStaticGameData = Global.get("DicStaticGameData")
	pass

func set_data(data):
	buff_data = data
	remain = buff_data["remain"]
	var icon_path = DicStaticGameData.buff_icon_dic[str(buff_data["buffId"])]
	$TextureRect.texture = load(icon_path)
	pass


func refresh(data):
	remain = buff_data["remain"]


func count_update():
	
	remain -= 1
	pass


func _process(delta: float) -> void :
	if remain <= 1:
		all_time += delta
		if all_time >= glimmer_time:
			all_time = 0.0
			$TextureRect.visible = not $TextureRect.visible
	else:
		$TextureRect.visible = true
		all_time = 0.0
	
	


