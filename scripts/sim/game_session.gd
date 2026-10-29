class_name GameSession
extends RefCounted
## Одна партия: деньги, долг ростовщику, карман с товаром, день, рынок.
## Только логика и числа, никаких узлов сцены — так её легко тестировать и сохранять.

enum Status { PLAYING, LOST, WON }

const SAVE_VERSION := 1

var balance: Dictionary
var market: Market
var rng := RandomNumberGenerator.new()

var day: int = 1
var money: int
var debt: int
var status: Status = Status.PLAYING
## Срок ближайшего платежа (номер дня, в конце которого проверяем).
var next_payment_day: int
## Сколько заплачено ростовщику с прошлого срока.
var paid_this_period: int = 0
## Сколько штук каждого товара в кармане и сколько за них заплачено всего.
var inventory: Dictionary = {}
var spent_on: Dictionary = {}


func _init(balance_data: Dictionary, goods: Array, seed_value: int = 0) -> void:
	balance = balance_data
	market = Market.new(goods, balance)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	money = balance.start_money
	debt = balance.start_debt
	next_payment_day = balance.payment_interval_days
	for good: Dictionary in goods:
		inventory[good.id] = 0
		spent_on[good.id] = 0


## Сколько штук можно купить на все деньги.
func max_affordable(id: String) -> int:
	return money / market.buy_price(id)


func buy(id: String, amount: int) -> bool:
	var cost := market.buy_price(id) * amount
	if status != Status.PLAYING or amount <= 0 or cost > money:
		return false
	money -= cost
	inventory[id] += amount
	spent_on[id] += cost
	return true


func sell(id: String, amount: int) -> bool:
	if status != Status.PLAYING or amount <= 0 or amount > inventory[id]:
		return false
	spent_on[id] -= roundi(float(spent_on[id]) * amount / inventory[id])
	inventory[id] -= amount
	money += market.sell_price(id) * amount
	return true


## Средняя цена, по которой куплен товар в кармане (0, если пусто).
func average_cost(id: String) -> int:
	if inventory[id] == 0:
		return 0
	return roundi(float(spent_on[id]) / inventory[id])


## Сколько ещё нужно внести до ближайшего срока.
func payment_left() -> int:
	return maxi(0, mini(balance.payment_min, debt) - paid_this_period)


## Заплатить ростовщику. Возвращает, сколько реально ушло.
func pay(amount: int) -> int:
	if status != Status.PLAYING:
		return 0
	var paid := mini(amount, mini(money, debt))
	if paid <= 0:
		return 0
	money -= paid
	debt -= paid
	paid_this_period += paid
	if debt == 0:
		status = Status.WON
	return paid


## Закрыть день: проценты, проверка платежа, новые цены.
## Возвращает отчёт: список [ключ_перевода, аргументы].
func end_day() -> Array:
	var report: Array = []
	if status != Status.PLAYING:
		return report
	if day % 7 == 0:
		var interest := roundi(debt * float(balance.weekly_interest))
		debt += interest
		report.append(["LOG_INTEREST", [interest]])
	if day == next_payment_day:
		if payment_left() > 0:
			status = Status.LOST
			report.append(["LOG_PAYMENT_MISSED", []])
			return report
		report.append(["LOG_PAYMENT_OK", []])
		next_payment_day += int(balance.payment_interval_days)
		paid_this_period = 0
	market.roll_day(rng)
	report.insert(0, ["LOG_DAY_ENDED", [day]])
	day += 1
	return report


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"money": money,
		"debt": debt,
		"status": status,
		"next_payment_day": next_payment_day,
		"paid_this_period": paid_this_period,
		"inventory": inventory.duplicate(),
		"spent_on": spent_on.duplicate(),
		"rng_state": str(rng.state),
		"market": market.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	day = int(data.day)
	money = int(data.money)
	debt = int(data.debt)
	status = int(data.status) as Status
	next_payment_day = int(data.next_payment_day)
	paid_this_period = int(data.paid_this_period)
	for id: String in inventory:
		inventory[id] = int(data.inventory.get(id, 0))
		spent_on[id] = int(data.spent_on.get(id, 0))
	rng.state = int(data.rng_state)
	market.load_dict(data.market)
