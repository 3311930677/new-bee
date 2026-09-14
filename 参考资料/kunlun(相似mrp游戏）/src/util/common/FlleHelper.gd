class_name FileHelper

const prefix = "FileHelper->"

func save(path, data):
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(to_json(data))
	file.close()

func read(path):
	var file = File.new()
	file.open(path, File.READ)
	var content: String = file.get_as_text()
	file.close()
	return str2var(content)

func save_encrypted(path, data: Dictionary, key):
	var file = File.new()
	if file.open_encrypted_with_pass(path, File.WRITE, key) != OK:
		Global.log_info(str(prefix, path, "文件保存失败"))
		return
	var js = to_json(data)
	file.store_string(js)
	file.close()

func read_encrypted(path, key):
	var file = File.new()
	if file.open_encrypted_with_pass(path, File.READ, key) != OK:
		Global.log_info(str(prefix, path, "文件读取失败"))
		return {}
	var content: String = file.get_as_text()
	file.close()
	return parse_json(content)

func file_exits(file):
	var fp: File = File.new()
	var e = fp.file_exists(file)
	fp.close()
	return e
