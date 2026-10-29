class_name Market
extends RefCounted
## Рынок города: цены товаров по районам.
## Цена = базовая × коэф. района × дневной коэф. × (1 + давление) × событие.
## Дневной коэффициент общий для города: гуляет случайно и тянется обратно к 1.0.
## Давление — насыщение: твои продажи сбивают цену в районе, покупки поднимают; за ночь проходит.

var goods: Array = []
var districts: Array = []
## Дневной коэффициент по товарам.
var factors: Dictionary = {}
## Давление по районам: { район: { товар: число } }.
var pressure: Dictionary = {}
## Цены покупки вчера вечером — чтобы показать, выросла цена или упала.
var previous_prices: Dictionary = {}
## Влияние сегодняшнего события (пусто — события нет).
var event: Dictionary = {}

var _balance: Dictionary


func _init(goods_list: Array, district_list: Array, balance: Dictionary) -> void:
	goods = goods_list
	districts = district_list
	_balance = balance
	for good: Dictionary in goods:
		factors[good.id] = 1.0
	for district: Dictionary in districts:
		pressure[district.id] = {}
		for good: Dictionary in goods:
			pressure[district.id][good.id] = 0.0
	_remember_prices()


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
func quote_sell(district: String, id: String, amount: int) -> int:
	var total := 0
	var p: float = pressure[district][id]
	for i in amount:
		total += _sell(_price(district, id, p))
		p = _shift(p, id, -1)
	return total


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
	event = new_event
	for good: Dictionary in goods:
		var factor: float = factors[good.id]
		factor += (1.0 - factor) * _balance.price_reversion + rng.randfn(0.0, good.volatility)
		factors[good.id] = clampf(factor, _balance.min_price_factor, _balance.max_price_factor)
	for district: String in pressure:
		for id: String in pressure[district]:
			pressure[district][id] *= _balance.pressure_kept_overnight


## Множитель полиции от события в этом районе.
func event_police(district: String) -> float:
	if event.is_empty() or (event.district != "" and event.district != district):
		return 1.0
	return event.police


func _remember_prices() -> void:
	for district: Dictionary in districts:
		previous_prices[district.id] = {}
		for good: Dictionary in goods:
			previous_prices[district.id][good.id] = buy_price(district.id, good.id)


func _price(district: String, id: String, p: float) -> int:
	var price: float = get_good(id).base_price * get_district(district).prices[id] * factors[id] * (1.0 + p)
	if not event.is_empty() and (event.district == "" or event.district == district):
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
		"factors": factors.duplicate(),
		"pressure": pressure.duplicate(true),
		"previous_prices": previous_prices.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	for id: String in data.factors:
		if factors.has(id):
			factors[id] = float(data.factors[id])
	for district: String in data.pressure:
		if not pressure.has(district):
			continue
		for id: String in data.pressure[district]:
			if pressure[district].has(id):
				pressure[district][id] = float(data.pressure[district][id])
				previous_prices[district][id] = int(data.previous_prices[district][id])
