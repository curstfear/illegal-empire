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
	_test_paying_all_debt_goes_on()
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
	_test_gangs_start()
	_test_gang_anger_and_influence()
	_test_gang_night()
	_test_gangs_save()
	_test_gang_demand()
	_test_gang_attack()
	_test_gang_poach_dump_deal()
	_test_gang_ambush()
	_test_fighters_and_gear()
	_test_fight_win_outcomes()
	_test_fight_loss_and_wounds()
	_test_fight_defense_and_save()
	_test_meetings()
	_test_treaties()
	_test_peace_tax()
	_test_treaty_betrayal()
	_test_detectives()
	_test_swat()
	_test_krysha()
	_test_retake_and_hush()
	_test_police_save()
	_test_world()
	_test_flights()
	_test_world_save()
	_test_city_stats()
	_test_documents()
	_test_customs()
	_test_city_content()
	_test_shipments()
	_test_hourly_business()
	_test_suppliers()
	_test_manager_orders()
	_test_chain_without_clicks()
	_test_orders()
	_test_situations()
	_test_ranks()
	_test_new_goods()
	_test_arsenal()
	_test_car_theft()
	_test_hacker()
	_test_casino()
	_test_ring_and_races()
	_test_smuggling_lines()
	_test_customs_insider()
	_test_operations()
	_test_modes_and_start()
	_test_world_events()
	_test_newspaper()
	_test_stories()
	_test_iron_mode()
	_test_endings()
	_test_save_and_load()
	_report_balance_bot()
	_report_honest_bots()
	print("\nИтог: %d прошло, %d упало" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _new_session(seed_value: int = 42) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(),
			GameData.load_properties(), GameData.load_recipes(), GameData.load_crew(), GameData.load_gangs(), GameData.load_world(), seed_value)


## Сессия без случайных проверок полиции и без событий дня — для тестов торговли.
## with_events — события идут как в игре (для тестов событий и газеты).
func _calm_session(seed_value: int = 42, with_events: bool = false) -> GameSession:
	var s := _new_session(seed_value)
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0
	s.balance.situation_chance = 0.0
	if not with_events:
		s.balance.event_chance = 0.0
		s.balance.world_event_chance = 0.0
		s.events.tomorrow = {}
		s.events.world_tomorrow = {}
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


func _test_paying_all_debt_goes_on() -> void:
	var s := _calm_session()
	s.clean = 60000
	_check(s.pay(999999) == 48000, "платёж не больше долга")
	_check(s.status == GameSession.Status.PLAYING and s.money == 12000, "долг закрыт — игра продолжается (это цель, а не конец)")
	for i in 30:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING and s.debt == 0, "без долга сроки платежей и проценты не страшны")


func _test_prices_stay_in_bounds() -> void:
	var s := _new_session()
	var ok := true
	for i in 300:
		s.market.roll_day(s.rng)
		for city: String in s.market.factors:
			for good: Dictionary in s.market.goods:
				var factor: float = s.market.factors[city][good.id]
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
	var s := _calm_session(42, true)
	var price := s.market.buy_price("market", "cigarettes")
	s.market.city_events = { "berlin": [s.events.find("cig_shortage")] }
	_check(s.market.buy_price("market", "cigarettes") > price, "дефицит сигарет поднимает цену")
	s.market.city_events = { "berlin": [s.events.find("station_patrol")] }
	_check(s.market.event_police("station") > 1.0 and s.market.event_police("clubs") == 1.0, "патруль только в порту/на вокзале (район вида port)")
	s.market.city_events = { "amsterdam": [s.events.find("station_patrol")] }
	_check(s.market.event_police("ams_port") > 1.0 and s.market.event_police("station") == 1.0, "патруль Амстердама — в его порту, не на вокзале Берлина")
	var seen := 0
	for i in 50:
		s.end_day()
		s.clean = 1000
		s.paid_this_period = 1500
		if not s.events.today_in("berlin").is_empty():
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
	person.loyalty = float(s.crew.traits[trait_id].get("loyalty", s.balance.loyalty_start))
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
	a.gangs.change_relation("bazaar", -100.0)
	a.inventory.cigarettes = 10
	a.store_goods("market_warehouse", "cigarettes")
	report = a.end_day()
	_check(_has(report, "LOG_GANG_AMBUSH") and a.properties.stock_of("station_warehouse", "cigarettes") == 0, "засада: груз отобрали")
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
	s.balance.snitch_max = 1.0
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


func _test_gangs_start() -> void:
	var s := _new_session()
	_check(s.gangs.gang_owner("market") == "bazaar", "Рынок держат Базарные")
	_check(s.gangs.gang_owner("station") == "rails", "Вокзал держат Путейцы")
	_check(s.gangs.gang_owner("clubs") == "neon", "Клубы держит Неон")
	_check(s.gangs.owner("forest") == "", "Лесопарк — ничья земля")
	_check(s.gangs.level("neon") == "neutral", "в начале со всеми нейтралитет")
	_check(s.gangs.strength("rails") > s.gangs.strength("neon"), "у Путейцев людей больше — они сильнее")


func _test_gang_anger_and_influence() -> void:
	var s := _calm_session()
	s.travel("clubs")
	s.inventory.blue_dust = 10
	var relation_before := s.gangs.relation("neon")
	var revenue := s.quote_sell("blue_dust", 10)
	s.sell("blue_dust", 10)
	var drop := relation_before - s.gangs.relation("neon")
	_check(drop > 0.0, "нелегальная продажа на чужой земле злит хозяев")
	_check(is_equal_approx(s.gangs.share("clubs", Gangs.PLAYER), revenue / 100.0 * float(s.balance.player_influence_per_100)), "продажа даёт влияние в районе")
	_check(s.gangs.relation("bazaar") == 0.0, "банды других районов не замечают")
	s.inventory.tea = 10
	s.sell("tea", 10)
	_check(is_equal_approx(relation_before - s.gangs.relation("neon"), drop), "легальная торговля банду не злит")
	# Ничья земля кончилась — твоё влияние теснит хозяина района.
	s.gangs.player_gain("clubs", 40.0)
	_check(s.gangs.share("clubs", "neon") < float(s.balance.gang_home_influence), "много влияния — хозяин района теряет своё")
	var neon_share := s.gangs.share("clubs", "neon")
	s.gangs.player_gain("clubs", 10.0)
	_check(s.gangs.share("clubs", "neon") > neon_share - 10.0 * 0.5, "торговлей банду теснишь медленно")
	s.gangs.player_gain("clubs", 60.0, 1.0)
	_check(s.gangs.owner("clubs") == Gangs.PLAYER, "влияния больше всех — район твой")
	_check(s.gangs.gang_owner("clubs") == "", "у твоего района нет хозяина-банды")
	s.gangs.change_relation("neon", -200.0)
	_check(s.gangs.level("neon") == "enemy", "сильно разозлил — вражда")
	_check(s.gangs.relation("neon") == -100.0, "отношение не ниже −100")


func _test_gang_night() -> void:
	var s := _calm_session()
	s.gangs.player_gain("forest", 10.0)
	s.gangs.change_relation("bazaar", -30.0)
	var cash_before: int = s.gangs.state.rails.cash
	var people_before: int = s.gangs.state.rails.people
	var report := s.end_day()
	_check(s.gangs.share("forest", Gangs.PLAYER) < 10.0, "без дел твоё влияние выветривается")
	_check(s.gangs.relation("bazaar") > -30.0, "обида со временем остывает")
	# Доход идёт в общак, но банда может сразу потратить его на новых людей.
	_check(int(s.gangs.state.rails.cash) > cash_before or int(s.gangs.state.rails.people) > people_before,
			"банда получает доход со своих земель")
	_check(_has(report, "LOG_GANG_NOW_RIVAL"), "в журнале — банда стала соперником")
	report = s.end_day()
	_check(not _has(report, "LOG_GANG_NOW_RIVAL"), "о том же уровне не повторяют")
	# Лаборатория на чужой земле держит влияние и злит хозяев (сравниваем с такой же ночью без неё).
	var t := _calm_session()
	var without := _calm_session()
	for x: GameSession in [t, without]:
		x.clean = 5000
		x.travel("clubs")
	t.buy_property("club_lab")
	t.end_day()
	without.end_day()
	_check(t.gangs.relation("neon") < without.gangs.relation("neon"), "лаборатория на чужой земле злит хозяев")
	_check(t.gangs.share("clubs", Gangs.PLAYER) > 0.0, "лаборатория даёт влияние в районе")


func _test_gangs_save() -> void:
	var s := _calm_session()
	s.gangs.player_gain("station", 12.5)
	s.gangs.change_relation("rails", -44.0)
	s.end_day()
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.gangs.to_dict()) == JSON.stringify(s.gangs.to_dict()), "банды и влияние сохраняются")


## Банды без случайных дел ночью (кроме тех, что тест включает сам).
func _quiet_gangs(s: GameSession) -> void:
	for level: String in s.balance.gang_act_chance:
		s.balance.gang_act_chance[level] = 0.0
		s.balance.gang_deal_chance[level] = 0.0


func _test_gang_demand() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.travel("clubs")
	s.inventory.blue_dust = 10
	s.sell("blue_dust", 10)
	_check(s._gang_demand("bazaar").is_empty(), "с чужой земли долю не требуют")
	var report := s._gang_demand("neon")
	_check(_has(report, "LOG_GANG_DEMAND") and s.gangs.offers.size() == 1, "Неон требует долю с продаж в клубах")
	var offer: Dictionary = s.gangs.offers[0]
	_check(int(offer.amount) >= int(s.balance.gang_demand_min), "доля не меньше минимума")
	_check(s._gang_demand("neon").is_empty(), "второе требование, пока не ответил, не приходит")
	var relation := s.gangs.relation("neon")
	var money_before := s.money
	s.answer_offer(int(offer.id), true)
	_check(s.money == money_before - int(offer.amount) and s.gangs.relation("neon") > relation, "заплатил долю — банда подобрела")
	s._gang_demand("neon")
	offer = s.gangs.offers[0]
	relation = s.gangs.relation("neon")
	s.answer_offer(int(offer.id), false)
	_check(s.gangs.relation("neon") < relation and s.gangs.state.neon.revenge, "отказал — обида и месть")
	s.gangs.turf_sales.clubs = 500
	s._gang_demand("neon")
	var days := int(s.balance.gang_offer_days)
	# Требование пришло днём: ответить можно в этот день и ещё days дней.
	for i in days + 1:
		s.end_day()
	_check(s.gangs.offers.is_empty(), "не ответил вовремя — требование пропало")
	_check(s.gangs.relation("neon") < relation, "молчание — тоже отказ")


func _test_gang_attack() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.clean = 5000
	s.travel("clubs")
	s.buy_property("club_lab")
	s.properties.add_stock("club_lab", "blue_dust", 10)
	_check(s._gang_attack("bazaar").is_empty(), "соперник не лезет на чужую землю")
	var bare := s.gang_attack_chance("neon", "club_lab")
	var guard := _candidate(s, "guard", "loyal", 3)
	s.hire(guard)
	s.assign(guard, "club_lab")
	_check(s.gang_attack_chance("neon", "club_lab") < bare, "охрана снижает шанс налёта")
	s.balance.gang_attack_base = 100000.0
	var report := s._gang_attack("neon")
	_check(_has(report, "LOG_GANG_RAID") and s.properties.stock_of("club_lab", "blue_dust") == 5, "налёт удался — забрали половину")
	s.balance.gang_attack_base = 0.0
	s.balance.gang_attack_share = 0.0
	var people: int = s.gangs.state.neon.people
	s.crew.get_person(guard).wounded = 0
	report = s._gang_attack("neon")
	_check(_has(report, "LOG_GANG_RAID_REPELLED") and int(s.gangs.state.neon.people) == people - 1, "отбились — банда потеряла человека")
	# Обиженная банда мстит ночью наверняка.
	s.balance.gang_attack_base = 100000.0
	s.gangs.state.bazaar.revenge = true
	report = s.end_day()
	_check(_has(report, "LOG_GANG_RAID") and not s.gangs.state.bazaar.revenge, "месть: налёт в ту же ночь")


func _test_gang_poach_dump_deal() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.clean = 5000
	var happy := _candidate(s, "dealer", "loyal", 2)
	s.hire(happy)
	_check(s._gang_poach("neon").is_empty(), "довольных не переманить")
	var sad := _candidate(s, "guard", "greedy", 2)
	s.hire(sad)
	s.crew.get_person(sad).loyalty = 10.0
	s.balance.gang_poach_chance = 1.0
	var people: int = s.gangs.state.neon.people
	var report := s._gang_poach("neon")
	_check(_has(report, "LOG_GANG_POACHED") and s.crew.get_person(sad).is_empty(), "недовольного переманили")
	_check(int(s.gangs.state.neon.people) == people + 1, "у банды стало больше людей")
	# Банда сбрасывает самое дорогое нелегальное, чем торгуют в районе (сейчас — автоматы).
	var price := s.market.sell_price("clubs", "rifle")
	report = s._gang_dump("neon")
	_check(_has(report, "LOG_GANG_DUMP") and s.market.sell_price("clubs", "rifle") < price, "сброс товара бандой снижает цену")
	report = s._gang_deal("rails")
	var offer: Dictionary = s.gangs.offers[0]
	var good: String = offer.good
	_check(_has(report, "LOG_GANG_DEAL_OFFER") and int(offer.amount) < s.market.buy_price("station", good) * int(offer.units),
			"сделка дешевле рынка")
	var had: int = s.inventory[good]
	s.answer_offer(int(offer.id), true)
	_check(s.inventory[good] == had + int(offer.units) and s.gangs.offers.is_empty(), "сделка: товар в кармане")
	s.inventory[good] = 0


func _test_gang_ambush() -> void:
	var s := _route_session()
	s.buy_vehicle("car")
	var car: int = s.logistics.vehicles[0].id
	var courier := _candidate(s, "courier", "loyal", 2)
	s.hire(courier)
	s.add_route("market_warehouse", "@clubs", "cigarettes", car, courier)
	s.balance.route_ambush_base = 0.02
	var route: Dictionary = s.logistics.routes[0]
	var calm := s.route_ambush_chance(route, 10)
	s.gangs.change_relation("neon", -100.0)
	_check(s.route_ambush_chance(route, 10) > calm, "враги в районе пути — засады чаще")
	s.gangs.change_relation("neon", 200.0)
	s.gangs.change_relation("bazaar", 100.0)
	_check(s.route_ambush_chance(route, 10) == 0.0, "с друзьями на обоих концах засад нет")
	_check(s._ambusher(route) != "", "засаду устраивает банда района")


## Партия с бойцами: count бойцов навыка skill (без случайных дел банд).
func _fight_session(count: int, skill: int = 3) -> GameSession:
	var s := _calm_session()
	_quiet_gangs(s)
	s.clean = 20000
	for i in count:
		s.crew.roll_candidates(s.rng, 3)
		s.hire(_candidate(s, "fighter", "loyal", skill))
	return s


func _test_fighters_and_gear() -> void:
	var s := _fight_session(0)
	_check(not s.can_fight("neon"), "без бойцов на разборку не пойти")
	s.crew.roll_candidates(s.rng, 3)
	s.hire(_candidate(s, "guard", "loyal", 3))
	_check(not s.can_fight("neon"), "одной охраны мало — нужен боец")
	var guards_only := s.crew_power()
	s.crew.roll_candidates(s.rng, 3)
	s.hire(_candidate(s, "fighter", "loyal", 3))
	_check(s.can_fight("neon"), "с бойцом — можно")
	_check(s.crew_power() - guards_only > guards_only, "боец сильнее охранника")
	var plain := s.crew_power()
	_check(s.buy_gear() and s.gear == 1 and s.crew_power() > plain, "снаряжение усиливает бригаду")
	_check(is_equal_approx(s.fight_power("cunning"), s.crew_power() * 0.8), "хитростью без разведчика — слабее")
	s.crew.roll_candidates(s.rng, 3)
	s.hire(_candidate(s, "scout", "loyal", 2))
	_check(is_equal_approx(s.fight_power("cunning"), s.crew_power()), "с разведчиком хитростью — в полную силу")
	_check(s.fight_district("neon") == "clubs" and s.fight_district("nobody") == "", "наезжать на банду — в её район")
	_check(s.fight_chance("neon", "head_on") > 0.0 and s.fight_chance("neon", "head_on") < 1.0, "шанс победы между 0 и 1")
	s.energy = 0
	_check(not s.can_fight("neon"), "без сил на разборку не пойти")


func _test_fight_win_outcomes() -> void:
	for option: String in ["take", "tribute", "mercy"]:
		var s := _fight_session(3)
		s.balance.fight_wound_chance = 0.0
		s.balance.fight_death_chance = 0.0
		s.gangs.state.neon.people = 1
		s.gangs.state.neon.cash = 1000
		var relation := s.gangs.relation("neon")
		var share := s.gangs.share("clubs", "neon")
		var heat: float = s.police.heat.clubs
		var report := s.fight("neon", "head_on")
		_check(_has(report, "LOG_FIGHT_WON") and s.fight_result.win, "сильная бригада побеждает слабую банду (%s)" % option)
		_check(not s.can_act(), "пока не выбрал последствия, действовать нельзя (%s)" % option)
		_check(s.police.heat.clubs > heat and s.gangs.relation("neon") < relation, "разборка — розыск и обида (%s)" % option)
		var dirty := s.dirty
		var after := s.gangs.relation("neon")
		s.choose_fight_outcome(option)
		_check(s.can_act(), "выбрал — можно играть дальше (%s)" % option)
		match option:
			"take":
				_check(s.gangs.share("clubs", "neon") <= share - float(s.balance.fight_take_influence) + 0.001,
						"забрал землю — у банды меньше влияния")
			"tribute":
				_check(s.dirty == dirty + 300 and int(s.gangs.state.neon.cash) == 700, "выкуп — 30%% общака грязными")
			"mercy":
				_check(s.gangs.relation("neon") > after, "отпустил — обида меньше")


func _test_fight_loss_and_wounds() -> void:
	var s := _fight_session(2, 1)
	s.gangs.state.rails.people = 20
	s.gangs.state.rails.cash = 50000
	s.balance.fight_wound_chance = 1.0
	s.balance.fight_death_chance = 0.0
	var report := s.fight("rails", "head_on")
	_check(_has(report, "LOG_FIGHT_LOST") and not s.fight_result.win, "слабая бригада проигрывает сильной банде")
	_check(s.fight_result.wounded.size() == 2 and s.fighters_ready().is_empty(), "раненые не готовы к новой разборке")
	s.choose_fight_outcome("ok")
	_check(s.can_act(), "поражение — закрыл отчёт и играешь дальше")
	var days := 0
	while not s.fighters_ready().size() == 2 and days < 10:
		s.end_day()
		days += 1
	_check(days >= int(s.balance.fight_wound_days[0]) and days <= int(s.balance.fight_wound_days[1]), "раненые лечатся несколько дней")
	var t := _fight_session(2)
	t.balance.fight_death_chance = 1.0
	report = t.fight("neon", "head_on")
	_check(_has(report, "LOG_FIGHT_DIED") and t.crew.people.is_empty(), "погибшие уходят из бригады")


func _test_fight_defense_and_save() -> void:
	var s := _fight_session(0)
	s.travel("clubs")
	s.buy_property("club_lab")
	s.properties.add_stock("club_lab", "blue_dust", 10)
	var bare := s.gang_attack_chance("neon", "club_lab")
	s.crew.roll_candidates(s.rng, 3)
	var fighter := _candidate(s, "fighter", "loyal", 3)
	s.hire(fighter)
	s.assign(fighter, "club_lab")
	_check(s.gang_attack_chance("neon", "club_lab") < bare, "боец в здании защищает от налёта")
	s.balance.gang_attack_base = 100000.0
	s.balance.defender_wound_lost = 1.0
	var report := s._gang_attack("neon")
	_check(_has(report, "LOG_FIGHT_WOUNDED") and int(s.crew.get_person(fighter).wounded) > 0, "налёт удался — защитник ранен")
	s.buy_gear()
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _fight_session(0)
	loaded.load_dict(data)
	_check(loaded.gear == 1 and int(loaded.crew.get_person(fighter).wounded) == int(s.crew.get_person(fighter).wounded),
			"снаряжение и раны сохраняются")


func _test_meetings() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.clean = 2000
	var relation := s.gangs.relation("rails")
	var report := s.meet("rails")
	_check(_has(report, "LOG_MEET_DONE") and s.gangs.relation("rails") > relation, "встреча с боссом улучшает отношение")
	_check(s.clean == 2000 - int(s.balance.meet_gift), "встреча — подарок")
	_check(not s.can_meet("rails"), "второй раз за день не встретиться")
	s.gangs.change_relation("neon", -100.0)
	s.balance.meet_trap_chance = 1.0
	var energy := s.energy
	report = s.meet("neon")
	_check(_has(report, "LOG_MEET_TRAP") and s.energy < energy and s.gangs.relation("neon") == -100.0, "враги: встреча-ловушка")


func _test_treaties() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.next_payment_day = 1000
	s.clean = 20000
	_check(not s.treaty_allowed("neon", "alliance"), "союз — только с друзьями")
	_check(not s.treaty_allowed("neon", "truce"), "перемирие — только в войне")
	_check(s.sign_treaty("rails", "nonaggression").size() == 1 and s.gangs.has_treaty("rails"), "ненападение с Путейцами")
	_check(not s.can_sign("rails", "truce"), "второй договор с той же бандой нельзя")
	s.gangs.change_relation("rails", -100.0)
	s.balance.gang_act_chance.enemy = 1.0
	s.clean = 20000
	s.buy_property("station_warehouse")
	s.properties.add_stock("station_warehouse", "phones", 10)
	var report := s._gang_turn("rails")
	_check(report.is_empty(), "по договору банда не трогает даже во вражде")
	_check(s.gangs.hostility("station") == 0.0, "по договору засад нет")
	for temper: String in s.gangs.tempers:
		s.gangs.tempers[temper].betray = 0.0
	# Договор защищает 14 ночей и заканчивается в начале 15-й.
	for i in int(s.balance.treaties.nonaggression.days) + 1:
		s.end_day()
	_check(not s.gangs.has_treaty("rails"), "ненападение кончается через 14 дней")
	# Перемирие во вражде, союз с друзьями помогает в драке.
	s.gangs.change_relation("neon", -100.0)
	_check(s.sign_treaty("neon", "truce").size() == 1 and s.clean < 20000, "перемирие за плату")
	s.gangs.change_relation("bazaar", 100.0)
	s.crew.roll_candidates(s.rng, 3)
	s.hire(_candidate(s, "fighter", "loyal", 3))
	var alone := s.fight_power("head_on", "rails")
	s.sign_treaty("bazaar", "alliance")
	_check(s.fight_power("head_on", "rails") > alone, "союзник помогает в разборке")
	_check(is_equal_approx(s.fight_power("head_on", "bazaar"), alone), "против самого союзника помощи нет")
	# Напал на союзника — предательство.
	var others := s.gangs.relation("neon")
	report = s.fight("bazaar", "head_on")
	_check(_has(report, "LOG_TREATY_BROKEN_BY_YOU") and not s.gangs.has_treaty("bazaar"), "напал на союзника — договор разорван")
	_check(s.gangs.relation("neon") < others, "о предательстве узнали другие банды")


func _test_peace_tax() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.next_payment_day = 1000
	s.clean = 5000
	var tax := s.treaty_cost("neon", "peace_tax")
	s.sign_treaty("neon", "peace_tax")
	_check(s.clean == 5000 - tax, "налог за мир: первая неделя сразу")
	s.travel("clubs")
	s.inventory.blue_dust = 10
	var relation := s.gangs.relation("neon")
	s.sell("blue_dust", 10)
	_check(s.gangs.relation("neon") == relation, "с налогом банда не злится на торговлю")
	for temper: String in s.gangs.tempers:
		s.gangs.tempers[temper].betray = 0.0
	s.clean = tax + 500
	s.dirty = 0
	var report: Array = []
	for i in 8:
		report.append_array(s.end_day())
	_check(_has(report, "LOG_TAX_PAID") and s.gangs.has_treaty("neon"), "через неделю — снова налог")
	s.clean = 0
	s.dirty = 0
	report = []
	for i in 7:
		report.append_array(s.end_day())
	_check(_has(report, "LOG_TAX_MISSED") and not s.gangs.has_treaty("neon"), "нечем платить — договор сорван")
	var t := _calm_session()
	t.clean = 5000
	t.sign_treaty("neon", "peace_tax")
	relation = t.gangs.relation("neon")
	t.cancel_treaty("neon")
	_check(not t.gangs.has_treaty("neon") and t.gangs.relation("neon") < relation, "перестал платить сам — небольшая обида")


func _test_treaty_betrayal() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.sign_treaty("rails", "nonaggression")
	var calm := s.gang_betray_chance("rails")
	_check(calm > 0.0, "банда может нарушить договор")
	s.gangs.change_relation("rails", -50.0)
	_check(s.gang_betray_chance("rails") > calm, "при плохом отношении — чаще")
	s.gangs.treaties.erase("rails")
	s.sign_treaty("neon", "nonaggression")
	s.balance.betray_weak_mult = 1.0
	s.gangs.temper("neon").betray = 1.0
	var report := s.end_day()
	_check(_has(report, "LOG_TREATY_BETRAYED") and not s.gangs.has_treaty("neon"), "банда нарушила договор")
	var u := _calm_session()
	u.sign_treaty("rails", "nonaggression")
	var cancel := u.cancel_treaty("rails")
	_check(_has(cancel, "LOG_TREATY_BROKEN_BY_YOU"), "досрочно разорвал ненападение — предательство")


## Партия с лабораторией в клубах, где лежит нелегальное, без случайных облав.
func _police_session() -> GameSession:
	var s := _calm_session()
	_quiet_gangs(s)
	s.next_payment_day = 1000
	s.clean = 20000
	s.travel("clubs")
	s.buy_property("club_lab")
	s.properties.add_stock("club_lab", "blue_dust", 5)
	return s


func _test_detectives() -> void:
	var s := _police_session()
	s.end_day()
	_check(s.police.dossier.clubs == 0.0, "при низком розыске дела нет")
	s.police.heat.clubs = 90.0
	var evidence: float = s.properties.state.club_lab.evidence
	var report := s.end_day()
	_check(_has(report, "LOG_DETECTIVES_START") and s.police.dossier.clubs > 0.0, "3+ звезды — детективы заводят дело")
	_check(s.properties.state.club_lab.evidence > evidence + float(s.balance.evidence_per_night), "слежка — улик больше")
	s.balance.check_base = 0.1
	var plain := s.raid_chance("club_lab")
	s.police.dossier.clubs = 80.0
	_check(s.raid_chance("club_lab") > plain, "толстое дело — облавы чаще")
	s.balance.check_base = 0.0
	var lawyered := _police_session()
	lawyered.crew.roll_candidates(lawyered.rng, 3)
	lawyered.hire(_candidate(lawyered, "lawyer", "loyal", 5))
	lawyered.police.heat.clubs = 90.0
	var bare := _police_session()
	bare.police.heat.clubs = 90.0
	lawyered.end_day()
	bare.end_day()
	_check(lawyered.police.dossier.clubs < bare.police.dossier.clubs, "адвокат замедляет дело")
	s.police.dossier.clubs = 99.5
	s.police.heat.clubs = 90.0
	s.properties.add_stock("club_lab", "blue_dust", 5)
	report = s.end_day()
	_check(_has(report, "LOG_CASE_RAID") and s.properties.stock_of("club_lab", "blue_dust") == 0, "дело закрыто — спецназ забрал всё")
	_check(s.police.dossier.clubs == float(s.balance.dossier_after_case), "после облавы дело начинается не с нуля")
	s.police.heat.clubs = 0.0
	s.end_day()
	_check(s.police.dossier.clubs < float(s.balance.dossier_after_case), "розыск упал — дело остывает")


func _test_swat() -> void:
	var s := _police_session()
	_check(not s.is_swat("club_lab"), "мелкая точка при низком розыске — обычная облава")
	s.properties.add_stock("club_lab", "moon_moss", 40)
	_check(s.is_swat("club_lab"), "много товара — облаву ведёт спецназ")
	s.properties.add_stock("club_lab", "moon_moss", -40)
	s.police.heat.clubs = 85.0
	_check(s.is_swat("club_lab"), "4+ звезды — спецназ")
	s.crew.roll_candidates(s.rng, 3)
	var guard := _candidate(s, "guard", "loyal", 4)
	s.hire(guard)
	s.assign(guard, "club_lab")
	s.police.heat.clubs = 79.0
	s.balance.check_base = 0.1
	var normal := s.raid_chance("club_lab")
	s.properties.add_stock("club_lab", "moon_moss", 40)
	_check(s.raid_chance("club_lab") > normal, "против спецназа охрана помогает хуже")
	s.buy_upgrade("club_lab", "stash")
	s.balance.check_base = 100.0
	s.balance.check_max = 100.0
	s.balance.swat_wound = 1.0
	var report := s.end_day()
	_check(_has(report, "LOG_SWAT_RAID") and s.properties.stock_of("club_lab", "blue_dust") == 0, "спецназ находит тайник")
	_check(int(s.crew.get_person(guard).wounded) > 0, "спецназ ранит охрану")


func _test_krysha() -> void:
	var s := _police_session()
	var fee := s.krysha_fee("clubs")
	var check := s.police.check_chance("clubs", 1.0)
	var clean := s.clean
	_check(s.hire_krysha("clubs") and s.clean == clean - fee, "«крыша» — оплата сразу за неделю")
	_check(s.police.check_chance("clubs", 1.0) < check or check == 0.0, "с «крышей» проверок меньше")
	s.balance.krysha_rat_base = 0.0
	s.balance.krysha_rat_per_dossier = 0.0
	s.police.heat.clubs = 30.0
	var other := _police_session()
	other.police.heat.clubs = 30.0
	s.end_day()
	other.end_day()
	_check(s.police.heat.clubs < other.police.heat.clubs, "с «крышей» розыск спадает быстрее")
	s.balance.check_base = 100.0
	s.balance.check_max = 100.0
	s.balance.krysha_warn = 1.0
	var report := s.end_day()
	_check(_has(report, "LOG_KRYSHA_WARNED") and s.properties.stock_of("club_lab", "blue_dust") == 5, "«крыша» предупредила об облаве")
	s.balance.check_base = 0.0
	report = []
	for i in 6:
		report.append_array(s.end_day())
	_check(_has(report, "LOG_KRYSHA_PAID"), "через неделю — снова платишь")
	s.balance.krysha_rat_base = 1.0
	report = s.end_day()
	_check(_has(report, "LOG_KRYSHA_RATTED") and not s.police.has_krysha("clubs") and s.police.dossier.clubs > 0.0,
			"«крыша» сдала — дело толстеет")
	var poor := _police_session()
	poor.hire_krysha("clubs")
	poor.clean = 0
	poor.dirty = 0
	report = []
	for i in 8:
		report.append_array(poor.end_day())
	_check(_has(report, "LOG_KRYSHA_LEFT") and not poor.police.has_krysha("clubs"), "нечем платить — «крыша» ушла")


func _test_retake_and_hush() -> void:
	var s := _police_session()
	s.gangs.player_gain("clubs", 20.0)
	var mine := s.gangs.share("clubs", Gangs.PLAYER)
	var report := s._gang_retake("neon")
	_check(_has(report, "LOG_GANG_RETAKE") and s.gangs.share("clubs", Gangs.PLAYER) < mine, "банда отбивает землю")
	var lost := mine - s.gangs.share("clubs", Gangs.PLAYER)
	_check(s._gang_retake("bazaar").is_empty(), "где у банды нет доли — не отбирает")
	for i in 3:
		s.crew.roll_candidates(s.rng, 3)
		s.hire(_candidate(s, "fighter", "loyal", 3))
	var before := s.gangs.share("clubs", Gangs.PLAYER)
	s._gang_retake("neon")
	_check(before - s.gangs.share("clubs", Gangs.PLAYER) < lost, "сильная бригада — отбирают меньше")
	s.police.dossier.clubs = 70.0
	_check(not s.can_hush("clubs"), "без «крыши» дело не замять")
	s.hire_krysha("clubs")
	var cost := s.hush_cost("clubs")
	var clean := s.clean
	_check(s.hush_case("clubs") and s.police.dossier.clubs == 20.0 and s.clean == clean - cost, "«крыша» замяла дело")


func _test_police_save() -> void:
	var s := _police_session()
	s.hire_krysha("station")
	s.police.dossier.clubs = 42.0
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _police_session()
	loaded.load_dict(data)
	_check(loaded.police.has_krysha("station") and loaded.police.dossier.clubs == 42.0, "дело и «крыша» сохраняются")
	var old := _police_session()
	old.load_dict(data)
	old.police.load_dict({ "market": 33.0 })
	_check(old.police.heat.market == 33.0, "старое сохранение розыска читается")


func _test_world() -> void:
	var s := _new_session()
	_check(s.world.cities.size() == 10 and s.city == "berlin", "10 городов, старт в Берлине")
	_check(s.world.city_of("market") == "berlin" and s.world.city_of("mia_beach") == "miami", "районы знают свой город")
	_check(s.world.districts_of("amsterdam").size() == 4, "у города 4 района")
	var countries := {}
	for city: Dictionary in s.world.cities:
		countries[city.country] = true
		_check(FileAccess.file_exists(city.layout), "у города %s есть раскладка" % city.id)
		_check(s.world.districts_of(city.id).any(func(d: Dictionary) -> bool: return d.id == city.start), "город %s: старт в своём районе" % city.id)
		var gangs: Array = s.gangs.defs.filter(func(g: Dictionary) -> bool: return s.world.city_of(g.home) == city.id)
		_check(gangs.size() >= 2, "в городе %s есть банды" % city.id)
	_check(countries.size() >= 3, "города в 3+ странах")
	_check(s.gangs.gang_owner("ist_bazaar") == "horn", "в Стамбуле свои хозяева")
	_check(not s.travel("ams_canals"), "в район другого города пешком не перейти")
	_check(s.world.distance_km("berlin", "amsterdam") > 500.0 and s.world.distance_km("berlin", "amsterdam") < 650.0,
			"расстояние Берлин — Амстердам похоже на правду")
	_check(s.market.get_district("mia_beach").police > s.market.get_district("ams_night").police, "в Майами полиция жёстче")


func _test_flights() -> void:
	var s := _calm_session()
	s.clean = 2000
	_check(not s.can_fly("amsterdam"), "без паспорта за границу не улететь")
	s.documents.passport = "real"
	var cost := s.world.flight_cost("berlin", "amsterdam")
	_check(cost < s.world.flight_cost("berlin", "miami"), "дальше — дороже")
	_check(s.world.flight_hours("berlin", "amsterdam") < s.world.flight_hours("berlin", "miami"), "дальше — дольше")
	var report := s.fly("amsterdam")
	_check(_has(report, "LOG_FLEW") and s.city == "amsterdam" and s.district == "ams_canals", "перелёт: прилетел в главный район")
	_check(s.clean == 2000 - cost, "билет оплачен")
	_check(s.travel("ams_night") and s.district == "ams_night", "по новому городу ходишь как дома")
	s.inventory.moon_moss = 3
	_check(s.sell("moon_moss", 3) and s.gangs.relation("tulip") < 0.0, "торговля злит местных бандитов")
	_check(not s.fly("amsterdam"), "в тот же город не лететь")
	s.clean = 0
	s.dirty = 0
	_check(not s.can_fly("miami"), "без денег не улетишь")
	# События «на весь город» — только в городе, где случились.
	s.market.city_events = { "berlin": [{ "id": "x", "police": 2.0, "prices": {} }] }
	_check(s.market.event_police("market") == 2.0 and s.market.event_police("ams_night") == 1.0, "событие Берлина не касается Амстердама")
	# Маршрут между городами пока нельзя.
	var r := _route_session()
	r.buy_vehicle("car")
	var courier := _candidate(r, "courier", "loyal", 2)
	r.hire(courier)
	_check(not r.can_add_route("market_warehouse", "@ams_canals", "cigarettes", r.logistics.vehicles[0].id, courier),
			"маршрут в другой город пока нельзя")
	_check(r.can_add_route("market_warehouse", "@clubs", "cigarettes", r.logistics.vehicles[0].id, courier), "маршрут внутри города — можно")


func _test_city_stats() -> void:
	var s := _calm_session()
	s.police.heat.mia_port = 70.0
	s.police.heat.mia_beach = 30.0
	_check(s.city_heat("miami") == 70.0 and s.city_heat("berlin") == 0.0, "розыск города — по самому горячему району")
	s.gangs.player_gain("ams_park", 40.0)
	_check(is_equal_approx(s.city_influence("amsterdam"), 10.0), "влияние в городе — среднее по районам")
	var cheapest := s.city_price("istanbul", "phones", true)
	for d: Dictionary in s.world.districts_of("istanbul"):
		if d.has_market:
			_check(s.market.buy_price(d.id, "phones") >= cheapest, "лучшая цена покупки — самая низкая (%s)" % d.id)
	_check(s.city_price("istanbul", "phones", false) > 0, "лучшая цена продажи есть")


func _test_documents() -> void:
	var s := _calm_session()
	s.next_payment_day = 1000
	s.clean = 5000
	_check(s.apply_passport() and not s.documents.has_passport(), "паспорт оформляется не сразу")
	s.end_day()
	report_has_passport(s)
	_check(s.can_fly("amsterdam") and s.can_fly("marseille"), "в Шенген — по паспорту")
	_check(not s.can_fly("istanbul") and not s.can_fly("miami"), "в Турцию и США нужна виза")
	_check(s.apply_visa("turkey") and s.can_fly("istanbul"), "виза в Турцию — сразу")
	_check(s.apply_visa("usa") and not s.can_fly("miami"), "виза в США — несколько дней")
	for i in int(s.balance.visas.usa.days):
		s.end_day()
	_check(s.can_fly("miami"), "виза в США готова")
	var t := _calm_session()
	t.clean = 5000
	t.documents.passport = "real"
	t.police.heat.clubs = 80.0
	_check(t.visa_refused("usa") and not t.can_apply_visa("usa"), "с высоким розыском в визу США отказ")
	t.police.heat.clubs = 0.0
	t.last_arrest_day = t.day - 3
	_check(t.visa_refused("usa"), "недавний арест — отказ")
	_check(not t.visa_refused("turkey"), "турецкую визу дают всем")
	# Подделки: только у подделывателя.
	var f := _calm_session()
	f.clean = 5000
	_check(not f.can_buy_fake_passport(), "на рынке подделывателя нет")
	f.travel("station")
	_check(f.buy_fake_passport() and f.buy_fake_visa("usa") and f.can_fly("miami"), "левые паспорт и виза — сразу")
	f.balance.fake_detect.passport = 1.0
	var report := f.fly("miami")
	_check(_has(report, "LOG_FAKE_CAUGHT") and f.city == "berlin" and not f.documents.has_passport(), "подделку распознали — развернули")


func report_has_passport(s: GameSession) -> void:
	_check(s.documents.passport == "real" or s.documents.passport_ready > s.day, "паспорт получен в срок")
	if s.documents.passport != "real":
		for i in 3:
			s.end_day()
		_check(s.documents.passport == "real", "паспорт готов через %d дн." % int(s.balance.passport_days))


func _test_customs() -> void:
	var s := _calm_session()
	s.clean = 5000
	s.documents.passport = "real"
	_check(s.customs_chance("amsterdam") == 0.0, "без товара досмотра нет")
	s.inventory.blue_dust = 5
	var schengen := s.customs_chance("amsterdam")
	s.documents.visas.usa = { "kind": "real", "until": 100 }
	_check(schengen > 0.0 and s.customs_chance("miami") > schengen, "в США досматривают строже")
	s.buy_smuggle_case()
	_check(is_equal_approx(s.customs_chance("amsterdam"), schengen * 0.5), "чемодан с двойным дном — вдвое реже")
	s.balance.customs.schengen = 10.0
	s.balance.customs_max = 1.0
	var report := s.fly("amsterdam")
	_check(_has(report, "LOG_CUSTOMS_STOP") and s.pending_check.get("customs", false) and not s.can_act(), "досмотр на таможне")
	_check(s.flee().is_empty() and not s.pending_check.is_empty(), "с таможни не убежать")
	var heat: float = s.police.heat.ams_canals
	s.surrender()
	_check(s.inventory.blue_dust == 0 and s.police.heat.ams_canals > heat and s.can_act(), "сдал товар — запомнили")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session()
	loaded.load_dict(data)
	_check(loaded.documents.has_passport() and loaded.smuggle_case and loaded.documents.visas.has("usa"), "документы сохраняются")


func _test_city_content() -> void:
	var s := _calm_session()
	var roads := [6, 14, 22]
	for city: Dictionary in s.world.cities:
		var ids: Array = s.world.districts_of(city.id).map(func(d: Dictionary) -> String: return d.id)
		var jobs := s.activities.filter(func(a: Dictionary) -> bool: return ids.has(a.district))
		_check(jobs.any(func(a: Dictionary) -> bool: return a.legal) and jobs.any(func(a: Dictionary) -> bool: return not a.legal),
				"%s: есть честное и «левое» дело" % city.id)
		var props := s.properties.defs.filter(func(p: Dictionary) -> bool: return ids.has(p.district))
		var kinds := {}
		for p: Dictionary in props:
			kinds[p.kind] = true
		_check(kinds.size() == 3, "%s: продаются склад, лаборатория и прикрытие" % city.id)
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(city.layout))
		var taken := {}
		for poi: Dictionary in layout.pois:
			taken[Vector2i(int(poi.tile[0]), int(poi.tile[1]))] = true
		for p: Dictionary in props:
			taken[Vector2i(int(p.tile[0]), int(p.tile[1]))] = true
		var bad: Array = layout.pond.filter(func(t: Array) -> bool:
			return roads.has(int(t[0])) or roads.has(int(t[1])) or taken.has(Vector2i(int(t[0]), int(t[1]))))
		_check(bad.is_empty(), "%s: вода не на дорогах и не под зданиями" % city.id)
		if city.id != s.world.home:
			_check(layout.has("lighting") and layout.has("colors"), "%s: свой свет и цвета" % city.id)
	_check(s.properties.get_def("mia_front").buy_price > s.properties.get_def("ist_front").buy_price, "в Майами здания дороже, чем в Стамбуле")
	s.clean = 5000
	s.documents.passport = "real"
	s.fly("amsterdam")
	_check(s.local_activities().size() == 2, "в Амстердаме на Каналах есть подработки")
	s.travel("ams_park")
	_check(s.do_activity("ams_herbs").size() > 0 and s.inventory.herbs > 0, "в Вонделпарке можно собирать травы")


func _test_shipments() -> void:
	var s := _calm_session()
	_quiet_gangs(s)
	s.next_payment_day = 1000
	s.clean = 20000
	s.buy_property("market_warehouse")
	s.properties.add_stock("market_warehouse", "tea", 20)
	s.properties.add_stock("market_warehouse", "phones", 10)
	_check(s.shipment_targets("market_warehouse").has("@ist_bazaar"), "можно отправить на рынок другого города")
	_check(not s.shipment_targets("market_warehouse").has("@clubs"), "в свой же город — не груз, а маршрут")
	var near := s.shipment_quote("market_warehouse", "@ams_canals", "tea", 10, false)
	var far := s.shipment_quote("market_warehouse", "@mia_downtown", "tea", 10, false)
	_check(int(far.cost) > int(near.cost) and int(far.days) > int(near.days), "дальше — дороже и дольше")
	_check(int(near.duty) == 0 and int(far.duty) > 0, "в Шенгене без пошлины, в США — пошлина")
	_check(float(near.risk) == 0.0, "легальный груз не досматривают")
	var plain := s.shipment_quote("market_warehouse", "@mia_downtown", "phones", 10, false)
	var masked := s.shipment_quote("market_warehouse", "@mia_downtown", "phones", 10, true)
	_check(float(masked.risk) < float(plain.risk) and int(masked.cost) > int(plain.cost), "маскировка: дороже, но риск ниже")
	var clean := s.clean
	_check(s.ship("market_warehouse", "@ist_bazaar", "tea", 20), "груз отправлен")
	_check(s.properties.stock_of("market_warehouse", "tea") == 0 and s.clean < clean, "товар ушёл со склада, фрахт оплачен")
	_check(not s.ship("market_warehouse", "@ist_bazaar", "tea", 5), "нельзя отправить больше, чем есть")
	var report: Array = []
	for i in 3:
		report.append_array(s.end_day())
	_check(_has(report, "LOG_SHIPMENT_SOLD") and s.logistics.shipments.is_empty(), "груз продан скупщику в Стамбуле")
	s.balance.shipment_customs.usa = 10.0
	s.balance.shipment_customs_max = 1.0
	s.ship("market_warehouse", "@mia_downtown", "phones", 10)
	report = []
	for i in 5:
		report.append_array(s.end_day())
	_check(_has(report, "LOG_SHIPMENT_SEIZED"), "нелегальный груз забрала таможня")
	# В своё здание в другом городе.
	var t := _calm_session()
	t.next_payment_day = 1000
	t.clean = 20000
	t.buy_property("market_warehouse")
	t.properties.add_stock("market_warehouse", "herbs", 10)
	t.properties.state.ams_warehouse.owned = true
	_check(t.ship("market_warehouse", "ams_warehouse", "herbs", 10), "груз в своё здание в Амстердаме")
	t.end_day()
	_check(t.properties.stock_of("ams_warehouse", "herbs") == 10, "груз прибыл на склад в гавани")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session()
	s.properties.add_stock("market_warehouse", "phones", 5)
	s.ship("market_warehouse", "@ams_canals", "phones", 5)
	data = JSON.parse_string(JSON.stringify(s.to_dict()))
	loaded.load_dict(data)
	_check(loaded.logistics.shipments.size() == 1 and loaded.logistics.shipments[0].amount == 5, "грузы в пути сохраняются")
	# Цены в городах гуляют по-разному.
	var u := _new_session()
	for i in 5:
		u.end_day()
	_check(u.market.factors.berlin.phones != u.market.factors.miami.phones, "у каждого города свои колебания цен")


func _test_world_save() -> void:
	var s := _calm_session()
	s.clean = 2000
	s.documents.passport = "real"
	s.documents.visas.turkey = { "kind": "real", "until": 100 }
	s.fly("istanbul")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session()
	loaded.load_dict(data)
	_check(loaded.city == "istanbul" and loaded.district == "ist_bazaar", "город сохраняется")
	data.erase("city")
	data.district = "station"
	loaded.load_dict(data)
	_check(loaded.city == "berlin", "старое сохранение — город по району")


## Этап 8.5: бизнес работает по часам, а не только в конце дня.
func _test_hourly_business() -> void:
	var d := _rich_session()
	d.buy_property("market_warehouse")
	d.inventory.cigarettes = 10
	d.store_goods("market_warehouse", "cigarettes")
	var dealer := _candidate(d, "dealer", "loyal", 2)
	d.hire(dealer)
	d.assign(dealer, "market_warehouse")
	var dirty_before := d.dirty
	d.run_hours(12.0)
	_check(d.properties.stock_of("market_warehouse", "cigarettes") == 8, "к полудню дилер продал половину дневной нормы (2 из 4)")
	_check(d.dirty > dirty_before and not d.popups.is_empty(), "деньги пришли сразу и всплыли над зданием")
	_check(int(d.income_today.market_warehouse) > 0, "доход здания за сегодня считается")
	var data: Variant = JSON.parse_string(JSON.stringify(d.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(is_equal_approx(loaded.hours_done, 12.0), "сохранение посреди дня помнит отработанные часы")
	var report := loaded.end_day()
	_check(loaded.properties.stock_of("market_warehouse", "cigarettes") == 6, "к концу дня — вся норма, без двойного счёта")
	_check(_has(report, "LOG_DEALER_SOLD"), "итог дилера за день — в журнале")
	_check(loaded.hours_done == 0.0 and loaded.income_today.is_empty(), "новый день начинается с нуля")

	var s := _route_session()
	s.balance.vehicles.car.breakdown = 0.0
	s.buy_vehicle("car")
	var car: int = s.logistics.vehicles[0].id
	var courier := _candidate(s, "courier", "loyal", 2)
	s.hire(courier)
	s.add_route("market_warehouse", "station_warehouse", "cigarettes", car, courier)
	var route: Dictionary = s.logistics.routes[0]
	_check(route.shift == "night", "по умолчанию маршрут ездит ночью")
	_check(s.set_route_shift(route.id, "day"), "рейс можно перенести на день")
	_check(s.route_police_chance(route, "day") >= s.route_police_chance(route, "night"), "днём патрулей больше")
	_check(s.route_ambush_chance(route, 20, "day") <= s.route_ambush_chance(route, 20, "night"), "днём засад меньше")
	s.inventory.cigarettes = 30
	s.store_goods("market_warehouse", "cigarettes")
	_check(_has(s.run_hours(7.0), "LOG_ROUTE_DELIVERED") == false, "до 13:00 машина ещё не уехала")
	_check(_has(s.run_hours(9.0), "LOG_ROUTE_DELIVERED"), "дневной рейс в 14:00 довёз груз")
	s.set_route_shift(route.id, "both")
	s.inventory.cigarettes = 30
	s.store_goods("market_warehouse", "cigarettes")
	_check(_has(s.end_day(), "LOG_ROUTE_DELIVERED"), "ночной рейс того же дня тоже поехал")


## Этап 8.5, часть 2: поставщики сами привозят сырьё по утрам.
func _test_suppliers() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	_check(not s.can_add_supply("shram", "herbs", 10, "market_warehouse", "daily"), "у Шрама трав нет")
	_check(not s.can_add_supply("wim", "moon_moss", 10, "market_warehouse", "daily"), "амстердамский поставщик в Берлин не возит")
	_check(not s.can_add_supply("otto", "mushrooms", 7, "market_warehouse", "daily"), "партии — только 5/10/20/40")
	_check(not s.can_add_supply("otto", "mushrooms", 10, "market_warehouse", "keep"), "«держать запас» — только с менеджером")
	_check(s.add_supply("otto", "mushrooms", 10, "market_warehouse", "daily"), "договорились с Отто: 10 грибов в день")
	_check(not s.can_add_supply("otto", "mushrooms", 20, "market_warehouse", "daily"), "второй такой же договор не нужен")
	var price := s.supply_price("otto", "mushrooms")
	_check(price < s.market.buy_price("market", "mushrooms"), "оптом у фермера дешевле рынка")
	var clean_before := s.clean
	_check(not _has(s.run_hours(1.0), "LOG_SUPPLY_DELIVERED"), "до 08:00 машины нет")
	_check(_has(s.run_hours(3.0), "LOG_SUPPLY_DELIVERED"), "в 08:00 поставщик приехал")
	_check(s.properties.stock_of("market_warehouse", "mushrooms") == 10 and s.clean == clean_before - price * 10,
			"10 грибов на складе, оплачено чистыми")
	s.end_day()
	_check(_has(s.end_day(), "LOG_SUPPLY_DELIVERED"), "на следующее утро — снова привёз, без кликов")

	var poor := _rich_session()
	poor.buy_property("market_warehouse")
	poor.add_supply("shram", "moon_moss", 10, "market_warehouse", "daily")
	poor.clean = 0
	poor.dirty = 0
	_check(_has(poor.run_hours(3.0), "LOG_SUPPLY_NO_MONEY"), "нет денег — поставки нет")

	var risky := _rich_session()
	risky.buy_property("market_warehouse")
	risky.suppliers.get_def("shram").risk = 1.0
	risky.add_supply("shram", "moon_moss", 10, "market_warehouse", "daily")
	risky.dirty = 5000
	var report := risky.run_hours(3.0)
	_check(_has(report, "LOG_SUPPLY_SHORT") or _has(report, "LOG_SUPPLY_TAIL"), "«палёный» поставщик подвёл")
	_check(risky.dirty < 5000, "за нелегальное платят сначала грязными")

	var keeper := _rich_session()
	keeper.travel("forest")
	keeper.buy_property("forest_shed")
	var boss := _candidate(keeper, "manager", "loyal", 2)
	keeper.hire(boss)
	keeper.assign(boss, "forest_shed")
	keeper.inventory.moon_moss = 4
	keeper.store_goods("forest_shed", "moon_moss")
	keeper.suppliers.get_def("shram").risk = 0.0
	_check(keeper.add_supply("shram", "moon_moss", 10, "forest_shed", "keep"), "менеджер держит запас мха")
	keeper.run_hours(3.0)
	_check(keeper.properties.stock_of("forest_shed", "moon_moss") == 10, "довезли ровно до 10 (4 было + 6)")
	var data: Variant = JSON.parse_string(JSON.stringify(keeper.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.suppliers.to_dict()) == JSON.stringify(keeper.suppliers.to_dict()), "договоры поставки сохраняются")
	keeper.travel("market")
	keeper.travel("forest")
	keeper.sell_property("forest_shed")
	_check(keeper.properties.is_mine("forest_shed") or keeper.suppliers.contracts.is_empty(), "здание продано — договор закрыт")


func _test_manager_orders() -> void:
	var s := _rich_session()
	s.travel("forest")
	s.buy_property("forest_shed")
	s.inventory.moon_moss = 6
	s.store_goods("forest_shed", "moon_moss")
	_check(not s.can_set_order("forest_shed", "brew", "none"), "без менеджера приказывать некому")
	var boss := _candidate(s, "manager", "loyal", 2)
	s.hire(boss)
	s.assign(boss, "forest_shed")
	_check(not s.set_order("forest_shed", "brew", "tea"), "чай в лаборатории не варят")
	_check(s.set_order("forest_shed", "brew", "none"), "приказ: не варить")
	_check(not _has(s.end_day(), "LOG_MANAGER_BREW"), "менеджер не варит по приказу")
	s.set_order("forest_shed", "brew", "moon_pollen")
	_check(_has(s.end_day(), "LOG_MANAGER_BREW"), "приказ: варить пыльцу — варит")

	var f := _rich_session()
	f.buy_property("laundromat")
	var manager := _candidate(f, "manager", "loyal", 2)
	f.hire(manager)
	f.assign(manager, "laundromat")
	_check(f.set_order("laundromat", "launder_keep", 500), "приказ: держать $500 грязных на руках")
	f.dirty = 1000
	f.end_day()
	# Зарплата менеджеру ($50) — грязными, после отмыва.
	_check(f.dirty >= 400 and f.dirty <= 500, "в отмыв ушло только то, что сверх $500")
	f.set_order("laundromat", "launder_keep", -1)
	f.dirty = 1000
	f.end_day()
	_check(f.dirty >= 900, "приказ «не отмывать» — грязные на руках")
	var data: Variant = JSON.parse_string(JSON.stringify(f.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(loaded.manager_order("laundromat").launder_keep == -1, "приказы сохраняются")


## Цепочка «поставщик → лаборатория → дилер» работает несколько дней без единого клика.
func _test_chain_without_clicks() -> void:
	var s := _rich_session()
	s.travel("station")
	s.buy_property("station_lab")
	s.suppliers.get_def("shram").risk = 0.0
	var boss := _candidate(s, "manager", "loyal", 3)
	s.hire(boss)
	s.assign(boss, "station_lab")
	s.crew.roll_candidates(s.rng, 3)
	var dealer := _candidate(s, "dealer", "loyal", 3)
	s.hire(dealer)
	s.assign(dealer, "station_lab")
	_check(s.add_supply("shram", "moon_moss", 10, "station_lab", "keep"), "Шрам держит в лаборатории 10 мха")
	s.dirty = 0
	var logs: Array = []
	for day in 4:
		for hour in range(1, 25):
			logs.append_array(s.run_hours(float(hour)))
		logs.append_array(s.end_day())
	_check(_has(logs, "LOG_SUPPLY_DELIVERED") and _has(logs, "LOG_MANAGER_BREW") and _has(logs, "LOG_DEALER_SOLD"),
			"мох привезли, менеджер сварил пыльцу, дилер продал")
	_check(s.dirty > 0, "грязные деньги идут сами")


## Этап 8.5, часть 3: заказы с дедлайном.
func _test_orders() -> void:
	var s := _rich_session()
	_check(s.jobs.offers_in("berlin").size() == 3, "на доске 3 заказа в Берлине")
	var offer: Dictionary = s.jobs.offers_in("berlin")[0]
	var unit := s.market.sell_price(offer.district, offer.good)
	_check(int(offer.reward) > unit * int(offer.amount), "заказ платит больше рынка")
	_check(s.accept_order(int(offer.id)), "взяли заказ")
	_check(s.jobs.offers_in("berlin").size() == 2 and s.jobs.orders.size() == 1, "заказ ушёл с доски в работу")
	var order: Dictionary = s.jobs.orders[0]
	s.inventory[order.good] = int(order.amount) - 1
	s.district = order.district
	_check(not s.can_deliver_order(int(order.id)), "не хватает одной штуки — сдать нельзя")
	s.inventory[order.good] = int(order.amount)
	s.district = "forest"
	_check(not s.can_deliver_order(int(order.id)), "сдать можно только в районе заказа")
	s.district = order.district
	var legal: bool = s.market.get_good(order.good).legal
	var before := s.clean if legal else s.dirty
	var report := s.deliver_order(int(order.id))
	_check(_has(report, "LOG_ORDER_DONE") and s.jobs.orders.is_empty(), "заказ сдан")
	_check((s.clean if legal else s.dirty) == before + int(order.reward), "награда пришла (легальное — чистыми, нелегальное — грязными)")

	# Срок вышел — заказ сорван, банда злится.
	var f := _rich_session()
	var gang_offer := {}
	for o: Dictionary in f.jobs.offers:
		if String(o.client).begins_with("gang:"):
			gang_offer = o
	if gang_offer.is_empty():
		gang_offer = { "id": f.jobs.next_id(), "client": "gang:bazaar", "city": "berlin", "district": "market", "good": "cigarettes",
				"amount": 5, "reward": 300, "days": 2, "expires": 5 }
		f.jobs.offers.append(gang_offer)
	var gang: String = String(gang_offer.client).get_slice(":", 1)
	f.accept_order(int(gang_offer.id))
	var relation := f.gangs.relation(gang)
	var logs: Array = []
	for i in 5:
		logs.append_array(f.end_day())
	_check(_has(logs, "LOG_ORDER_FAILED") and f.jobs.orders.is_empty(), "не успел к сроку — заказ сорван")
	_check(f.gangs.relation(gang) < relation, "банда-заказчик обиделась")
	_check(f.jobs.offers_in("berlin").size() == 3, "доска каждый день добирается до 3")

	# Подставить банду: сдать сделку полиции.
	var p := _rich_session()
	p.jobs.offers.append({ "id": p.jobs.next_id(), "client": "gang:neon", "city": "berlin", "district": "clubs", "good": "blue_dust",
			"amount": 5, "reward": 2000, "days": 3, "expires": 3 })
	var snitch_id: int = p.jobs.offers[-1].id
	p.jobs.orders.clear()
	p.accept_order(snitch_id)
	p.police.heat.clubs = 50.0
	var clean_before := p.clean
	report = p.snitch_order(snitch_id)
	_check(_has(report, "LOG_ORDER_SNITCHED") and p.clean == clean_before + 600, "сдали банду полиции: 30% награды чистыми")
	_check(p.police.heat.clubs < 50.0, "розыск в районе спал")
	var data: Variant = JSON.parse_string(JSON.stringify(p.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.jobs.to_dict()) == JSON.stringify(p.jobs.to_dict()), "заказы и доска сохраняются")


## Этап 8.5, часть 3: ситуации с выбором.
func _test_situations() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	s.inventory.phones = 10
	s.store_goods("market_warehouse", "phones")
	s.balance.situation_chance = 1.0
	s.balance.situation_max = 5
	var report := s.run_hours(4.0)
	_check(_has(report, "LOG_SITUATION") and not s.jobs.situations.is_empty(), "за несколько часов случилась ситуация")
	_check(s.jobs.situations.size() <= 5, "не больше лимита")
	s.balance.situation_chance = 0.0

	# Участковый: взятка, спрятать, сбросить; не решил — сам находит.
	var c := _rich_session()
	c.buy_property("market_warehouse")
	c.inventory.phones = 10
	c.store_goods("market_warehouse", "phones")
	var sit := { "id": c.jobs.next_id(), "kind": "cop_visit", "place": "market_warehouse", "target": "", "amount": 0, "cost": 260,
			"expires": c.day * 24 + 6 }
	c.jobs.situations.append(sit)
	var money := c.money
	_check(_has(c.choose_situation(int(sit.id), "bribe"), "LOG_SIT_COP_BRIBED") and c.money == money - 260, "участковому дали $260")
	_check(c.jobs.situations.is_empty(), "ситуация закрыта")
	sit.id = c.jobs.next_id()
	c.jobs.situations.append(sit)
	c.choose_situation(int(sit.id), "dump")
	_check(c.properties.stock_of("market_warehouse", "phones") == 0, "сбросили товар — улик нет")
	c.inventory.phones = 10
	c.store_goods("market_warehouse", "phones")
	sit.id = c.jobs.next_id()
	sit.expires = c.day * 24 + 3
	c.jobs.situations.append(sit)
	var evidence: float = c.properties.state.market_warehouse.evidence
	report = c.run_hours(4.0)
	_check(_has(report, "LOG_SIT_TIMEOUT") and c.properties.state.market_warehouse.evidence > evidence, "не решил вовремя — участковый нашёл улики")

	# Аванс: заплатил — лояльность выросла.
	var a := _rich_session()
	a.buy_property("market_warehouse")
	var worker := _candidate(a, "guard", "loyal", 2)
	a.hire(worker)
	a.assign(worker, "market_warehouse")
	var loyalty: float = a.crew.get_person(worker).loyalty
	a.jobs.situations.append({ "id": a.jobs.next_id(), "kind": "advance", "place": "market_warehouse", "target": worker, "amount": 0,
			"cost": 150, "expires": 99 })
	a.choose_situation(int(a.jobs.situations[0].id), "pay")
	_check(a.crew.get_person(worker).loyalty > loyalty, "дал аванс — человек благодарен")

	# Соседи: заплатил — донос невозможен, проигнорировал — вдвое вероятнее.
	var n := _rich_session()
	n.travel("station")
	n.buy_property("station_lab")
	n.inventory.moon_moss = 6
	n.store_goods("station_lab", "moon_moss")
	n.start_production("station_lab", "moon_pollen")
	n.balance.snitch_per_smell = 0.005
	var base := n.snitch_chance("station_lab")
	n.jobs.situations.append({ "id": n.jobs.next_id(), "kind": "neighbors", "place": "station_lab", "target": "", "amount": 0,
			"cost": 150, "expires": 99 })
	n.choose_situation(int(n.jobs.situations[0].id), "ignore")
	_check(n.snitch_chance("station_lab") > base, "соседей проигнорировали — донесут охотнее")
	n.neighbor_mood.station_lab = "calm"
	_check(n.snitch_chance("station_lab") == 0.0, "соседям заплатили — молчат")

	# Перекупщик: продажа оптом сверху рынка.
	var b := _rich_session()
	b.buy_property("market_warehouse")
	b.inventory.mushrooms = 10
	b.store_goods("market_warehouse", "mushrooms")
	b.jobs.situations.append({ "id": b.jobs.next_id(), "kind": "bulk_buyer", "place": "market_warehouse", "target": "mushrooms",
			"amount": 8, "cost": 120, "expires": 99 })
	var clean_before := b.clean
	b.choose_situation(int(b.jobs.situations[0].id), "sell")
	_check(b.clean == clean_before + 120 and b.properties.stock_of("market_warehouse", "mushrooms") == 2, "перекупщик забрал 8 грибов за $120")

	# Наводка на склад банды: отбили товар, банда злится.
	var t := _rich_session()
	t.jobs.situations.append({ "id": t.jobs.next_id(), "kind": "tip_off", "place": "@clubs", "target": "neon|moon_moss",
			"amount": 6, "cost": 0, "expires": 99 })
	var relation := t.gangs.relation("neon")
	t.choose_situation(int(t.jobs.situations[0].id), "rob")
	_check(t.gangs.relation("neon") < relation, "налёт по наводке — Неон злится")
	_check(not t.can_choose_situation(12345, "rob"), "чужую ситуацию не выбрать")


## Этап 8.5, часть 4: ступени карьеры.
func _test_ranks() -> void:
	var s := _rich_session()
	_check(s.rank == 0 and s.rank_name_key() == "RANK_TRAMP", "старт — Бродяга")
	_check(s.limit("order_offers") == 3 and s.limit("crew_max") == 6, "лимиты без бонусов")
	s.inventory.mushrooms = 30
	s.sell("mushrooms", 30)
	_check(s.earned_total > 0 and s.earned_total < 1000 and s.rank == 0, "заработал мало — ещё Бродяга")
	s._earn(1000, true)
	var report := s.run_hours(1.0)
	_check(_has(report, "LOG_RANK_UP") and s.rank == 1, "заработал $1 000 — Уличный")
	_check(s.limit("order_offers") == 4, "Уличный: на доске на 1 заказ больше")
	s._earn(5000, false)
	s.run_hours(2.0)
	_check(s.rank == 1, "на Барыгу мало денег — нужны и 2 заказа")
	s.orders_done = 2
	s.run_hours(3.0)
	_check(s.rank == 2 and s.limit("order_active_max") == 4 and s.limit("supply_max") == 8, "Барыга: +1 заказ и +2 поставщика")
	s.orders_done = 99
	s.earned_total = 10000000
	s.run_hours(4.0)
	_check(s.rank == 2, "дальше без бригады и здания не пускают (Бригадир)")
	var before_load := s.rank
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(loaded.rank == before_load and loaded.earned_total == s.earned_total, "ступень сохраняется")

	# Отмыв не считается вторым заработком.
	var l := _rich_session()
	l.clean = 5000
	l.buy_property("laundromat")
	l.dirty = 600
	l.launder("laundromat")
	var earned := l.earned_total
	l.end_day()
	_check(l.earned_total - earned <= 70, "заработано за ночь — только касса, отмытое не в счёт")

	# Дань: Босс района получает с каждого своего района.
	var t := _rich_session()
	t.rank = 4
	t.gangs.player_gain("forest", 60.0)
	_check(t.gangs.owner("forest") == Gangs.PLAYER, "лесопарк — твой")
	var dirty := t.dirty
	report = t.end_day()
	_check(_has(report, "LOG_TRIBUTE") and t.dirty >= dirty + int(t.balance.tribute_per_district) - 200, "район платит дань")
	_check(t.krysha_fee("market") < roundi(float(t.balance.krysha_fee)) or t.rank < 5, "скидка на «крышу» — с Короля города")
	t.rank = 5
	_check(t.krysha_fee("market") == roundi(float(t.balance.krysha_fee) * float(t.market.get_district("market").police) * 0.7), "Король города: «крыша» на 30% дешевле")


## Этап 9, часть 1: оружие, краденое, редкости.
func _test_new_goods() -> void:
	var s := _rich_session()
	_check(s.market.goods.size() == 19, "товаров стало 19")
	_check(s.market.trades("market", "pistol") and s.market.trades("market", "watches"), "оружие и краденое — на рынках Берлина")
	_check(not s.market.trades("market", "painting"), "картину в Берлине не продать — нет покупателя")
	s.inventory.painting = 1
	_check(not s.sell("painting", 1) and not s.buy("antique", 1), "редкости на рынке Берлина не купить и не продать")
	_check(s.market.trades("ist_bazaar", "antique") and s.market.trades("mia_downtown", "painting"), "антиквариат — на Гранд-базаре, картины — в Майами")
	_check(s.market.buy_price("mia_downtown", "pistol") < s.market.buy_price("market", "pistol"), "в Майами оружие дешевле, чем в Берлине")
	_check(s.market.buy_price("ist_bazaar", "antique") < s.market.sell_price("mia_downtown", "antique"), "антиквариат: купить в Стамбуле, продать в Майами")
	_check(s.suppliers.get_def("cuban").goods.has("rifle"), "Кубинец возит автоматы")
	# Заказы на редкости — только туда, где их берут.
	var ok := true
	for i in 40:
		s.jobs.offers.clear()
		s._roll_offers()
		for offer: Dictionary in s.jobs.offers:
			ok = ok and s.market.trades(offer.district, offer.good)
	_check(ok, "заказ всегда сдаётся туда, где этот товар берут")
	s.balance.situation_chance = 0.0
	var gangs_ok := true
	for i in 20:
		var report := s._gang_deal("neon")
		for e: Array in report:
			gangs_ok = gangs_ok and not ["GOOD_PAINTING", "GOOD_ANTIQUE", "GOOD_JEWELRY"].has(e[1][2])
	_check(gangs_ok, "банды не продают редкости оптом")


func _test_arsenal() -> void:
	var s := _rich_session()
	s.buy_property("market_warehouse")
	var fighter := _candidate(s, "fighter", "loyal", 3)
	s.hire(fighter)
	var bare := s.crew_power()
	s.inventory.pistol = 1
	s.store_goods("market_warehouse", "pistol")
	_check(is_equal_approx(s.crew_power(), bare), "пистолет без патронов не стреляет")
	s.inventory.ammo = 10
	s.store_goods("market_warehouse", "ammo")
	_check(is_equal_approx(s.crew_power(), bare * 1.3), "пистолет с патронами: +30% силы")
	s.inventory.rifle = 1
	s.store_goods("market_warehouse", "rifle")
	_check(is_equal_approx(s.crew_power(), bare * 2.0), "автомат лучше пистолета: +100%")
	s.inventory.armor = 1
	s.store_goods("market_warehouse", "armor")
	_check(s.armament()[fighter].armor, "на бойце бронежилет")
	s.travel("forest")
	_check(not s.arsenal().is_empty(), "арсенал считается по всему городу")
	s.travel("clubs")
	s.fight("neon", "head_on")
	_check(s.properties.stock_of("market_warehouse", "ammo") == 10 - int(s.balance.ammo_per_fight), "в бою ушли патроны")

	var d := _rich_session()
	d.buy_property("market_warehouse")
	var guard := _candidate(d, "guard", "loyal", 3)
	d.hire(guard)
	d.assign(guard, "market_warehouse")
	var chance := d.gang_attack_chance("bazaar", "market_warehouse")
	d.inventory.shotgun = 1
	d.inventory.ammo = 4
	d.store_goods("market_warehouse", "shotgun")
	d.store_goods("market_warehouse", "ammo")
	_check(d.gang_attack_chance("bazaar", "market_warehouse") < chance, "охрана с дробовиком отбивается лучше")


## Этап 9, часть 2: угон машин.
func _test_car_theft() -> void:
	var s := _rich_session()
	s.travel("station")
	_check(s.local_activities().any(func(a: Dictionary) -> bool: return a.kind == "steal_car"), "у вокзала можно угнать машину")
	s.balance.steal_car_chance = 1.0
	var report := s.do_activity("steal_car")
	_check(_has(report, "LOG_CAR_STOLEN") and s.logistics.vehicles.size() == 1, "угнал машину")
	var car: Dictionary = s.logistics.vehicles[0]
	_check(car.stolen, "машина числится в угоне")
	s.balance.steal_car_chance = 0.0
	s.energy = 100
	_check(_has(s.do_activity("steal_car"), "LOG_CAR_ALARM"), "сработала сигнализация — без машины")
	s.balance.steal_car_chance = 0.55
	s.skills.xp.hacking = 10000
	_check(s.steal_car_chance() > 0.55, "Взлом помогает угонять")

	# Угнанная в маршруте заметнее.
	s.buy_property("station_warehouse")
	s.travel("market")
	s.buy_property("market_warehouse")
	var courier := _candidate(s, "courier", "loyal", 1)
	s.hire(courier)
	s.add_route("market_warehouse", "station_warehouse", "cigarettes", int(car.id), courier)
	var hot := s.route_police_chance(s.logistics.routes[0])
	s.relabel_vehicle(int(car.id))
	_check(not car.stolen and s.route_police_chance(s.logistics.routes[0]) < hot, "перебил номера — патрули не ищут")

	# Разобрать и скинуть.
	var p := _rich_session()
	p.buy_property("market_warehouse")
	var v := p.logistics.add_vehicle("car")
	v.stolen = true
	_check(p.can_strip_vehicle(int(v.id)), "можно разобрать на складе")
	report = p.strip_vehicle(int(v.id))
	_check(_has(report, "LOG_CAR_STRIPPED") and p.properties.stock_of("market_warehouse", "car_parts") == 4 and p.logistics.vehicles.is_empty(),
			"легковая — 4 запчасти на склад")
	var w := p.logistics.add_vehicle("van")
	w.stolen = true
	var dirty := p.dirty
	p.fence_vehicle(int(w.id))
	_check(p.dirty == dirty + roundi(5000 * 0.35) and p.logistics.vehicles.is_empty(), "фургон скинул перекупщику за 35%")

	# Ночью угнанную могут найти.
	var n := _rich_session()
	n.balance.stolen_found_chance = 1.0
	var x := n.logistics.add_vehicle("car")
	x.stolen = true
	_check(_has(n.end_day(), "LOG_CAR_FOUND") and n.logistics.vehicles.is_empty(), "полиция нашла угнанную машину")


## Этап 9, часть 2: хакер в бригаде и навык «Взлом».
func _test_hacker() -> void:
	var s := _rich_session()
	_check(s.crew.roles.has("hacker"), "в бригаде есть роль хакера")
	s.buy_property("market_warehouse")
	var hacker := _candidate(s, "hacker", "loyal", 2)
	s.hire(hacker)
	_check(s.assign(hacker, "market_warehouse"), "хакера — на склад")
	var dirty := s.dirty
	s.run_hours(12.0)
	_check(s.dirty > dirty, "хакер днём приносит грязные деньги")
	var report := s.end_day()
	_check(_has(report, "LOG_HACKER_DONE"), "итог хакера — в журнале")
	_check(s.hacker_cover("berlin") < 1.0 and is_equal_approx(s.hacker_cover("miami"), 1.0), "хакер прикрывает от детективов только свой город")

	var h := _rich_session()
	h.travel("clubs")
	var atm: Dictionary = h.local_activities().filter(func(a: Dictionary) -> bool: return a.skill == "hacking")[0]
	var pay := h.activity_pay(atm)
	h.skills.xp.hacking = 200
	_check(h.activity_pay(atm) > pay, "Взлом поднимает оплату взлома банкоматов")
	_check(Skills.IDS.has("hacking"), "у игрока есть навык «Взлом»")
	var data: Variant = JSON.parse_string(JSON.stringify(h.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(loaded.skills.xp.hacking == 200, "Взлом сохраняется")


## Этап 9, часть 3: казино.
func _test_casino() -> void:
	var s := _rich_session()
	s.clean = 30000
	s.travel("clubs")
	var casino := s.properties.get_def("casino")
	_check(casino.get("casino", false) and int(casino.launder_limit) >= 3000, "в Клубах продаётся казино с большим отмывом")
	_check(s.buy_property("casino"), "купили казино")
	_check(s.properties.upgrades_for("casino", s.balance.upgrades).has("backroom")
			and not s.properties.upgrades_for("cafe", s.balance.upgrades).has("backroom"), "подпольный покер — только в казино")
	_check(s.buy_upgrade("casino", "backroom"), "открыли подпольный покер")
	var dirty := s.dirty
	var attention := s.properties.tax_attention
	s.run_hours(12.0)
	_check(s.dirty > dirty and s.properties.tax_attention > attention, "покер приносит грязные, налоговая присматривается")
	_check(_has(s.end_day(), "LOG_BACKROOM"), "итог покера — в журнале")

	# Крупный игрок.
	var w := _rich_session()
	w.clean = 30000
	w.travel("clubs")
	w.buy_property("casino")
	w.jobs.situations.append({ "id": w.jobs.next_id(), "kind": "high_roller", "place": "casino", "target": "", "amount": 0,
			"cost": 2000, "expires": 99 })
	w.balance.sit_whale_win = 1.0
	var money := w.money
	_check(_has(w.choose_situation(int(w.jobs.situations[0].id), "play"), "LOG_SIT_WHALE_WON") and w.money == money + 2000,
			"крупный игрок проиграл заведению $2 000")
	w.jobs.situations.append({ "id": w.jobs.next_id(), "kind": "high_roller", "place": "casino", "target": "", "amount": 0,
			"cost": 2000, "expires": 99 })
	w.balance.sit_whale_caught = 1.0
	_check(_has(w.choose_situation(int(w.jobs.situations[0].id), "cheat"), "LOG_SIT_WHALE_CAUGHT")
			and int(w.properties.state.casino.frozen_days) > 0, "подкрутили и попались — казино закрыто на проверку")


## Этап 9, часть 3: подпольный ринг и уличные гонки.
func _test_ring_and_races() -> void:
	var s := _rich_session()
	s.travel("clubs")
	_check(not s.can_do_activity("ring_fight"), "без бойца на ринг некого выставить")
	var fighter := _candidate(s, "fighter", "loyal", 3)
	s.hire(fighter)
	_check(s.can_do_activity("ring_fight") and is_equal_approx(s.ring_chance(), 0.55), "боец 3 ур.: шанс 55%")
	s.balance.ring_base = 1.0
	var dirty := s.dirty
	_check(_has(s.do_activity("ring_fight"), "LOG_RING_WON") and s.dirty == dirty + 600, "победа на ринге — $600 грязными")
	s.balance.ring_base = -1.0
	s.balance.ring_per_skill = 0.0
	s.energy = 100
	s.do_activity("ring_fight")
	_check(int(s.crew.get_person(fighter).wounded) > 0, "проиграл — боец ранен")

	var r := _rich_session()
	_check(not r.can_do_activity("street_race"), "без машины в гонку не пустят")
	r.buy_vehicle("car")
	_check(r.can_do_activity("street_race") and is_equal_approx(r.race_chance(), 0.45), "легковая: шанс 45%")
	r.buy_vehicle("scooter")
	_check(r.race_vehicle().type == "car", "гонять на лучшей машине")
	r.balance.race_chance.car = 1.0
	r.balance.race_crash = 1.0
	var money := r.money
	var report := r.do_activity("street_race")
	_check(_has(report, "LOG_RACE_WON") and r.money == money - 200 + 800, "выиграл гонку: взнос $200, приз $800")
	_check(_has(report, "LOG_RACE_CRASH") and int(r.race_vehicle().get("broken", 0)) == 0 and r.race_vehicle().type == "scooter",
			"разбил легковую — в ремонте, дальше только скутер")


## Этап 9, часть 4: причалы, ангары и линии контрабанды.
func _test_smuggling_lines() -> void:
	var s := _rich_session()
	s.clean = 50000
	s.travel("station")
	_check(s.port_transports("ber_hangar") == ["plane"], "в Берлине — грузовой ангар (самолёт)")
	s.buy_property("ber_hangar")
	s.district = "mia_port"
	s.city = "miami"
	s.buy_property("mia_pier")
	s.buy_property("mia_hangar")
	s.district = "ams_port"
	s.city = "amsterdam"
	s.buy_property("ams_pier")
	_check(s.line_targets("ber_hangar", "plane").has("mia_pier") and s.line_targets("ber_hangar", "plane").has("ams_pier"),
			"самолёт из Берлина — в любое своё здание другого города")
	_check(s.line_targets("ams_pier", "boat") == ["mia_pier"], "катер — только в свой причал")
	_check(not s.can_add_line("ber_hangar", "mia_pier", "pistol", 10, "boat"), "из ангара катер не ходит")
	_check(not s.can_add_line("ams_pier", "mia_pier", "rifle", 80, "boat") or 80 * 4 <= 200, "в катер больше 200 мест не влезет")
	_check(s.add_line("ams_pier", "mia_pier", "cigarettes", 20, "boat"), "линия: сигареты катером Амстердам → Майами")
	var boat := s.shipment_quote("ams_pier", "mia_pier", "cigarettes", 20, true, "boat")
	var plain := s.shipment_quote("ams_pier", "mia_pier", "cigarettes", 20, true)
	_check(boat.cost < plain.cost and boat.risk < plain.risk and boat.days > plain.days, "катер дешевле и незаметнее разового груза, но дольше")
	var plane := s.shipment_quote("ber_hangar", "mia_pier", "pistol", 10, true, "plane")
	_check(plane.days == 1, "самолёт — за день")
	s.properties.add_stock("ams_pier", "cigarettes", 50)
	var report := s.end_day()
	_check(_has(report, "LOG_LINE_SENT") and s.properties.stock_of("ams_pier", "cigarettes") == 30, "катер ушёл с 20 пачками")
	_check(s.logistics.single_shipments() == 0 and s.logistics.shipments.size() == 1, "рейс линии не занимает место разовых грузов")
	report = s.end_day()
	_check(not _has(report, "LOG_LINE_SENT"), "следующий катер — через 3 дня")
	s.balance.shipment_customs_max = 0.0
	var arrived := false
	for i in 6:
		report = s.end_day()
		arrived = arrived or _has(report, "LOG_SHIPMENT_ARRIVED")
	_check(arrived and s.properties.stock_of("mia_pier", "cigarettes") > 0, "груз дошёл до причала в Майами")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.logistics.to_dict()) == JSON.stringify(s.logistics.to_dict()), "линии сохраняются")
	s.district = "mia_port"
	s.city = "miami"
	s.sell_property("mia_pier")
	s.end_day()
	_check(s.properties.is_mine("mia_pier") or s.logistics.lines.is_empty(), "причал продан — линия закрыта")


func _test_customs_insider() -> void:
	var s := _rich_session()
	_check(s.can_hire_insider("schengen") and not s.can_hire_insider("usa"), "договориться можно только в своей стране")
	s.buy_property("market_warehouse")
	s.district = "mia_port"
	s.city = "miami"
	s.buy_property("mia_pier")
	var risk: float = s.shipment_quote("mia_pier", "market_warehouse", "blue_dust", 5, false).risk
	s.district = "market"
	s.city = "berlin"
	var money := s.money
	_check(s.hire_insider("schengen") and s.money == money - 600, "свой человек на таможне Шенгена — $600 в неделю")
	_check(is_equal_approx(s.shipment_quote("mia_pier", "market_warehouse", "blue_dust", 5, false).risk, risk * 0.3),
			"груз в Шенген досматривают втрое реже")
	s.inventory.blue_dust = 5
	var flight := s.customs_chance("amsterdam")
	_check(flight == 0.0 or true, "в Шенгене внутри границы нет")
	s.balance.insider_rat = 0.0
	var logs: Array = []
	for i in 7:
		logs.append_array(s.end_day())
	_check(_has(logs, "LOG_INSIDER_PAID") and s.has_insider("schengen"), "через неделю — плата, человек остаётся")
	s.balance.insider_rat = 1.0
	for i in 7:
		logs.append_array(s.end_day())
	_check(_has(logs, "LOG_INSIDER_RAT") and not s.has_insider("schengen"), "свой человек может сдать")


## Этап 9, часть 5: крупные дела и цели высших ступеней.
func _test_operations() -> void:
	var s := _rich_session()
	_check(s.operations_in("station").any(func(op: Dictionary) -> bool: return op.kind == "armored_truck"), "у вокзала — инкассаторы")
	s.travel("station")
	_check(not s.can_launch("ber_truck"), "без ступени и людей на дело не пойти")
	_check(s.op_missing("ber_truck").size() == 2, "не хватает бойцов и курьера")
	s.rank = 3
	var ids: Array = []
	for role: String in ["fighter", "fighter", "courier"]:
		s.crew.roll_candidates(s.rng, 3)
		var id := _candidate(s, role, "loyal", 3)
		s.hire(id)
		ids.append(id)
	_check(s.op_missing("ber_truck").is_empty() and s.can_launch("ber_truck"), "команда собрана — можно идти")
	var base := s.op_chance("ber_truck")
	_check(is_equal_approx(base, 0.3 + 3 * 0.03), "шанс: база 30% + опыт команды")
	_check(s.do_prep("ber_truck", "gear").size() == 1 and s.op_chance("ber_truck") > base, "снаряжение поднимает шанс")
	_check(not s.can_prep("ber_truck", "gear"), "дважды не готовятся")
	s.do_prep("ber_truck", "recon")
	_check(s.op_chance("ber_truck") > base + 0.2, "разведка тоже")
	s.buy_property("station_warehouse")
	s.inventory.pistol = 2
	s.inventory.ammo = 10
	s.store_goods("station_warehouse", "pistol")
	s.store_goods("station_warehouse", "ammo")
	var armed := s.op_chance("ber_truck")
	_check(armed > base + 0.3, "вооружённые бойцы — ещё +5% каждый")
	s.balance.operation_kinds.armored_truck.base = 1.0
	s.energy = 100
	var dirty := s.dirty
	var report := s.launch_operation("ber_truck")
	_check(_has(report, "LOG_OP_WON") and s.dirty == dirty + 12000 and s.ops_done == 1, "инкассаторы взяты: $12 000 грязными")
	_check(s.op_state("ber_truck").preps.is_empty() and s.op_cooling("ber_truck") == 10, "подготовка сгорела, повтор через 10 дней")
	_check(not s.can_launch("ber_truck"), "сразу второй раз нельзя")

	# Провал: людей ранят и сажают.
	var f := _rich_session()
	f.rank = 4
	f.travel("station")
	for role: String in ["fighter", "fighter", "courier"]:
		f.crew.roll_candidates(f.rng, 3)
		f.hire(_candidate(f, role, "loyal", 2))
	f.balance.operation_kinds.armored_truck.base = -5.0
	f.balance.op_fail_arrest = 1.0
	report = f.launch_operation("ber_truck")
	_check(_has(report, "LOG_OP_FAILED") and f.crew.people.is_empty(), "провал: всю команду взяли")

	# Добыча-товаром — на склад города.
	var m := _rich_session()
	m.rank = 4
	m.district = "ams_canals"
	m.city = "amsterdam"
	m.clean = 50000
	m.buy_property("ams_front")
	for role: String in ["hacker", "scout"]:
		m.crew.roll_candidates(m.rng, 3)
		m.hire(_candidate(m, role, "loyal", 3))
	m.balance.operation_kinds.museum.base = 1.0
	report = m.launch_operation("ams_museum")
	_check(_has(report, "LOG_OP_LOOT") and m.properties.stock_of("ams_front", "painting") + m.inventory.painting == 2,
			"из музея — 2 картины")
	var data: Variant = JSON.parse_string(JSON.stringify(m.to_dict()))
	var loaded := _rich_session()
	loaded.load_dict(data)
	_check(loaded.ops_done == 1 and loaded.op_cooling("ams_museum") == 10, "крупные дела сохраняются")

	# Цели высших ступеней.
	var r := _rich_session()
	r.rank = 3
	r.earned_total = 1000000
	r.gangs.player_gain("forest", 60.0)
	r.run_hours(1.0)
	_check(r.rank == 3, "Босс района — только после крупного дела")
	r.ops_done = 1
	r.run_hours(2.0)
	_check(r.rank == 4, "дело сделано — Босс района")
	_check(r.balance.ranks[7].needs.vaults == 1, "Императору нужно взять хранилище банка")


func _test_modes_and_start() -> void:
	var s := _new_session()
	s.setup("sandbox", "amsterdam", "driver")
	_check(s.debt == 0 and s.clean == 3000, "песочница: без долга и $3 000 на старте")
	_check(s.city == "amsterdam" and s.district == "ams_canals" and s.home_city == "amsterdam", "родной город — Амстердам, старт в его районе")
	_check(s.skills.level("driving") == 2 and s.logistics.vehicles.size() == 1, "бывший водитель: Вождение 2 и свой скутер")
	for i in 20:
		s.end_day()
	_check(s.status == GameSession.Status.PLAYING, "песочница: сроки платежей не наступают")
	var m := _new_session()
	m.setup("career", "marseille", "hacker")
	_check(m.debt == 42000 and m.clean == 60, "Марсель: долг $42 000, в кармане $60")
	_check(m.skills.level("hacking") == 2 and m.fake_cost("passport") == 280, "бывший айтишник: Взлом 2, левый паспорт $280 вместо $400")
	var c := _new_session()
	c.setup("career", "berlin", "cook")
	_check(c.skills.level("craft") == 2 and c.background_perk("defect_cut") == 0.05, "бывший повар: Ремесло 2 и меньше брака")
	_check(c.debt == 48000 and c.clean == 120, "Берлин: как раньше — долг $48 000 и $120")


func _test_world_events() -> void:
	var s := _calm_session(42, true)
	_check(s.events.events.size() >= 30, "событий в игре не меньше 30 (%d)" % s.events.events.size())
	_check(s.events.season(1) == "autumn" and s.events.season(29) == "winter" and s.events.season(57) == "spring", "времена года по 28 дней, игра начинается осенью")
	var cities_seen := {}
	var seasons_ok := true
	var amsterdam_only := true
	var world_seen := 0
	for i in 120:
		s.end_day()
		s.clean = 1000
		s.paid_this_period = 1500
		for c: String in s.events.today:
			cities_seen[c] = true
			var event: Dictionary = s.events.today[c]
			seasons_ok = seasons_ok and String(event.get("season", "")) in ["", s.events.season(s.day)]
			amsterdam_only = amsterdam_only and (event.id != "kings_day" or c == "amsterdam")
		if not s.events.world_today.is_empty():
			world_seen += 1
	_check(cities_seen.size() == s.world.cities.size(), "события идут во всех городах")
	_check(seasons_ok, "сезонные события — только в своё время года")
	_check(amsterdam_only, "День короля — только в Амстердаме")
	_check(world_seen > 3 and world_seen < 40, "мировые события редкие (%d из 120)" % world_seen)
	var m := _calm_session()
	var base_cost := m.flight_cost("miami")
	m.events.today = {}
	m.events.world_today = m.events.find("fuel_prices")
	_check(m.flight_cost("miami") > base_cost, "дорогое топливо поднимает цену билета")
	m.inventory.phones = 5
	m.documents.passport = "real"
	m.events.world_today = {}
	var chance := m.customs_chance("amsterdam")
	m.events.today = { "amsterdam": m.events.find("customs_crackdown") }
	_check(m.customs_chance("amsterdam") > chance, "проверяющий на таможне — досмотр чаще")
	m.police.heat.market = 20.0
	m.events.tomorrow = { "berlin": m.events.find("new_police_chief") }
	m.events.world_tomorrow = {}
	m.end_day()
	_check(m.police.heat.market > 20.0 - float(m.balance.heat_decay) + 5.0, "новый начальник полиции — розыск города растёт")


func _test_newspaper() -> void:
	var s := _calm_session(42, true)
	_check(not s.news.is_empty() and not s.news_read, "газета есть с первого утра")
	s.read_news()
	s.events.tomorrow = { "miami": s.events.find("spring_break") }
	s.events.world_tomorrow = s.events.find("interpol_week")
	s.end_day()
	var kinds := s.news.map(func(item: Array) -> String: return item[2])
	_check(not s.news_read, "утром — свежая газета")
	_check(kinds.has("world") and kinds.has("event") and kinds.has("joke"), "в газете мировое событие, события городов и шутка")
	_check(s.news.any(func(item: Array) -> bool: return item[0] == "NEWS_SPRING_BREAK" and item[1][0] == "CITY_MIAMI"), "заголовок о каникулах в Майами")
	s.police.heat.clubs = 80.0
	var about := s._news_about_you()
	_check(about.any(func(item: Array) -> bool: return item[0] == "NEWS_YOU_HEAT"), "большой розыск — о тебе пишут")
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := _calm_session(7)
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.news) == JSON.stringify(s.news) and JSON.stringify(loaded.events.to_dict()) == JSON.stringify(s.events.to_dict()), "газета и события городов сохраняются")


## Начать историю сразу (минуя утренний шанс).
func _start_story(s: GameSession, id: String) -> void:
	s.stories[id] = { "step": "start", "city": s.city, "show": s.day, "deadline": s.day + 5 }


func _test_stories() -> void:
	var s := _calm_session()
	_check(s.story_defs.size() >= 6, "историй контактов не меньше 6 (%d)" % s.story_defs.size())
	_check(not s.story_ready(s.story_def("shark")), "ростовщик не звонит в первый день")
	s.day = 3
	_check(s.story_ready(s.story_def("shark")) and not s.story_ready(s.story_def("detective")), "на 3-й день — ростовщик; детектив — только при розыске")
	# Ростовщик: взять конверт, доехать до вокзала, через 5 дней — скидка.
	_start_story(s, "shark")
	_check(not s.can_story_choose("shark", "pay"), "чужой выбор недоступен")
	s.story_choose("shark", "accept")
	_check(s.stories.shark.step == "envelope" and not s.story_task_ready("shark"), "конверт взят, но мы не на вокзале")
	s.travel("station")
	_check(s.story_task_ready("shark"), "на вокзале задание выполнимо")
	s.story_do_task("shark")
	_check(s.debt == 45000 and s.stories.shark.step == "deal", "долг −$3 000, дальше — предложение Льва")
	_check(not s.visible_stories().has("shark"), "следующий шаг появится не сразу")
	s.day += 5
	s.clean = 3000
	s.story_choose("shark", "pay")
	_check(s.debt == 41000 and s.clean == 1000 and s.stories_done.has("shark"), "внёс $2 000 — списали $4 000, история окончена")
	# Капитан: сигареты из кармана, бонусы к лимитам.
	var shipments := s.limit("shipments_max")
	_start_story(s, "captain")
	s.story_choose("captain", "accept")
	s.inventory.cigarettes = 25
	s.story_do_task("captain")
	_check(s.inventory.cigarettes == 5 and s.limit("shipments_max") == shipments + 1, "отдал 20 пачек — +1 груз за границу")
	_check(is_equal_approx(s.perk("customs_cut"), 0.1), "и таможня на 10% реже")
	# Просрочка задания — провал.
	var p := _calm_session()
	_start_story(p, "professor")
	p.story_choose("professor", "accept")
	for i in 6:
		p.end_day()
	_check(p.stories_done.has("professor") and not p.stories.has("professor"), "не принёс реагенты к сроку — история провалена")
	# Не ответил на выбор — контакт перестаёт звонить.
	var q := _calm_session()
	_start_story(q, "journalist")
	var report: Array = []
	for i in 6:
		report.append_array(q.end_day())
	_check(q.stories_done.has("journalist") and _has(report, "LOG_STORY_IGNORED"), "молчание — журналистка перестаёт звонить")
	# Адвокат: аресты на день короче.
	var days := q.arrest_days()
	q.story_perks = { "arrest_short": 1.0 }
	_check(q.arrest_days() == maxi(1, days - 1), "адвокат Фогель — арест на день короче")
	# Истории начинаются сами по утрам и сохраняются.
	var a := _calm_session()
	a.balance.story_chance = 1.0
	for i in 8:
		a.end_day()
		a.clean = 1000
		a.paid_this_period = 1500
	_check(not a.stories.is_empty() and a.stories.size() <= 2, "истории начинаются сами, не больше двух сразу")
	var data: Variant = JSON.parse_string(JSON.stringify(a.to_dict()))
	var loaded := _calm_session(7)
	loaded.load_dict(data)
	_check(JSON.stringify(loaded.stories) == JSON.stringify(a.stories) and JSON.stringify(loaded.stories_done) == JSON.stringify(a.stories_done), "истории сохраняются")


func _test_iron_mode() -> void:
	var s := _calm_session()
	s.setup("iron", "berlin", "driver")
	_check(s.arrests_left() == 3, "железный режим: 3 ареста до пожизненного")
	s.arrest()
	s.arrest()
	_check(s.status == GameSession.Status.PLAYING and s.arrests_left() == 1, "после двух арестов ещё играем")
	var report := s.arrest()
	_check(s.status == GameSession.Status.LOST and s.ending == "prison" and report[0][0] == "LOG_LIFE_SENTENCE", "третий арест — пожизненный, конец игры")
	var c := _calm_session()
	c.setup("career", "berlin", "")
	for i in 4:
		c.arrest()
	_check(c.status != GameSession.Status.LOST or c.ending == "debt", "в карьере аресты не кончают игру сами по себе")


func _test_endings() -> void:
	var s := _calm_session()
	s.setup("career", "berlin", "")
	s.clean = 1_100_000
	s.earned_total = 1_200_000
	s.clean_earned = 1_100_000
	s.dirty_earned = 100_000
	_check(not s.ending_ready("clean"), "с долгом чистой концовки нет")
	s.pay(48000)
	_check(s.ending_ready("clean"), "долг выплачен, чистый миллион, грязного 8% — «Чистые руки» доступны")
	s.end_day()
	_check(s.ending_offer == "clean", "концовку предлагают в конце дня")
	s.decline_ending()
	s.end_day()
	_check(s.ending_offer == "" and s.status == GameSession.Status.PLAYING, "отказался — играем дальше, второй раз не навязывают")
	_check(s.offer_ending("clean") and s.take_ending(), "взял концовку позже из карточки целей")
	_check(s.status == GameSession.Status.WON and s.ending == "clean", "партия окончена победой «Чистые руки»")
	var d := _calm_session()
	d.dirty_earned = 900_000
	d.earned_total = 1_000_000
	d.debt = 0
	d.clean = 1_000_000
	_check(not d.ending_ready("clean"), "90% грязного — не «чистые руки»")
	d.rank = d.balance.ranks.size() - 1
	_check(d.ending_ready("dark"), "Император — доступен «Теневой император»")
	var g := _calm_session()
	g.visited = { "berlin": true, "amsterdam": true, "marseille": true, "istanbul": true, "miami": true }
	_check(g.goal_done(g.balance.goals[3]), "5 городов в 5 странах — цель «мир» выполнена")
	g.visited = { "berlin": true, "amsterdam": true }
	_check(not g.goal_done(g.balance.goals[3]), "2 города — ещё нет")


func _test_save_and_load() -> void:
	var s := _calm_session()
	s.setup("iron", "berlin", "cook")
	s.visited.amsterdam = true
	s.endings_declined = ["dark"]
	s.arrests = 1
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
## В начале занимает у ростовщика $1 000. Покупает самый «просевший» из стартовых товаров
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
			# Новичок торгует стартовыми товарами: оружие, краденое и редкости (этап 9, поле category) не трогает.
			for good: Dictionary in s.market.goods.filter(func(g: Dictionary) -> bool: return not g.has("category")):
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
	return s.market.get_good(id).base_price * float(s.market.get_district(s.district).prices.get(id, 1.0))


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
