extends Panel

onready var level = $Panel2 / Level
onready var hp = $"Panel2/HpC/Hp"
onready var hp_num = $"Panel2/HpC/Nums"
onready var mp = $"Panel2/MpC/Mp"
onready var mp_num = $"Panel2/MpC/Nums"
onready var expc = $"Panel2/ExpC/Exp"
onready var expc_num = $"Panel2/ExpC/Nums"

onready var pet_display = $"Panel2/DisplayPet"

var StaticGameData

var data
var static_data


func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	pass

func set_data(data):
	self.data = data
	static_data = StaticGameData.get_pet_data(data["petHold"]["pet_race_id"])
	
	level.text = str("LV", data["petHold"]["level"])
	var attribute = Global.get("CalculationManage").caculate_pet(data)

	
	hp.value = attribute["hp"] / attribute["normal"]["max_hp"] * 100
	hp_num.text = str("%d/%d" % [attribute["hp"], attribute["normal"]["max_hp"]])
	
	mp.value = attribute["mp"] / attribute["normal"]["max_mp"] * 100
	mp_num.text = str("%d/%d" % [attribute["mp"], attribute["normal"]["max_mp"]])
	
	expc.value = attribute["exp"] / Global.get("CalculationManage").calculate_pet_level_exp(data["petHold"]["level"]) * 100
	expc_num.text = str("%d/%d" % [attribute["exp"], Global.get("CalculationManage").calculate_pet_level_exp(data["petHold"]["level"])])
	
	pet_display.load_data(static_data.get("img_dir", "htxjptcw"))
	
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label1.text = str("宠物忠诚度：%d/1000" % data["petHold"]["cur_loyalty"])
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label2.text = str("成长度  %d/1000" % 1000)
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label3.text = str("成长等级  0")
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label4.text = str("品质  ", Global.get("StaticGameData").get_pet_grade_text(data["petHold"]["grade"]))
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label5.text = str("种类  %s" % static_data["race"])
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label6.text = str("出战等级  ", static_data["battle_grade"])
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label7.text = str("技能悟性  ", data["petHold"]["savvy"])
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label8.text = str("成长率  %d" % data["petHold"]["growing_up"])
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label9.text = str("定身抗性  ", data["petHold"].get("fixation_res", 0))
	$Background / Background2 / ScrollContainer / VBoxContainer / Label10.text = str("昏睡抗性  ", data["petHold"].get("lethargy_res", 0))
	$Background / Background2 / ScrollContainer / VBoxContainer / Label11.text = str("混乱抗性  ", data["petHold"].get("confusion_res", 0))
	
	$Background / Background2 / ScrollContainer / VBoxContainer / Label12.text = str("技能槽数  ", data["petHold"].get("expand_skill_slot", 0))
	pass
