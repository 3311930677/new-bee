extends Panel

onready var vbox = $Background / Background2 / ScrollContainer / VBoxContainer

var skill_items = []
var ScreenUtils
var skill_checked_item = null

var skill_learn_default_size = 5

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	for i in vbox.get_children():
		if i is TextureRect:
			skill_items.append(i)
	
	for i in skill_items:
		i.set_skill_id( - 1)
		i.connect("item_click", self, "skill_item_click")

func set_data(data):
	var skills = data["skills"]
	var temp = []
	var index = 0
	
	for i in skill_items.size():
		skill_items[i].set_skill_id( - 1)
	
	for skill in skills:
		skill_items[index].set_skill_id(skill)
		index += 1
	
	
	
	for i in range(skills.size(), skills.size() + data["petHold"].get("expand_skill_slot", 0)):
		if i >= skill_items.size(): continue
		skill_items[i].set_skill_id( - 1)
	
	
	for i in range(skills.size() + data["petHold"].get("expand_skill_slot", 0) + 5 - index, skill_items.size()):
		if i >= skill_items.size(): continue
		skill_items[i].set_skill_id(0)

func skill_item_click(node):
	if node == skill_checked_item:
		_on_Ok_pressed()
		return
	skill_checked_item = node
	pass


func _on_Ok_pressed() -> void :
	if skill_checked_item.skill_id_ > 0:
		ScreenUtils.show_message_plus(skill_checked_item.get_skill_desc())
