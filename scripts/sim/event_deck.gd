class_name EventDeck
extends RefCounted
## События дня (data/events.json). У каждого города своё событие, выбирается на день вперёд;
## изредка случается мировое — оно касается всех городов. О завтрашнем событии может ходить слух:
## в городе, где ты сейчас, — чаще, о других городах пишет газета реже.
## Фильтры события: "cities" (только в этих городах), "season" (только в это время года),
## "kind" (только в районе такого вида: market, port, night, park), "scope": "world" — мировое.
## Влияние: prices, police, customs (досмотр), flight (цена билета), а утром — heat (розыск города)
## и relation (отношение банд города).

const SEASONS: Array[String] = ["autumn", "winter", "spring", "summer"]

var events: Array = []
## Сегодняшние и завтрашние события: { город: событие } и мировое (пусто — нет).
var today: Dictionary = {}
var tomorrow: Dictionary = {}
var world_today: Dictionary = {}
var world_tomorrow: Dictionary = {}
## О каких завтрашних событиях известно заранее: { город: true }, "@world" — о мировом.
var rumors: Dictionary = {}

var _balance: Dictionary


func _init(event_list: Array, balance: Dictionary) -> void:
	events = event_list
	_balance = balance


## Время года по номеру дня: игра начинается осенью, сезон — balance.season_days дней.
func season(day: int) -> String:
	return SEASONS[floori(float(day - 1) / float(_balance.season_days)) % SEASONS.size()]


## Ночь: завтрашнее становится сегодняшним, для каждого города выбираем новое завтрашнее.
## day — номер завтрашнего дня (для времени года), here — город игрока (о нём слухи чаще).
func roll(rng: RandomNumberGenerator, cities: Array, day: int, here: String) -> void:
	today = tomorrow
	world_today = world_tomorrow
	tomorrow = {}
	rumors = {}
	var when := season(day)
	for city: String in cities:
		if rng.randf() < float(_balance.event_chance):
			var event := _pick(rng, func(e: Dictionary) -> bool: return _fits(e, city, when))
			if not event.is_empty():
				tomorrow[city] = event
				var chance := float(_balance.rumor_chance) if city == here else float(_balance.rumor_far_chance)
				if rng.randf() < chance:
					rumors[city] = true
	world_tomorrow = {}
	if rng.randf() < float(_balance.world_event_chance):
		world_tomorrow = _pick(rng, func(e: Dictionary) -> bool: return e.get("scope", "") == "world")
		if not world_tomorrow.is_empty() and rng.randf() < float(_balance.rumor_chance):
			rumors["@world"] = true


## Событие сегодня в городе (без мирового).
func today_in(city: String) -> Dictionary:
	return today.get(city, {})


func tomorrow_in(city: String) -> Dictionary:
	return tomorrow.get(city, {})


## Известен ли слух о завтрашнем событии в городе.
func rumor_known(city: String) -> bool:
	return rumors.has(city) and tomorrow.has(city)


## Все события, что действуют сегодня в городе: своё и мировое.
func active_in(city: String) -> Array:
	var result: Array = []
	if today.has(city):
		result.append(today[city])
	if not world_today.is_empty():
		result.append(world_today)
	return result


## Произведение множителя (customs, flight, police…) по событиям города сегодня.
func factor(city: String, key: String) -> float:
	var result := 1.0
	for event: Dictionary in active_in(city):
		result *= float(event.get(key, 1.0))
	return result


func _fits(event: Dictionary, city: String, when: String) -> bool:
	if event.get("scope", "") == "world":
		return false
	var cities: Array = event.get("cities", [])
	if not cities.is_empty() and not cities.has(city):
		return false
	return String(event.get("season", "")) in ["", when]


func _pick(rng: RandomNumberGenerator, allowed: Callable) -> Dictionary:
	var pool := events.filter(allowed)
	var total := 0.0
	for event: Dictionary in pool:
		total += float(event.weight)
	if total <= 0.0:
		return {}
	var roll_value := rng.randf() * total
	for event: Dictionary in pool:
		roll_value -= float(event.weight)
		if roll_value <= 0.0:
			return event
	return pool.back()


func find(id: String) -> Dictionary:
	for event: Dictionary in events:
		if event.id == id:
			return event
	return {}


func _ids(by_city: Dictionary) -> Dictionary:
	var result := {}
	for city: String in by_city:
		result[city] = by_city[city].id
	return result


func _events(ids: Dictionary) -> Dictionary:
	var result := {}
	for city: String in ids:
		var event := find(String(ids[city]))
		if not event.is_empty():
			result[city] = event
	return result


func to_dict() -> Dictionary:
	return {
		"today": _ids(today),
		"tomorrow": _ids(tomorrow),
		"world_today": world_today.get("id", ""),
		"world_tomorrow": world_tomorrow.get("id", ""),
		"rumors": rumors.keys(),
	}


## Старые сохранения (до этапа 10): одно событие на всех — достаётся городу, где был игрок.
func load_dict(data: Dictionary, old_city: String) -> void:
	if data.today is Dictionary:
		today = _events(data.today)
		tomorrow = _events(data.tomorrow)
	else:
		today = {}
		tomorrow = {}
		if find(String(data.today)).size() > 0:
			today[old_city] = find(String(data.today))
		if find(String(data.tomorrow)).size() > 0:
			tomorrow[old_city] = find(String(data.tomorrow))
	world_today = find(String(data.get("world_today", "")))
	world_tomorrow = find(String(data.get("world_tomorrow", "")))
	rumors = {}
	for city: Variant in data.get("rumors", [old_city] if data.get("rumor_known", false) else []):
		rumors[String(city)] = true
