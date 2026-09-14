extends Node2D
export (String) var names = "宠物名称"
export (String) var petId = "htxjptcw"

export (bool) var show_name = true
var anim_player_zd: AnimationPlayer = null

var RoleUtils
var ScreenUtils

func _ready() -> void :
	RoleUtils = Global.get("RoleUtils")
	ScreenUtils = Global.get("ScreenUtils")
	load_data(petId)
	if show_name: $Label.visible = true
	else: $Label.visible = false

func load_data(petId):
	self.petId = petId
	load_pet(petId)
	pass

func load_pet(pet_no):
	if anim_player_zd != null:
		anim_player_zd.stop()
		anim_player_zd.queue_free()
	anim_player_zd = RoleUtils.parseZDNpc(petId)
	if anim_player_zd == null:
		ScreenUtils.show_message("当前宠物没有战斗动画资源")
		return
	anim_player_zd.play("fight_idle")
	anim_player_zd.root_node = self.get_path()
	add_child(anim_player_zd)
	var rec = RoleUtils.getPetRec(pet_no)
	if show_name:
		$Label.rect_size.y = - (abs(rec.size.y) + abs(rec.position.y))
