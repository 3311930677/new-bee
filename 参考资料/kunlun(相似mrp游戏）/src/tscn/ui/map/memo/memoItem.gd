extends TextureRect

signal item_click

export var text: String
export var level: int
export var star: int

var id

var npc_id
var item_type



var light_tex = null


func _ready():
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	
	self.add_to_group("memo_item")
	find_node("TextureButton").connect("pressed", self, "_on_TextureButton_pressed")
	set_data(level, name, star)


func set_id(id):
	self.id = id
	
func set_npc(npc_id):
	self.npc_id = npc_id
	
func set_data(level, name, star):
	$levelLabel.text = "LV" + str(level)
	$nameLabel.text = name
	
	var childs = $stars.get_children()
	for i in range(star):
		childs[i].show()
	
	for i in range(star, 5):
		childs[i].hide()
		


func chekced():
	if (self.texture != null):
		emit_signal("item_click", self)
		
	self.texture = light_tex
	
	
	
func unchecked():
	self.texture = null
	
func _on_TextureButton_pressed() -> void :
	var items = Global.get_nodes_in_group("memo_item")
	for item in items:
		if item != self:
			item.unchecked()
			
	chekced()

