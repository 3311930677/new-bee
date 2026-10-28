extends "res://tools/FullPlayAudit.gd"
## Re-render production panels at phone aspect ratios, using an isolated fixture.
var output := "res://shots/visual_audit_20261027/responsive_before/"
var geometry: Array = []

func shot(id: String, bottom := false) -> void:
	if bottom:
		for sc in current.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = 100000
		await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+id+".png")
	var nodes: Array = []
	var controls:=current.find_children("*", "Control", true, false)
	# Global info popups live on the viewport, outside the active page tree.
	for modal in G._modals:
		controls.append_array(modal.layer.find_children("*","Control",true,false))
	for node in controls:
		if not node.is_visible_in_tree(): continue
		var rect: Rect2 = node.get_global_rect()
		if not rect.intersects(get_viewport().get_visible_rect()): continue
		var clipped := false
		var parent := node.get_parent()
		while parent != current and parent != null:
			if parent is Control and parent.clip_contents and not parent.get_global_rect().encloses(rect):
				clipped = true
				break
			parent = parent.get_parent()
		if clipped: continue
		if node is Label or node is Button or node.name=="InfoPopupPaper":
			nodes.append({"path":str(node.get_path()),"text":node.text if node is Label or node is Button else "popup_frame","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum":str(node.get_combined_minimum_size()),"class":node.get_class(),"overrun":not get_viewport().get_visible_rect().grow(1).encloses(rect)})
	geometry.append({"shot":id,"nodes":nodes})

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	# No access to the player's save: all mutations go to this run's directory.
	G.SAVE_PATH=ProjectSettings.globalize_path(output+"isolated_save.json")
	G._init_state_defaults(); G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.gm_unlocked=true; G.gm_grant_all(); G.gm_unlock_all_features(); G.gm_world_open=true
	G.player_name="沈舟"; G.selected_role="zs"; G.prog.level=35
	G.wallet={"gold":128400,"expedition":2310,"soul":860,"honor":1240}
	G.ensure_starter_pets(); G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":24},false)
	G.prog.tips_seen={"pet_raise":true,"deploy":true}
	get_window().unresizable=false
	get_window().min_size=Vector2i(300,480)
	var sizes := [Vector2i(320,640),Vector2i(480,640),Vector2i(480,800),Vector2i(480,1067)]
	for dimensions in sizes:
		get_window().size=dimensions
		get_window().content_scale_size=dimensions
		await frames()
		var tag := "%dx%d_"%[dimensions.x,dimensions.y]
		for file in ["Login","CreateRole"]:
			await clean()
			await attach(load("res://src/ui/"+file+".tscn").instantiate())
			await shot(tag+file)
		for page in ["", "growth", "growth:talent", "growth:equip", "growth:pet", "growth:mount", "growth:title", "growth:skill", "bag", "quests", "activities", "worlds", "arena", "archery", "companion", "shop", "journal", "oath", "avatar", "gacha", "exchange", "curio", "mail", "trade:city", "contract", "fishing:salt", "journey", "relic_hunt", "settings", "deploy"]:
			await home_with(page)
			# A one-time help modal should not hide the page under review.
			if page=="growth:pet":
				for modal in current.find_children("*","Control",true,false):
					if "heading" in modal and modal.heading is String and modal.heading.begins_with("灵宠养成"): modal.queue_free()
				await frames(3)
			await shot(tag+("home" if page.is_empty() else page.replace(":","_")))
			if page=="deploy":
				G.show_info_popup(current._deploy,"出征筹备 · 怎么操作",current._deploy.TIPS,current._deploy)
				await frames(4)
				await shot(tag+"deploy_help")
		await clean()
	await frames(4)
	var file:=FileAccess.open(output+"geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t")); file.close()
	Audio.stop_bgm(); Audio.set_suspended(true)
	var overruns:=[]
	for page in geometry:
		for node in page.nodes:
			if node.overrun:overruns.append({"shot":page.shot,"node":node})
	print("RESPONSIVE_CAPTURE_OK shots=%d overruns=%d"%[geometry.size(),overruns.size()])
	get_tree().quit(0 if overruns.is_empty() else 1)
