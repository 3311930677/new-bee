extends Node
const C:=preload("res://src/world/TradeContracts.gd")
var fails:=0
func check(ok:bool,line:String)->void:
	if not ok:
		fails+=1
		push_error("FAIL: "+line)
func reset()->void:
	G._init_state_defaults()
	G.save_locked=false
	G.wallet.gold=10000
	G.prog.story={"step":"s29","done":["s20","s28"],"goals":{}}
	for i in range(1,29):
		var step:="s%02d"%i
		if not G.prog.story.done.has(step):G.prog.story.done.append(step)
	G.economy_state()
func site(id:String)->void:
	G.prog.main_world={"map_id":C.map_for(id)}
func button(root:Node,label:String)->Control:
	if root is Label and root.text.replace(" ","")==label.replace(" ",""):return root.get_parent() as Control
	for child in root.get_children():
		var found:=button(child,label)
		if found!=null:return found
	return null
func click(control:Control)->void:
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	control.gui_input.emit(e)
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_trade_contracts.json"
	for definition in C.templates():
		for mode in ["insured","self"]:
			reset()
			var origin:=String(definition.origin)
			var dest:=String(definition.destination)
			var template:=String(definition.id)
			site(dest)
			check(not C.sign(G,template,mode,origin).ok,"签约必须亲到原城")
			site(origin)
			check(C.sign(G,template,mode,origin).ok,"三城两模式签约")
			var id:=template+"|1"
			var record:Dictionary=C.state(G)[id]
			var locked:=int(record.payout)
			check(G.wallet.gold==9940 and C.validate(C.state(G)),"押金只扣一次且存档合法")
			check(not C.sign(G,template,mode,origin).ok,"同日同批不重签")
			G.economy_state().port_event="dredge"
			G.economy_state().day=2
			check(C.state(G)[id].payout==locked,"行情和日期不改签约报价")
			check(not C.action(G,id,"aid").ok,"异地不能核准路线")
			G.prog.main_world.map_id=String(definition.route_map)
			check(C.action(G,id,"aid").ok and not C.action(G,id,"aid").ok,"路线只核准一次")
			site(dest)
			var before:=C.snapshot(G)
			check(not C.action(G,id,"deliver",dest).ok and C.snapshot(G)==before,"缺货保留全量状态")
			for good in definition.cargo:G.items[good]=int(definition.cargo[good])+1
			var gold:=int(G.wallet.gold)
			var expected:=locked+60-(8 if mode=="insured" else 0)
			check(C.action(G,id,"deliver",dest).ok and G.wallet.gold==gold+expected,"交货款和退押一次到账")
			for good in definition.cargo:check(G.item_count(String(good))==1,"只扣合同货物")
			check(not C.action(G,id,"deliver",dest).ok,"不能重复交货")
			check(G.reload_save() and C.state(G)[id].status=="done","重载保存的已交付状态")
	reset()
	site("city_market")
	check(C.sign(G,"bridge_iron","self","city_market").ok,"第一张待办")
	site("shenyuan_market")
	check(C.sign(G,"port_salt","insured","shenyuan_market").ok,"第二张待办")
	site("frost_market")
	check(not C.sign(G,"frost_grain","self","frost_market").ok and C.active_count(G)==2,"最多两张未结单")
	site("city_market")
	G.economy_state().day=5
	check(not C.action(G,"bridge_iron|1","deliver","shenyuan_market").ok,"逾期不能交货")
	check(C.action(G,"bridge_iron|1","extend","city_market").ok and C.state(G)["bridge_iron|1"].due_day==7,"一次延期补两日")
	check(not C.action(G,"bridge_iron|1","extend","city_market").ok,"延期不重复收费")
	var before:=C.snapshot(G)
	G.SAVE_PATH="res://tools/_logs/absent_contract_parent/save.json"
	var quiet:=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed:=C.action(G,"bridge_iron|1","cancel","city_market")
	Engine.print_error_messages=quiet
	check(not failed.ok and C.snapshot(G)==before,"退单写盘失败全回滚")
	G.SAVE_PATH="res://tools/_logs/save_verify_trade_contracts.json"
	var gold:=int(G.wallet.gold)
	check(C.action(G,"bridge_iron|1","cancel","city_market").ok and G.wallet.gold==gold+30,"自担退单不扣货，退半押")
	site("shenyuan_market")
	G.economy_state().day=8
	gold=int(G.wallet.gold)
	check(C.tick(G) and G.wallet.gold==gold+52 and C.state(G)["port_salt|1"].status=="cancelled","逾期保价自动退押")
	check(C.tick(G) and G.wallet.gold==gold+52,"自动退押幂等")
	reset()
	site("city_market")
	check(C.sign(G,"bridge_iron","self","city_market").ok,"实际路线实体样本")
	G.prog.main_world.map_id="old_salt_road"
	var run:=RunState.new()
	run.setup({"theme":"forest","role_id":"zs","level":20,"seed":7})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"old_salt_road","run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	map.set_process(false)
	map.set_physics_process(false)
	var found:=false
	for entity in map._quest_entities:
		if entity.kind=="trade_contract" and entity.contract_id=="bridge_iron|1":
			found=true
			map.on_quest_entity(entity)
	check(found and C.state(G)["bridge_iron|1"].aid,"生产路线实际生成并核准合约目标")
	map.queue_free()
	await get_tree().process_frame
	site("city_market")
	var cancel_panel:=preload("res://src/ui/TradeContractsPanel.gd").new()
	add_child(cancel_panel)
	cancel_panel.open_contracts("city_market")
	await get_tree().process_frame
	var cancel_button:=button(cancel_panel,"退单")
	check(cancel_button!=null,"合约页提供真实退单按钮")
	if cancel_button!=null:
		click(cancel_button)
		check(C.state(G)["bridge_iron|1"].status=="active","第一次点击只确认，不吞押金")
		click(cancel_button)
		check(C.state(G)["bridge_iron|1"].status=="cancelled","第二次点击真实退单")
	cancel_panel.queue_free()
	await get_tree().process_frame
	reset()
	site("city_market")
	before=C.snapshot(G)
	G.save_locked=true
	check(not C.sign(G,"bridge_iron","self","city_market").ok and C.snapshot(G)==before,"锁档禁止签约")
	G.save_locked=false
	G.SAVE_PATH="res://tools/_logs/absent_contract_parent/save.json"
	Engine.print_error_messages=false
	failed=C.sign(G,"bridge_iron","self","city_market")
	Engine.print_error_messages=quiet
	check(not failed.ok and C.snapshot(G)==before,"签约写盘失败押金与账本全回滚")
	G.SAVE_PATH="res://tools/_logs/save_verify_trade_contracts.json"
	check(C.sign(G,"bridge_iron","self","city_market").ok,"生成跨进程续单样本")
	var broken:=C.state(G).duplicate(true)
	broken["bridge_iron|1"].rules.insured_fee=61
	check(not C.validate(broken),"拒绝退押条款超保证金")
	for seed_value in range(1000):
		G.economy_state().seed=seed_value
		for mode in ["insured","self"]:
			var offer:=C.quote(G,"bridge_iron",mode)
			var profit:=int(offer.profit)-(25 if mode=="self" and offer.risk else 0)-int(offer.fee)
			check(profit>=17 and profit<=55 and int(offer.max_loss)+12<60,"千种路况净利与最大损失有界")
	check(G.save_game(),"保存跨进程合约样本")
	var panel:=preload("res://src/ui/TradeContractsPanel.gd").new()
	add_child(panel)
	panel.open_contracts("city_market")
	await get_tree().process_frame
	await get_tree().process_frame
	check(panel.list.get_child_count()>1,"真实面板展示待办合约")
	if OS.get_cmdline_user_args().has("--screens"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/trade_contracts.png")
	panel.queue_free()
	await get_tree().process_frame
	print("TRADE_CONTRACTS_OK" if fails==0 else "TRADE_CONTRACTS_FAIL fails=%d"%fails)
	get_tree().quit(0 if fails==0 else 1)
