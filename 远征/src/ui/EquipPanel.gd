# EquipPanel.gd —— 装备面板（强化 + 宝石镶嵌 + 精炼洗词条）
# 武器 4 系绑人物（剑/枪/杖/锤各自独立强化线），甲/饰全人物通用；
# 当前角色对应的武器槽高亮。全部数值走 data/equip.json。
class_name EquipPanel
extends Control

signal closed

const CONTENT_W := 408.0
const SLOT_W := 62.0
# 背包宝石区：4 列 × 2 行 = 8 格一页（问题 #4；15 种宝石分 2 页）
const GEM_COLS := 4
const GEM_ROWS := 2

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const BagPanelScript := preload("res://src/ui/BagPanel.gd")
const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
var _view: Control
const Finesse := preload("res://src/ui/UIFinesse.gd")

var _sel := ""               # 当前选中槽位
var _detail: Control = null  # 详情区（重绘）
var _slots_row: Control = null
var _hint: Label = null
var _toast: Control = null
var _bag: Control = null     # 背包浮层（P04：装备面板直达）
## 宝石区两种动作：镶嵌（默认）/ 合成（3 合 1）；点同一排的宝石格在两种动作下含义不同
var _gem_mode := "socket"
var _work_tab := "enhance"  # 一次只展示一条工坊操作线，减少同屏文字竞争
## 槽位等级 Label 的直引用（问题 #14）：原来靠 get_child(0).get_child(2) 数节点，
#  缺图标时子节点数变化就取错节点、刷新时崩或被静默跳过
var _slot_lv: Dictionary = {}
var _gem_page := 0           # 背包宝石分页（问题 #4）：以前只列前 6 种，持有 15 种也选不到后面的
var _operation_until := 0

func _busy() -> bool:
	return Time.get_ticks_msec()<_operation_until

func _begin_operation() -> bool:
	if _busy(): return false
	_operation_until=Time.get_ticks_msec()+400
	get_tree().create_timer(.4).timeout.connect(func(): if is_inside_tree(): _refresh())
	return true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = G.equip_weapon_slot()
	if _sel.is_empty():
		_sel = "armor"
	_build()


func _build() -> void:
	_view = preload("res://src/ui/EquipChestView.gd").new()
	_view.host = self
	add_child(_view)

func _refresh() -> void:
	if _view!=null: _view.refresh()

func _bonus_summary(bonus: Dictionary) -> String:
	var lines := PackedStringArray()
	for pair in [["atk", "攻击"], ["def", "防御"], ["hp", "生命"]]:
		var n := int(bonus.get(String(pair[0]), 0))
		if n > 0:
			lines.append("%s +%d" % [String(pair[1]), n])
	var crit := float(bonus.get("crit", 0.0))
	if crit > 0.0:
		lines.append("暴击 +%d%%" % roundi(crit * 100.0))
	return " · ".join(lines) if not lines.is_empty() else "暂无加成"


## 宝石孔。已镶孔位可点：拆除宝石回背包（P04，修掉「只能镶不能拆」的旧问题）
func _socket_box(uid:int,gems:Array,idx:int) -> Control:
	var id:=String(gems[idx]) if idx<gems.size() else ""
	var b:=Page.GemSocket.new(G.res_tex(id) if not id.is_empty() else null)
	b.set_meta("socket_index",idx)
	b.disabled=id.is_empty()
	b.tooltip_text=G.gem_label(id)+" · 点击拆除" if not id.is_empty() else "空宝石孔"
	if not id.is_empty():b.pressed.connect(func():
		var result:=G.inv_gem_pop(uid,idx)
		_toast_msg("已拆除 "+G.gem_label(id) if result.get("ok",false) else String(result.get("err","")))
		_refresh())
	return b

func _gem_inventory() -> Array:
	var out: Array = []
	for k in G.items.keys():
		var id := String(k)
		if id.begins_with("gem_") and int(G.items[k]) > 0:
			out.append(id)
	out.sort()
	return out


## 宝石区分几页（每页 GEM_COLS×GEM_ROWS）
func gem_page_count() -> int:
	var inv := _gem_inventory()
	return maxi(1, int(ceil(float(inv.size()) / float(GEM_COLS * GEM_ROWS))))


## 当前页实际列出的宝石 id（回归用例据此断言"持有 15 种也全都翻得到"）
func gem_page_ids() -> Array:
	var inv := _gem_inventory()
	var page_size := GEM_COLS * GEM_ROWS
	var begin := _gem_page * page_size
	var out: Array = []
	for k in range(begin, mini(begin + page_size, inv.size())):
		out.append(String(inv[k]))
	return out


func _gem_chip(gid: String) -> Control:
	var b := Page.ItemCell.new()
	b.custom_minimum_size = Vector2(96,84)
	b.item_image.texture = G.res_tex(gid)
	b.heading.text = G.gem_label(gid)
	b.amount.text = "×%d" % G.item_count(gid)
	b.tooltip_text = "%s +%d · %s" % [G.gem_label(gid),G.equip_gem_value(gid),"合成" if _gem_mode=="merge" else "镶嵌"]
	b.set_meta("gem_id",gid)
	b.pressed.connect(func():
		if _gem_mode=="merge": _on_gem_merge(gid)
		else:
			var result := G.equip_socket_gem(_sel,gid)
			_toast_msg("已镶嵌" if result.get("ok",false) else String(result.get("err","")))
			_refresh())
	return b

func _affix_row(a: Dictionary, idx: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(420,44)
	var l := Page.line(Page.affix_label(a),"body")
	row.add_child(l)
	var b := UI.action("解锁" if a.get("locked",false) else "锁定","secondary")
	b.custom_minimum_size = Vector2(76,44)
	b.set_meta("affix_index",idx)
	b.pressed.connect(func(): G.equip_toggle_lock(_sel,idx); _refresh())
	row.add_child(b)
	return row

func _on_enhance() -> void:
	if not _begin_operation():return
	if G.equip_state(_sel).is_empty():
		_toast_msg("先从背包装备一件物品")
		return
	var r := G.equip_enhance(_sel)
	_present_enhance(r)

func _present_enhance(r: Dictionary) -> void:
	if not bool(r.get("ok", false)):
		_toast_msg(String(r.get("err", "")))
	elif bool(r.get("success", false)):
		_toast_msg("强化成功！+%d" % int(r.get("lv", 0)))
	else:
		_toast_msg("未成功，等级不变 · 积累%d次，下次%.1f%%" % [
			int(r.get("failures", 0)), float(r.get("next_rate", 0.0)) * 100.0])
	_refresh()
	if bool(r.get("success",false)):
		Finesse.celebrate(self,Vector2(240,330),Color("f1cc80"),180)
		Audio.sfx("reward",0.0)


func _on_refine() -> void:
	if not _begin_operation():return
	if G.equip_state(_sel).is_empty():
		_toast_msg("先从背包装备一件物品")
		return
	var r := G.equip_refine(_sel)
	_toast_msg("洗练完成" if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()
	if bool(r.get("ok",false)):
		Finesse.celebrate(self,Vector2(240,340),Color("b5a7d9"),160)


# ---------- P04：卸下 / 宝石合成 / 背包直达 ----------

func _on_unequip() -> void:
	var r := G.inv_unequip(_sel)
	_toast_msg("已卸下，装备回到背包" if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()


## 合成口径与扣费同源（data/equip.json 的 merge 段）
func _gem_merge_need() -> int:
	var mc: Dictionary = G.equip_cfg().get("merge", {})
	return maxi(2, int(mc.get("gem_merge_n", 3)))


func _gem_merge_cost() -> int:
	var mc: Dictionary = G.equip_cfg().get("merge", {})
	return maxi(0, int(mc.get("gem_merge_cost_gold", 300)))


func _on_gem_merge(gid: String) -> void:
	if not _begin_operation():return
	var r := G.inv_gem_merge(gid)
	_toast_msg("合成成功 → %s" % G.gem_label(String(r.get("gem", "")))
		if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()
	if bool(r.get("ok",false)):
		Finesse.celebrate(self,Vector2(240,370),Color("8fcdd3"),150)


func _open_bag() -> void:
	if _bag != null:
		return
	Audio.sfx("ui_open")
	_bag = BagPanelScript.new()
	_bag.set("z_index", 20)
	_bag.closed.connect(func():
		Audio.sfx("ui_close")
		_bag.queue_free()
		_bag = null
		_refresh())   # 背包里换装/拆宝石都会改动在身实例，关掉后重绘工坊
	add_child(_bag)


func _toast_msg(msg: String) -> void:
	if is_instance_valid(_toast): _toast.queue_free()
	_toast = UI.toast(self,msg)
	_toast.z_index = UI.Z_FEEDBACK
	_toast.position.y = G.ui_safe_rect(self).end.y-116

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if _bag != null:   # 背包浮层叠在上面，ESC 交给它，别一次关掉两层
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
