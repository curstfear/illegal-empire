class_name EventDeck
extends RefCounted
## События дня. Событие выбирается на день вперёд,
## и с некоторым шансом о нём заранее ходит слух.

var events: Array = []
## Сегодняшнее и завтрашнее событие (пусто — спокойный день).
var today: Dictionary = {}
var tomorrow: Dictionary = {}
## Знает ли игрок слух о завтрашнем событии.
var rumor_known: bool = false

var _balance: Dictionary


func _init(event_list: Array, balance: Dictionary) -> void:
	events = event_list
	_balance = balance


## Ночь: завтрашнее становится сегодняшним, выбираем новое завтрашнее.
func roll(rng: RandomNumberGenerator) -> void:
	today = tomorrow
	tomorrow = _pick(rng) if rng.randf() < _balance.event_chance else {}
	rumor_known = not tomorrow.is_empty() and rng.randf() < _balance.rumor_chance


func _pick(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for event: Dictionary in events:
		total += event.weight
	var roll_value := rng.randf() * total
	for event: Dictionary in events:
		roll_value -= event.weight
		if roll_value <= 0.0:
			return event
	return events.back()


func _find(id: String) -> Dictionary:
	for event: Dictionary in events:
		if event.id == id:
			return event
	return {}


func to_dict() -> Dictionary:
	return {
		"today": today.get("id", ""),
		"tomorrow": tomorrow.get("id", ""),
		"rumor_known": rumor_known,
	}


func load_dict(data: Dictionary) -> void:
	today = _find(data.today)
	tomorrow = _find(data.tomorrow)
	rumor_known = bool(data.rumor_known)
