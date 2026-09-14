extends Node
class_name RichTextContentFormat



func get_content_format(content: String):
	var face_template_res = str(Global.get("AssetsManage").get_prefix(), "assets/res/emoji/%d.png")
	var format_content = content
	for i in range(14):
		var tm = str("[img]", face_template_res % i, "[/img]")
		format_content = format_content.replacen("{m%d}" % i, tm)
	return format_content
