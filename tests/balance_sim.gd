extends SceneTree
## Замер баланса без графики (этап 10, часть 5). Не тест: печатает таблицы для docs/BALANCE.md.
## Запуск: Godot --headless --path . --script res://tests/balance_sim.gd
## 1) Маршруты: купить полный карман в одном городе, перелететь, продать в другом — с насыщением рынка,
##    билетом и таможней (ожидаемая взятка). Цены «средние» (дневные колебания = 1, без событий).
## 2) Бот-контрабандист: 60 дней возит лучший по текущим ценам груз между городами (старт: $3 000 и паспорт).
## 3) Окупаемость зданий: прикрытия (касса − аренда) и лаборатории (лучший рецепт по ценам города).

const RUNS := 50
const DAYS := 60


func _init() -> void:
	_routes()
	_smuggler()
	_properties()
	quit()


func _session(seed_value: int) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(),
			GameData.load_properties(), GameData.load_recipes(), GameData.load_crew(), GameData.load_gangs(), GameData.load_world(), seed_value)


## Сессия со «средними» ценами: дневные коэффициенты = 1, событий нет.
func _flat_session() -> GameSession:
	var s := _session(1)
	for city: String in s.market.factors:
		for id: String in s.market.factors[city]:
			s.market.factors[city][id] = 1.0
	s.market.city_events = {}
	return s


func _market_districts(s: GameSession, city: String, good: String) -> Array:
	return s.world.districts_of(city).filter(func(d: Dictionary) -> bool: return s.market.trades(d.id, good)) \
			.map(func(d: Dictionary) -> String: return d.id)


## Лучший рейс с товаром good из from в to при деньгах money: { "n", "buy", "sell", "profit", "customs", "bribe", "where_buy", "where_sell" }.
func _best_trip(s: GameSession, good: String, from: String, to: String, money: int) -> Dictionary:
	var buys := _market_districts(s, from, good)
	var sells := _market_districts(s, to, good)
	if buys.is_empty() or sells.is_empty():
		return {}
	buys.sort_custom(func(a: String, b: String) -> bool: return s.market.buy_price(a, good) < s.market.buy_price(b, good))
	sells.sort_custom(func(a: String, b: String) -> bool: return s.market.sell_price(a, good) > s.market.sell_price(b, good))
	var info := s.market.get_good(good)
	var cap := int(s.balance.pocket_size) / int(info.get("size", 1))
	var flight := s.world.flight_cost(from, to)
	var best := {}
	# Не каждое число штук, а лесенка — иначе бот считает слишком долго.
	for n: int in [1, 2, 3, 4, 6, 8, 10, 12, 15, 20, 25, 30, 40, 60]:
		if n > cap:
			break
		var buy := s.market.quote_buy(buys[0], good, n)
		if buy + flight > money:
			break
		var sell := s.market.quote_sell(sells[0], good, n)
		var chance := 0.0
		var bribe := 0.0
		# Как в GameSession.fly: шанс досмотра — от базовой цены груза, взятка — от цены в районе прилёта.
		if not info.legal and s.zone_of(from) != s.zone_of(to):
			var zone := s.zone_of(to)
			chance = minf(float(s.balance.customs_max), float(s.balance.customs[zone])
					+ float(info.base_price) * n / 1000.0 * float(s.balance.customs_per_1000))
			bribe = float(s.market.sell_price(s.world.get_city(to).start, good) * n) * float(s.balance.customs_bribe_share) \
					* float(s.balance.customs_bribe_mult[zone])
		var profit := sell - buy - flight - chance * bribe
		if best.is_empty() or profit > float(best.profit):
			best = { "n": n, "buy": buy, "sell": sell, "profit": profit, "customs": chance, "bribe": bribe, "where_buy": buys[0], "where_sell": sells[0] }
	return best


func _routes() -> void:
	var s := _flat_session()
	var rows: Array = []
	for good: Dictionary in s.market.goods:
		for a: Dictionary in s.world.cities:
			for b: Dictionary in s.world.cities:
				if a.id == b.id:
					continue
				var trip := _best_trip(s, good.id, a.id, b.id, 100000)
				if trip.is_empty() or float(trip.profit) <= 0.0:
					continue
				trip.good = good.id
				trip.from = a.id
				trip.to = b.id
				rows.append(trip)
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.profit) > float(y.profit))
	print("\n### Маршруты: лучший рейс «полный карман» (средние цены, ожидаемая взятка на таможне)\n")
	print("| Товар | Откуда → куда | Штук | Купить | Продать | Таможня | Ожид. прибыль | Доходность |")
	print("|---|---|---|---|---|---|---|---|")
	for row: Dictionary in rows.slice(0, 15):
		print("| %s | %s → %s | %d | $%d | $%d | %d%% | $%d | %d%% |" % [row.good, row.from, row.to, row.n, row.buy, row.sell,
				roundi(float(row.customs) * 100), roundi(float(row.profit)), roundi(100.0 * float(row.profit) / float(row.buy))])
	print("\nЛучший маршрут каждого товара:\n")
	print("| Товар | Маршрут | Ожид. прибыль | Доходность |")
	print("|---|---|---|---|")
	for good: Dictionary in s.market.goods:
		var mine := rows.filter(func(r: Dictionary) -> bool: return r.good == good.id)
		if mine.is_empty():
			print("| %s | — | — | — |" % good.id)
			continue
		var r: Dictionary = mine[0]
		print("| %s | %s → %s | $%d | %d%% |" % [good.id, r.from, r.to, roundi(float(r.profit)), roundi(100.0 * float(r.profit) / float(r.buy))])


## Бот-контрабандист: в каждом городе ищет по текущим ценам лучший груз в любой город, куда пускают документы,
## покупает (не больше 60% денег), летит, продаёт; на досмотре откупается (или сдаёт товар). Визы покупает, когда нужны.
## Без долга (песочница), чтобы мерить только торговлю.
func _smuggler() -> void:
	var finals: Array = []
	var at30: Array = []
	var stops := 0
	var trips := 0
	var lost := 0
	for seed_value in range(1, RUNS + 1):
		var s := _session(seed_value)
		s.setup("sandbox", "berlin", "")
		s.documents.passport = "real"
		for day in DAYS:
			var plan := {}
			for good: Dictionary in s.market.goods:
				for c: Dictionary in s.world.cities:
					if c.id == s.city:
						continue
					# Как осторожный игрок: на груз — не больше 60% денег, остальное — запас на взятку и билеты.
					var trip := _best_trip(s, good.id, s.city, c.id, roundi(s.money * 0.6))
					if not trip.is_empty() and float(trip.profit) > float(plan.get("profit", 50.0)) and _can_enter(s, c.id):
						trip.good = good.id
						trip.to = c.id
						plan = trip
			if not plan.is_empty():
				s.travel(plan.where_buy)
				s.buy(plan.good, int(plan.n))
				_resolve(s)
				var had := int(s.inventory[plan.good])
				_get_visa(s, plan.to)
				if s.fly(plan.to).size() > 0:
					trips += 1
					if not s.pending_check.is_empty():
						stops += 1
						if not s.can_bribe():
							lost += 1
					_resolve(s)
					if s.travel(plan.where_sell) or s.district == plan.where_sell:
						s.sell(plan.good, int(s.inventory[plan.good]))
						_resolve(s)
					if had > 0 and s.inventory[plan.good] > 0:
						s.sell(plan.good, int(s.inventory[plan.good]))
			s.end_day()
			if day == 29:
				at30.append(s.net_money())
		finals.append(s.net_money())
	finals.sort()
	at30.sort()
	print("\n### Бот-контрабандист: %d партий по %d дней (старт $3 000, паспорт, без долга)\n" % [RUNS, DAYS])
	print("| Замер | Значение |")
	print("|---|---|")
	print("| Деньги на 30-й день (медиана) | $%d |" % at30[at30.size() / 2])
	print("| Деньги на 60-й день: худшие 10%% / медиана / лучшие 10%% | $%d / $%d / $%d |" % [finals[finals.size() / 10], finals[finals.size() / 2], finals[finals.size() * 9 / 10]])
	print("| Рейсов за партию | %.1f |" % (float(trips) / RUNS))
	print("| Досмотров на таможне | %d%% рейсов |" % roundi(100.0 * stops / maxf(1.0, trips)))
	print("| Не хватило на взятку (товар отдан) | %d%% рейсов |" % roundi(100.0 * lost / maxf(1.0, trips)))


func _can_enter(s: GameSession, city: String) -> bool:
	if s.docs_ok(city):
		return true
	var zone := s.zone_of(city)
	return s.balance.visas.has(zone) and int(s.balance.visas[zone].days) == 0 and s.money >= int(s.balance.visas[zone].cost) + 500


func _get_visa(s: GameSession, city: String) -> void:
	if not s.docs_ok(city):
		s.apply_visa(s.zone_of(city))


func _resolve(s: GameSession) -> void:
	if s.pending_check.is_empty():
		return
	if s.can_bribe():
		s.bribe()
	else:
		s.surrender()


func _properties() -> void:
	var s := _flat_session()
	print("\n### Окупаемость зданий (средние цены)\n")
	print("| Здание | Город | Цена | Аренда/день | Доход/день | Окупится, дней |")
	print("|---|---|---|---|---|---|")
	for prop: Dictionary in s.properties.defs:
		var city := s.world.city_of(prop.district)
		var income := 0.0
		var note := ""
		if prop.kind == "front":
			income = float(prop.get("revenue", 0)) - float(prop.rent)
			note = "касса"
		elif prop.kind == "lab":
			for recipe: Dictionary in s.properties.recipes:
				if recipe.where != "lab":
					continue
				# Партий столько, сколько сырья влезает в здание; продаём всё сразу в лучшем районе (с насыщением).
				# Сырьё тоже покупаем разом — цена растёт (насыщение).
				var places := 0
				for good: String in recipe.inputs:
					places += int(recipe.inputs[good]) * int(s.market.get_good(good).get("size", 1))
				var batches := int(prop.capacity) / places
				var sell := _sell_district(s, city, recipe.output)
				if sell == "" or batches == 0:
					continue
				var cost := 0.0
				var buyable := true
				for good: String in recipe.inputs:
					var where := _buy_district(s, city, good)
					if where == "":
						buyable = false
						break
					cost += float(s.market.quote_buy(where, good, batches * int(recipe.inputs[good])))
				if not buyable:
					continue
				var value := float(s.market.quote_sell(sell, recipe.output, batches * int(recipe.amount)))
				var per_night := (value - cost) / float(recipe.nights)
				if per_night > income:
					income = per_night
					note = recipe.id
			income -= float(prop.rent)
		else:
			continue
		var days := "—" if income <= 0.0 else str(ceili(float(prop.buy_price) / income))
		print("| %s (%s) | %s | $%d | $%d | $%d | %s |" % [prop.id, note, city, prop.buy_price, prop.rent, roundi(income), days])


func _buy_district(s: GameSession, city: String, good: String) -> String:
	var best := ""
	for d: String in _market_districts(s, city, good):
		if best == "" or s.market.buy_price(d, good) < s.market.buy_price(best, good):
			best = d
	return best


func _sell_district(s: GameSession, city: String, good: String) -> String:
	var best := ""
	for d: String in _market_districts(s, city, good):
		if best == "" or s.market.sell_price(d, good) > s.market.sell_price(best, good):
			best = d
	return best
