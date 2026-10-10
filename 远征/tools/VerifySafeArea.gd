extends Node
const Safe:=preload("res://src/ui/UiSafeArea.gd")
var _fails:=0
func _check(ok:bool,reason:String)->void:
	if not ok:
		_fails+=1
		push_error("FAIL: "+reason)
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_safe_area.json"
	G._init_state_defaults()
	G.save_locked=false
	var view:=Rect2(0,0,480,1067)
	var transform:=Transform2D(Vector2(2.25,0),Vector2(0,2.25),Vector2(0,12))
	var expected:=Rect2(0,40,480,1000)
	_check(Safe.from_screen(view,transform*expected,transform).is_equal_approx(expected),"设备像素安全区转换考虑缩放与屏幕偏移")
	_check(Safe.from_screen(view,Rect2(),transform)==view,"空安全区回退完整视口")
	_check(Safe.from_screen(view,Rect2(0,0,500,500),Transform2D(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO))==view,"无效变换不导致UI消失")
	# A rider preview is a Node2D beside Control UI, so both must use the same transform.
	var mixed:=Control.new()
	var actor:=Node2D.new()
	actor.position=Vector2(240,430)
	actor.scale=Vector2(1.35,1.35)
	mixed.add_child(actor)
	var safe_mixed:=Rect2(8,36,464,740)
	Safe.fit_page(mixed,safe_mixed)
	var factor:=740.0/800.0
	var origin:=safe_mixed.position+(safe_mixed.size-Vector2(480,800)*factor)*.5
	_check(actor.position.is_equal_approx(origin+Vector2(240,430)*factor),"营帐角色与界面共用安全区变换")
	Safe.restore_page(mixed)
	_check(actor.position==Vector2(240,430) and actor.scale.is_equal_approx(Vector2(1.35,1.35)),"重新布局前恢复原始位置与缩放")
	mixed.free()
	var login:=preload("res://src/ui/Login.tscn").instantiate() as Control
	add_child(login)
	await get_tree().process_frame
	Safe.fit_page(login,safe_mixed)
	_check(safe_mixed.encloses(login._paper.get_global_rect()),"登录纸页在模拟手机安全区内")
	login._layout_page()
	Safe.fit_page(login,safe_mixed)
	_check(safe_mixed.encloses(login._paper.get_global_rect()),"登录重排后不累计缩放")
	login.queue_free()
	await get_tree().process_frame
	for height in [800,1067]:
		view=Rect2(0,0,480,height)
		var safe:=Rect2(8,36,464,height-60)
		var page:=preload("res://src/ui/OathPanel.gd").new()
		add_child(page)
		await get_tree().process_frame
		Safe.fit_page(page,safe)
		for child in page.get_children():
			if child is PanelContainer:
				var rect:Rect2=child.get_global_rect()
				_check(safe.encloses(rect),"短屏和长屏誓约纸页在模拟异形屏安全区内")
				var before:=rect
				Safe.fit_page(page,safe)
				_check(child.get_global_rect().is_equal_approx(before),"重复安全区布局不累计平移或缩放")
		page.queue_free()
		await get_tree().process_frame
	var run:=RunState.new()
	run.setup({"role_id":"zs","theme":"forest","level":20,"seed":882})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	view=map.get_viewport_rect()
	var safe:=Rect2(8,36,view.size.x-16,view.size.y-60)
	Safe.fit_hud(map._hud,safe,view)
	for control in [map._joy,map._minimap,map._pet_btn,map._sprint_btn,map._mount_btn]:
		_check(safe.encloses(control.get_global_rect()),"地图摇杆、小地图与行动按钮避开顶端缺口及底部手势区")
	var old:=map._joy.position
	Safe.fit_hud(map._hud,safe,view)
	_check(map._joy.position==old,"HUD适配重复调用不漂移")
	map.queue_free()
	await get_tree().process_frame
	BattleScene.pending_cfg={"presentation":"classic_inline","seed":881,"ally":{"role_id":"zs","level":5,"traits":[],"potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1}}
	var battle:=preload("res://src/battle/BattleScene.tscn").instantiate() as BattleScene
	add_child(battle)
	await get_tree().process_frame
	view=battle.get_viewport_rect()
	safe=Rect2(8,36,view.size.x-16,view.size.y-60)
	battle._chest.layout(safe)
	await get_tree().process_frame
	_check(battle._cmd_root!=null,"安全区用例必须构建实际经典战斗操作栏")
	if battle._cmd_root!=null:
		for child in battle._cmd_root.get_children():
			if child is Control and child.mouse_filter==Control.MOUSE_FILTER_STOP:
				_check(safe.encloses(child.get_global_rect()),"战斗攻击、技能、道具和撤退按钮在安全区内")
		_check(safe.encloses(battle._chest._buttons.flee.get_global_rect()),"撤退入口在顶端安全区内")
	battle.queue_free()
	await get_tree().process_frame
	print("SAFE_AREA_OK desktop_and_simulated_cutouts" if _fails==0 else "SAFE_AREA_FAIL count=%d"%_fails)
	get_tree().quit(0 if _fails==0 else 1)
