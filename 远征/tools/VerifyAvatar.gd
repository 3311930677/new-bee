# VerifyAvatar.gd —— 头像回归（场景模式：godot --headless --path . res://tools/VerifyAvatar.tscn）
# 守：上传本地图片（任意比例都裁成 256 方图）/ 坏图与缺文件分支 / 切职业头像与切回上传图 /
#     存档持久化（写盘后重读仍在）/ 登录页 5 张卡（含「自定义」）/ 主页点头像能开出更换浮层。
# 上传链路是"玩家自己的图"，这里用代码临时造图，不依赖 image/ 素材。
extends Node

const AvatarPanelScript := preload("res://src/ui/AvatarPanel.gd")

const TMP_SRC := "user://verify_avatar_src.png"
const TMP_BAD := "user://verify_avatar_bad.txt"

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_avatar.json"
	_wipe(G.SAVE_PATH)
	await _run()
	_cleanup()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 造一张 400×200 的横图（非正方形，才能验证"居中裁方"真的发生了）
func _make_source() -> void:
	var img := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color("3366aa"))
	for x in 400:
		for y in 200:
			if x < 150:
				img.set_pixel(x, y, Color("cc4422"))
	img.save_png(TMP_SRC)


func _cleanup() -> void:
	_wipe(TMP_SRC)
	_wipe(TMP_BAD)
	_wipe(SAVE_TMP())
	if not G.avatar_custom.is_empty():
		_wipe(G.AVATAR_DIR + G.avatar_custom)
	G.avatar_custom = ""
	G.avatar_use_custom = false
	G._reload_avatar_texture()


func SAVE_TMP() -> String:
	return G.SAVE_PATH


func _run() -> void:
	await _verify_import()
	await _verify_switch()
	await _verify_persist()
	await _verify_panels()
	if _fails == 0:
		print("AVATAR_OK all tests passed")
	else:
		print("AVATAR_FAIL fails=%d" % _fails)


# ---------- A. 上传：裁方 + 缩到 256 + 落盘 + 立即生效 ----------
func _verify_import() -> void:
	_make_source()
	# 1. 缺文件 / 非图片：给玩家看的错误文案，不能静默成功
	_check(G.import_avatar("user://not_exist_avatar.png") != "", "缺文件应返回错误文案")
	var f := FileAccess.open(TMP_BAD, FileAccess.WRITE)
	f.store_string("this is not an image")
	f.close()
	_check(G.import_avatar(TMP_BAD) != "", "非图片文件应返回错误文案")
	_check(not G.avatar_use_custom, "失败的上传不应改变当前头像状态")

	# 2. 正常上传
	var err := G.import_avatar(TMP_SRC)
	_check(err.is_empty(), "上传本地图片应成功，实为「%s」" % err)
	_check(not G.avatar_custom.is_empty(), "上传后应记录文件名")
	_check(G.avatar_use_custom, "上传后应立刻启用自定义头像")
	var saved := G.AVATAR_DIR + G.avatar_custom
	_check(FileAccess.file_exists(saved), "头像应落盘到 %s" % saved)

	# 3. 落盘尺寸统一 256 方图（任意来源比例都收成同一规格）
	var img := Image.new()
	_check(img.load(saved) == OK, "落盘的头像应可读回")
	_check(img.get_width() == G.AVATAR_SIZE and img.get_height() == G.AVATAR_SIZE,
		"落盘头像应为 %d×%d，实为 %d×%d" % [G.AVATAR_SIZE, G.AVATAR_SIZE,
			img.get_width(), img.get_height()])

	# 4. 贴图可用
	var tex := G.custom_avatar_texture()
	_check(tex != null, "custom_avatar_texture 应返回贴图")
	if tex != null:
		_check(tex.get_width() == G.AVATAR_SIZE, "头像贴图宽度应为 %d" % G.AVATAR_SIZE)
	_check(G.has_custom_avatar(), "has_custom_avatar 应为 true")

	# 5. 再传一张：旧图应被清掉，不攒垃圾
	var first := G.avatar_custom
	await get_tree().create_timer(1.1).timeout   # 文件名带秒级时间戳，等一下避免撞名
	_make_source()
	_check(G.import_avatar(TMP_SRC).is_empty(), "第二次上传应成功")
	_check(G.avatar_custom != first, "第二次上传应写入新文件")
	_check(not FileAccess.file_exists(G.AVATAR_DIR + first), "换图后旧文件应被清理")


# ---------- B. 切换：职业头像 ↔ 自定义头像 ----------
func _verify_switch() -> void:
	G.use_role_avatar("ck")
	_check(G.avatar_id == "ck", "切到职业头像应成功")
	_check(not G.avatar_use_custom, "切职业头像后不应再使用自定义图")
	_check(G.avatar_texture() == load(G.role_icon_path("ck")), "应使用穿杨的职业头像")
	_check(G.has_custom_avatar(), "切走后上传的图应保留（还能切回来）")

	_check(G.use_custom_avatar(), "有上传图时应能切回自定义头像")
	_check(G.avatar_use_custom, "切回后应启用自定义头像")
	_check(G.avatar_texture() == G.custom_avatar_texture(), "应使用上传的图")

	# 未知职业 id 不应写坏状态，也不应返回空贴图
	G.use_role_avatar("not_exist")
	_check(G.avatar_id == "ck", "未知职业 id 不应覆盖已有选择")
	_check(G.role_icon_path("not_exist").ends_with("pojun_icon.png"), "未知职业应回落到破军头像")
	_check(G.avatar_texture() != null, "头像贴图任何时候都不该为空")


# ---------- C. 存档：写盘后重读仍在（重启游戏不丢） ----------
func _verify_persist() -> void:
	G.use_custom_avatar()
	G.save_game()
	var name_on_disk := G.avatar_custom
	# 模拟重启：清空内存状态再读档
	G.avatar_custom = ""
	G.avatar_use_custom = false
	G._reload_avatar_texture()
	G.call("_load_save")
	_check(G.avatar_custom == name_on_disk, "读档应恢复上传的头像文件名")
	_check(G.avatar_use_custom, "读档应恢复「正在使用自定义头像」")
	_check(G.custom_avatar_texture() != null, "读档后自定义头像应可用")

	# 图被系统清掉时退回职业头像，不让主页头像开天窗
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.AVATAR_DIR + name_on_disk))
	G.avatar_use_custom = true
	G._reload_avatar_texture()
	G.call("_load_save")
	_check(not G.avatar_use_custom, "文件丢失时应退回职业头像")
	_check(G.avatar_texture() != null, "退回职业头像后贴图不应为空")


# ---------- D. 界面接线：登录页卡片 / 主页入口 / 浮层上传 ----------
func _verify_panels() -> void:
	var login: Control = (load("res://src/ui/Login.tscn") as PackedScene).instantiate()
	add_child(login)
	await get_tree().process_frame
	var cards: Array = login.get("_avatar_buttons")
	_check(cards.size() == 5, "登录页应有 5 张头像卡（4 职业 + 自定义），实为 %d" % cards.size())
	var ids: Array = []
	for c in cards:
		ids.append(String(c.get_meta("avatar_id", "")))
	_check(ids.has("custom"), "登录页应有一张「自定义」上传卡")
	login.queue_free()
	await get_tree().process_frame

	# 浮层：上传入口走 do_upload（自动化绕开系统文件框）
	_make_source()
	var panel: Control = AvatarPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	_check(panel.do_upload(TMP_SRC).is_empty(), "浮层上传应成功")
	_check(G.avatar_use_custom and G.has_custom_avatar(), "浮层上传后应启用自定义头像")

	# 主页：头像贴图接上，点它能开出更换浮层，关闭后回收
	var home: Control = (load("res://src/ui/GameHome.tscn") as PackedScene).instantiate()
	add_child(home)
	await get_tree().process_frame
	var pic := home.get("_avatar_pic") as TextureRect
	_check(pic != null and pic.texture != null, "主页头像应显示当前头像贴图")
	home.call("_open_avatar_panel")
	await get_tree().process_frame
	var opened: Control = home.get("_avatar_panel") as Control
	_check(opened != null, "点主页头像应开出更换头像浮层")
	_check(home.get("_avatar_frame") != null, "主页头像外框应存在（悬停亮边用）")
	if opened != null:
		opened.emit_signal("closed")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(home.get("_avatar_panel") == null, "关闭后应回收浮层")
	home.queue_free()
	await get_tree().process_frame
