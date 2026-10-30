extends Node
## Сохранение партии в JSON. Пока один слот; он же автосохранение в конце дня.

const SAVE_PATH := "user://save_1.json"


## Есть ли сохранение, которое эта версия игры умеет загрузить.
func has_save() -> bool:
	return not _read().is_empty()


func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Стереть сохранение (железный режим: проигрыш не переиграть).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func load_game() -> Dictionary:
	var data := _read()
	if data.is_empty():
		push_error("Сохранения нет, оно повреждено или от другой версии")
	return data


func _read() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or int(data.get("version", 0)) != GameSession.SAVE_VERSION:
		return {}
	return data
