# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
var _page: Control
var _stage: Control
var _tray: Control
var _row_scroll: ScrollContainer
var _heading: Control
var _back: Button
var _hero: Control
var _hero_name: Label
var _pool: TextureRect
var _stats:VBoxContainer
var _recommend:Button
var _next_id:=""

const CONTENT_W := 408.0
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const TalentPanelScript := preload("res://src/ui/TalentPanel.gd")
const EquipPanelScript := preload("res://src/ui/EquipPanel.gd")
const PetRaisePanelScript := preload("res://src/ui/PetRaisePanel.gd")
const SkillBookPanelScript := preload("res://src/ui/SkillBookPanel.gd")
const MountPanelScript := preload("res://src/ui/MountPanel.gd")
const TitlePanelScript := preload("res://src/ui/TitlePanel.gd")

var _rows: Array = []        # 各行状态 Label 引用（刷新用）
var _sub: Control = null     # 当前打开的子面板
var _toast: Label = null
var _summary: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	theme = UI.theme()
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	_stage = Page.Stage.new()
	_page.add_child(_stage)
	_pool = Page.picture(UI.texture("stage_pool"),Vector2(256,60))
	_pool.modulate.a = .35
	_page.add_child(_pool)
	_hero = Field.portrait(G.selected_role,Vector2.ZERO,Vector2(200,200))
	_page.add_child(_hero)
	_hero_name = UI.label("%s · Lv.%d" % [G.get_role(G.selected_role).get("name","旅人"),int(G.prog.get("level",1))],"section")
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_hero_name)
	_stats=VBoxContainer.new()
	_stats.add_theme_constant_override("separation",4)
	_page.add_child(_stats)
	_back = UI.action("‹","back")
	_back.tooltip_text = "返回营帐"
	_back.pressed.connect(_close)
	_page.add_child(_back)
	_heading = UI.label("人物养成","title")
	_page.add_child(_heading)
	_tray = UI.Tray.new()
	_page.add_child(_tray)
	_recommend=Page.GrowthRow.new("下一步","talent")
	_recommend.set_meta("recommendation",true)
	_recommend.custom_minimum_size.y=44
	_recommend.pressed.connect(func():if not _next_id.is_empty():_open(_next_id))
	_page.add_child(_recommend)
	_summary=_recommend.heading
	_row_scroll = Page.scroll()
	_page.add_child(_row_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",4)
	_row_scroll.add_child(box)
	for group in [["修习与装备",["equip","talent","skill"]],["同行与荣誉",["pet","mount","title"]]]:
		if group[0]=="同行与荣誉":
			var gap:=Control.new();gap.custom_minimum_size.y=12;box.add_child(gap)
		var section := UI.label(group[0],"caption",UI.AGED)
		section.custom_minimum_size.y = 24
		box.add_child(section)
		for id in group[1]:
			box.add_child(_entry_row({"equip":"装备","talent":"天赋","skill":"技能书","pet":"宠物","mount":"坐骑","title":"称号"}[id],id,id))
	_refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout(safe_override: Rect2 = Rect2()) -> void:
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x := safe.position.x
	var y := safe.position.y
	var top := safe.end.y-472
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_back,Vector2(x+8,y+6),Vector2(44,44))
	Page.place(_heading,Vector2(x+64,y+8),Vector2(300,40))
	Page.place(_pool,Vector2(x+196,top-58),Vector2(256,60))
	var stage_start:=maxf(y+60,top-232)
	var hero_extent:=minf(200,top-stage_start-28)
	Page.place(_hero,Vector2(x+216,top-28-hero_extent),Vector2(hero_extent,hero_extent))
	Page.place(_hero_name,Vector2(x+192,top-42),Vector2(256,30))
	Page.place(_stats,Vector2(x+16,stage_start),Vector2(172,184))
	Page.place(_tray,Vector2(x,top),Vector2(safe.size.x,safe.end.y-top))
	Page.place(_recommend,Vector2(x+16,top+8),Vector2(safe.size.x-32,44))
	Page.place(_row_scroll,Vector2(x+16,top+60),Vector2(safe.size.x-32,safe.end.y-top-72))

func _entry_row(words: String, icon: String, id: String) -> Control:
	var row := Page.GrowthRow.new(words,icon)
	row.name = "Growth_"+id
	row.set_meta("growth_id",id)
	row.tooltip_text = "打开"+words
	_rows.append({"id":id,"label":row.status,"action":row,"words":words})
	row.pressed.connect(func(): _open(id))
	return row

func _refresh() -> void:
	var left := G.talent_points_left()
	Page.clear(_stats)
	var base:=TableCache.role_stats(G.selected_role,int(G.prog.get("level",1)))
	var bonus:=G.growth_bonuses(G.selected_role)
	var values:Dictionary={} if base.is_empty() else {"生命":TraitSystem.role_max_hp(G.selected_role,int(G.prog.get("level",1)),[],bonus),"攻击":maxi(1,int(float(base.get("atk",0))*(1+float(bonus.get("atk_pct",0)))+float(bonus.get("atk_add",0)))),"防御":maxi(0,int(float(base.get("def",0))*(1+float(bonus.get("def_pct",0)))+float(bonus.get("def_add",0)))),"暴击":"%.1f%%"%(clampf(float(base.get("crit",0))+float(bonus.get("crit_add",0)),0,.95)*100),"速度":"%.2f"%(float(base.get("spd",1))*(1+float(bonus.get("spd_pct",0))))}
	_stats.add_child(UI.label("尚未选择人物" if base.is_empty() else "人物属性","caption",UI.AGED))
	for key in values:
		var row:=HBoxContainer.new();_stats.add_child(row)
		var label:=UI.label(key,"caption",UI.AGED);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var value:=UI.label(str(values[key]),"number");value.add_theme_font_size_override("font_size",16);row.add_child(value)
	_next_id="talent" if left>0 else ""
	_summary.text = "尚有 %d 点天赋待分配" % left if left > 0 else "天赋点已分配完毕"
	_summary.add_theme_color_override("font_color",UI.GOLD if left>0 else UI.AGED)
	var tip := find_child("GrowthBonusSummary",true,false) as Label
	if tip != null:
		tip.text = "装备强化 %d / %d / %d  ·  灵宠 %d 只\n精研招式与同行伙伴，整备下一段旅程。" % [int(G.equip_state(G.equip_weapon_slot()).get("lv",0)),int(G.equip_state("armor").get("lv",0)),int(G.equip_state("accessory").get("lv",0)),G.owned_pets().size()]
	for r in _rows:
		var l := (r as Dictionary)["label"] as Label
		match String((r as Dictionary)["id"]):
			"talent":
				l.text = "可分配 %d 点" % G.talent_points_left()
			"equip":
				var ws := G.equip_weapon_slot()
				l.text = "武%d / 甲%d / 饰%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收 %d / %d" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "精研 %d 门" % n
			"mount":
				var mid := G.mount_active()
				l.text = ("骑乘：%s" % String(G.mount_cfg(mid).get("name", ""))) if not mid.is_empty() else "尚未骑乘"
			"title":
				var tid := G.title_active()
				l.text = ("佩戴：%s" % String(G.title_cfg(tid).get("name", ""))) if not tid.is_empty() else "未佩戴"

		var action: Button = r.action
		action.actionable = String(r.id)=="talent" and left>0
		action.next_action.text = "分配天赋" if action.actionable else ""
		if String(r.id)=="equip":
			for slot in [G.equip_weapon_slot(),"armor","accessory"]:
				var cost := G.equip_enhance_cost(slot)
				if not G.equip_state(slot).is_empty() and int(G.equip_state(slot).get("lv",0))<G.equip_enhance_max() and int(G.wallet.get("gold",0))>=int(cost.gold) and G.item_count(String(cost.item))>=int(cost.item_n):
					action.actionable = true
					action.next_action.text = "可强化"
					if left<=0:
						_next_id="equip"
						_summary.text = "行前推荐 · 装备材料已齐，可以强化"
						_summary.add_theme_color_override("font_color",UI.GOLD)
					break
		action.queue_redraw()
		(r as Dictionary)["action"].tooltip_text = "打开" + String((r as Dictionary)["words"]) + " · " + l.text
	_recommend.disabled=_next_id.is_empty()
	_recommend.actionable=not _next_id.is_empty()
	_recommend.image.texture=Page.texture(_next_id if not _next_id.is_empty() else "equip")
	_recommend.status.text=""
	_recommend.next_action.text=""
	_summary.text="下一步 · 天赋可分配 %d 点"%left if _next_id=="talent" else "下一步 · 装备材料已齐" if _next_id=="equip" else "装备强化 %d/%d/%d · 灵宠 %d/%d"%[int(G.equip_state(G.equip_weapon_slot()).get("lv",0)),int(G.equip_state("armor").get("lv",0)),int(G.equip_state("accessory").get("lv",0)),G.owned_pets().size(),TableCache.pets().size()]
	_summary.add_theme_font_size_override("font_size",14)
	_recommend.queue_redraw()


# ---------- 子面板 ----------
func _open(id: String) -> void:
	if _sub != null:
		return
	match id:
		"talent":
			_sub = TalentPanelScript.new()
		"equip":
			_sub = EquipPanelScript.new()
		"pet":
			_sub = PetRaisePanelScript.new()
		"skill":
			_sub = SkillBookPanelScript.new()
		"mount":
			_sub = MountPanelScript.new()
		"title":
			_sub = TitlePanelScript.new()
	if _sub == null:
		return
	Audio.sfx("ui_open")
	_sub.set("z_index", 10)
	_sub.connect("closed", func():
		Audio.sfx("ui_close")
		_sub.queue_free()
		_sub = null
		_set_page_visible(true)
		_refresh())
	_set_page_visible(false)
	add_child(_sub)


func _set_page_visible(shown: bool) -> void:
	for child in get_children():
		if child is CanvasItem and child != _sub:
			child.visible = shown

func _close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_close()
		get_viewport().set_input_as_handled()
