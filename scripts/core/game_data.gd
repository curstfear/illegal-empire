class_name GameData
## Чтение файлов данных из data/ (баланс и товары).

const BALANCE_PATH := "res://data/balance.json"
const GOODS_PATH := "res://data/goods.json"
const DISTRICTS_PATH := "res://data/districts.json"
const EVENTS_PATH := "res://data/events.json"
const ACTIVITIES_PATH := "res://data/activities.json"
const PROPERTIES_PATH := "res://data/properties.json"
const RECIPES_PATH := "res://data/recipes.json"
const CREW_PATH := "res://data/crew.json"
const GANGS_PATH := "res://data/gangs.json"
const WORLD_PATH := "res://data/world.json"


static func load_balance() -> Dictionary:
	return _load_json(BALANCE_PATH)


static func load_goods() -> Array:
	return _load_json(GOODS_PATH)


static func load_districts() -> Array:
	return _load_json(DISTRICTS_PATH)


static func load_events() -> Array:
	return _load_json(EVENTS_PATH)


static func load_activities() -> Array:
	return _load_json(ACTIVITIES_PATH)


static func load_properties() -> Array:
	return _load_json(PROPERTIES_PATH)


static func load_recipes() -> Array:
	return _load_json(RECIPES_PATH)


static func load_crew() -> Dictionary:
	return _load_json(CREW_PATH)


static func load_gangs() -> Dictionary:
	return _load_json(GANGS_PATH)


static func load_world() -> Dictionary:
	return _load_json(WORLD_PATH)


static func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("Не удалось прочитать %s" % path)
	return data
