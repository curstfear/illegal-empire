extends SceneTree
## Автотесты логики. Запуск без окна:
## Godot --headless --path . --script res://tests/run_tests.gd

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	_test_start_values()
	_test_buy_and_sell()
	_test_saturation()
	_test_districts_differ()
	_test_clean_and_dirty()
	_test_rent()
	_test_weekly_interest()
	_test_missed_payment_loses()
	_test_payment_on_time()
	_test_paying_all_debt_wins()
	_test_prices_stay_in_bounds()
	_test_heat()
	_test_police_check_choices()
	_test_arrest()
	_test_bank()
	_test_shark_loan()
	_test_events()
	_test_jobs()
	_test_shady_job()
	_test_gathering()
	_test_skills()
	_test_stall()
	_test_save_and_load()
	_report_balance_bot()
	_report_honest_bots()
	print("\nИтог: %d прошло, %d упало" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _new_session(seed_value: int = 42) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(), seed_value)


## Сессия без случайных проверок полиции — для тестов торговли.
func _calm_session(seed_value: int = 42) -> GameSession:
	var s := _new_session(seed_value)
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0
	return s


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)


func _test_start_values() -> void:
	var s := _new_session()
	_check(s.money == 120 and s.clean == 120 and s.dirty == 0, "старт: $120 чистыми")
	_check(s.debt == 48000 and s.day == 1 and s.district == "market", "старт: долг $48 000, день 1, рынок")
	_check(s.next_payment_day == 14 and s.payment_left() == 1500, "старт: платёж $1 500 к 14-му дню")


func _test_buy_and_sell() -> void:
	var s := _calm_session()
	var expected := s.market.quote_buy("market", "mushrooms", 3)
	_check(s.buy("mushrooms", 3), "покупка 3 грибов")
	_check(s.money == 120 - expected and s.inventory.mushrooms == 3, "деньги списаны, грибы в кармане")
	_check(not s.buy("blue_dust", 1), "нельзя купить дороже, чем есть денег")
	_check(not s.sell("mushrooms", 4), "нельзя продать больше, чем есть")
	_check(s.sell_price("mushrooms") < s.buy_price("mushrooms"), "продать дешевле, чем купить")


func _test_saturation() -> void:
	var s := _calm_session()
	s.clean = 100000
	var price_before := s.buy_price("phones")
	s.buy("phones", 8)
	_check(s.buy_price("phones") > price_before, "покупки поднимают цену в районе")
	var sell_before := s.sell_price("phones")
	s.sell("phones", 8)
	_check(s.sell_price("phones") < sell_before, "продажи сбивают цену")
	_check(s.market.quote_sell("market", "phones", 8) < s.sell_price("phones") * 8, "крупная продажа дешевле поштучной цены")
	s.sell("phones", 0)
	s.buy("phones", 8)
	s.sell("phones", 8)
	var pressure: float = s.market.pressure.market.phones
	s.end_day()
	_check(absf(s.market.pressure.market.phones) < absf(pressure) or pressure == 0.0, "за ночь давление спадает")


func _test_districts_differ() -> void:
	var s := _calm_session()
	_check(s.market.buy_price("station", "blue_dust") < s.market.buy_price("clubs", "blue_dust"),
			"«Синяя пыль» на вокзале дешевле, чем в клубах")
	_check(s.travel("clubs") and s.district == "clubs", "переезд в клубы")
	_check(not s.travel("clubs"), "нельзя переехать туда, где уже стоишь")


func _test_clean_and_dirty() -> void:
	var s := _calm_session()
	s.buy("mushrooms", 5)
	var clean_before := s.clean
	s.sell("mushrooms", 5)
	_check(s.clean > clean_before and s.dirty == 0, "грибы приносят чистые деньги")
	s.buy("cigarettes", 1)
	s.sell("cigarettes", 1)
	_check(s.dirty > 0, "сигареты приносят грязные деньги")
	s.dirty = 50
	var clean_now := s.clean
	s.buy("mushrooms", 1)
	_check(s.clean == clean_now and s.dirty < 50, "сначала тратятся грязные")


func _test_rent() -> void:
	var s := _calm_session()
	s.end_day()
	_check(s.clean == 120 - 12, "аренда $12 в день из чистых")
	s.clean = 5
	s.dirty = 100
	var heat_before: float = s.police.heat.market
	s.end_day()
	_check(s.clean == 0 and s.dirty == 93 and s.police.heat.market >= heat_before, "не хватает чистых — доплата грязными")
	s.clean = 0
	s.dirty = 0
	var debt_before := s.debt
	s.end_day()
	_check(s.debt == debt_before + 12, "совсем нет денег — аренда в долг ростовщику")


func _test_weekly_interest() -> void:
	var s := _calm_session()
	s.clean = 100000
	for i in 6:
		s.end_day()
	_check(s.debt == 48000, "до 7-го дня проценты не начислены")
	s.end_day()
	_check(s.debt == 48960, "после 7-го дня +2%% (48 960), сейчас %d" % s.debt)


func _test_missed_payment_loses() -> void:
	var s := _calm_session()
	for i in 13:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING, "13 дней без платежа — ещё играем")
	s.end_day()
	_check(s.status == GameSession.Status.LOST, "не заплатил к концу 14-го дня — проигрыш")


func _test_payment_on_time() -> void:
	var s := _calm_session()
	s.clean = 2000
	_check(s.pay(1500) == 1500 and s.payment_left() == 0, "внесли $1 500")
	for i in 14:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING, "платёж внесён — игра идёт")
	_check(s.next_payment_day == 28 and s.payment_left() == 1500, "следующий платёж к 28-му дню")


func _test_paying_all_debt_wins() -> void:
	var s := _calm_session()
	s.clean = 60000
	_check(s.pay(999999) == 48000, "платёж не больше долга")
	_check(s.status == GameSession.Status.WON and s.money == 12000, "долг закрыт — победа")


func _test_prices_stay_in_bounds() -> void:
	var s := _new_session()
	var ok := true
	for i in 300:
		s.market.roll_day(s.rng, {})
		for good: Dictionary in s.market.goods:
			var factor: float = s.market.factors[good.id]
			ok = ok and factor >= 0.5 and factor <= 1.8
	_check(ok, "цены за 300 дней в пределах ×0.5…×1.8")
	var yesterday := s.buy_price("phones")
	s.end_day()
	_check(s.market.previous_prices.market.phones == yesterday, "стрелки сравнивают со вчерашней ценой")


func _test_heat() -> void:
	var s := _calm_session()
	s.buy("mushrooms", 5)
	_check(s.police.heat.market == 0.0, "легальный товар не даёт розыска")
	s.clean = 10000
	s.buy("phones", 4)
	_check(s.police.heat.market == 10.0 and s.police.heat.station == 0.0, "4 телефона: +10 розыска только в этом районе")
	s.police.heat.market = 65.0
	_check(s.police.stars("market") == 3, "65 розыска = 3 звезды")
	s.end_day()
	_check(s.police.heat.market == 53.0, "за ночь розыск спадает на 12")
	s.lay_low()
	s.end_day()
	_check(s.police.heat.market == 18.0, "залёг на дно — спадает на 35")


func _test_police_check_choices() -> void:
	var s := _calm_session()
	s.clean = 1000
	s.buy("phones", 2)
	s.pending_check = { "bribe": 150 }
	_check(not s.buy("mushrooms", 1) and not s.travel("clubs"), "во время проверки нельзя торговать и уходить")
	var money_before := s.money
	s.bribe()
	_check(s.money == money_before - 150 and s.inventory.phones == 2 and s.can_act(), "откупился — товар при тебе")

	s.pending_check = { "bribe": 150 }
	s.surrender()
	_check(s.inventory.phones == 0 and s.can_act(), "сдал товар — товар забрали, свободен")

	var real := _new_session()
	real.clean = 100000
	real.police.heat.station = 100.0
	real.travel("station")
	var checks := 0
	for i in 40:
		if real.buy("cigarettes", 1):
			pass
		if not real.pending_check.is_empty():
			checks += 1
			real.surrender()
	_check(checks > 5, "при большом розыске проверки случаются часто (%d из 40)" % checks)


func _test_arrest() -> void:
	var s := _calm_session()
	s.clean = 1000
	s.buy("phones", 2)
	s.dirty = 400
	s.bank.deposit = 300
	var day_before := s.day
	s.arrest()
	_check(s.inventory.phones == 0 and s.dirty == 200, "арест: товар и половина грязных забраны")
	_check(s.day == day_before + 2 and s.bank.deposit == 300, "арест: прошло 2 дня, вклад в банке цел")
	_check(s.police.heat.market < 40.0, "арест: розыск района сбрасывается к 40 (и спадает за ночь)")


func _test_bank() -> void:
	var s := _calm_session()
	_check(not s.can_take_loan(), "без честной истории кредита нет")
	s.clean_earned = 1000
	s.police.heat.clubs = 60.0
	_check(not s.can_take_loan(), "при розыске кредита нет")
	s.police.heat.clubs = 0.0
	_check(s.take_bank_loan() == 500 and s.clean == 620 and s.bank.loan == 500, "кредит = половина честно заработанного")
	_check(s.deposit_clean() and s.clean == 0 and s.bank.deposit == 620, "положили чистые на вклад")
	s.dirty = 100
	_check(not s.deposit_clean(), "грязные на вклад не кладутся")
	s.withdraw_deposit()
	_check(s.repay_bank_loan() == 500 and s.bank.loan == 0, "вернули кредит чистыми")


func _test_shark_loan() -> void:
	var s := _calm_session()
	s.borrow_from_shark()
	_check(s.dirty == 500 and s.debt == 48600, "заняли у ростовщика $500, долг +$600")


func _test_events() -> void:
	var s := _calm_session()
	var price := s.market.buy_price("market", "cigarettes")
	s.market.event = s.events._find("cig_shortage")
	_check(s.market.buy_price("market", "cigarettes") > price, "дефицит сигарет поднимает цену")
	s.market.event = s.events._find("station_patrol")
	_check(s.market.event_police("station") > 1.0 and s.market.event_police("clubs") == 1.0, "патруль только на вокзале")
	var seen := 0
	for i in 50:
		s.end_day()
		s.clean = 1000
		s.paid_this_period = 1500
		if not s.events.today.is_empty():
			seen += 1
	_check(seen > 15 and seen < 45, "события случаются часто, но не каждый день (%d из 50)" % seen)


func _test_jobs() -> void:
	var s := _calm_session()
	_check(not s.can_do_activity("loader"), "грузчиком можно работать только на вокзале")
	s.travel("station")
	var reports := s.do_activity("loader")
	_check(s.clean == 200 and s.clean_earned == 80 and s.energy == 50, "грузчик: +$80 чистыми, −50 сил")
	_check(reports.size() >= 1 and reports[0][0] == "LOG_JOB_DONE", "в журнал пишется, что работа сделана")
	s.do_activity("loader")
	_check(not s.can_do_activity("loader") and s.energy == 0, "сил не осталось — работать нельзя")
	s.end_day()
	_check(s.energy == 100, "за ночь силы восстановились")


func _test_shady_job() -> void:
	var s := _calm_session()
	s.do_activity("shady_parcel")
	_check(s.dirty == 120 and s.police.heat.market > 0.0, "левая посылка: +$120 грязными и розыск")
	var busted := 0
	var arrested := 0
	for seed_value in range(1, 101):
		var r := _new_session(seed_value)
		r.police.heat.market = 40.0
		var report := r.do_activity("shady_parcel")
		if report[0][0] == "LOG_ACTIVITY_BUSTED" and r.dirty == 0:
			busted += 1
		var hot := _new_session(seed_value)
		hot.police.heat.market = 100.0
		if hot.do_activity("shady_parcel")[0][0] == "LOG_ARRESTED" and hot.day == 3:
			arrested += 1
	_check(busted > 10, "при розыске левые дела срываются, денег нет (%d из 100)" % busted)
	_check(arrested > 20, "при 3+ звёздах провал = арест на 2 дня (%d из 100)" % arrested)


func _test_gathering() -> void:
	var s := _calm_session()
	s.travel("forest")
	_check(not s.has_market() and not s.buy("mushrooms", 1), "в лесопарке нет рынка")
	s.do_activity("pick_mushrooms")
	_check(s.inventory.mushrooms >= 4 and s.inventory.mushrooms <= 10, "собрал 4–10 грибов (%d)" % s.inventory.mushrooms)
	_check(s.average_cost("mushrooms") == 0, "собранное ничего не стоило")
	s.do_activity("pick_moon_moss")
	_check(s.police.heat.forest > 0.0, "сбор «Лунного мха» даёт розыск")


func _test_skills() -> void:
	var s := _calm_session()
	_check(s.skills.level("charisma") == 0, "навыки с нуля")
	s.skills.add_xp("charisma", 20)
	_check(s.skills.level("charisma") == 1, "20 опыта — уровень 1")
	s.skills.add_xp("charisma", 39)
	_check(s.skills.level("charisma") == 1 and s.skills.progress("charisma") > 0.9, "до 2-го уровня нужно ещё 40")
	s.skills.add_xp("charisma", 1)
	_check(s.skills.level("charisma") == 2, "60 опыта — уровень 2")
	_check(s.activity_pay(s.get_activity("courier")) == 44, "Харизма 2: курьер платит $44 вместо $40")
	var price := s.sell_price("phones")
	s.skills.add_xp("trade", 1000)
	_check(s.sell_price("phones") > price, "Торговля поднимает цену продажи")
	s.skills.add_xp("stealth", 100000)
	_check(s.skills.level("stealth") == 10, "навык не выше 10")


func _test_stall() -> void:
	var s := _calm_session()
	_check(not s.can_buy_stall(), "на ларёк ($400) не хватает")
	s.clean = 1000
	_check(s.buy_stall() and s.clean == 600, "купили ларёк за $400 чистыми")
	s.inventory.mushrooms = 20
	s.inventory.phones = 2
	_check(not s.stock_stall("phones"), "краденые телефоны в ларёк не положишь")
	s.travel("clubs")
	_check(not s.stock_stall("mushrooms"), "выкладывать можно только на рынке")
	s.travel("market")
	_check(s.stock_stall("mushrooms") and s.stall.stock.mushrooms == 20 and s.inventory.mushrooms == 0, "выложили 20 грибов")
	var clean_before := s.clean
	s.end_day()
	_check(s.stall.stock.mushrooms == 5, "за день ларёк продал 15 грибов, осталось 5")
	_check(s.clean > clean_before - 12 - 5, "ларёк принёс чистые деньги (минус аренда и место)")


func _test_save_and_load() -> void:
	var s := _calm_session()
	s.buy("cigarettes", 2)
	s.travel("clubs")
	s.end_day()
	s.end_day()
	s.bank.deposit = 77
	s.skills.add_xp("craft", 33)
	s.clean = 1000
	s.buy_stall()
	s.travel("market")
	s.inventory.herbs = 4
	s.stock_stall("herbs")
	s.energy = 42
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session(7)
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.to_dict()) == JSON.stringify(s.to_dict()), "сохранение и загрузка дают то же состояние")
	s.end_day()
	loaded.end_day()
	_check(loaded.market.buy_price("clubs", "phones") == s.market.buy_price("clubs", "phones"), "после загрузки цены идут так же")


## Не тест, а замер баланса: простой бот торгует 14 дней в районе «рынок».
## В начале занимает у ростовщика $1 000. Покупает самый «просевший» товар
## (цена ниже обычной для района), продаёт, когда цена выше покупки.
## На проверке откупается, если хватает денег, иначе сдаёт товар.
## Выигрыш = внёс $1 500 к сроку.
func _report_balance_bot() -> void:
	var runs := 300
	var wins := 0
	var total_money := 0
	var checks := 0
	for seed_value in range(1, runs + 1):
		var s := _new_session(seed_value)
		s.borrow_from_shark()
		s.borrow_from_shark()
		for day in 14:
			for good: Dictionary in s.market.goods:
				var id: String = good.id
				var amount := _bot_units(s, id, -1, s.average_cost(id) + 1)
				if amount > 0:
					s.sell(id, amount)
					checks += _bot_resolve(s)
			var best := ""
			var best_ratio := 0.85
			for good: Dictionary in s.market.goods:
				var id: String = good.id
				var ratio: float = s.buy_price(id) / _fair_price(s, id)
				if ratio < best_ratio and s.max_affordable(id) > 0:
					best = id
					best_ratio = ratio
			if best != "":
				s.buy(best, _bot_units(s, best, 1, floori(_fair_price(s, best) * 0.95)))
				checks += _bot_resolve(s)
			if day == 13:
				for good: Dictionary in s.market.goods:
					s.sell(good.id, s.inventory[good.id])
					_bot_resolve(s)
				if s.money >= 1500:
					wins += 1
				total_money += s.money
			s.end_day()
	print("\nБаланс (бот, %d партий): набрал $1 500 за 14 дней в %d%% партий, в среднем $%d, проверок полиции в среднем %.1f"
			% [runs, wins * 100 / runs, total_money / runs, float(checks) / runs])


## Замер баланса этапа 3: два честных бота и один «левый» для сравнения.
## «Работяга» (worker): каждый день грузчик на вокзале + курьер на рынке.
## «Ларёчник» (stall): утром собирает травы и грибы в лесопарке, днём курьер,
## как накопит — покупает ларёк и выкладывает туда собранное.
## «Левый» (shady): то же, что работяга, но берёт левые подработки.
## Выигрыш = к концу 14-го дня внесён платёж $1 500.
func _report_honest_bots() -> void:
	var runs := 300
	for bot in ["worker", "stall", "shady"]:
		var wins := 0
		var total_paid := 0
		var total_left := 0
		for seed_value in range(1, runs + 1):
			var s := _new_session(seed_value)
			for day in 14:
				if bot == "worker":
					s.travel("station")
					s.do_activity("loader")
					s.travel("market")
					s.do_activity("courier")
				elif bot == "shady":
					s.travel("station")
					s.do_activity("shady_wagon")
					s.travel("market")
					s.do_activity("shady_parcel")
				else:
					s.travel("forest")
					s.do_activity("pick_herbs")
					s.do_activity("pick_mushrooms")
					s.travel("market")
					if not s.stall.owned and s.clean >= 450:
						s.buy_stall()
					for id in ["herbs", "mushrooms"]:
						if s.stall.owned:
							s.stock_stall(id)
						else:
							s.sell(id, s.inventory[id])
					s.do_activity("courier")
				s.pay(mini(s.payment_left(), s.money - 20))
				s.end_day()
			if s.status == GameSession.Status.PLAYING and s.next_payment_day > 14:
				wins += 1
			total_paid += s.paid_this_period if s.next_payment_day == 14 else 1500
			total_left += s.money + s.bank.deposit
		print("Баланс (честный бот «%s», %d партий): внёс $1 500 к сроку в %d%% партий, в среднем внесено $%d, осталось $%d"
				% [bot, runs, wins * 100 / runs, total_paid / runs, total_left / runs])


## Обычная цена товара в районе (без дневных колебаний).
func _fair_price(s: GameSession, id: String) -> float:
	return s.market.get_good(id).base_price * s.market.get_district(s.district).prices[id]


## Сколько штук купить (step = 1), пока цена не выше limit и хватает денег,
## или продать (step = −1), пока цена продажи не ниже limit.
func _bot_units(s: GameSession, id: String, step: int, limit: int) -> int:
	var p: float = s.market.pressure[s.district][id]
	var money := s.money
	var count := 0
	while true:
		var price := s.market._price(s.district, id, p)
		if step > 0 and (price > limit or price > money):
			return count
		if step < 0 and (count >= s.inventory[id] or s.market._sell(price) < limit):
			return count
		money -= price
		count += 1
		p = s.market._shift(p, id, step)
	return count


func _bot_resolve(s: GameSession) -> int:
	if s.pending_check.is_empty():
		return 0
	if s.can_bribe():
		s.bribe()
	else:
		s.surrender()
	return 1
