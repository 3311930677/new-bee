extends Control

onready var pet_list = $"Tabs/Panels/PetList"


onready var pet_ability = $"Tabs/Panels/PetAbility"
onready var pet_attribute = $"Tabs/Panels/PetAttrbute"
onready var pet_qual = $"Tabs/Panels/PetQualification"
onready var pet_skill = $"Tabs/Panels/PetSkill"

onready var pet_list_tab = $Tabs / HBoxContainer / PetListTab



var PetInfoManage
var RoleInfoManage
var ScreenUtils

var data
var details_pet_id = 0
var pet_detail_info

func load_data(data):
	self.data = data
	
	hide()
	
	if data.pet_type == 1:
		$Tabs / HBoxContainer / PetListTab.visible = false
		$Tabs / HBoxContainer / PetListTab.queue_free()
		
		$"Tabs/Panels/PetAttrbute/Background/Background2/Private".visible = false
		$"Tabs/Panels/PetAttrbute/Background/Background2/Public".visible = true
		
		for tab in $"Tabs/HBoxContainer".get_children():
			tab.rect_size.x += 70 / 4
		$"Tabs/HBoxContainer/AbilityTab".checked()
		
		details_pet_id = data.get("id", 0)
		PetInfoManage.request_pet_details(details_pet_id)
	else:
		
		
		details_pet_id = RoleInfoManage.get_pet_fight_id()
		

		var info = PetInfoManage.get_fight_pet_details()
		if info != null and not info.empty():
			_on_pet_info_result(details_pet_id, info)
		
		PetInfoManage.request_data()
		$"Tabs/HBoxContainer/PetListTab".checked()

func _ready() -> void :
	PetInfoManage = Global.get("PetInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	PetInfoManage.connect("loaded_all_list_pets", self, "_on_pet_data_result")
	PetInfoManage.connect("pet_info", self, "_on_pet_info_result")
	PetInfoManage.connect("reset_pet", self, "_on_reset_pet_result")
	PetInfoManage.connect("fight_pet", self, "_on_fight_pet_result")


func _on_pet_data_result():
	if data.get("pet_type") != 1:
		show()

func _on_reset_pet_result():
	details_pet_id = 0
	$Head / XQTitle.set_title("请选择出战宠物")


func _on_fight_pet_result():
	details_pet_id = PetInfoManage.fight_pet_id
	$Head / XQTitle.set_title(PetInfoManage.get_fight_pet_name())
	pass


func _on_pet_info_result(id, data):
	
	if id != details_pet_id: return
	
	pet_detail_info = data
	$Head / XQTitle.set_title(data["petHold"]["name"])
	if self.data.get("pet_type") == 1:
		show()
	
	
	pet_ability.set_data(data)
	pet_attribute.set_data(data)
	pet_qual.set_data(data)
	pet_skill.set_data(data)

func _on_PetListTab_tab_click(node) -> void :
	hide_all_panels()
	$"Tabs/Panels/PetList".visible = true


func _on_AbilityTab_tab_click(node) -> void :
	if PetInfoManage.get_fight_pet_id() == 0 and data.pet_type == 0:
		ScreenUtils.show_message("请先选择出战宠物")
		if pet_list_tab != null: pet_list_tab.checked()
		node.unchecked()
		return
	hide_all_panels()
	$"Tabs/Panels/PetAbility".visible = true


func _on_AttributeTab_tab_click(node) -> void :
	if PetInfoManage.get_fight_pet_id() == 0 and data.pet_type == 0:
		ScreenUtils.show_message("请先选择出战宠物")
		if pet_list_tab != null: pet_list_tab.checked()
		node.unchecked()
		return
	hide_all_panels()
	$"Tabs/Panels/PetAttrbute".visible = true


func _on_QualificationTab_tab_click(node) -> void :
	if PetInfoManage.get_fight_pet_id() == 0 and data.pet_type == 0:
		ScreenUtils.show_message("请先选择出战宠物")
		if pet_list_tab != null: pet_list_tab.checked()
		node.unchecked()
		return
	hide_all_panels()
	$"Tabs/Panels/PetQualification".visible = true


func _on_SkillTab_tab_click(node) -> void :
	if PetInfoManage.get_fight_pet_id() == 0 and data.pet_type == 0:
		ScreenUtils.show_message("请先选择出战宠物")
		if pet_list_tab != null: pet_list_tab.checked()
		node.unchecked()
		return
	hide_all_panels()
	$"Tabs/Panels/PetSkill".visible = true


func _on_Cancle_pressed() -> void :
	queue_free()
	

func hide_all_panels():
	for pan in $"Tabs/Panels".get_children():
		pan.visible = false
