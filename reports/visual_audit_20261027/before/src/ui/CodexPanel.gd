# CodexPanel.gd —— 宠物图鉴浮层（收集进度；未收集的只给暗色剪影 + 解锁途径）
# 版式：一屏一只灵宠的大卡轮播，大图居中、稀有度外框叠在图上；
#      插画命名 <宠物id>.png（如 pet_emberling.png），缺图就留白占位并标出素材名。
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用
class_name CodexPanel
extends Control

signal closed
var _chest:Control

const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const SlideCardScript := preload("res://src/ui/SlideCard.gd")
const Craft := preload("res://src/ui/CraftUI.gd")

# 稀有度色/名全项目唯一定义在 G.gd（C6），这里只引用，不再各自复制一份
const GScript := preload("res://src/autoload/G.gd")
const RARITY_NAME := GScript.RARITY_NAME
const ROLE_NAME := {
	"tank": "护卫", "ranged_dps": "远程", "fast_dps": "速攻", "control": "控制",
	"healer": "治疗", "aoe_dps": "群攻", "poison_control": "毒控",
}
# 稀有度 → 边框素材名（frame_* 为方框空心底图，叠在宠物头像外圈）
const RARITY_FRAME := {"white": "frame_white", "blue": "frame_blue",
	"purple": "frame_purple", "gold": "frame_gold", "relic": "frame_gold"}
const RARITY_HUE := GScript.RARITY_HUE
# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
const DECK_H := 400.0
const DECK_Y := 30.0

var _deck: Control = null   # 大卡轮播（工厂模式：卡用到才建）
var _pets: Array = []       # 宠物表快照（进化后重建卡组要重读）
var _content: Control = null
var _ms_l: Label = null     # 收集里程进度行（轮次 20）
var _claim_btn: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	_pets=TableCache.pets()
	_chest=preload("res://src/ui/CollectionChestView.gd").new()
	_chest.host=self
	add_child(_chest)
	var start:=0
	for i in _pets.size():
		if not G.owns_pet(String(_pets[i].id)):start=i;break
	_deck.go(start,true)

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _card(p: Dictionary, idx: int, total: int) -> Control:
	var pid := String(p.get("id", ""))
	var owned: bool = G.owns_pet(pid)
	var rarity := String(p.get("rarity", "white"))
	var base: Dictionary = p.get("base", {})
	var hue: Color = RARITY_HUE.get(rarity, G.C_HINT)

	var lines: Array = []
	var subtitle := ""
	if owned:
		subtitle = "%s · %s" % [RARITY_NAME.get(rarity, "普通"),
			ROLE_NAME.get(String(p.get("role", "")), "未知")]
		if bool(G.pet_stat(pid).get("evolved", false)):
			lines.append("已进化 · 全属性 +25％")
		lines.append("血 %d · 攻 %d · 防 %d" % [
			int(base.get("hp", 0)), int(base.get("atk", 0)), int(base.get("def", 0))])
		var sk := PackedStringArray()
		for s in p.get("skills", []):
			sk.append(String((s as Dictionary).get("name", "")))
		if sk.size() > 0:
			lines.append("技能 · " + " · ".join(sk))
	else:
		lines.append(G.pet_unlock_text(pid))

	return SlideCardScript.new({
		"kicker": "灵 宠 %02d / %02d" % [idx + 1, total],
		"title": String(p.get("name", pid)) if owned else "？？？",
		"subtitle": subtitle,
		"art_names": (["%s_evo" % pid, "%s_art" % pid, pid]
			if owned and bool(G.pet_stat(pid).get("evolved", false)) else ["%s_art" % pid, pid]),
		"art_hint": "%s.png" % pid,
		"art_tint": hue,
		"art_fit": "contain",
		"art_dim": not owned,
		"art_stage": true,
		"editorial": true,
		"art_ratio": 0.44,
		"badge": "已结伴" if owned else "待结缘",
		"badge_color": Color("4a7a44") if owned else Color("7a7263"),
		"lines": lines,
		"footer": "← → 翻阅 · 未收集的会标出解锁途径",
	})


## 建/重建卡组（进化后数据变了要整组重建；start = 落在哪一页）
func _build_deck(start:int) -> void:
	_deck.go(start,true)

func _on_evolve() -> void:
	if _deck == null or _pets.is_empty():
		return
	var idx: int = clampi(int(_deck.current), 0, _pets.size() - 1)
	var pid := String((_pets[idx] as Dictionary).get("id", ""))
	var res := G.pet_evolve(pid)
	if bool(res.get("ok", false)):
		_build_deck(idx)
		_refresh_milestone()
		_toast("进化成功 · 全属性提升")
	else:
		_toast(String(res.get("err", "不可进化")))


## 收集里程进度行 + 领取按钮可用态。
## 文案分三种：还有可领的 / 下一档还差几只 / 全部领完。
func _refresh_milestone() -> void:
	if _ms_l == null:
		return
	var owned := G.owned_pets().size()
	var states := G.codex_milestone_state()
	var ready := G.codex_next_ready()
	if not ready.is_empty():
		_ms_l.text = "收集里程 · 已集 %d 只 · 可领取「%s」" % [owned, String(ready.get("name", ""))]
		_ms_l.add_theme_color_override("font_color", Color("8a4a3a"))
	elif states.is_empty():
		_ms_l.text = "收集里程 · 已集 %d 只" % owned
		_ms_l.add_theme_color_override("font_color", G.TEXT_MUTED)
	else:
		var nxt: Dictionary = {}
		for s in states:
			if not bool((s as Dictionary).get("claimed", false)):
				nxt = s
				break
		if nxt.is_empty():
			_ms_l.text = "收集里程 · 已集 %d 只 · 全部领取完毕" % owned
		else:
			_ms_l.text = "收集里程 · 已集 %d 只 · 再集 %d 只可领「%s」" % [
				owned, int(nxt.get("missing", 0)), String(nxt.get("name", ""))]
		_ms_l.add_theme_color_override("font_color", G.TEXT_MUTED)
	if _claim_btn != null:
		var can := not ready.is_empty()
		_claim_btn.modulate = Color.WHITE if can else Color(1, 1, 1, 0.5)
		_claim_btn.mouse_filter = Control.MOUSE_FILTER_STOP if can else Control.MOUSE_FILTER_IGNORE


func _on_claim() -> void:
	var ready := G.codex_next_ready()
	if ready.is_empty():
		_toast("暂时没有可领取的收集奖励")
		return
	var res := G.codex_claim(String(ready.get("id", "")))
	if bool(res.get("ok", false)):
		_refresh_milestone()
		var lines: Array = res.get("lines", [])
		_toast("「%s」达成 · %s" % [String(res.get("name", "")), " · ".join(lines)])
	else:
		_refresh_milestone()
		_toast(String(res.get("err", "领取失败")))


## 一句话提示（图鉴没有行内提示位，用临时金字）
func _toast(msg:String) -> void:
	var toast:=preload("res://src/ui/TravelChestUI.gd").toast(self,msg)
	toast.position.y=G.ui_safe_rect(self).end.y-116
