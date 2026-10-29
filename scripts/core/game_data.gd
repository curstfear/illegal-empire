class_name GameData
## Чтение файлов данных из data/ (баланс и товары).

const BALANCE_PATH := "res://data/balance.json"
const GOODS_PATH := "res://data/goods.json"


static func load_balance() -> Dictionary:
	return _load_json(BALANCE_PATH)


static func load_goods() -> Array:
	return _load_json(GOODS_PATH)


static func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("Не удалось прочитать %s" % path)
	return data
