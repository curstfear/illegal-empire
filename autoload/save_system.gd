extends Node
## Сохранение партии в JSON. Пока один слот; он же автосохранение в конце дня.

const SAVE_PATH := "user://save_1.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or int(data.get("version", 0)) != GameSession.SAVE_VERSION:
		push_error("Сохранение повреждено или от другой версии")
		return {}
	return data
