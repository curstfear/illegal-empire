extends SceneTree
## Автотесты логики. Запуск без окна:
## Godot --headless --path . --script res://tests/run_tests.gd

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	_test_start_values()
	_test_buy_and_sell()
	_test_weekly_interest()
	_test_missed_payment_loses()
	_test_payment_on_time()
	_test_paying_all_debt_wins()
	_test_prices_stay_in_bounds()
	_test_save_and_load()
	_report_balance_bot()
	print("\nИтог: %d прошло, %d упало" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _new_session(seed_value: int = 42) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(), seed_value)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)


func _test_start_values() -> void:
	var s := _new_session()
	_check(s.money == 120 and s.debt == 48000 and s.day == 1, "старт: $120, долг $48 000, день 1")
	_check(s.next_payment_day == 14 and s.payment_left() == 1500, "старт: платёж $1 500 к 14-му дню")


func _test_buy_and_sell() -> void:
	var s := _new_session()
	var price := s.market.buy_price("mushrooms")
	_check(s.buy("mushrooms", 3), "покупка 3 грибов")
	_check(s.money == 120 - price * 3 and s.inventory.mushrooms == 3, "деньги списаны, грибы в кармане")
	_check(s.average_cost("mushrooms") == price, "средняя цена покупки")
	_check(not s.buy("blue_dust", 1), "нельзя купить дороже, чем есть денег")
	_check(not s.sell("mushrooms", 4), "нельзя продать больше, чем есть")
	var money_before := s.money
	_check(s.sell("mushrooms", 2), "продажа 2 грибов")
	_check(s.money == money_before + s.market.sell_price("mushrooms") * 2, "деньги за продажу пришли")
	_check(s.market.sell_price("mushrooms") < s.market.buy_price("mushrooms"), "продать дешевле, чем купить")


func _test_weekly_interest() -> void:
	var s := _new_session()
	for i in 6:
		s.end_day()
	_check(s.debt == 48000, "до 7-го дня проценты не начислены")
	s.end_day()
	_check(s.debt == 48960, "после 7-го дня +2%% (48 960), сейчас %d" % s.debt)


func _test_missed_payment_loses() -> void:
	var s := _new_session()
	for i in 13:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING, "13 дней без платежа — ещё играем")
	s.end_day()
	_check(s.status == GameSession.Status.LOST, "не заплатил к концу 14-го дня — проигрыш")


func _test_payment_on_time() -> void:
	var s := _new_session()
	s.money = 2000
	_check(s.pay(1500) == 1500 and s.payment_left() == 0, "внесли $1 500")
	for i in 14:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING, "платёж внесён — игра идёт")
	_check(s.next_payment_day == 28 and s.payment_left() == 1500, "следующий платёж к 28-му дню")


func _test_paying_all_debt_wins() -> void:
	var s := _new_session()
	s.money = 60000
	_check(s.pay(999999) == 48000, "платёж не больше долга")
	_check(s.status == GameSession.Status.WON and s.money == 12000, "долг закрыт — победа")


func _test_prices_stay_in_bounds() -> void:
	var s := _new_session()
	var ok := true
	for i in 300:
		s.market.roll_day(s.rng)
		for good: Dictionary in s.market.goods:
			var factor: float = s.market.factors[good.id]
			ok = ok and factor >= 0.5 and factor <= 1.8
	_check(ok, "цены за 300 дней в пределах ×0.5…×1.8")


func _test_save_and_load() -> void:
	var s := _new_session()
	s.buy("cigarettes", 2)
	s.end_day()
	s.end_day()
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _new_session(7)
	loaded.load_dict(data)
	_check(loaded.to_dict() == s.to_dict() or JSON.stringify(loaded.to_dict()) == JSON.stringify(s.to_dict()),
			"сохранение и загрузка дают то же состояние")
	s.end_day()
	loaded.end_day()
	_check(loaded.market.buy_price("phones") == s.market.buy_price("phones"), "после загрузки цены идут так же")


## Не тест, а замер баланса: простой бот торгует 14 дней.
## Покупает самый «просевший» товар, продаёт, когда цена выше покупки.
func _report_balance_bot() -> void:
	var runs := 300
	var wins := 0
	var total_money := 0
	for seed_value in range(1, runs + 1):
		var s := _new_session(seed_value)
		for day in 14:
			for good: Dictionary in s.market.goods:
				var id: String = good.id
				if s.inventory[id] > 0 and s.market.sell_price(id) > s.average_cost(id):
					s.sell(id, s.inventory[id])
			var best := ""
			for good: Dictionary in s.market.goods:
				var id: String = good.id
				if s.market.factors[id] < 0.85 and s.max_affordable(id) > 0 \
						and (best == "" or s.market.factors[id] < s.market.factors[best]):
					best = id
			if best != "":
				s.buy(best, s.max_affordable(best))
			if day == 13:
				for good: Dictionary in s.market.goods:
					s.sell(good.id, s.inventory[good.id])
				if s.money >= 1500:
					wins += 1
				total_money += s.money
			s.end_day()
	print("\nБаланс (бот, %d партий): набрал $1 500 за 14 дней в %d%% партий, в среднем $%d"
			% [runs, wins * 100 / runs, total_money / runs])
