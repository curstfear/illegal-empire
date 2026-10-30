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
	_test_history()
	_test_pocket()
	_test_property_buy_and_storage()
	_test_production()
	_test_lab_risks()
	_test_laundering_and_tax()
	_test_cafe_tea()
	_test_property_sale()
	_test_property_upgrades()
	_test_snitch_and_explosion()
	_test_great_batch()
	_test_spoilage_and_evidence()
	_test_properties_save()
	_test_crew_hiring()
	_test_crew_work()
	_test_crew_traits()
	_test_crew_save()
	_test_loyalty()
	_test_betrayal()
	_test_manager()
	_test_routes()
	_test_route_risks()
	_test_logistics_save()
	_test_market_route()
	_test_crew_growth()
	_test_new_roles()
	_test_disguise_and_scout()
	_test_driving_and_leadership()
	_test_save_and_load()
	_report_balance_bot()
	_report_honest_bots()
	print("\nИтог: %d прошло, %d упало" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _new_session(seed_value: int = 42) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(),
			GameData.load_properties(), GameData.load_recipes(), GameData.load_crew(), seed_value)


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


## Сессия с деньгами, без случайных проверок и без брака — для тестов недвижимости.
func _rich_session() -> GameSession:
	var s := _calm_session()
	s.clean = 20000
	s.balance.lab_defect_chance = [0.0, 0.0, 0.0]
	s.balance.lab_fire_chance = [0.0, 0.0, 0.0]
	s.balance.lab_explosion_chance = [0.0, 0.0, 0.0]
	s.balance.great_batch_chance = [0.0, 0.0, 0.0]
	s.balance.great_per_craft_level = 0.0
	s.balance.snitch_per_smell = 0.0
	s.balance.lab_raid_factor = 0.0
	s.balance.warehouse_raid_factor = 0.0
	return s


func _test_pocket() -> void:
	var s := _calm_session()
	_check(s.pocket_used() == 0 and s.pocket_free() == 30, "карман: 30 свободных мест")
	s.clean = 100000
	_check(s.max_affordable("phones") == 15, "телефон занимает 2 места — влезет 15 (сейчас %d)" % s.max_affordable("phones"))
	_check(not s.buy("mushrooms", 31), "31 гриб в карман не влезет")
	s.buy("mushrooms", 28)
	s.travel("forest")
	var report := s.do_activity("pick_herbs")
	_check(s.inventory.herbs <= 2, "собрал не больше, чем влезло (2 места)")
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_POCKET_FULL") or s.inventory.herbs == 2,
			"если не влезло — об этом сказано")


func _test_property_buy_and_storage() -> void:
	var s := _rich_session()
	_check(not s.can_buy_property("station_warehouse"), "склад на вокзале не купить, стоя на рынке")
	_check(s.buy_property("market_warehouse") and s.clean == 18500, "купили склад у рынка за $1 500 чистыми")
	s.dirty = 5000
	s.clean = 100
	s.travel("station")
	_check(not s.can_buy_property("station_lab"), "грязными здание не купить")
	_check(s.rent_property("station_lab") and s.properties.is_mine("station_lab"), "арендовали подвал на вокзале")
	s.travel("market")
	s.clean = 10000
	s.buy("phones", 10)
	_check(s.store_goods("market_warehouse", "phones") == 10 and s.inventory.phones == 0, "положили 10 телефонов на склад")
	_check(s.properties.stock_used("market_warehouse") == 20, "10 телефонов занимают 20 мест склада")
	_check(s.take_goods("market_warehouse", "phones") == 10 and s.inventory.phones == 10, "забрали обратно")
	var clean_before := s.clean
	s.end_day()
	_check(s.clean == clean_before - 12 - 35, "ночью: аренда комнаты $12 и подвала $35")


func _test_production() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.inventory.moon_moss = 6
	s.store_goods("forest_shed", "moon_moss")
	_check(s.start_production("forest_shed", "moon_pollen") == 2, "из 6 мха — 2 партии пыльцы")
	_check(s.properties.stock_of("forest_shed", "moon_moss") == 0, "сырьё ушло в варку")
	var heat_before: float = s.police.heat.forest
	s.end_day()
	_check(s.properties.stock_of("forest_shed", "moon_pollen") == 4, "к утру 4 «Лунной пыльцы»")
	_check(s.police.heat.forest > heat_before - 12.0, "варка пахнет: розыск района растёт")
	# Цепочка: мох → пыльца → «Синяя пыль» (пыльца уже лежит в сарае).
	s.inventory.reagents = 2
	s.store_goods("forest_shed", "reagents")
	_check(s.start_production("forest_shed", "blue_dust") == 1, "«Синяя пыль» варится из пыльцы — второй шаг цепочки")
	_check(s.properties.stock_of("forest_shed", "moon_pollen") == 3, "на партию ушла 1 пыльца")
	s.end_day()
	_check(s.properties.stock_of("forest_shed", "blue_dust") == 0, "«Синяя пыль» за одну ночь не готова")
	s.end_day()
	_check(s.properties.stock_of("forest_shed", "blue_dust") == 1, "через 2 ночи — 1 «Синяя пыль»")
	_check(s.upgrade_lab("forest_shed") and s.properties.state.forest_shed.level == 2, "улучшили оборудование")


func _test_lab_risks() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.balance.lab_defect_chance = [1.0, 1.0, 1.0]
	s.inventory.moon_moss = 3
	s.store_goods("forest_shed", "moon_moss")
	s.start_production("forest_shed", "moon_pollen")
	s.end_day()
	_check(s.properties.stock_of("forest_shed", "moon_pollen") == 1, "брак: вместо 2 пыльцы — 1")

	var raid := _rich_session()
	raid.travel("forest")
	raid.buy_property("forest_shed")
	raid.upgrade_lab("forest_shed")
	raid.inventory.moon_moss = 6
	raid.store_goods("forest_shed", "moon_moss")
	raid.balance.lab_raid_factor = 100.0
	raid.balance.check_base = 1.0
	raid.end_day()
	_check(raid.properties.stock_of("forest_shed", "moon_moss") == 0 and raid.properties.state.forest_shed.level == 1,
			"облава: нелегальное забрали, оборудование сломали")

	var fire := _rich_session()
	fire.travel("forest")
	fire.buy_property("forest_shed")
	fire.balance.lab_fire_chance = [1.0, 1.0, 1.0]
	fire.inventory.moon_moss = 6
	fire.store_goods("forest_shed", "moon_moss")
	fire.start_production("forest_shed", "moon_pollen")
	fire.end_day()
	_check(fire.properties.state.forest_shed.batches.is_empty() and fire.properties.stock_of("forest_shed", "moon_pollen") == 0,
			"пожар: варка пропала")


func _test_laundering_and_tax() -> void:
	var s := _rich_session()
	s.clean = 5000
	s.buy_property("laundromat")
	s.dirty = 1000
	_check(s.launder("laundromat") == 1000 and s.dirty == 0, "сдали $1 000 грязных в прачечную")
	var clean_before := s.clean
	s.end_day()
	_check(s.clean == clean_before + 70 + 510 - 12, "за ночь: касса $70 + отмыто $510 (600 − 15%%) − аренда комнаты")
	_check(s.properties.state.laundromat.dirty_queue == 400, "в очереди осталось $400")
	_check(s.properties.tax_attention == 1.0, "налоговая заметила полный лимит (+4 −3)")
	s.properties.tax_attention = 99.0
	s.balance.tax_audit_chance = 1.0
	var debt_before := s.debt
	var report := s.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_TAX_AUDIT"), "проверка налоговой при высоком внимании")
	_check(s.properties.state.laundromat.frozen_days > 0, "после проверки отмыв заморожен")
	s.dirty = 300
	_check(not s.can_launder("laundromat"), "во время заморозки грязные не принимают")
	_check(s.clean + s.debt - debt_before >= 0, "штраф списан")


func _test_cafe_tea() -> void:
	var s := _rich_session()
	s.travel("clubs")
	s.buy_property("cafe")
	s.inventory.herbs = 4
	s.inventory.mushrooms = 4
	s.store_goods("cafe", "herbs")
	s.store_goods("cafe", "mushrooms")
	_check(s.start_production("cafe", "tea") == 2, "на кухне кафе: 2 партии чая")
	_check(s.start_production("cafe", "moon_pollen") == 0, "пыльцу в кафе не сваришь")
	var report := s.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_CAFE_SOLD"), "кафе продаёт свой чай посетителям в ту же ночь")


func _test_properties_save() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.inventory.moon_moss = 6
	s.store_goods("forest_shed", "moon_moss")
	s.start_production("forest_shed", "moon_pollen")
	s.properties.tax_attention = 12.5
	s.buy_upgrade("forest_shed", "vent")
	s.properties.state.forest_shed.evidence = 18.0
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.properties.to_dict()) == JSON.stringify(s.properties.to_dict()),
			"здания, склад, варка, улучшения, улики и налоговая сохраняются")


## Кандидат с нужной ролью и чертой (подменяем случайного).
func _candidate(s: GameSession, role: String, trait_id: String, skill: int) -> int:
	var person: Dictionary = s.crew.candidates[0]
	person.role = role
	person.trait = trait_id
	person.skill = skill
	person.wage = 50
	return person.id


func _test_crew_hiring() -> void:
	var s := _rich_session()
	_check(s.crew.candidates.size() == 3, "на бирже 3 кандидата")
	var id := _candidate(s, "guard", "loyal", 2)
	var clean_before := s.clean
	_check(s.hire(id) and s.crew.people.size() == 1 and s.clean == clean_before - 50, "наняли: первый день оплачен сразу")
	_check(s.crew.get_candidate(id).is_empty(), "кандидат ушёл с биржи")
	_check(not s.assign(id, "market_warehouse"), "в чужое здание не поставить")
	s.buy_property("market_warehouse")
	_check(s.assign(id, "market_warehouse"), "охранника — на свой склад")
	var cook_id := _candidate(s, "cook", "loyal", 2)
	s.hire(cook_id)
	_check(not s.assign(cook_id, "market_warehouse"), "повар на складе не работает — только в лаборатории")
	var report := s.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_CREW_WAGES"), "ночью платим зарплаты")
	_check(s.crew.candidates.size() == 3 and s.crew.get_candidate(id).is_empty(), "утром на бирже новые кандидаты")
	s.clean = 0
	s.dirty = 60
	report = s.end_day()
	_check(s.crew.people.size() == 1 and report.any(func(e: Array) -> bool: return e[0] == "LOG_CREW_UNPAID"),
			"не хватило денег на зарплату — один ушёл")
	s.sell_property("market_warehouse")
	_check(s.crew.people.all(func(p: Dictionary) -> bool: return p.job == ""), "склад продан — люди без места")
	_check(not s.fire(s.crew.people[0].id).is_empty() and s.crew.people.is_empty(), "уволили")


func _test_crew_work() -> void:
	# Повар: брак ниже, удачных партий больше.
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.balance.lab_defect_chance = [0.25, 0.15, 0.07]
	s.balance.great_batch_chance = [0.05, 0.12, 0.25]
	var defect := s.defect_chance("forest_shed")
	var great := s.great_chance("forest_shed")
	var cook := _candidate(s, "cook", "loyal", 3)
	s.hire(cook)
	s.assign(cook, "forest_shed")
	_check(is_equal_approx(s.defect_chance("forest_shed"), defect - 0.09), "повар 3 ур.: брак −9%%")
	_check(is_equal_approx(s.great_chance("forest_shed"), great + 0.09), "повар 3 ур.: удачная партия +9%%")

	# Охранник: облава реже.
	var g := _rich_session()
	g.buy_property("market_warehouse")
	g.balance.warehouse_raid_factor = 0.5
	g.balance.check_base = 0.3
	var raid := g.raid_chance("market_warehouse")
	var guard := _candidate(g, "guard", "loyal", 3)
	g.hire(guard)
	g.assign(guard, "market_warehouse")
	_check(is_equal_approx(g.raid_chance("market_warehouse"), raid * 0.7), "охранник 3 ур.: облава −30%%")

	# Дилер: сам продаёт со склада, деньги грязные, розыск растёт.
	var d := _rich_session()
	d.buy_property("market_warehouse")
	d.inventory.cigarettes = 10
	d.store_goods("market_warehouse", "cigarettes")
	var dealer := _candidate(d, "dealer", "loyal", 2)
	d.hire(dealer)
	d.assign(dealer, "market_warehouse")
	var dirty_before := d.dirty
	var report := d.end_day()
	_check(d.properties.stock_of("market_warehouse", "cigarettes") == 6, "дилер 2 ур. продал за ночь 4 пачки")
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_DEALER_SOLD"), "в журнале — продажи дилера")
	_check(d.dirty > dirty_before - 50, "выручка дилера — грязными")

	var forest := _rich_session()
	forest.travel("forest")
	forest.buy_property("forest_shed")
	forest.inventory.moon_moss = 5
	forest.store_goods("forest_shed", "moon_moss")
	var lonely := _candidate(forest, "dealer", "loyal", 3)
	forest.hire(lonely)
	forest.assign(lonely, "forest_shed")
	forest.end_day()
	_check(forest.properties.stock_of("forest_shed", "moon_moss") >= 4, "в лесу покупателей нет — дилер не продаёт")


func _test_crew_traits() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	var drunk := _candidate(s, "guard", "drinker", 2)
	s.hire(drunk)
	s.assign(drunk, "market_warehouse")
	s.crew.traits.drinker.no_show = 1.0
	var report := s.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_CREW_NO_SHOW"), "пьющий не вышел на работу")

	var c := _rich_session()
	c.buy_property("market_warehouse")
	c.inventory.cigarettes = 5
	c.store_goods("market_warehouse", "cigarettes")
	var coward := _candidate(c, "guard", "coward", 1)
	c.hire(coward)
	c.assign(coward, "market_warehouse")
	c.balance.warehouse_raid_factor = 100.0
	c.balance.check_base = 1.0
	report = c.end_day()
	_check(c.crew.people.is_empty() and report.any(func(e: Array) -> bool: return e[0] == "LOG_CREW_FLED"),
			"трус при облаве сбежал")

	var h := _rich_session()
	h.buy_property("market_warehouse")
	var hothead := _candidate(h, "guard", "hothead", 2)
	h.hire(hothead)
	h.assign(hothead, "market_warehouse")
	var heat_before: float = h.police.heat.market
	h.end_day()
	_check(h.police.heat.market > heat_before - float(h.balance.heat_decay) + 3.0, "вспыльчивый шумит — розыск района выше")


func _test_crew_save() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	var id := _candidate(s, "dealer", "sly", 3)
	s.hire(id)
	s.assign(id, "market_warehouse")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.crew.to_dict()) == JSON.stringify(s.crew.to_dict()), "бригада и биржа сохраняются")


func _has(report: Array, key: String) -> bool:
	return report.any(func(e: Array) -> bool: return e[0] == key)


func _test_loyalty() -> void:
	var s := _rich_session()
	var loyal := _candidate(s, "guard", "loyal", 2)
	_check(is_equal_approx(float(s.crew.get_candidate(loyal).loyalty), 75.0), "у верного лояльность 75")
	s.hire(loyal)
	var greedy := _candidate(s, "guard", "greedy", 2)
	s.crew.get_candidate(greedy).loyalty = 40.0
	s.hire(greedy)
	s.end_day()
	_check(is_equal_approx(float(s.crew.get_person(loyal).loyalty), 77.0), "за оплаченную ночь верный +2")
	_check(is_equal_approx(float(s.crew.get_person(greedy).loyalty), 40.0), "жадный: +1 за зарплату, −1 за жадность")
	_check(int(s.crew.get_person(loyal).knows) == 1, "за ночь узнал больше")
	var clean_before := s.clean
	_check(s.give_bonus(greedy) and s.clean == clean_before - 100, "премия — два дня зарплаты")
	_check(is_equal_approx(float(s.crew.get_person(greedy).loyalty), 60.0), "премия: лояльность +20")
	_check(not s.can_give_bonus(greedy), "вторая премия в тот же день — нельзя")
	s.pressure(loyal)
	_check(is_equal_approx(float(s.crew.get_person(loyal).fear), 35.0), "надавили: страх 35")
	_check(is_equal_approx(float(s.crew.get_person(loyal).loyalty), 67.0), "надавили: лояльность −10")
	var person := s.crew.get_person(loyal)
	person.loyalty = 10.0
	person.fear = 0.0
	var free := s.betray_chance(person)
	person.fear = 80.0
	_check(free > 0.0 and s.betray_chance(person) < free, "страх снижает шанс предательства")
	person.loyalty = 50.0
	_check(s.betray_chance(person) == 0.0, "лояльный не предаёт")
	var hot := _candidate(s, "guard", "hothead", 2)
	s.hire(hot)
	s.crew.traits.hothead.quits_on_pressure = 1.0
	_check(_has(s.pressure(hot), "LOG_PRESSURE_QUIT") and s.crew.get_person(hot).is_empty(), "вспыльчивый на давление ушёл")


func _test_betrayal() -> void:
	# Жадный ворует со склада, где работает, и пропадает.
	var s := _rich_session()
	s.buy_property("market_warehouse")
	s.inventory.cigarettes = 10
	s.store_goods("market_warehouse", "cigarettes")
	var thief := _candidate(s, "guard", "greedy", 2)
	s.hire(thief)
	s.assign(thief, "market_warehouse")
	s.crew.get_person(thief).loyalty = 0.0
	s.balance.betray_chance_per_point = 1.0
	var report := s.end_day()
	_check(_has(report, "LOG_BETRAY_STOLE_GOODS") and s.crew.people.is_empty(), "нелояльный жадный украл и сбежал")
	_check(s.properties.stock_of("market_warehouse", "cigarettes") == 7, "унёс 30%% товара")

	# Трус доносит: розыск района и улики в здании.
	var c := _rich_session()
	c.buy_property("market_warehouse")
	var rat := _candidate(c, "guard", "coward", 1)
	c.hire(rat)
	c.assign(rat, "market_warehouse")
	c.crew.get_person(rat).loyalty = 0.0
	c.crew.get_person(rat).knows = 20
	c.balance.betray_chance_per_point = 1.0
	var heat_before: float = c.police.heat.market
	report = c.end_day()
	_check(_has(report, "LOG_BETRAY_SNITCH"), "трус донёс")
	_check(c.police.heat.market > heat_before + 15.0, "донос поднял розыск (знал много)")
	_check(c.properties.state.market_warehouse.evidence >= 30.0, "донос — улики в здании")

	# Обиженный при увольнении может сдать.
	var f := _rich_session()
	var angry := _candidate(f, "dealer", "loyal", 2)
	f.hire(angry)
	f.crew.get_person(angry).loyalty = 0.0
	f.crew.get_person(angry).knows = 30
	f.balance.fired_snitch_chance = 1.0
	_check(_has(f.fire(angry), "LOG_FIRED_SNITCHED"), "уволенный обиженный, знающий всё, донёс")


func _test_manager() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.inventory.moon_moss = 6
	s.store_goods("forest_shed", "moon_moss")
	s.properties.state.forest_shed.evidence = 20.0
	var boss := _candidate(s, "manager", "loyal", 3)
	s.hire(boss)
	_check(s.assign(boss, "forest_shed"), "менеджера — в лабораторию")
	var report := s.end_day()
	_check(_has(report, "LOG_MANAGER_BREW"), "менеджер сам запустил варку")
	_check(s.properties.stock_of("forest_shed", "moon_pollen") >= 2 and s.properties.stock_of("forest_shed", "moon_moss") < 3,
			"мох ушёл в варку — к утру пыльца")
	_check(s.properties.state.forest_shed.evidence <= 8.0 + float(s.balance.evidence_per_night), "менеджер прибрал улики")

	var f := _rich_session()
	f.buy_property("laundromat")
	f.dirty = 1000
	var accountant := _candidate(f, "manager", "loyal", 2)
	f.hire(accountant)
	f.assign(accountant, "laundromat")
	report = f.end_day()
	_check(_has(report, "LOG_MANAGER_LAUNDER") and _has(report, "LOG_LAUNDERED"), "менеджер фасада сам сдал грязные в отмыв")


## Две своих точки и курьер на скутере с маршрутом склад → склад.
func _route_session() -> GameSession:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	s.travel("station")
	s.buy_property("station_warehouse")
	s.travel("market")
	s.balance.vehicles.scooter.breakdown = 0.0
	s.balance.route_police_base = 0.0
	s.balance.route_ambush_base = 0.0
	s.balance.route_ambush_per_1000 = 0.0
	return s


func _test_routes() -> void:
	var s := _route_session()
	var clean_before := s.clean
	_check(s.buy_vehicle("scooter") and s.clean == clean_before - 600, "купили скутер за $600")
	var vehicle: int = s.logistics.vehicles[0].id
	var guard := _candidate(s, "guard", "loyal", 2)
	s.hire(guard)
	_check(not s.can_add_route("market_warehouse", "station_warehouse", "cigarettes", vehicle, guard), "охранник — не курьер")
	var courier := _candidate(s, "courier", "loyal", 2)
	s.hire(courier)
	_check(not s.can_add_route("market_warehouse", "market_warehouse", "cigarettes", vehicle, courier), "в то же здание — нельзя")
	_check(not s.can_add_route("market_warehouse", "cafe", "cigarettes", vehicle, courier), "в чужое здание — нельзя")
	_check(s.add_route("market_warehouse", "station_warehouse", "cigarettes", vehicle, courier), "маршрут создан")
	var other := _candidate(s, "courier", "loyal", 2)
	s.hire(other)
	_check(not s.can_add_route("station_warehouse", "market_warehouse", "cigarettes", vehicle, other), "машина занята")
	s.inventory.cigarettes = 30
	s.store_goods("market_warehouse", "cigarettes")
	var report := s.end_day()
	_check(_has(report, "LOG_ROUTE_DELIVERED"), "курьер довёз")
	_check(s.properties.stock_of("station_warehouse", "cigarettes") == 20 and s.properties.stock_of("market_warehouse", "cigarettes") == 10,
			"за ночь скутер увёз 20 пачек")
	s.fire(courier)
	_check(s.logistics.routes.is_empty(), "курьера уволили — маршрут закрыт")
	_check(s.can_add_hidden(vehicle) and s.add_hidden(vehicle) and s.logistics.get_vehicle(vehicle).hidden, "тайник в скутере")


func _test_route_risks() -> void:
	var s := _route_session()
	s.buy_vehicle("van")
	var vehicle: int = s.logistics.vehicles[0].id
	var courier := _candidate(s, "courier", "loyal", 0)
	s.hire(courier)
	s.add_route("market_warehouse", "station_warehouse", "cigarettes", vehicle, courier)
	s.balance.route_police_base = 0.1
	var route: Dictionary = s.logistics.routes[0]
	var plain := s.route_police_chance(route)
	s.logistics.get_vehicle(vehicle).hidden = true
	_check(is_equal_approx(s.route_police_chance(route), plain * 0.5), "тайник: патруль находит вдвое реже")
	s.crew.get_person(courier).skill = 5
	_check(s.route_police_chance(route) < plain * 0.5, "опытный курьер — риск ниже")
	route.good = "mushrooms"
	_check(s.route_police_chance(route) == 0.0, "легальный груз полиции не интересен")
	route.good = "cigarettes"

	s.balance.route_police_base = 100.0
	s.inventory.cigarettes = 20
	s.store_goods("market_warehouse", "cigarettes")
	var report := s.end_day()
	_check(_has(report, "LOG_ROUTE_BUSTED"), "патруль поймал курьера")
	_check(s.crew.get_person(courier).is_empty() and s.logistics.vehicles.is_empty() and s.logistics.routes.is_empty(),
			"курьер сел, машина на штрафстоянке, маршрута нет")
	_check(s.properties.stock_of("market_warehouse", "cigarettes") == 0, "груз забрали")

	var a := _route_session()
	a.buy_vehicle("car")
	var car: int = a.logistics.vehicles[0].id
	var runner := _candidate(a, "courier", "loyal", 2)
	a.hire(runner)
	a.add_route("market_warehouse", "station_warehouse", "cigarettes", car, runner)
	a.balance.route_ambush_base = 1.0
	a.balance.route_ambush_max = 1.0
	a.inventory.cigarettes = 10
	a.store_goods("market_warehouse", "cigarettes")
	report = a.end_day()
	_check(_has(report, "LOG_ROUTE_AMBUSH") and a.properties.stock_of("station_warehouse", "cigarettes") == 0, "засада: груз отобрали")
	_check(float(a.crew.get_person(runner).loyalty) < 75.0, "после засады курьер недоволен")

	var b := _route_session()
	b.buy_vehicle("scooter")
	var scooter: int = b.logistics.vehicles[0].id
	var slow := _candidate(b, "courier", "loyal", 2)
	b.hire(slow)
	b.add_route("market_warehouse", "station_warehouse", "mushrooms", scooter, slow)
	b.balance.vehicles.scooter.breakdown = 1.0
	b.inventory.mushrooms = 10
	b.store_goods("market_warehouse", "mushrooms")
	report = b.end_day()
	_check(_has(report, "LOG_ROUTE_BREAKDOWN") and b.properties.stock_of("station_warehouse", "mushrooms") == 0, "поломка: в эту ночь не поехал")


func _test_logistics_save() -> void:
	var s := _route_session()
	s.buy_vehicle("car")
	var vehicle: int = s.logistics.vehicles[0].id
	s.add_hidden(vehicle)
	var courier := _candidate(s, "courier", "sly", 3)
	s.hire(courier)
	s.add_route("market_warehouse", "station_warehouse", "phones", vehicle, courier)
	s.give_bonus(courier)
	s.pressure(courier)
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _route_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.logistics.to_dict()) == JSON.stringify(s.logistics.to_dict()), "машины и маршруты сохраняются")
	_check(JSON.stringify(loaded.crew.to_dict()) == JSON.stringify(s.crew.to_dict()), "лояльность и страх сохраняются")


func _test_market_route() -> void:
	var s := _route_session()
	s.buy_vehicle("car")
	var car: int = s.logistics.vehicles[0].id
	var courier := _candidate(s, "courier", "loyal", 2)
	s.hire(courier)
	_check(not s.can_add_route("market_warehouse", "@forest", "cigarettes", car, courier), "в лесу рынка нет — маршрут туда нельзя")
	_check(s.add_route("market_warehouse", "@clubs", "cigarettes", car, courier), "маршрут на рынок клубов")
	s.inventory.cigarettes = 30
	s.store_goods("market_warehouse", "cigarettes")
	var quote := s.route_sale_quote(s.logistics.routes[0], 30)
	var dirty_before := s.dirty
	var heat_before: float = s.police.heat.clubs
	var report := s.end_day()
	_check(_has(report, "LOG_ROUTE_SOLD"), "курьер продал на рынке")
	_check(s.properties.stock_of("market_warehouse", "cigarettes") == 0, "весь груз уехал (влез в легковую)")
	_check(s.dirty >= dirty_before + quote - 400, "выручка — грязными")
	_check(s.police.heat.clubs > heat_before - float(s.balance.heat_decay), "розыск в районе продажи")
	s.travel("station")
	s.travel("market")
	s.sell_property("market_warehouse")
	_check(s.logistics.routes.is_empty(), "склад продан — маршрут закрыт")


func _test_crew_growth() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	var guard := _candidate(s, "guard", "loyal", 1)
	s.hire(guard)
	s.assign(guard, "market_warehouse")
	var report: Array = []
	for i in 4:
		report.append_array(s.end_day())
	var person := s.crew.get_person(guard)
	_check(_has(report, "LOG_CREW_SKILL_UP") and int(person.skill) == 2, "4 ночи работы — навык 1 → 2")
	_check(int(person.wage) == s.crew.wage_for("guard", 2, "loyal") and s.crew.wage_for("guard", 2, "loyal") > s.crew.wage_for("guard", 1, "loyal"),
			"вырос навык — зарплата по новой ставке, выше прежней")
	_check(float(person.fatigue) >= 40.0, "за 4 ночи устал")
	var tired := float(person.fatigue)
	_check(s.give_day_off(guard) and float(person.fatigue) < tired, "выходной — усталость меньше")
	_check(not s.can_give_day_off(guard), "второй выходной в тот же день — нельзя")
	report = s.end_day()
	_check(int(person.xp) == 0 and not _has(report, "LOG_CREW_NO_SHOW"), "в выходной не работал и опыта не получил")
	person.fatigue = 100.0
	s.balance.fatigue_no_show = 1.0
	report = s.end_day()
	_check(_has(report, "LOG_CREW_TIRED"), "вымотанный не вышел на работу")

	var p := _rich_session()
	var vet := _candidate(p, "guard", "loyal", 2)
	p.hire(vet)
	_check(not p.can_promote(vet), "навык 2 — до менеджера рано")
	p.crew.get_person(vet).skill = 3
	_check(p.promote(vet) and p.crew.get_person(vet).role == "manager", "навык 3 и верность — повышен до менеджера")
	_check(int(p.crew.get_person(vet).wage) == p.crew.wage_for("manager", 3, "loyal"), "зарплата — как у менеджера")


func _test_new_roles() -> void:
	# Бухгалтер в фасаде: комиссия отмыва меньше.
	var s := _rich_session()
	s.buy_property("laundromat")
	var fee := s.launder_fee("laundromat")
	var acc := _candidate(s, "accountant", "loyal", 3)
	s.hire(acc)
	_check(not s.assign(acc, "market_warehouse"), "бухгалтер работает только в фасаде")
	s.assign(acc, "laundromat")
	_check(is_equal_approx(s.launder_fee("laundromat"), fee - 0.06), "бухгалтер 3 ур.: комиссия −6%%")

	# Адвокат: короче арест, меньше штраф.
	var a := _rich_session()
	a.dirty = 1000
	var lawyer := _candidate(a, "lawyer", "loyal", 3)
	a.hire(lawyer)
	_check(a.arrest_days() == int(a.balance.arrest_days) - 1, "адвокат 3 ур.: на день меньше в камере")
	var report := a.arrest()
	_check(_has(report, "LOG_LAWYER_HELPED"), "адвокат помог при аресте")
	_check(a.day == 1 + int(a.balance.arrest_days) - 1, "арест прошёл быстрее")

	# Адвокат вытаскивает курьера после остановки.
	var r := _route_session()
	r.buy_vehicle("car")
	var courier := _candidate(r, "courier", "loyal", 2)
	r.hire(courier)
	var lw := _candidate(r, "lawyer", "loyal", 5)
	r.hire(lw)
	r.balance.lawyer_free_per_skill = 1.0
	r.add_route("market_warehouse", "station_warehouse", "cigarettes", r.logistics.vehicles[0].id, courier)
	r.balance.route_police_base = 100.0
	r.inventory.cigarettes = 10
	r.store_goods("market_warehouse", "cigarettes")
	report = r.end_day()
	_check(_has(report, "LOG_LAWYER_FREED") and not r.crew.get_person(courier).is_empty(), "адвокат вытащил курьера")


func _test_disguise_and_scout() -> void:
	var s := _route_session()
	s.buy_vehicle("van")
	var van: int = s.logistics.vehicles[0].id
	var courier := _candidate(s, "courier", "loyal", 0)
	s.hire(courier)
	var scout := _candidate(s, "scout", "loyal", 3)
	s.hire(scout)
	_check(not s.can_add_route("market_warehouse", "station_warehouse", "cigarettes", van, courier, courier), "курьер не может быть разведчиком")
	s.add_route("market_warehouse", "station_warehouse", "cigarettes", van, courier)
	s.balance.route_police_base = 0.1
	s.balance.route_ambush_base = 0.1
	var route: Dictionary = s.logistics.routes[0]
	var plain := s.route_police_chance(route)
	var ambush := s.route_ambush_chance(route, 10)
	_check(s.add_disguise(van) and is_equal_approx(s.route_police_chance(route), plain * 0.75), "маскировка: патруль −25%%")
	route.scout = scout
	_check(is_equal_approx(s.route_police_chance(route), plain * 0.75 * 0.7), "разведчик 3 ур.: патруль ещё −30%%")
	_check(is_equal_approx(s.route_ambush_chance(route, 10), ambush * 0.5), "разведчик: засада вдвое реже")
	s.fire(scout)
	_check(s.logistics.routes.size() == 1 and int(s.logistics.routes[0].scout) == 0, "разведчика уволили — маршрут остался без него")


func _test_driving_and_leadership() -> void:
	var s := _rich_session()
	var hours := s.travel_hours()
	s.skills.xp.driving = 1000
	_check(s.travel_hours() < hours, "Вождение: переезд быстрее")
	s.skills.xp.leadership = 1000
	var person := s.crew.get_candidate(_candidate(s, "guard", "loyal", 2))
	person.loyalty = 0.0
	var base := _new_session()
	_check(s.betray_chance(person) < base.betray_chance(person), "Лидерство: предают реже")
	var xp_before: int = base.skills.xp.driving
	base.travel("station")
	_check(int(base.skills.xp.driving) > xp_before, "переезды качают Вождение")


func _test_property_sale() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	s.inventory.mushrooms = 5
	s.store_goods("market_warehouse", "mushrooms")
	_check(not s.can_sell_property("market_warehouse"), "здание с товаром не продать")
	s.take_goods("market_warehouse", "mushrooms")
	var clean_before := s.clean
	_check(s.sell_property("market_warehouse") == 900 and s.clean == clean_before + 900, "продали пустой склад за 60%% цены — $900 чистыми")
	_check(not s.properties.is_mine("market_warehouse"), "склад больше не наш")
	s.travel("station")
	s.rent_property("station_lab")
	_check(s.sell_property("station_lab") == 0 and not s.properties.is_mine("station_lab"), "из аренды можно съехать бесплатно")


func _test_property_upgrades() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	_check(not s.can_buy_upgrade("forest_shed", "books"), "бухгалтерия только для фасадов")
	s.inventory.moon_moss = 6
	s.store_goods("forest_shed", "moon_moss")
	s.start_production("forest_shed", "moon_pollen")
	var smell := s.smell_tonight("forest_shed")
	_check(s.buy_upgrade("forest_shed", "vent") and is_equal_approx(s.smell_tonight("forest_shed"), smell * 0.4), "вентиляция: запах −60%%")
	s.balance.lab_raid_factor = 0.5
	s.balance.check_base = 0.2
	var raid := s.raid_chance("forest_shed")
	s.buy_upgrade("forest_shed", "alarm")
	_check(is_equal_approx(s.raid_chance("forest_shed"), raid * 0.5), "сигнализация: облава −50%%")
	_check(not s.buy_upgrade("forest_shed", "alarm"), "второй раз ту же сигнализацию не поставить")

	var stash := _rich_session()
	stash.travel("forest")
	stash.buy_property("forest_shed")
	stash.buy_upgrade("forest_shed", "stash")
	stash.inventory.moon_moss = 20
	stash.store_goods("forest_shed", "moon_moss")
	stash.balance.lab_raid_factor = 100.0
	stash.balance.check_base = 1.0
	var report := stash.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_STASH_SAVED"), "облава была, но тайник сработал")
	_check(stash.properties.stock_of("forest_shed", "moon_moss") == 15, "в тайнике уцелело 15 мха из 20 (порча до облавы: −1)")

	var books := _rich_session()
	books.clean = 5000
	books.buy_property("laundromat")
	books.buy_upgrade("laundromat", "books")
	books.dirty = 1000
	books.launder("laundromat")
	books.properties.tax_attention = 10.0
	books.end_day()
	_check(books.properties.tax_attention == 9.0, "с двойной бухгалтерией внимание налоговой +2 вместо +4")


func _test_snitch_and_explosion() -> void:
	var s := _rich_session()
	s.travel("clubs")
	s.buy_property("club_lab")
	s.balance.snitch_per_smell = 1.0
	s.inventory.moon_moss = 6
	s.store_goods("club_lab", "moon_moss")
	s.start_production("club_lab", "moon_pollen")
	var heat_before: float = s.police.heat.clubs
	var report := s.end_day()
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_SNITCHED"), "соседи донесли на сильный запах")
	_check(s.police.heat.clubs > heat_before + 12.0, "после доноса розыск района выше, чем от одного запаха")

	var boom := _rich_session()
	boom.travel("forest")
	boom.buy_property("forest_shed")
	boom.upgrade_lab("forest_shed")
	boom.buy_upgrade("forest_shed", "vent")
	boom.balance.lab_explosion_chance = [1.0, 1.0, 1.0]
	boom.inventory.reagents = 2
	boom.inventory.moon_pollen = 1
	boom.store_goods("forest_shed", "reagents")
	boom.store_goods("forest_shed", "moon_pollen")
	boom.start_production("forest_shed", "blue_dust")
	report = boom.end_day()
	var st: Dictionary = boom.properties.state.forest_shed
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_LAB_EXPLOSION"), "«Синяя пыль» может взорваться")
	_check(st.owned and st.stock.is_empty() and st.upgrades.is_empty() and st.level == 1,
			"после взрыва сарай наш, но пустой, без оборудования и улучшений")

	var calm := _rich_session()
	calm.travel("forest")
	calm.buy_property("forest_shed")
	calm.balance.lab_explosion_chance = [1.0, 1.0, 1.0]
	calm.inventory.moon_moss = 3
	calm.store_goods("forest_shed", "moon_moss")
	calm.start_production("forest_shed", "moon_pollen")
	report = calm.end_day()
	_check(not report.any(func(e: Array) -> bool: return e[0] == "LOG_LAB_EXPLOSION"), "пыльца не взрывается")


func _test_great_batch() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.balance.great_batch_chance = [1.0, 1.0, 1.0]
	s.inventory.moon_moss = 3
	s.store_goods("forest_shed", "moon_moss")
	s.start_production("forest_shed", "moon_pollen")
	var report := s.end_day()
	_check(s.properties.stock_of("forest_shed", "moon_pollen") == 3, "удачная партия: 3 пыльцы вместо 2")
	_check(report.any(func(e: Array) -> bool: return e[0] == "LOG_BATCH_GREAT"), "в журнале — удачная партия")


func _test_spoilage_and_evidence() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	s.inventory.mushrooms = 20
	s.inventory.cigarettes = 5
	s.store_goods("market_warehouse", "mushrooms")
	s.store_goods("market_warehouse", "cigarettes")
	s.end_day()
	_check(s.properties.stock_of("market_warehouse", "mushrooms") == 17, "грибы гниют: −15%% за ночь (20 → 17)")
	_check(s.properties.stock_of("market_warehouse", "cigarettes") == 5, "сигареты не портятся")
	_check(s.properties.state.market_warehouse.evidence == 6.0, "нелегальное на складе — копятся улики")
	s.buy_upgrade("market_warehouse", "fridge")
	s.end_day()
	_check(s.properties.stock_of("market_warehouse", "mushrooms") == 17, "с холодильником грибы не гниют")
	s.balance.warehouse_raid_factor = 0.15
	s.balance.check_base = 0.2
	var dirty_raid := s.raid_chance("market_warehouse")
	_check(s.cleanup("market_warehouse") and s.properties.state.market_warehouse.evidence == 0.0, "прибрался — улик нет")
	_check(s.raid_chance("market_warehouse") < dirty_raid, "без улик облава менее вероятна")
	_check(s.energy == int(s.balance.energy_max) - int(s.balance.cleanup_energy), "уборка стоит сил")


func _test_history() -> void:
	var s := _calm_session()
	_check(s.market.price_series("market", "phones").size() == 1, "в первый день на графике одна точка — сегодня")
	var yesterday := s.buy_price("phones")
	s.end_day()
	var series := s.market.price_series("market", "phones")
	_check(series.size() == 2 and series[0] == yesterday, "после дня — вчерашняя цена и сегодняшняя")
	for i in 20:
		s.clean = 1000
		s.paid_this_period = 1500
		s.end_day()
	_check(s.market.price_series("market", "phones").size() == 14, "график хранит не больше 14 дней")
	_check(s.money_series().size() == 14 and s.heat_series().size() == 14, "история денег и розыска — тоже 14 дней")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session(7)
	loaded.load_dict(data)
	_check(loaded.market.price_series("market", "phones") == s.market.price_series("market", "phones"),
			"история цен сохраняется и загружается")


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
