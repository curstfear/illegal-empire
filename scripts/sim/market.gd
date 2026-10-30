class_name Market
extends RefCounted
## Рынок мира: цены товаров по районам всех городов.
## Цена = базовая × коэф. района × дневной коэф. города × (1 + давление) × событие.
## Дневной коэффициент у каждого города свой: гуляет случайно и тянется обратно к 1.0 —
## поэтому разница цен между городами каждый день другая.
## Давление — насыщение: твои продажи сбивают цену в районе, покупки поднимают; за ночь проходит.

var goods: Array = []
var districts: Array = []
## Дневной коэффициент: { город: { товар: число } }.
var factors: Dictionary = {}
## Давление по районам: { район: { товар: число } }.
var pressure: Dictionary = {}
## Цены покупки вчера вечером — чтобы показать, выросла цена или упала.
var previous_prices: Dictionary = {}
## Влияние сегодняшнего события (пусто — события нет).
var event: Dictionary = {}
## Город, где случилось сегодняшнее событие «на весь город» ("" — везде).
var event_city: String = ""
## Цены прошлых дней для графиков: { район: { товар: [цена вечером дня, …] } }, не длиннее HISTORY_DAYS.
var history: Dictionary = {}

const HISTORY_DAYS := 14

var _balance: Dictionary


func _init(goods_list: Array, district_list: Array, balance: Dictionary) -> void:
	goods = goods_list
	districts = district_list
	_balance = balance
	for district: Dictionary in districts:
		var city := String(district.get("city", ""))
		if not factors.has(city):
			factors[city] = {}
			for good: Dictionary in goods:
				factors[city][good.id] = 1.0
	for district: Dictionary in districts:
		pressure[district.id] = {}
		history[district.id] = {}
		for good: Dictionary in goods:
			pressure[district.id][good.id] = 0.0
			history[district.id][good.id] = []
	_remember_prices()


## Цены за прошлые дни и сегодняшняя — для графика (старые слева).
func price_series(district: String, id: String) -> Array:
	var series: Array = history[district][id].duplicate()
	series.append(buy_price(district, id))
	return series


func get_good(id: String) -> Dictionary:
	for good: Dictionary in goods:
		if good.id == id:
			return good
	return {}


func get_district(id: String) -> Dictionary:
	for district: Dictionary in districts:
		if district.id == id:
			return district
	return {}


## Сколько стоит купить 1 штуку.
func buy_price(district: String, id: String) -> int:
	return _price(district, id, pressure[district][id])


## Сколько дадут за 1 штуку (рынок берёт себе наценку).
func sell_price(district: String, id: String) -> int:
	return _sell(_price(district, id, pressure[district][id]))


## Сколько стоит купить amount штук подряд: каждая следующая чуть дороже.
func quote_buy(district: String, id: String, amount: int) -> int:
	var total := 0
	var p: float = pressure[district][id]
	for i in amount:
		total += _price(district, id, p)
		p = _shift(p, id, 1)
	return total


## Сколько дадут за amount штук подряд: каждая следующая чуть дешевле.
## saturation — насколько каждая проданная штука сбивает цену (1 — как обычно, оптовик — меньше).
func quote_sell(district: String, id: String, amount: int, saturation: float = 1.0) -> int:
	var total := 0
	var p: float = pressure[district][id]
	for i in amount:
		total += _sell(_price(district, id, p))
		p = lerpf(p, _shift(p, id, -1), saturation)
	return total


## Записать оптовую продажу: давление растёт слабее (saturation < 1).
func apply_wholesale(district: String, id: String, amount: int, saturation: float) -> void:
	for i in amount:
		pressure[district][id] = lerpf(pressure[district][id], _shift(pressure[district][id], id, -1), saturation)


## Сколько штук можно купить на эти деньги.
func max_affordable(district: String, id: String, money: int) -> int:
	var count := 0
	var p: float = pressure[district][id]
	while true:
		var price := _price(district, id, p)
		if price > money:
			return count
		money -= price
		count += 1
		p = _shift(p, id, 1)
	return count


## Записать сделку: amount > 0 — купили, < 0 — продали.
func apply_trade(district: String, id: String, amount: int) -> void:
	var step := 1 if amount > 0 else -1
	for i in absi(amount):
		pressure[district][id] = _shift(pressure[district][id], id, step)


## Риск товара для подписи: 0 — легальный, 1–3 — чем выше, тем горячее.
func risk_level(id: String) -> int:
	var heat: float = get_good(id).heat
	if heat <= 0.0:
		return 0
	return 1 if heat < 1.0 else (2 if heat < 3.0 else 3)


## Ночь: запоминаем вчерашние цены, ставим событие нового дня, цены гуляют, давление спадает.
func roll_day(rng: RandomNumberGenerator, new_event: Dictionary) -> void:
	_remember_prices()
	for district: String in history:
		for id: String in history[district]:
			var days: Array = history[district][id]
			days.append(previous_prices[district][id])
			if days.size() > HISTORY_DAYS - 1:
				days.pop_front()
	event = new_event
	for city: String in factors:
		for good: Dictionary in goods:
			var factor: float = factors[city][good.id]
			factor += (1.0 - factor) * _balance.price_reversion + rng.randfn(0.0, good.volatility)
			factors[city][good.id] = clampf(factor, _balance.min_price_factor, _balance.max_price_factor)
	for district: String in pressure:
		for id: String in pressure[district]:
			pressure[district][id] *= _balance.pressure_kept_overnight


## Множитель полиции от события в этом районе.
func event_police(district: String) -> float:
	return event.police if _event_here(district) else 1.0


## Событие дня касается района: события «на весь город» — только в городе, где они случились (event_city).
func _event_here(district: String) -> bool:
	if event.is_empty():
		return false
	if event.district != "":
		return event.district == district
	return event_city == "" or get_district(district).get("city", event_city) == event_city


func _remember_prices() -> void:
	for district: Dictionary in districts:
		previous_prices[district.id] = {}
		for good: Dictionary in goods:
			previous_prices[district.id][good.id] = buy_price(district.id, good.id)


func _price(district: String, id: String, p: float) -> int:
	var d := get_district(district)
	var price: float = get_good(id).base_price * d.prices[id] * factors[String(d.get("city", ""))][id] * (1.0 + p)
	if _event_here(district):
		price *= event.prices.get(id, 1.0)
	return maxi(1, roundi(price))


func _sell(price: int) -> int:
	return maxi(1, floori(price * _balance.sell_spread))


## Давление после одной штуки: step = +1 купили, −1 продали.
func _shift(p: float, id: String, step: int) -> float:
	var limit: float = _balance.pressure_limit
	return clampf(p + step * _balance.pressure_per_depth / get_good(id).depth, -limit, limit)


func to_dict() -> Dictionary:
	return {
		"factors": factors.duplicate(true),
		"pressure": pressure.duplicate(true),
		"previous_prices": previous_prices.duplicate(true),
		"history": history.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	# Старые сохранения: один коэффициент на товар — тогда он у всех городов.
	for key: String in data.factors:
		if data.factors[key] is Dictionary:
			if factors.has(key):
				for id: String in data.factors[key]:
					if factors[key].has(id):
						factors[key][id] = float(data.factors[key][id])
		else:
			for city: String in factors:
				if factors[city].has(key):
					factors[city][key] = float(data.factors[key])
	for district: String in data.pressure:
		if not pressure.has(district):
			continue
		for id: String in data.pressure[district]:
			if pressure[district].has(id):
				pressure[district][id] = float(data.pressure[district][id])
				previous_prices[district][id] = int(data.previous_prices[district][id])
	# Истории нет в старых сохранениях — тогда графики начнутся с пустого.
	var saved_history: Dictionary = data.get("history", {})
	for district: String in saved_history:
		if not history.has(district):
			continue
		for id: String in saved_history[district]:
			if history[district].has(id):
				history[district][id] = saved_history[district][id].map(func(v: Variant) -> int: return int(v))
