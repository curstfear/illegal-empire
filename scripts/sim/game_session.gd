class_name GameSession
extends RefCounted
## Одна партия: деньги (чистые и грязные), долги, карман с товаром, день, район,
## рынок, розыск, события и банк.
## Только логика и числа, никаких узлов сцены — так её легко тестировать и сохранять.
## Действия, о которых надо рассказать игроку, возвращают отчёт: список [ключ_перевода, аргументы].

enum Status { PLAYING, LOST, WON }

const SAVE_VERSION := 2
const START_DISTRICT := "market"

var balance: Dictionary
var market: Market
var police: Police
var events: EventDeck
var bank: Bank
var rng := RandomNumberGenerator.new()

var day: int = 1
var district: String = START_DISTRICT
## Чистые — от легальной торговли, грязные — от нелегальной.
var clean: int
var dirty: int
## Сколько чистых денег заработано за игру (это «честная история» для банка).
var clean_earned: int = 0
var debt: int
var status: Status = Status.PLAYING
## Срок ближайшего платежа (номер дня, в конце которого проверяем).
var next_payment_day: int
## Сколько заплачено ростовщику с прошлого срока.
var paid_this_period: int = 0
## Сколько штук каждого товара в кармане и сколько за них заплачено всего.
var inventory: Dictionary = {}
var spent_on: Dictionary = {}
## Идёт проверка полиции: { "bribe": сумма }. Пока не решена, торговать нельзя.
var pending_check: Dictionary = {}

var money: int:
	get:
		return clean + dirty


func _init(balance_data: Dictionary, goods: Array, districts: Array, event_list: Array, seed_value: int = 0) -> void:
	balance = balance_data
	market = Market.new(goods, districts, balance)
	police = Police.new(districts, balance)
	events = EventDeck.new(event_list, balance)
	bank = Bank.new(balance)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	clean = balance.start_money
	dirty = 0
	debt = balance.start_debt
	next_payment_day = balance.payment_interval_days
	for good: Dictionary in goods:
		inventory[good.id] = 0
		spent_on[good.id] = 0
	events.roll(rng)


func can_act() -> bool:
	return status == Status.PLAYING and pending_check.is_empty()


# --- Рынок ---

func buy_price(id: String) -> int:
	return market.buy_price(district, id)


func sell_price(id: String) -> int:
	return market.sell_price(district, id)


## Сколько штук можно купить на все деньги.
func max_affordable(id: String) -> int:
	return market.max_affordable(district, id, money)


func buy(id: String, amount: int) -> bool:
	if not can_act() or amount <= 0:
		return false
	var cost := market.quote_buy(district, id, amount)
	if cost > money:
		return false
	_spend(cost)
	inventory[id] += amount
	spent_on[id] += cost
	market.apply_trade(district, id, amount)
	_after_deal(id, amount)
	return true


func sell(id: String, amount: int) -> bool:
	if not can_act() or amount <= 0 or amount > inventory[id]:
		return false
	var revenue := market.quote_sell(district, id, amount)
	spent_on[id] -= roundi(float(spent_on[id]) * amount / inventory[id])
	inventory[id] -= amount
	market.apply_trade(district, id, -amount)
	if market.get_good(id).legal:
		clean += revenue
		clean_earned += revenue
	else:
		dirty += revenue
	_after_deal(id, amount)
	return true


## Средняя цена, по которой куплен товар в кармане (0, если пусто).
func average_cost(id: String) -> int:
	if inventory[id] == 0:
		return 0
	return roundi(float(spent_on[id]) / inventory[id])


## Сколько стоит весь нелегальный товар в кармане по ценам этого района.
func illegal_goods_value() -> int:
	var total := 0
	for good: Dictionary in market.goods:
		if not good.legal:
			total += sell_price(good.id) * inventory[good.id]
	return total


## Переезд в другой район. Время в пути отсчитывают часы.
func travel(to_district: String) -> bool:
	if not can_act() or to_district == district or market.get_district(to_district).is_empty():
		return false
	district = to_district
	return true


# --- Полиция ---

## После нелегальной сделки растёт розыск и может начаться проверка.
func _after_deal(id: String, amount: int) -> void:
	var good := market.get_good(id)
	if good.legal:
		return
	police.add_heat(district, good.heat * amount)
	if illegal_goods_value() == 0:
		return
	var multiplier: float = market.get_district(district).police * market.event_police(district)
	if rng.randf() < police.check_chance(district, multiplier):
		pending_check = { "bribe": roundi(balance.bribe_base + illegal_goods_value() * balance.bribe_share) }


func flee_chance() -> float:
	return police.flee_chance(district)


func can_bribe() -> bool:
	return not pending_check.is_empty() and money >= pending_check.bribe


func bribe() -> Array:
	if not can_bribe():
		return []
	_spend(pending_check.bribe)
	police.add_heat(district, balance.bribe_heat)
	var report := [["LOG_BRIBED", [pending_check.bribe]]]
	pending_check = {}
	return report


func surrender() -> Array:
	if pending_check.is_empty():
		return []
	_lose_illegal_goods()
	police.add_heat(district, -balance.surrender_heat_drop)
	pending_check = {}
	return [["LOG_SURRENDERED", []]]


func flee() -> Array:
	if pending_check.is_empty():
		return []
	pending_check = {}
	if rng.randf() < flee_chance():
		police.add_heat(district, balance.flee_heat)
		return [["LOG_FLED", []]]
	return arrest()


## Арест: товар и часть грязных денег забирают, несколько дней сидишь.
## Дни в камере идут как обычные: аренда, проценты и срок платежа никуда не деваются.
func arrest() -> Array:
	_lose_illegal_goods()
	var fine := floori(dirty * float(balance.arrest_dirty_fine))
	dirty -= fine
	police.heat[district] = float(balance.arrest_heat)
	var report := [["LOG_ARRESTED", [fine, int(balance.arrest_days)]]]
	for i in int(balance.arrest_days):
		report.append_array(end_day())
		if status != Status.PLAYING:
			break
	return report


func _lose_illegal_goods() -> void:
	for good: Dictionary in market.goods:
		if not good.legal:
			inventory[good.id] = 0
			spent_on[good.id] = 0


# --- Деньги и долги ---

## Тратим сначала грязные, потом чистые. Сумма должна быть по карману.
func _spend(amount: int) -> void:
	var from_dirty := mini(amount, dirty)
	dirty -= from_dirty
	clean -= amount - from_dirty


## Сколько ещё нужно внести до ближайшего срока.
func payment_left() -> int:
	return maxi(0, mini(balance.payment_min, debt) - paid_this_period)


## Заплатить ростовщику (он берёт любые деньги). Возвращает, сколько реально ушло.
func pay(amount: int) -> int:
	if not can_act():
		return 0
	var paid := mini(amount, mini(money, debt))
	if paid <= 0:
		return 0
	_spend(paid)
	debt -= paid
	paid_this_period += paid
	if debt == 0:
		status = Status.WON
	return paid


## Занять у ростовщика ещё: деньги сразу (грязные), в долг ложится больше.
func borrow_from_shark() -> bool:
	if not can_act():
		return false
	var amount: int = balance.shark_loan_step
	dirty += amount
	debt += roundi(amount * (1.0 + balance.shark_loan_fee))
	return true


func deposit_clean() -> bool:
	if not can_act() or clean <= 0:
		return false
	bank.deposit += clean
	clean = 0
	return true


func withdraw_deposit() -> bool:
	if not can_act() or bank.deposit <= 0:
		return false
	clean += bank.deposit
	bank.deposit = 0
	return true


func can_take_loan() -> bool:
	return can_act() and bank.trusts(police.max_heat()) and bank.loan_limit(clean_earned) > 0


func take_bank_loan() -> int:
	if not can_take_loan():
		return 0
	var amount := bank.loan_limit(clean_earned)
	bank.loan += amount
	clean += amount
	return amount


## Банку возвращаем только чистыми.
func repay_bank_loan() -> int:
	if not can_act():
		return 0
	var amount := mini(clean, bank.loan)
	clean -= amount
	bank.loan -= amount
	return amount


# --- День ---

## Залечь на дно: день без дел, розыск спадает сильнее.
func lay_low() -> Array:
	if not can_act():
		return []
	police.decay(balance.lay_low_decay - balance.heat_decay)
	return [["LOG_LAY_LOW", []]]


## Закрыть день: аренда, проценты, проверка платежа, новые цены, события.
func end_day() -> Array:
	var report: Array = []
	if status != Status.PLAYING:
		return report
	pending_check = {}
	report.append_array(_pay_rent())
	if day % 7 == 0:
		var interest := roundi(debt * float(balance.weekly_interest))
		debt += interest
		report.append(["LOG_INTEREST", [interest]])
		if bank.loan > 0:
			report.append(["LOG_BANK_INTEREST", [bank.add_interest()]])
	if day == next_payment_day:
		if payment_left() > 0:
			status = Status.LOST
			report.append(["LOG_PAYMENT_MISSED", []])
			return report
		report.append(["LOG_PAYMENT_OK", []])
		next_payment_day += int(balance.payment_interval_days)
		paid_this_period = 0
	police.decay(balance.heat_decay)
	events.roll(rng)
	market.roll_day(rng, events.today)
	report.insert(0, ["LOG_DAY_ENDED", [day]])
	day += 1
	if not events.today.is_empty():
		report.append(["LOG_EVENT", [events.today.text_key]])
	return report


## Аренда комнаты — только чистыми. Не хватает: доплачиваешь грязными, и это замечают.
## Совсем нечем: ростовщик платит за тебя и добавляет в долг.
func _pay_rent() -> Array:
	var rent: int = balance.rent_per_day
	var from_clean := mini(rent, clean)
	clean -= from_clean
	var rest := rent - from_clean
	if rest == 0:
		return []
	var from_dirty := mini(rest, dirty)
	dirty -= from_dirty
	rest -= from_dirty
	var report: Array = []
	if from_dirty > 0:
		police.add_heat(district, balance.dirty_rent_heat)
		report.append(["LOG_RENT_DIRTY", []])
	if rest > 0:
		debt += rest
		report.append(["LOG_RENT_DEBT", [rest]])
	return report


# --- Сохранение ---

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"district": district,
		"clean": clean,
		"dirty": dirty,
		"clean_earned": clean_earned,
		"debt": debt,
		"status": status,
		"next_payment_day": next_payment_day,
		"paid_this_period": paid_this_period,
		"inventory": inventory.duplicate(),
		"spent_on": spent_on.duplicate(),
		"pending_check": pending_check.duplicate(),
		"rng_state": str(rng.state),
		"market": market.to_dict(),
		"police": police.to_dict(),
		"events": events.to_dict(),
		"bank": bank.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	day = int(data.day)
	district = data.district
	clean = int(data.clean)
	dirty = int(data.dirty)
	clean_earned = int(data.clean_earned)
	debt = int(data.debt)
	status = int(data.status) as Status
	next_payment_day = int(data.next_payment_day)
	paid_this_period = int(data.paid_this_period)
	for id: String in inventory:
		inventory[id] = int(data.inventory.get(id, 0))
		spent_on[id] = int(data.spent_on.get(id, 0))
	pending_check = {}
	if not data.pending_check.is_empty():
		pending_check = { "bribe": int(data.pending_check.bribe) }
	rng.state = int(data.rng_state)
	police.load_dict(data.police)
	events.load_dict(data.events)
	bank.load_dict(data.bank)
	market.event = events.today
	market.load_dict(data.market)
