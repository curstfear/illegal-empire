class_name GameSession
extends RefCounted
## Одна партия: деньги (чистые и грязные), долги, карман с товаром, день, район,
## рынок, розыск, события, банк, силы, навыки, подработки, сбор, ларёк,
## карман ограниченного размера, недвижимость (склады, лаборатории, фасады и отмыв),
## бригада (повара, дилеры, охрана, курьеры, менеджеры, бухгалтеры, адвокаты, разведчики;
## лояльность, страх, усталость, рост, предательство), перевозки (в том числе на рынок)
## и банды (хозяева районов, отношение к тебе, твоё влияние).
## Только логика и числа, никаких узлов сцены — так её легко тестировать и сохранять.
## Действия, о которых надо рассказать игроку, возвращают отчёт: список [ключ_перевода, аргументы].

enum Status { PLAYING, LOST, WON }

const SAVE_VERSION := 3
const START_DISTRICT := "market"

var balance: Dictionary
var market: Market
var police: Police
var events: EventDeck
var bank: Bank
var skills: Skills
var stall: Stall
var properties: Properties
var crew: Crew
var logistics: Logistics
var gangs: Gangs
## Подработки и сбор (data/activities.json).
var activities: Array = []
var rng := RandomNumberGenerator.new()

var day: int = 1
var district: String = START_DISTRICT
## Силы: тратятся на подработки и сбор, за ночь восстанавливаются.
var energy: int
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
## Итоги прошлых дней для графиков: все деньги (с вкладом) и самый большой розыск.
var money_history: Array = []
var heat_history: Array = []

var money: int:
	get:
		return clean + dirty


func _init(balance_data: Dictionary, goods: Array, districts: Array, event_list: Array,
		activity_list: Array, property_list: Array, recipe_list: Array, crew_data: Dictionary,
		gang_data: Dictionary, seed_value: int = 0) -> void:
	balance = balance_data
	market = Market.new(goods, districts, balance)
	police = Police.new(districts, balance)
	events = EventDeck.new(event_list, balance)
	bank = Bank.new(balance)
	skills = Skills.new(balance)
	stall = Stall.new(goods)
	properties = Properties.new(property_list, recipe_list, goods)
	crew = Crew.new(crew_data, int(balance_data.crew_skill_max), float(balance_data.loyalty_start))
	logistics = Logistics.new(balance_data.vehicles)
	gangs = Gangs.new(gang_data, districts, balance)
	activities = activity_list
	energy = balance.energy_max
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
	crew.roll_candidates(rng, int(balance.crew_candidates))


## Все деньги: чистые, грязные и вклад в банке.
func net_money() -> int:
	return money + bank.deposit


## Ряды для графиков: прошлые дни и сейчас (старые слева).
func money_series() -> Array:
	return money_history + [net_money()]


func heat_series() -> Array:
	return heat_history + [police.max_heat()]


func _remember_day() -> void:
	money_history.append(net_money())
	heat_history.append(police.max_heat())
	if money_history.size() > Market.HISTORY_DAYS - 1:
		money_history.pop_front()
		heat_history.pop_front()


func can_act() -> bool:
	return status == Status.PLAYING and pending_check.is_empty()


# --- Рынок ---

func buy_price(id: String) -> int:
	return market.buy_price(district, id)


## Сколько дадут за 1 штуку (с учётом Торговли).
func sell_price(id: String) -> int:
	return roundi(market.sell_price(district, id) * skills.sell_multiplier())


## Сколько дадут за amount штук подряд (с учётом Торговли и насыщения).
func quote_sell(id: String, amount: int) -> int:
	return roundi(market.quote_sell(district, id, amount) * skills.sell_multiplier())


func has_market() -> bool:
	return market.get_district(district).has_market


## Сколько штук можно купить: хватает и денег, и места в кармане.
func max_affordable(id: String) -> int:
	return mini(market.max_affordable(district, id, money), pocket_free() / good_size(id))


# --- Карман ---

func good_size(id: String) -> int:
	return int(market.get_good(id).get("size", 1))


## Сколько мест в кармане занято (тяжёлый товар занимает больше).
func pocket_used() -> int:
	var used := 0
	for id: String in inventory:
		used += inventory[id] * good_size(id)
	return used


func pocket_free() -> int:
	return maxi(0, int(balance.pocket_size) - pocket_used())


func buy(id: String, amount: int) -> bool:
	if not can_act() or not has_market() or amount <= 0 or amount * good_size(id) > pocket_free():
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
	if not can_act() or not has_market() or amount <= 0 or amount > inventory[id]:
		return false
	var revenue := quote_sell(id, amount)
	_remove_from_inventory(id, amount)
	market.apply_trade(district, id, -amount)
	_earn(revenue, market.get_good(id).legal)
	skills.add_xp("trade", ceili(float(revenue) / balance.xp_trade_per_dollars))
	if not market.get_good(id).legal:
		_gang_notice(district, revenue)
	_after_deal(id, amount)
	return true


func _remove_from_inventory(id: String, amount: int) -> void:
	spent_on[id] -= roundi(float(spent_on[id]) * amount / inventory[id])
	inventory[id] -= amount


func _earn(amount: int, is_clean: bool) -> void:
	if is_clean:
		clean += amount
		clean_earned += amount
	else:
		dirty += amount


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
	skills.add_xp("driving", int(balance.xp_travel))
	return true


## Сколько часов занимает переезд (Вождение сокращает).
func travel_hours() -> float:
	return float(balance.travel_hours) * skills.travel_multiplier()


# --- Дела: подработки и сбор ---

func get_activity(id: String) -> Dictionary:
	for activity: Dictionary in activities:
		if activity.id == id:
			return activity
	return {}


## Дела, доступные в текущем районе.
func local_activities() -> Array:
	return activities.filter(func(a: Dictionary) -> bool: return a.district == district)


## Сколько заплатят за подработку (с учётом Харизмы).
func activity_pay(activity: Dictionary) -> int:
	return roundi(activity.pay * skills.pay_multiplier())


## Сколько примерно соберёшь: [от, до] (с учётом Ремесла).
func activity_yield(activity: Dictionary) -> Array:
	var mult := skills.yield_multiplier()
	return [roundi(activity.yield_min * mult), roundi(activity.yield_max * mult)]


## Можно ли взяться за дело. Хватит ли часов в дне — решают часы (GameState).
func can_do_activity(id: String) -> bool:
	var activity := get_activity(id)
	return can_act() and not activity.is_empty() and activity.district == district \
			and energy >= int(activity.energy)


## Сделать дело. Нелегальное может сорваться, если заметит полиция,
## а при большом розыске провал заканчивается арестом.
func do_activity(id: String) -> Array:
	if not can_do_activity(id):
		return []
	var activity := get_activity(id)
	energy -= int(activity.energy)
	var level_before := skills.level(activity.skill)
	skills.add_xp(activity.skill, int(balance.xp_activity))
	var report: Array = []
	if not activity.legal:
		_add_heat(activity.heat)
		if _police_noticed():
			if police.heat[district] >= float(balance.activity_arrest_heat):
				return arrest()
			police.add_heat(district, balance.activity_bust_heat)
			return [["LOG_ACTIVITY_BUSTED", [activity.name_key]]]
	if activity.kind == "job":
		var pay := activity_pay(activity)
		_earn(pay, activity.legal)
		report.append(["LOG_JOB_DONE", [activity.name_key, pay]])
	else:
		var range_ := activity_yield(activity)
		var found := rng.randi_range(range_[0], range_[1])
		# Сколько влезло в карман — столько и унёс.
		var amount := mini(found, pocket_free() / good_size(activity.good))
		inventory[activity.good] += amount
		report.append(["LOG_GATHERED", [amount, market.get_good(activity.good).name_key]])
		if amount < found:
			report.append(["LOG_POCKET_FULL", [found - amount]])
	if skills.level(activity.skill) > level_before:
		report.append(["LOG_SKILL_UP", ["SKILL_" + activity.skill.to_upper(), skills.level(activity.skill)]])
	return report


# --- Ларёк ---

func can_buy_stall() -> bool:
	return can_act() and not stall.owned and clean >= int(balance.stall_price)


## Ларёк покупается только на чистые деньги.
func buy_stall() -> bool:
	if not can_buy_stall():
		return false
	clean -= int(balance.stall_price)
	stall.owned = true
	return true


## Выложить в ларёк весь товар этого вида из кармана. Только стоя на рынке.
func can_stock_stall(id: String) -> bool:
	return can_act() and stall.owned and district == Stall.DISTRICT and stall.accepts(id) and inventory[id] > 0


func stock_stall(id: String) -> bool:
	if not can_stock_stall(id):
		return false
	stall.stock[id] += inventory[id]
	_remove_from_inventory(id, inventory[id])
	return true


## Ночью ларёк подводит итог дня: продажи по полной цене рынка, плата за место.
func _run_stall() -> Array:
	if not stall.owned:
		return []
	var report: Array = []
	var total_clean := 0
	var total_dirty := 0
	for id: String in stall.stock:
		var good := market.get_good(id)
		var sold := mini(stall.stock[id], int(good.stall_daily))
		if sold == 0:
			continue
		# Ларёк продаёт без наценки перекупщика, но насыщение рынка действует.
		var revenue := roundi(market.quote_sell(Stall.DISTRICT, id, sold) / balance.sell_spread)
		stall.stock[id] -= sold
		market.apply_trade(Stall.DISTRICT, id, -sold)
		if good.legal:
			total_clean += revenue
		else:
			total_dirty += revenue
			police.add_heat(Stall.DISTRICT, good.heat * sold * skills.heat_multiplier())
	_earn(total_clean, true)
	_earn(total_dirty, false)
	if total_dirty > 0:
		report.append(["LOG_STALL_SOLD", [total_clean, total_dirty]])
	elif total_clean > 0:
		report.append(["LOG_STALL_SOLD_CLEAN", [total_clean]])
	var fee: int = balance.stall_daily_fee
	var from_clean := mini(fee, clean)
	clean -= from_clean
	debt += fee - from_clean
	return report


# --- Недвижимость ---

## Стоишь ли в районе здания (всё, кроме просмотра, — только на месте).
func at_property(id: String) -> bool:
	return properties.get_def(id).district == district


func can_buy_property(id: String) -> bool:
	return can_act() and at_property(id) and not properties.state[id].owned \
			and clean >= int(properties.get_def(id).buy_price)


## Покупка — только на чистые деньги (сделка с документами).
func buy_property(id: String) -> bool:
	if not can_buy_property(id):
		return false
	clean -= int(properties.get_def(id).buy_price)
	properties.state[id].owned = true
	properties.state[id].rented = false
	return true


## Аренду платим каждую ночь; чтобы начать, нужны чистые на первые сутки.
func can_rent_property(id: String) -> bool:
	return can_act() and at_property(id) and not properties.is_mine(id) \
			and clean >= int(properties.get_def(id).rent)


func rent_property(id: String) -> bool:
	if not can_rent_property(id):
		return false
	properties.state[id].rented = true
	return true


func can_use_property(id: String) -> bool:
	return can_act() and at_property(id) and properties.is_mine(id)


## Положить весь товар этого вида из кармана в здание (сколько влезет).
func store_goods(id: String, good: String) -> int:
	if not can_use_property(id):
		return 0
	var amount := mini(inventory[good], properties.stock_free(id) / good_size(good))
	if amount <= 0:
		return 0
	_remove_from_inventory(good, amount)
	properties.add_stock(id, good, amount)
	return amount


## Забрать весь товар этого вида из здания в карман (сколько влезет).
func take_goods(id: String, good: String) -> int:
	if not can_use_property(id):
		return 0
	var amount := mini(properties.stock_of(id, good), pocket_free() / good_size(good))
	if amount <= 0:
		return 0
	properties.add_stock(id, good, -amount)
	inventory[good] += amount
	return amount


## Запустить варку: столько партий, на сколько хватает сырья в здании.
func start_production(id: String, recipe_id: String) -> int:
	if not can_use_property(id):
		return 0
	var count := properties.max_batches(id, recipe_id)
	if count <= 0:
		return 0
	properties.start_batches(id, recipe_id, count)
	return count


func lab_upgrade_cost(id: String) -> int:
	var level: int = properties.state[id].level
	if level >= int(balance.lab_levels):
		return 0
	return int(balance.lab_upgrade_cost[level])


## Оборудование покупается «с рук» — подходят любые деньги.
func can_upgrade_lab(id: String) -> bool:
	return can_use_property(id) and lab_upgrade_cost(id) > 0 and money >= lab_upgrade_cost(id)


func upgrade_lab(id: String) -> bool:
	if not can_upgrade_lab(id):
		return false
	_spend(lab_upgrade_cost(id))
	properties.state[id].level += 1
	return true


## Продать купленное здание (часть цены чистыми) или съехать из арендованного.
## Только пустое: без товара, варки и денег в кассе.
func can_sell_property(id: String) -> bool:
	return can_use_property(id) and properties.is_empty(id)


func property_sell_price(id: String) -> int:
	if not properties.state[id].owned:
		return 0
	return roundi(int(properties.get_def(id).buy_price) * float(balance.property_sell_share))


func sell_property(id: String) -> int:
	if not can_sell_property(id):
		return -1
	var price := property_sell_price(id)
	_earn(price, true)
	properties.reset(id)
	crew.unassign_from(id)
	_drop_broken_routes()
	return price


## Улучшение здания (вентиляция, огнетушители, сигнализация, тайник, холодильник, двойная бухгалтерия).
## Ставится «с рук» — подходят любые деньги. Пропадает при продаже и взрыве.
func can_buy_upgrade(id: String, upgrade: String) -> bool:
	return can_use_property(id) and properties.upgrades_for(id, balance.upgrades).has(upgrade) \
			and not properties.has_upgrade(id, upgrade) and money >= int(balance.upgrades[upgrade].cost)


func buy_upgrade(id: String, upgrade: String) -> bool:
	if not can_buy_upgrade(id, upgrade):
		return false
	_spend(int(balance.upgrades[upgrade].cost))
	properties.state[id].upgrades.append(upgrade)
	return true


## Множитель от улучшения: если стоит — его factor, иначе 1.
func _upgrade_factor(id: String, upgrade: String) -> float:
	return float(balance.upgrades[upgrade].factor) if properties.has_upgrade(id, upgrade) else 1.0


## Прибраться: вынести мусор и следы — улики обнуляются, тратятся силы.
func can_cleanup(id: String) -> bool:
	return can_use_property(id) and properties.state[id].evidence > 0.0 and energy >= int(balance.cleanup_energy)


func cleanup(id: String) -> bool:
	if not can_cleanup(id):
		return false
	energy -= int(balance.cleanup_energy)
	properties.state[id].evidence = 0.0
	return true


## Шанс брака партии: от уровня оборудования, меньше с Ремеслом и с поваром.
func defect_chance(id: String) -> float:
	var level: int = properties.state[id].level
	return maxf(0.02, float(balance.lab_defect_chance[level - 1]) - skills.level("craft") * float(balance.defect_per_craft_level)
			- _best_skill(id, "cook") * float(balance.cook_defect_per_skill))


## Шанс удачной партии (продукта больше): от оборудования, Ремесла и повара.
func great_chance(id: String) -> float:
	var level: int = properties.state[id].level
	return float(balance.great_batch_chance[level - 1]) + skills.level("craft") * float(balance.great_per_craft_level) \
			+ _best_skill(id, "cook") * float(balance.cook_great_per_skill)


func _best_skill(property_id: String, role: String) -> int:
	var best := crew.best_at(property_id, role)
	return 0 if best.is_empty() else int(best.skill)


## Сколько запаха даст варка этой ночью (вентиляция глушит).
func smell_tonight(id: String) -> float:
	var smell := 0.0
	for batch: Dictionary in properties.state[id].batches:
		smell += float(properties.get_recipe(batch.recipe).smell) * int(batch.count)
	return smell * _upgrade_factor(id, "vent") * skills.heat_multiplier()


## Шанс, что соседи донесут на запах.
func snitch_chance(id: String) -> float:
	var neighbors := float(properties.get_def(id).get("neighbors", 1.0))
	return minf(float(balance.snitch_max), smell_tonight(id) * neighbors * float(balance.snitch_per_smell))


## Комиссия отмыва фасада: бухгалтер в здании её снижает.
func launder_fee(id: String) -> float:
	return maxf(0.02, float(properties.get_def(id).launder_fee) - _best_skill(id, "accountant") * float(balance.accountant_fee_per_skill))


func can_launder(id: String) -> bool:
	return can_use_property(id) and properties.get_def(id).kind == "front" and dirty > 0 \
			and properties.state[id].frozen_days == 0


## Сдать все грязные в кассу фасада: по ночам они выходят чистыми в пределах лимита.
func launder(id: String) -> int:
	if not can_launder(id):
		return 0
	var amount := dirty
	dirty = 0
	properties.state[id].dirty_queue += amount
	return amount


## Ночь для недвижимости: аренда, порча, варка, запах и доносы, пожары и взрывы, улики и облавы,
## касса фасадов, отмыв, налоговая.
func _run_properties() -> Array:
	var report: Array = []
	var goods_legal := {}
	for good: Dictionary in market.goods:
		goods_legal[good.id] = good.legal
	var laundered_share := 0.0
	report.append_array(_roll_presence())
	for prop: Dictionary in properties.mine():
		var id: String = prop.id
		var s: Dictionary = properties.state[id]
		var where: String = prop.district
		if s.rented:
			report.append_array(_pay_property_rent(prop))
		# Вспыльчивые шумят — розыск района растёт.
		for person: Dictionary in crew.working_at(id):
			if crew.present.get(person.id, true):
				police.add_heat(where, float(crew.trait_value(person, "heat", 0)))
		report.append_array(_spoil(prop))
		report.append_array(_run_manager(prop))
		var snitched := false
		if not s.batches.is_empty() and rng.randf() < snitch_chance(id):
			snitched = true
			police.add_heat(where, balance.snitch_heat)
			report.append(["LOG_SNITCHED", [prop.name_key]])
		if prop.kind == "lab" or prop.get("kitchen", false):
			report.append_array(_run_batches(prop))
		report.append_array(_run_dealers(prop, goods_legal))
		var illegal := properties.has_illegal(id, goods_legal)
		if illegal and _property_raided(prop, snitched):
			var hidden := _lose_property_goods(id, goods_legal)
			police.add_heat(where, balance.activity_bust_heat)
			report.append(["LOG_PROPERTY_RAID", [prop.name_key]])
			# Трусливые при облаве сбегают насовсем, остальные злятся.
			for person: Dictionary in crew.working_at(id):
				if crew.trait_value(person, "flees", false):
					crew.fire(person.id)
					report.append(["LOG_CREW_FLED", [person.nick]])
				else:
					_change_loyalty(person, float(balance.loyalty_raid))
			if hidden > 0:
				report.append(["LOG_STASH_SAVED", [hidden]])
		# Улики копятся, пока внутри нелегальное, и сами выветриваются, когда чисто.
		if illegal:
			s.evidence = minf(100.0, s.evidence + float(balance.evidence_per_night))
		else:
			s.evidence = maxf(0.0, s.evidence - float(balance.evidence_decay))
		if prop.kind == "front":
			var revenue: int = prop.revenue
			_earn(revenue, true)
			# Кафе продаёт свой чай посетителям по полной цене района — чистыми.
			if prop.get("kitchen", false) and properties.stock_of(id, "tea") > 0:
				var sold := mini(properties.stock_of(id, "tea"), int(market.get_good("tea").stall_daily) * 2)
				var income := sold * market.buy_price(where, "tea")
				properties.add_stock(id, "tea", -sold)
				_earn(income, true)
				report.append(["LOG_CAFE_SOLD", [sold, income]])
			var limit: int = prop.launder_limit
			var amount := 0 if s.frozen_days > 0 else mini(s.dirty_queue, limit)
			if amount > 0:
				s.dirty_queue -= amount
				var out := roundi(amount * (1.0 - launder_fee(id)))
				_earn(out, true)
				laundered_share += float(amount) / limit * _upgrade_factor(id, "books") \
						* maxf(0.0, 1.0 - _best_skill(id, "accountant") * float(balance.accountant_tax_per_skill))
				report.append(["LOG_LAUNDERED", [prop.name_key, out]])
			s.frozen_days = maxi(0, s.frozen_days - 1)
	report.append_array(_run_tax(laundered_share))
	return report


# --- Бригада ---

func can_hire(id: int) -> bool:
	var person := crew.get_candidate(id)
	return can_act() and not person.is_empty() and crew.people.size() < int(balance.crew_max) \
			and money >= int(person.wage)


## Нанять: первый день оплачиваешь сразу (любыми деньгами).
func hire(id: int) -> bool:
	if not can_hire(id):
		return false
	_spend(int(crew.get_candidate(id).wage))
	crew.hire(id)
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


## Уволить. Обиженный (низкая лояльность), который много знает, может пойти в полицию.
func fire(id: int) -> Array:
	var person := crew.get_person(id)
	if not can_act() or person.is_empty():
		return []
	crew.fire(id)
	_drop_broken_routes()
	var report: Array = [["LOG_CREW_FIRED", [person.nick]]]
	if float(person.loyalty) < float(balance.fired_snitch_loyalty) \
			and rng.randf() < knows_share(person) * float(balance.fired_snitch_chance):
		_snitch(person)
		report.append(["LOG_FIRED_SNITCHED", [person.nick]])
	return report


## Сколько человек знает о делах: 0 (новичок) – 1 (знает всё).
func knows_share(person: Dictionary) -> float:
	return minf(1.0, float(person.knows) / float(balance.knows_max))


## Премия: два дня зарплаты сверху — лояльность растёт. Не чаще раза в день.
func bonus_cost(id: int) -> int:
	return int(crew.get_person(id).get("wage", 0)) * int(balance.bonus_wage_days)


func can_give_bonus(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and int(person.bonus_day) != day and money >= bonus_cost(id)


func give_bonus(id: int) -> bool:
	if not can_give_bonus(id):
		return false
	var person := crew.get_person(id)
	_spend(bonus_cost(id))
	person.bonus_day = day
	_change_loyalty(person, float(balance.bonus_loyalty))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


## Надавить: страх растёт (предаёт реже), лояльность падает. Вспыльчивый может хлопнуть дверью.
func can_pressure(id: int) -> bool:
	return can_act() and not crew.get_person(id).is_empty()


func pressure(id: int) -> Array:
	if not can_pressure(id):
		return []
	var person := crew.get_person(id)
	if rng.randf() < float(crew.trait_value(person, "quits_on_pressure", 0.0)):
		crew.fire(id)
		_drop_broken_routes()
		return [["LOG_PRESSURE_QUIT", [person.nick]]]
	person.fear = minf(100.0, float(person.fear) + float(balance.pressure_fear) * float(crew.trait_value(person, "fear_mult", 1.0)))
	_change_loyalty(person, float(balance.pressure_loyalty))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return [["LOG_PRESSURED", [person.nick]]]


## Работал ли человек этой ночью: вышел и был при деле (здание, маршрут или адвокат на связи).
func worked_tonight(person: Dictionary) -> bool:
	if not crew.present.get(person.id, true):
		return false
	return person.job != "" or not logistics.route_of(int(person.id)).is_empty() or person.role == "lawyer"


## Опыт и усталость за ночь. Опыта набралось — навык растёт, а с ним и зарплата.
func _grow(person: Dictionary) -> Array:
	if not worked_tonight(person):
		if int(person.off_day) != day:
			person.fatigue = maxf(0.0, float(person.fatigue) - float(balance.fatigue_rest))
		return []
	person.fatigue = minf(100.0, float(person.fatigue) + float(balance.fatigue_per_night))
	if int(person.skill) >= int(balance.crew_skill_max):
		return []
	person.xp = int(person.xp) + 1
	if int(person.xp) < int(balance.crew_xp_step) * maxi(1, int(person.skill)):
		return []
	person.xp = 0
	person.skill = int(person.skill) + 1
	person.wage = crew.wage_for(person.role, person.skill, person.trait)
	return [["LOG_CREW_SKILL_UP", [person.nick, int(person.skill), int(person.wage)]]]


## Выходной: этой ночью человек не работает и хорошо отдыхает. Раз в день.
func can_give_day_off(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and int(person.off_day) != day


func give_day_off(id: int) -> bool:
	if not can_give_day_off(id):
		return false
	var person := crew.get_person(id)
	person.off_day = day
	person.fatigue = maxf(0.0, float(person.fatigue) - float(balance.fatigue_day_off))
	return true


## Повысить до менеджера: опытный и верный. Зарплата — как у менеджера, лояльность растёт.
func can_promote(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and not ["manager", "accountant", "lawyer"].has(person.role) \
			and int(person.skill) >= int(balance.promote_skill) and float(person.loyalty) >= float(balance.promote_loyalty)


func promote(id: int) -> bool:
	if not can_promote(id):
		return false
	var person := crew.get_person(id)
	person.role = "manager"
	person.wage = crew.wage_for("manager", person.skill, person.trait)
	if person.job != "" and not crew.can_work_in(person, properties.get_def(person.job).kind):
		person.job = ""
	for route: Dictionary in logistics.routes.duplicate():
		if route.courier == id:
			logistics.remove_route(route.id)
		elif route.scout == id:
			route.scout = 0
	_change_loyalty(person, float(balance.promote_loyalty_gain))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


func _change_loyalty(person: Dictionary, amount: float) -> void:
	person.loyalty = clampf(float(person.loyalty) + amount, 0.0, 100.0)


## Шанс предательства за ночь: только у нелояльных; страх сдерживает.
func betray_chance(person: Dictionary) -> float:
	var below := float(balance.betray_loyalty) - float(person.loyalty)
	if below <= 0.0:
		return 0.0
	return maxf(0.0, below * float(balance.betray_chance_per_point) * (1.0 - float(person.fear) * float(balance.fear_betray_cut))) \
			* skills.betray_multiplier()


## Ночь для отношений: оплаченные чуть больше доверяют, знают больше, страх спадает;
## кто работал — набирается опыта и устаёт, кто отдыхал — восстанавливается;
## нелояльные могут предать: украсть и сбежать, донести или уйти к конкурентам.
func _run_loyalty() -> Array:
	var report: Array = []
	if not crew.people.is_empty():
		skills.add_xp("leadership", 1)
	for person: Dictionary in crew.people.duplicate():
		person.knows = mini(int(balance.knows_max), int(person.knows) + 1)
		report.append_array(_grow(person))
		var change := float(balance.loyalty_paid) + float(crew.trait_value(person, "drift", 0)) + skills.loyalty_bonus()
		if float(person.fear) > float(balance.fear_resent):
			change -= 1.0
		if float(person.fatigue) >= float(balance.fatigue_tired):
			change -= 1.0
		_change_loyalty(person, change)
		person.fear = maxf(0.0, float(person.fear) - float(balance.fear_decay))
		if rng.randf() >= betray_chance(person):
			continue
		crew.fire(person.id)
		var kind: String = crew.trait_value(person, "betray", ["steal", "snitch", "leave"][rng.randi() % 3])
		if kind == "steal":
			report.append(_steal(person))
		elif kind == "snitch":
			_snitch(person)
			report.append(["LOG_BETRAY_SNITCH", [person.nick]])
		else:
			report.append(["LOG_BETRAY_LEFT", [person.nick]])
	_drop_broken_routes()
	return report


## Кража: с места работы — часть товара, иначе — часть грязной налички.
func _steal(person: Dictionary) -> Array:
	var job: String = person.job
	if job != "" and properties.is_mine(job):
		var taken := 0
		for good: String in properties.state[job].stock.keys():
			var n := ceili(properties.stock_of(job, good) * float(balance.betray_steal_share))
			properties.add_stock(job, good, -n)
			taken += n
		if taken > 0:
			return ["LOG_BETRAY_STOLE_GOODS", [person.nick, taken, properties.get_def(job).name_key]]
	var cash := roundi(dirty * float(balance.betray_steal_cash_share))
	dirty -= cash
	return ["LOG_BETRAY_STOLE_CASH", [person.nick, cash]]


## Донос: розыск растёт тем сильнее, чем больше человек знает; на месте работы — улики.
func _snitch(person: Dictionary) -> void:
	var job: String = person.job
	var where := district
	if job != "" and properties.is_mine(job):
		where = properties.get_def(job).district
		var s: Dictionary = properties.state[job]
		s.evidence = minf(100.0, float(s.evidence) + float(balance.betray_snitch_evidence))
	police.add_heat(where, float(balance.betray_snitch_heat) + float(person.knows))


func _drop_broken_routes() -> void:
	logistics.drop_broken_routes(place_ok, func(id: int) -> bool: return not crew.get_person(id).is_empty())


## Менеджер в здании делает рутину сам: прибирает улики, в лаборатории/на кухне
## перезапускает варку из того, что лежит на складе (дорогое — первым), в фасаде сдаёт грязные в отмыв.
func _run_manager(prop: Dictionary) -> Array:
	var manager := crew.best_at(prop.id, "manager")
	if manager.is_empty():
		return []
	var report: Array = []
	var id: String = prop.id
	var s: Dictionary = properties.state[id]
	s.evidence = maxf(0.0, float(s.evidence) - int(manager.skill) * float(balance.manager_evidence_per_skill))
	if s.batches.is_empty():
		var options := properties.recipes_for(id)
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(market.get_good(a.output).base_price) > int(market.get_good(b.output).base_price))
		for recipe: Dictionary in options:
			var count := properties.max_batches(id, recipe.id)
			if count > 0:
				properties.start_batches(id, recipe.id, count)
				report.append(["LOG_MANAGER_BREW", [manager.nick, count, recipe.name_key]])
				break
	if prop.kind == "front" and s.frozen_days == 0 and dirty > 0:
		var amount := mini(dirty, maxi(0, int(prop.launder_limit) - int(s.dirty_queue)))
		if amount > 0:
			dirty -= amount
			s.dirty_queue += amount
			report.append(["LOG_MANAGER_LAUNDER", [manager.nick, amount]])
	return report


# --- Перевозки ---

## Курьер продаёт привезённое на рынке района: легальное — чистыми, нелегальное — грязными и с розыском.
func _route_sell(route: Dictionary, courier: Dictionary, amount: int) -> Array:
	var where := place_district(route.to)
	var good := market.get_good(route.good)
	var income := route_sale_quote(route, amount)
	market.apply_trade(where, route.good, -amount)
	_earn(income, good.legal)
	if not good.legal:
		police.add_heat(where, float(good.heat) * amount * float(balance.dealer_heat_share) * skills.heat_multiplier())
		_gang_notice(where, income)
	return ["LOG_ROUTE_SOLD", [courier.nick, amount, good.name_key, market.get_district(where).name_key, income]]

func vehicle_price(type: String) -> int:
	return int(balance.vehicles[type].price)


## Машину покупаешь «с рук» — любые деньги.
func can_buy_vehicle(type: String) -> bool:
	return can_act() and balance.vehicles.has(type) and logistics.vehicles.size() < int(balance.vehicles_max) \
			and money >= vehicle_price(type)


func buy_vehicle(type: String) -> bool:
	if not can_buy_vehicle(type):
		return false
	_spend(vehicle_price(type))
	logistics.add_vehicle(type)
	return true


## Тайник в машине (ложное дно): патруль находит груз вдвое реже.
func can_add_hidden(vehicle_id: int) -> bool:
	var vehicle := logistics.get_vehicle(vehicle_id)
	return can_act() and not vehicle.is_empty() and not vehicle.hidden and money >= int(balance.hidden_compartment_cost)


func add_hidden(vehicle_id: int) -> bool:
	if not can_add_hidden(vehicle_id):
		return false
	_spend(int(balance.hidden_compartment_cost))
	logistics.get_vehicle(vehicle_id).hidden = true
	return true


## Маскировка груза (мешки с картошкой сверху): патруль находит реже, дешевле тайника. Вместе — сильнее.
func can_add_disguise(vehicle_id: int) -> bool:
	var vehicle := logistics.get_vehicle(vehicle_id)
	return can_act() and not vehicle.is_empty() and not vehicle.disguise and money >= int(balance.disguise_cost)


func add_disguise(vehicle_id: int) -> bool:
	if not can_add_disguise(vehicle_id):
		return false
	_spend(int(balance.disguise_cost))
	logistics.get_vehicle(vehicle_id).disguise = true
	return true


## Место маршрута: id своего здания или рынок района "@district".
func is_market_place(place: String) -> bool:
	return place.begins_with("@")


func market_place(district_id: String) -> String:
	return "@" + district_id


## Район места маршрута.
func place_district(place: String) -> String:
	return place.substr(1) if is_market_place(place) else String(properties.get_def(place).district)


## Ключ перевода для названия места маршрута.
func place_name_key(place: String) -> String:
	if is_market_place(place):
		return market.get_district(place.substr(1)).name_key
	return properties.get_def(place).name_key


## Место ещё годится: своё здание или район с рынком.
func place_ok(place: String) -> bool:
	if is_market_place(place):
		return market.get_district(place.substr(1)).get("has_market", false)
	return properties.is_mine(place)


## Маршрут: из своего здания в другое своё или на рынок района, свободная машина и курьер;
## разведчик — по желанию (0 — без него).
func can_add_route(from: String, to: String, good: String, vehicle_id: int, courier_id: int, scout_id: int = 0) -> bool:
	var courier := crew.get_person(courier_id)
	if scout_id != 0:
		var scout := crew.get_person(scout_id)
		if scout.is_empty() or scout.role != "scout" or logistics.scout_busy(scout_id):
			return false
	return can_act() and from != to and properties.is_mine(from) and place_ok(to) \
			and not market.get_good(good).is_empty() and not logistics.get_vehicle(vehicle_id).is_empty() \
			and not logistics.vehicle_busy(vehicle_id) and not courier.is_empty() and courier.role == "courier" \
			and not logistics.courier_busy(courier_id)


func add_route(from: String, to: String, good: String, vehicle_id: int, courier_id: int, scout_id: int = 0) -> bool:
	if not can_add_route(from, to, good, vehicle_id, courier_id, scout_id):
		return false
	logistics.add_route(from, to, good, vehicle_id, courier_id, scout_id)
	return true


func remove_route(id: int) -> bool:
	if not can_act() or logistics.get_route(id).is_empty():
		return false
	logistics.remove_route(id)
	return true


## Шанс, что патруль остановит машину с нелегальным грузом: от заметности машины,
## розыска и силы полиции в обоих районах; тайник и опытный курьер снижают.
func route_police_chance(route: Dictionary) -> float:
	var good := market.get_good(route.good)
	if good.legal:
		return 0.0
	var vehicle := logistics.get_vehicle(route.vehicle)
	var courier := crew.get_person(route.courier)
	var chance := float(balance.route_police_base) * float(balance.vehicles[vehicle.type].notice)
	var heat := 0.0
	var force := 0.0
	for place: String in [route.from, route.to]:
		var where := place_district(place)
		heat += police.heat[where] / 2.0
		force += float(market.get_district(where).police) * market.event_police(where) / 2.0
	chance *= force * (1.0 + heat * float(balance.route_heat_per_point))
	if vehicle.hidden:
		chance *= float(balance.hidden_compartment_factor)
	if vehicle.disguise:
		chance *= float(balance.disguise_factor)
	chance *= maxf(0.2, 1.0 - int(courier.get("skill", 0)) * float(balance.route_courier_skill_cut))
	chance *= 1.0 - _scout_skill(route) * float(balance.scout_police_per_skill)
	chance *= skills.route_police_multiplier()
	return minf(1.0, chance)


## Навык разведчика маршрута, если он вышел этой ночью (0 — нет разведчика).
func _scout_skill(route: Dictionary) -> int:
	if int(route.get("scout", 0)) == 0 or not crew.present.get(route.scout, true):
		return 0
	return int(crew.get_person(route.scout).get("skill", 0))


## Шанс засады конкурентов: чем дороже нелегальный груз, тем выше.
func route_ambush_chance(route: Dictionary, amount: int) -> float:
	var good := market.get_good(route.good)
	if good.legal:
		return 0.0
	var value := float(good.base_price) * amount
	var chance := minf(float(balance.route_ambush_max),
			float(balance.route_ambush_base) + value / 1000.0 * float(balance.route_ambush_per_1000))
	return chance * (float(balance.scout_ambush_factor) if _scout_skill(route) > 0 else 1.0)


## Сколько штук увезёт маршрут этой ночью: сколько есть, влезет в машину и в здание назначения
## (на рынке места не надо — там продают).
func route_amount(route: Dictionary) -> int:
	var size := good_size(route.good)
	var vehicle := logistics.get_vehicle(route.vehicle)
	if vehicle.is_empty():
		return 0
	var fits := logistics.capacity(vehicle) / size
	if not is_market_place(route.to):
		fits = mini(fits, properties.stock_free(route.to) / size)
	return mini(properties.stock_of(route.from, route.good), fits)


## Сколько примерно выручит курьер на рынке за amount штук (цена района, насыщение, наценка перекупщика).
func route_sale_quote(route: Dictionary, amount: int) -> int:
	if not is_market_place(route.to) or amount <= 0:
		return 0
	return roundi(market.quote_sell(place_district(route.to), route.good, amount) * float(balance.route_sell_price))


## Ночь для маршрутов: поломки, патрули, засады; доехало — товар в здании назначения.
func _run_routes() -> Array:
	var report: Array = []
	for vehicle: Dictionary in logistics.vehicles:
		vehicle.broken = maxi(0, int(vehicle.broken) - 1)
	for route: Dictionary in logistics.routes.duplicate():
		var vehicle := logistics.get_vehicle(route.vehicle)
		var courier := crew.get_person(route.courier)
		if vehicle.is_empty() or courier.is_empty() or not crew.present.get(courier.id, true) or vehicle.broken > 0:
			continue
		var amount := route_amount(route)
		if amount <= 0:
			continue
		var good_key: String = market.get_good(route.good).name_key
		if rng.randf() < float(balance.vehicles[vehicle.type].breakdown):
			vehicle.broken = 1
			report.append(["LOG_ROUTE_BREAKDOWN", [courier.nick, balance.vehicles[vehicle.type].name_key]])
			continue
		if rng.randf() < route_police_chance(route):
			# Груз забрали, машину увезли на штрафстоянку, курьера посадили (адвокат может вытащить).
			properties.add_stock(route.from, route.good, -amount)
			police.add_heat(properties.get_def(route.from).district, float(balance.route_bust_heat))
			logistics.vehicles.erase(vehicle)
			report.append(["LOG_ROUTE_BUSTED", [courier.nick, amount, good_key]])
			if rng.randf() < crew.best_skill("lawyer") * float(balance.lawyer_free_per_skill):
				report.append(["LOG_LAWYER_FREED", [courier.nick]])
			else:
				crew.fire(courier.id)
				report.append(["LOG_COURIER_JAILED", [courier.nick]])
			continue
		if rng.randf() < route_ambush_chance(route, amount):
			properties.add_stock(route.from, route.good, -amount)
			_change_loyalty(courier, float(balance.loyalty_ambush))
			report.append(["LOG_ROUTE_AMBUSH", [courier.nick, amount, good_key]])
			continue
		properties.add_stock(route.from, route.good, -amount)
		if is_market_place(route.to):
			report.append(_route_sell(route, courier, amount))
			continue
		properties.add_stock(route.to, route.good, amount)
		report.append(["LOG_ROUTE_DELIVERED", [courier.nick, amount, good_key,
				properties.get_def(route.from).name_key, properties.get_def(route.to).name_key]])
	_drop_broken_routes()
	return report


## Поставить человека в своё здание подходящего типа ("" — снять с работы).
func can_assign(person_id: int, property_id: String) -> bool:
	var person := crew.get_person(person_id)
	if person.is_empty() or not can_act():
		return false
	if property_id == "":
		return true
	return properties.is_mine(property_id) and crew.can_work_in(person, properties.get_def(property_id).kind)


func assign(person_id: int, property_id: String) -> bool:
	if not can_assign(person_id, property_id):
		return false
	crew.get_person(person_id).job = property_id
	return true


## Кто вышел на работу: пьющий иногда не приходит.
func _roll_presence() -> Array:
	var report: Array = []
	crew.present.clear()
	for person: Dictionary in crew.people:
		if int(person.off_day) == day:
			crew.present[person.id] = false
			continue
		var tired := float(person.fatigue) >= float(balance.fatigue_tired)
		var no_show := float(crew.trait_value(person, "no_show", 0.0)) + (float(balance.fatigue_no_show) if tired else 0.0)
		var here := rng.randf() >= no_show
		crew.present[person.id] = here
		var busy: bool = person.job != "" or not logistics.route_of(int(person.id)).is_empty()
		if not here and busy:
			report.append(["LOG_CREW_TIRED" if tired else "LOG_CREW_NO_SHOW", [person.nick]])
	return report


## Дилеры в здании продают нелегальное из его склада (дорогое — первым) по цене района со скидкой.
## Деньги грязные, розыск — району. Где нет рынка, покупателей нет.
func _run_dealers(prop: Dictionary, goods_legal: Dictionary) -> Array:
	var report: Array = []
	var where: String = prop.district
	if not market.get_district(where).has_market:
		return report
	var goods := market.goods.filter(func(good: Dictionary) -> bool: return not good.legal)
	goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.base_price) > int(b.base_price))
	for dealer: Dictionary in crew.working_at(prop.id, "dealer"):
		if not crew.present.get(dealer.id, true):
			continue
		var left := int(balance.dealer_units_base) + int(balance.dealer_units_per_skill) * int(dealer.skill)
		var mult := float(balance.dealer_price_base) + float(balance.dealer_price_per_skill) * int(dealer.skill) \
				+ float(crew.trait_value(dealer, "price", 0.0))
		var sold := 0
		var income := 0
		for good: Dictionary in goods:
			var n := mini(left, properties.stock_of(prop.id, good.id))
			if n <= 0:
				continue
			income += roundi(market.quote_sell(where, good.id, n) * mult)
			market.apply_trade(where, good.id, -n)
			properties.add_stock(prop.id, good.id, -n)
			police.add_heat(where, float(good.heat) * n * float(balance.dealer_heat_share) * skills.heat_multiplier())
			sold += n
			left -= n
		if sold > 0:
			_earn(income, false)
			_gang_notice(where, income)
			report.append(["LOG_DEALER_SOLD", [dealer.nick, sold, income]])
	return report


## Зарплаты за ночь: сначала грязными (наличка), потом чистыми. Кому не хватило — уходит.
func _pay_crew() -> Array:
	var report: Array = []
	var total := 0
	for person: Dictionary in crew.people.duplicate():
		var wage := int(person.wage)
		if money < wage:
			crew.fire(person.id)
			report.append(["LOG_CREW_UNPAID", [person.nick]])
			continue
		_spend(wage)
		total += wage
	if total > 0:
		report.append(["LOG_CREW_WAGES", [total]])
	return report


## Порча: скоропортящееся (грибы, травы, чай, мох) гниёт без холодильника.
func _spoil(prop: Dictionary) -> Array:
	var report: Array = []
	var lost := properties.spoilage(prop.id)
	for good: String in lost:
		properties.add_stock(prop.id, good, -int(lost[good]))
		report.append(["LOG_SPOILED", [prop.name_key, int(lost[good]), market.get_good(good).name_key]])
	return report


func _pay_property_rent(prop: Dictionary) -> Array:
	var rent: int = prop.rent
	var from_clean := mini(rent, clean)
	clean -= from_clean
	var rest := rent - from_clean
	var from_dirty := mini(rest, dirty)
	dirty -= from_dirty
	debt += rest - from_dirty
	if from_dirty > 0:
		police.add_heat(prop.district, balance.dirty_rent_heat)
	return [] if rest == 0 else [["LOG_PROPERTY_RENT_DIRTY", [prop.name_key]]]


## Варка: партии идут к готовности; готовые — в склад здания (с риском брака), запах — в розыск района.
func _run_batches(prop: Dictionary) -> Array:
	var id: String = prop.id
	var s: Dictionary = properties.state[id]
	var report: Array = []
	if s.batches.is_empty():
		return report
	var level: int = s.level
	var safety := _upgrade_factor(id, "extinguisher")
	var volatile: bool = s.batches.any(func(batch: Dictionary) -> bool:
		return properties.get_recipe(batch.recipe).get("volatile", false))
	if prop.kind == "lab" and volatile and rng.randf() < float(balance.lab_explosion_chance[level - 1]) * safety:
		# Взрыв: всё внутри пропало, оборудование и улучшения разбиты, на шум съезжается полиция.
		properties.reset(id, true)
		police.add_heat(prop.district, balance.explosion_heat)
		report.append(["LOG_LAB_EXPLOSION", [prop.name_key]])
		return report
	if prop.kind == "lab" and rng.randf() < float(balance.lab_fire_chance[level - 1]) * safety:
		s.batches.clear()
		for good: String in s.stock.keys():
			properties.add_stock(id, good, -int(s.stock[good]) / 2)
		report.append(["LOG_LAB_FIRE", [prop.name_key]])
		return report
	police.add_heat(prop.district, smell_tonight(id))
	var still: Array = []
	for batch: Dictionary in s.batches:
		var recipe := properties.get_recipe(batch.recipe)
		batch.nights_left -= 1
		if batch.nights_left > 0:
			still.append(batch)
			continue
		var made: int = batch.count * int(recipe.amount)
		var defects := 0
		for i in batch.count:
			if rng.randf() < defect_chance(id):
				defects += 1
		made -= defects * ceili(float(recipe.amount) / 2.0)
		# Удачные партии (из небракованных) дают на половину больше.
		var great := 0
		for i in batch.count - defects:
			if rng.randf() < great_chance(id):
				great += 1
		made += great * ceili(float(recipe.amount) * float(balance.great_batch_bonus))
		properties.add_stock(id, recipe.output, made)
		skills.add_xp("craft", int(balance.xp_activity) * batch.count)
		report.append(["LOG_BATCH_DONE", [prop.name_key, made, market.get_good(recipe.output).name_key]])
		if defects > 0:
			report.append(["LOG_BATCH_DEFECT", [defects]])
		if great > 0:
			report.append(["LOG_BATCH_GREAT", [great]])
	s.batches = still
	return report


## Облава на здание: лаборатории — от розыска района и силы полиции; склады — реже.
## Улики и донос соседей повышают шанс, сигнализация — снижает (успеваешь прибрать).
func raid_chance(id: String, snitched: bool = false) -> float:
	var prop := properties.get_def(id)
	var where: String = prop.district
	var multiplier: float = market.get_district(where).police * market.event_police(where)
	var chance := police.check_chance(where, multiplier)
	chance *= float(balance.lab_raid_factor) if prop.kind == "lab" else float(balance.warehouse_raid_factor)
	chance *= 1.0 + properties.state[id].evidence * float(balance.evidence_raid_per_point)
	chance *= _upgrade_factor(id, "alarm")
	# Охрана: каждый вышедший охранник снижает шанс (вместе — не больше чем на 80%).
	var guarded := 0.0
	for guard: Dictionary in crew.working_at(id, "guard"):
		if crew.present.get(guard.id, true):
			guarded += int(guard.skill) * float(balance.guard_raid_per_skill)
	chance *= 1.0 - minf(0.8, guarded)
	if snitched:
		chance *= float(balance.snitch_raid_mult)
	return minf(1.0, chance)


func _property_raided(prop: Dictionary, snitched: bool) -> bool:
	return rng.randf() < raid_chance(prop.id, snitched)


## Облава забирает нелегальное. Что влезло в тайник — уцелело. Возвращает, сколько штук спасено.
func _lose_property_goods(id: String, goods_legal: Dictionary) -> int:
	var s: Dictionary = properties.state[id]
	var places := int(balance.upgrades.stash.places) if properties.has_upgrade(id, "stash") else 0
	var saved := 0
	for good: String in s.stock.keys():
		if goods_legal.get(good, true):
			continue
		var kept := mini(int(s.stock[good]), places / good_size(good))
		places -= kept * good_size(good)
		saved += kept
		if kept > 0:
			s.stock[good] = kept
		else:
			s.stock.erase(good)
	s.batches = s.batches.filter(func(batch: Dictionary) -> bool:
		return properties.get_recipe(batch.recipe).smell == 0)
	s.level = 1
	return saved


## Налоговая: отмыв на полный лимит поднимает внимание, со временем оно спадает.
## Когда внимание высокое — может прийти проверка: штраф и заморозка отмыва.
func _run_tax(laundered_share: float) -> Array:
	properties.tax_attention += laundered_share * float(balance.tax_attention_per_full_day)
	properties.tax_attention = clampf(properties.tax_attention - float(balance.tax_attention_decay), 0.0, 100.0)
	if properties.tax_attention < float(balance.tax_audit_threshold) or rng.randf() >= float(balance.tax_audit_chance):
		return []
	var fine := roundi(float(balance.tax_fine_base) + clean * float(balance.tax_fine_share))
	var from_clean := mini(fine, clean)
	clean -= from_clean
	debt += fine - from_clean
	for prop: Dictionary in properties.mine():
		if prop.kind == "front":
			properties.state[prop.id].frozen_days = int(balance.tax_freeze_days)
	properties.tax_attention = 30.0
	return [["LOG_TAX_AUDIT", [fine, int(balance.tax_freeze_days)]]]


# --- Полиция ---

## После нелегальной сделки растёт розыск и может начаться проверка.
func _after_deal(id: String, amount: int) -> void:
	var good := market.get_good(id)
	if good.legal:
		return
	_add_heat(good.heat * amount)
	if illegal_goods_value() == 0:
		return
	if _police_noticed():
		var bribe_value: float = (balance.bribe_base + illegal_goods_value() * balance.bribe_share) * skills.bribe_multiplier()
		pending_check = { "bribe": roundi(bribe_value) }


## Розыск в текущем районе с учётом Скрытности. Скрытность растёт от риска.
func _add_heat(amount: float) -> void:
	police.add_heat(district, amount * skills.heat_multiplier())
	skills.add_xp("stealth", ceili(amount))


## Бросок: заметила ли полиция (по розыску района, силе полиции и событию).
func _police_noticed() -> bool:
	var multiplier: float = market.get_district(district).police * market.event_police(district)
	return rng.randf() < police.check_chance(district, multiplier)


func flee_chance() -> float:
	return police.flee_chance(district)


func can_bribe() -> bool:
	return not pending_check.is_empty() and money >= pending_check.bribe


func bribe() -> Array:
	if not can_bribe():
		return []
	_spend(pending_check.bribe)
	police.add_heat(district, balance.bribe_heat)
	skills.add_xp("charisma", int(balance.xp_bribe))
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
## Адвокат в бригаде: штраф меньше, а опытный (от 3 ур.) сокращает срок на день.
func arrest() -> Array:
	_lose_illegal_goods()
	var lawyer := crew.best_skill("lawyer")
	var fine := floori(dirty * float(balance.arrest_dirty_fine) * maxf(0.0, 1.0 - lawyer * float(balance.lawyer_fine_per_skill)))
	dirty -= fine
	police.heat[district] = float(balance.arrest_heat)
	var days := arrest_days()
	var report := [["LOG_ARRESTED", [fine, days]]]
	if lawyer > 0:
		report.append(["LOG_LAWYER_HELPED", []])
	for i in days:
		report.append_array(end_day())
		if status != Status.PLAYING:
			break
	return report


func arrest_days() -> int:
	var short := 1 if crew.best_skill("lawyer") >= int(balance.lawyer_short_skill) else 0
	return maxi(1, int(balance.arrest_days) - short)


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


## Закрыть день: ларёк, аренда, проценты, проверка платежа, новые цены, события, сон.
func end_day() -> Array:
	var report: Array = []
	if status != Status.PLAYING:
		return report
	pending_check = {}
	report.append_array(_run_properties())
	report.append_array(_run_routes())
	report.append_array(_pay_crew())
	report.append_array(_run_loyalty())
	report.append_array(_run_stall())
	report.append_array(_pay_rent())
	report.append_array(_run_gangs())
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
	_remember_day()
	police.decay(balance.heat_decay)
	events.roll(rng)
	market.roll_day(rng, events.today)
	crew.roll_candidates(rng, int(balance.crew_candidates))
	report.insert(0, ["LOG_DAY_ENDED", [day]])
	day += 1
	energy = balance.energy_max
	if not events.today.is_empty():
		report.append(["LOG_EVENT", [events.today.text_key]])
	return report


# --- Банды ---

## Нелегальная продажа на сумму value в районе: твоё влияние растёт, банды района злятся
## (тем сильнее, чем больше их доля и чем вспыльчивее босс).
func _gang_notice(where: String, value: int) -> void:
	if value <= 0:
		return
	var hundreds := float(value) / 100.0
	for id: String in gangs.influence[where].keys():
		if id != Gangs.PLAYER:
			gangs.change_relation(id, -hundreds * float(balance.gang_relation_per_100)
					* float(gangs.temper(id).anger) * gangs.share(where, id) / 100.0)
	gangs.player_gain(where, hundreds * float(balance.player_influence_per_100))


## Ночь у банд: твои нелегальные точки (лаборатории и здания с нелегальным товаром) держат влияние
## и раздражают хозяев района; потом банды живут сами. Сообщаем, если отношение перешло на новый уровень.
func _run_gangs() -> Array:
	var report: Array = []
	var goods_legal := {}
	for good: Dictionary in market.goods:
		goods_legal[good.id] = good.legal
	for prop: Dictionary in properties.mine():
		if prop.kind != "lab" and not properties.has_illegal(prop.id, goods_legal):
			continue
		var where: String = prop.district
		var host := gangs.gang_owner(where)
		if host != "":
			gangs.change_relation(host, -float(balance.gang_relation_property) * float(gangs.temper(host).anger))
		gangs.player_gain(where, float(balance.player_influence_property))
	report.append_array(gangs.night(rng))
	for gang: Dictionary in gangs.defs:
		var now := gangs.level(gang.id)
		if now != gangs.known_level.get(gang.id, now):
			report.append(["LOG_GANG_NOW_" + now.to_upper(), [gang.name_key, gang.boss_key]])
		gangs.known_level[gang.id] = now
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
		"energy": energy,
		"skills": skills.to_dict(),
		"stall": stall.to_dict(),
		"properties": properties.to_dict(),
		"crew": crew.to_dict(),
		"logistics": logistics.to_dict(),
		"gangs": gangs.to_dict(),
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
		"money_history": money_history.duplicate(),
		"heat_history": heat_history.duplicate(),
		"rng_state": str(rng.state),
		"market": market.to_dict(),
		"police": police.to_dict(),
		"events": events.to_dict(),
		"bank": bank.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	day = int(data.day)
	district = data.district
	energy = int(data.energy)
	skills.load_dict(data.skills)
	stall.load_dict(data.stall)
	properties.load_dict(data.get("properties", {}))
	crew.load_dict(data.get("crew", {}))
	logistics.load_dict(data.get("logistics", {}))
	gangs.load_dict(data.get("gangs", {}))
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
	money_history = data.get("money_history", []).map(func(v: Variant) -> int: return int(v))
	heat_history = data.get("heat_history", []).map(func(v: Variant) -> float: return float(v))
	rng.state = int(data.rng_state)
	police.load_dict(data.police)
	events.load_dict(data.events)
	bank.load_dict(data.bank)
	market.event = events.today
	market.load_dict(data.market)
