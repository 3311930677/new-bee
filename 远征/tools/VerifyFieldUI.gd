extends Node
const Field := preload("res://src/ui/FieldUI.gd")
const Activities := preload("res://src/ui/ActivityPanel.gd")
var _fails := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_field_ui.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.player_name = "长昵称一二三四五六七八九十"
	G.wallet = {"gold":999999999,"expedition":999999999,"soul":999999999,"honor":999999999}
	for height in [800,1067]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480,height)
		add_child(viewport)
		var home := preload("res://src/ui/GameHome.tscn").instantiate()
		viewport.add_child(home)
		await get_tree().process_frame
		await get_tree().process_frame
		for ctl in _actions(home):
			_check(Rect2(Vector2.ZERO,Vector2(480,height)).encloses(ctl.get_global_rect()),"Home action must fit at %d: %s" % [height,ctl.caption.text])
			_check(ctl.size.y>=44,"Touch area must be at least 44 high")
		var wallet: HBoxContainer
		for child in home.get_children():
			if child is HBoxContainer: wallet=child
		_check(wallet!=null and wallet.get_global_rect().end.x<=456,"Four large currencies must fit inside page margin")
		if wallet!=null:
			for child in wallet.get_children():
				if child is Control and child.visible:
					_check(child.get_global_rect().end.x<=456,"Currency content must fit, including nine digit amounts")
		for words in ["世界","背包","养成","图鉴","竞技","召唤","兑换","活动"]:
			var action := _action(home,words)
			_check(action!=null,"Missing home action: "+words)
			if action!=null:
				action.gui_input.emit(_click())
				await get_tree().process_frame
				var key: String = {"世界":"_worlds","背包":"_bag","养成":"_growth","图鉴":"_codex","竞技":"_arena","召唤":"_gacha","兑换":"_exchange","活动":"_activities"}[words]
				var panel: Control = home.get(key)
				_check(panel!=null,"Visible home action must open its actual page: "+words)
				if panel!=null:
					panel.closed.emit()
					await get_tree().process_frame
					_check(home.get(key)==null,"Closing page must clear reference: "+words)
		G.wallet.expedition=1011
		home._open_growth()
		home._close_overlay_with_escape()
		await get_tree().process_frame
		_check(home._growth==null and home._anim.visible,"Escape must restore the home character after closing growth")
		home._open_growth()
		home._growth._open("skill")
		var nested: Control=home._growth._sub
		var nested_sid:=String(nested._sids[0])
		var nested_cost:=G.skill_upgrade_cost(nested_sid)
		nested._on_upgrade(nested_sid)
		nested.closed.emit()
		await get_tree().process_frame
		home._growth.closed.emit()
		await get_tree().process_frame
		_check(home._wallet_row.tooltip_text.contains("远征币：%d" % (1011-nested_cost)),"Returning from upgrade must refresh exact home balance")
		var amount_words: Array[String]=[]
		for child in home._wallet_row.get_children():
			if child is Label and child.visible: amount_words.append(child.text)
		_check(amount_words.has(str(1011-nested_cost)),"Visible home balance must refresh after spending")
		G.wallet.expedition=999999999
		home._open_activities()
		var activities: Control = home._activities
		_check(activities._events.is_empty(),"Default activity page must not invent active events")
		home._close_overlay_with_escape()
		await get_tree().process_frame
		_check(home._activities==null and home._anim.visible,"Activity back must restore home")
		var event_page := Activities.new()
		event_page.events_override = [{"id":"test","title":"活动排版回归", "summary":"这是临时测试配置，不是开放活动。", "body":["长说明。".repeat(240),"第二段说明"],"starts_at":2000,"ends_at":3000}]
		viewport.add_child(event_page)
		await get_tree().process_frame
		var before_progress := JSON.stringify(G.prog)
		var before_wallet := JSON.stringify(G.wallet)
		var entry: Control = event_page._content.find_child("Event_test",true,false)
		_check(entry!=null,"Configured event must appear in activity list")
		if entry!=null: entry.gui_input.emit(_click())
		_check(event_page._detail_id=="test","Activity card must open its own detail")
		_check(event_page._back.get_global_rect().end.y<=height,"Activity return action must fit on phone")
		event_page.go_back()
		_check(event_page._detail_id.is_empty(),"Activity detail back must return to list")
		_check(JSON.stringify(G.prog)==before_progress and JSON.stringify(G.wallet)==before_wallet,"Activities must not change progress or balances")
		event_page.queue_free()
		home.queue_free()
		viewport.queue_free()
		await get_tree().process_frame
	for role_id in ["zs","ck","fs","fz"]:
		G.selected_role=role_id
		G.wallet["expedition"]=9999
		G.prog["skills"]={}
		var book := preload("res://src/ui/SkillBookPanel.gd").new()
		add_child(book)
		await get_tree().process_frame
		_check(book._tabs.size()==5,"Each profession must expose five named skills")
		for i in book._tabs.size():
			book._tabs[i].gui_input.emit(_click())
			_check(book._deck.current==i,"Named tab must select actual skill")
			_check(book._tabs[i].selected,"Selected tab must follow PageDeck")
		var preview: Node = book._deck._made[4].get_node_or_null("SkillPreview")
		_check(preview!=null,"Selected skill must expose a cosmetic animation preview")
		if preview!=null:
			var preview_wallet := JSON.stringify(G.wallet)
			var preview_progress := JSON.stringify(G.prog)
			preview._play()
			await get_tree().process_frame
			_check(JSON.stringify(G.wallet)==preview_wallet and JSON.stringify(G.prog)==preview_progress,"Playing a preview must not spend resources or change real progress")
			for page_index in book._deck._made:
				var other: Node = book._deck._made[page_index].get_node_or_null("SkillPreview")
				if int(page_index)!=4 and other!=null:
					_check(other.process_mode==Node.PROCESS_MODE_DISABLED,"Hidden skill previews must stop processing")
		var sid := String(book._sids[4])
		var lv := G.skill_level(sid)
		var before := int(G.wallet.expedition)
		var cost := G.skill_upgrade_cost(sid)
		var upgrade := _action(book._deck._made[4],"研习升级 · %d 远征币" % cost)
		_check(upgrade!=null,"Current skill must have a real upgrade action")
		if upgrade!=null: upgrade.gui_input.emit(_click())
		_check(G.skill_level(sid)==lv+1,"Click must upgrade the selected skill")
		_check(int(G.wallet.expedition)==before-cost,"Upgrade must deduct actual cost")
		_check(book._deck.current==4 and book._tabs[4].selected,"Upgrade must preserve selected named tab")
		G.wallet.expedition=0
		book._refresh(true)
		var blocked := _action_prefix(book._deck._made[4],"远征币不足")
		_check(blocked!=null and blocked.disabled,"Insufficient currency must disable upgrade")
		if blocked!=null: blocked.gui_input.emit(_click())
		_check(G.skill_level(sid)==lv+1,"Disabled action must not mutate progress")
		G.prog.skills[sid]=G.skill_max_level()
		book._refresh(true)
		var capped := _action(book._deck._made[4],"研习已满")
		_check(capped!=null and capped.disabled,"Maxed skill must disable upgrade")
		book.queue_free()
		await get_tree().process_frame
	_check(Activities.event_status({"starts_at":100,"ends_at":200},99)=="即将开启","Upcoming activity status")
	_check(Activities.event_status({"starts_at":100,"ends_at":200},100)=="进行中","Start boundary inclusive")
	_check(Activities.event_status({"starts_at":100,"ends_at":200},200)=="已结束","End boundary exclusive")
	_check(Activities.event_status({"enabled":false},150)=="未开放","Disabled activity status")
	_check(Activities.event_status({"starts_at":200,"ends_at":100},150)=="未开放","Invalid date range stays closed")
	_check(Activities.valid_events([null,{}, {"id":"a","title":"A"}, {"id":"a","title":"duplicate"},{"id":"b","title":"hidden","visible":false}]).size()==1,"Invalid, duplicate and hidden activity records must be skipped")
	print("FIELD_UI_OK all actions, roles, currency, activities and skill states" if _fails==0 else "FIELD_UI_FAIL %d" % _fails)
	get_tree().quit(0 if _fails==0 else 1)

func _actions(node: Node) -> Array:
	var out: Array=[]
	if node is Field.Action: out.append(node)
	for child in node.get_children(): out.append_array(_actions(child))
	return out

func _action(node: Node,words: String) -> Control:
	for b in _actions(node):
		if b.caption.text==words: return b
	return null

func _action_prefix(node: Node,words: String) -> Control:
	for b in _actions(node):
		if b.caption.text.begins_with(words): return b
	return null

func _click() -> InputEventMouseButton:
	var ev:=InputEventMouseButton.new()
	ev.button_index=MOUSE_BUTTON_LEFT
	ev.pressed=true
	return ev

func _check(ok: bool,words: String) -> void:
	if not ok:
		_fails+=1
		push_error("FAIL: "+words)
