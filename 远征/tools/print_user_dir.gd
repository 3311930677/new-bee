# print_user_dir.gd —— 打印 user:// 的本机绝对路径，供回归脚本校验「测试没碰真实存档」
# 用法：godot --headless --path . -s res://tools/print_user_dir.gd
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("USER_DIR=" + ProjectSettings.globalize_path("user://"))
	quit(0)
