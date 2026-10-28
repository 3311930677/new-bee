extends RefCounted
## Explicitly copied by the player when reporting a display problem; no save data.
static func text(parent: Node) -> String:
	var view := parent.get_viewport()
	var safe := G.ui_safe_rect(parent)
	return "远征 %s\n%s %s\n机型：%s\n窗口像素：%s\n逻辑视口：%s\n系统安全区：%s\n交互安全区：%s\n屏幕变换：%s\n缺口：%s" % [
		ProjectSettings.get_setting("application/config/version",""),OS.get_name(),OS.get_version(),OS.get_model_name(),
		parent.get_window().size,view.get_visible_rect(),DisplayServer.get_display_safe_area(),safe,
		view.get_screen_transform(),DisplayServer.get_display_cutouts()]
