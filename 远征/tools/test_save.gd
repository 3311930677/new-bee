@tool
extends SceneTree
func _init():
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var path = ProjectSettings.globalize_path("res://shots/test_save.png")
	var res = img.save_png(path)
	var f = FileAccess.open("res://shots/test_log.txt", FileAccess.WRITE)
	f.store_string("path=" + path + " res=" + str(res))
	f.close()
	quit()
