class_name Market
extends RefCounted
## Рынок одного города: цены товаров и их изменение по дням.
## Цена = базовая × коэффициент. Коэффициент каждый день гуляет случайно
## и тянется обратно к 1.0, чтобы цены не улетали навсегда.

var goods: Array = []
var factors: Dictionary = {}
var previous_prices: Dictionary = {}

var _reversion: float
var _min_factor: float
var _max_factor: float
var _sell_spread: float


func _init(goods_list: Array, balance: Dictionary) -> void:
	goods = goods_list
	_reversion = balance.price_reversion
	_min_factor = balance.min_price_factor
	_max_factor = balance.max_price_factor
	_sell_spread = balance.sell_spread
	for good: Dictionary in goods:
		factors[good.id] = 1.0
		previous_prices[good.id] = buy_price(good.id)


func get_good(id: String) -> Dictionary:
	for good: Dictionary in goods:
		if good.id == id:
			return good
	return {}


## Сколько стоит купить 1 штуку.
func buy_price(id: String) -> int:
	return maxi(1, roundi(get_good(id).base_price * factors[id]))


## Сколько дадут за 1 штуку (рынок берёт себе наценку).
func sell_price(id: String) -> int:
	return maxi(1, floori(buy_price(id) * _sell_spread))


## Новые цены на следующий день.
func roll_day(rng: RandomNumberGenerator) -> void:
	for good: Dictionary in goods:
		var id: String = good.id
		previous_prices[id] = buy_price(id)
		var factor: float = factors[id]
		factor += (1.0 - factor) * _reversion + rng.randfn(0.0, good.volatility)
		factors[id] = clampf(factor, _min_factor, _max_factor)


func to_dict() -> Dictionary:
	return { "factors": factors.duplicate(), "previous_prices": previous_prices.duplicate() }


func load_dict(data: Dictionary) -> void:
	for id: String in data.factors:
		if factors.has(id):
			factors[id] = float(data.factors[id])
			previous_prices[id] = int(data.previous_prices.get(id, buy_price(id)))
