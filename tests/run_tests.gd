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
	_test_save_and_load()
	_report_balance_bot()
	_report_honest_bots()
	print("\nИтог: %d прошло, %d упало" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _new_session(seed_value: int = 42) -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(),
			GameData.load_properties(), GameData.load_recipes(), GameData.load_crew(), GameData.load_gangs(), GameData.load_world(), seed_value)


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
	var report := s.end_day()
	_check(s.gangs.share("forest", Gangs.PLAYER) < 10.0, "без дел твоё влияние выветривается")
	_check(s.gangs.relation("bazaar") > -30.0, "обида со временем остывает")
	_check(int(s.gangs.state.rails.cash) > cash_before, "банда получает доход со своих земель")
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
	var price := s.market.sell_price("clubs", "blue_dust")
	report = s._gang_dump("neon")
	_check(_has(report, "LOG_GANG_DUMP") and s.market.sell_price("clubs", "blue_dust") < price, "сброс товара бандой снижает цену")
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
	_check(s.world.cities.size() == 5 and s.city == "berlin", "5 городов, старт в Берлине")
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
	s.market.event = { "id": "x", "district": "", "police": 2.0, "prices": {} }
	s.market.event_city = "berlin"
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
