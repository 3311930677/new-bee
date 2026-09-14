extends Node2D

onready var npc_name = $Name
onready var sprite = $Sprite
onready var color_rect = $ColorRect
onready var rich_text = $ColorRect / RichTextLabel

var task_complete_res = null
var task_available_res = null
var task_accepting_res = null

var id = "10001"
var npc_data
var ScreenUtils
var NpcUtils
var DialogManage
var RichTextContentFormat
var TaskInfoManage
var MapInfoManage
var NTeamManage
var ActivityDataManage
var AssetsManage


var entered = false
var dynamic = false


var task_pick_npc = false


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	AssetsManage = Global.get("AssetsManage")
	RichTextContentFormat = Global.get("RichTextContentFormat")
	NpcUtils = Global.get("NpcUtils")
	DialogManage = Global.get("DialogManage")
	TaskInfoManage = Global.get("TaskInfoManage")
	MapInfoManage = Global.get("MapInfoManage")
	NTeamManage = Global.get("NTeamManage")
	ActivityDataManage = Global.get("ActivityDataManage")
	
	task_complete_res = load(str(AssetsManage.get_prefix(), "assets/res/task/m2.png"))
	task_available_res = load(str(AssetsManage.get_prefix(), "assets/res/task/m1.png"))
	task_accepting_res = load(str(AssetsManage.get_prefix(), "assets/res/task/m3.png"))
	
	
	
	
	TaskInfoManage.connect("task_state_update", self, "init_task")
	pass

func set_data(data: Dictionary):
	npc_data = data
	if check_monster_npc_visiable():
		queue_free()
		return
	
	position = Vector2(data.x, data.y)

	$Name.text = str(data.name)

	id = data["npc_id"]
	
	if RichTextContentFormat == null: return
	var txt = RichTextContentFormat.get_content_format(data["_desc"])

	rich_text.append_bbcode(str("[color=black]", txt, "[/color]"))
	
	
	var load_name = data["img_path"].replace(".png", "")
	var a = NpcUtils.load_npc(load_name)
	if a != null:
		
		var anims: Animation = a.get_animation("idle")
		anims.loop = true
		a.play("idle")
		add_child(a)
		if anims.length > 0.2:
			dynamic = true
			npc_name.rect_position.y = - 80
		else:
			npc_name.rect_position.y = - NpcUtils.get_height_npc(load_name) - 15
	else:
		sprite.texture = Global.get("MapeUtils").default_npc
		npc_name.rect_position.y = - sprite.texture.get_size().y - 15
	
	$ColorRect.rect_position.y = npc_name.rect_position.y - 20
	$Task.rect_position.y = npc_name.rect_position.y - 15
	init_task()
	
	ActivityDataManage.process_npc_activity(self)


func get_name():
	return npc_name.text


var max_y = 100
func _process(delta: float) -> void :
	if dynamic:
		if $Sprite.texture.get_size().y < max_y:
			max_y = $Sprite.texture.get_size().y
		npc_name.rect_position.y = - max_y / 2 - 20
		$Task.rect_position.y = npc_name.rect_position.y - 15
	if npc_is_collision_monster():
		
		pass
	pass

func _on_Area2D_body_entered(body: Node) -> void :
	if body is KinematicBody2D and not body.is_player: return
	
	if not task_pick_npc and not npc_is_collision_monster(): color_rect.show()
	if npc_is_collision_monster():
		Global.log_info("碰撞怪物npc")
		
		var arr_p = Global.get_nodes_in_group("player")
		var player = null
		if arr_p.size() > 0: player = arr_p[0]
		
		if player != null and not NTeamManage.self_is_follow():
			

			if get_task_id() == 111111:
				
				Global.get("TBBattleManage").request_monster_npc_fight(1)
			elif get_task_id() == 222222:
				
				Global.get("TBBattleManage").request_monster_npc_fight(11)
			elif get_task_id() == 333333:
				Global.get("TBBattleManage").request_monster_npc_fight(0)
			else:
				$TextureButton.mouse_filter = 1
				return
			
			ScreenUtils.show_please_wait("处理中,请稍后")
		
		MapInfoManage.get_reduce_num_monster_arr().append(get_id())
		queue_free()
	
	$TextureButton.mouse_filter = 1
	pass


func _on_Area2D_body_exited(body: Node) -> void :
	if not task_pick_npc and not npc_is_collision_monster(): color_rect.hide()
	
	$TextureButton.mouse_filter = 2
	pass


func _on_TextureButton_pressed() -> void :
	
	if MapInfoManage.yuguaiing: return
	if not task_pick_npc:
		
		
		var player = Global.get_nodes_in_group("player")[0]
		if not NTeamManage.self_is_follow() and not Global.get("TBBattleManage").current_fighting:
			DialogManage.request_npc(id)
	else:
		
		var line_task = TaskInfoManage.private_get_tasks("accepting_tasks", npc_data["task_id"], true)
		TaskInfoManage.request_pick_art_task(line_task.split(",")[0])


func _on_activity_xb_callback(data):
	if get_id() - ActivityDataManage.xb_start_npc_id > ActivityDataManage.get_xb_level():
		hide()
	else:
		show()













func init_task():
	$Task.visible = true
	
	
	if npc_data["task_id"] != 0 and int(npc_data["task_id"]) != 111111 and int(npc_data["task_id"]) != 222222 and int(npc_data["task_id"]) != 333333:
		
		task_pick_npc = true
		
		if TaskInfoManage.has_accepting_task_id(npc_data["task_id"]):
			sprite.texture = load("res://assets/skill/pet/cj_0.png")
			show()
		else:
			hide()
	pass
	
	
	if TaskInfoManage.has_fulfill_condition_tasks(get_npc_id()):
		$Task.texture = task_complete_res
		return
	
	if TaskInfoManage.has_available_task(get_npc_id()):
		$Task.texture = task_available_res
		return
	
	if TaskInfoManage.has_accepting_tasks(get_npc_id()):
		$Task.texture = task_accepting_res
		return
	$Task.visible = false


func get_npc_id():
	return npc_data["npc_id"]

func get_id():
	return npc_data["id"]

func get_task_id():
	return int(npc_data.get("task_id", 0))


func npc_is_collision_monster():
	return get_task_id() == 111111 or get_task_id() == 222222 or get_task_id() == 333333;


func check_monster_npc_visiable():
	if npc_is_collision_monster():
		if MapInfoManage.get_reduce_num_monster_arr().find(get_id()) != - 1:
			return true
		pass
	return false
