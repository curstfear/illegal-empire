extends Node
## Служебный прогон партии со скриншотами (для проверки глазами). Окно само закрывается в конце.
## Godot --path . res://tests/screenshot.tscn -- <папка_для_png> [часть]
## Часть: "all" (по умолчанию, вся партия — минуты две), "world" (только мировая карта — секунд 15)
## "cities" (все города днём и вечером), "engine" (бизнес по часам: деньги над зданиями, дневной рейс)
## "supply" (поставщик, приказы менеджеру, утренняя доставка), "jobs" (заказы и ситуации) или "rank" (ступени карьеры).
## Чтобы окно не мешало: --resolution 960x540 --position 0,0 перед --path.

const GAME_SCENE := preload("res://scenes/game.tscn")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "user://"
	var part: String = args[1] if args.size() > 1 else "all"
	# Если сценарий упадёт посередине — окно не висит, а закрывается само.
	get_tree().create_timer(150.0 if part == "all" else 45.0).timeout.connect(get_tree().quit.bind(1))
	TranslationServer.set_locale("ru")
	if part == "world":
		await _world_shots(out_dir)
		get_tree().quit()
		return
	if part == "cities":
		await _city_shots(out_dir)
		get_tree().quit()
		return
	if part == "rank":
		await _rank_shots(out_dir)
		get_tree().quit()
		return
	if part == "jobs":
		await _jobs_shots(out_dir)
		get_tree().quit()
		return
	if part == "supply":
		await _supply_shots(out_dir)
		get_tree().quit()
		return
	if part == "engine":
		await _engine_shots(out_dir)
		get_tree().quit()
		return
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	var city: Node3D = game.get_node("City")
	await _frames(15)
	_shot(out_dir.path_join("1_start.png"))

	# Без случайных проверок, чтобы прогон был предсказуемым.
	var s := GameState.session
	var check_base: float = s.balance.check_base
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0

	# Карточка чужого района: кнопка «Перейти».
	screen.open_card("forest")
	await _frames(10)
	_shot(out_dir.path_join("2_card_other.png"))

	# Переход в лесопарк по кнопке карточки и сбор.
	screen.get_node("%CardTravelButton").pressed.emit()
	GameState.do_activity("pick_mushrooms")
	await _frames(10)
	_shot(out_dir.path_join("3_forest.png"))
	print("лес: район ", s.district, ", грибов ", s.inventory.mushrooms, ", время ", Clock.minutes_of_day())

	# Сарай лесника: карточка «продаётся», покупка, мох на склад, варка пыльцы.
	screen.open_property_card("forest_shed")
	await _frames(10)
	_shot(out_dir.path_join("3a_shed_for_sale.png"))
	s.clean += 1500
	GameState.buy_property("forest_shed")
	s.inventory.moon_moss = 6
	GameState.store_goods("forest_shed", "moon_moss")
	GameState.start_production("forest_shed", "moon_pollen")
	await _frames(10)
	_shot(out_dir.path_join("3b_shed_brewing.png"))
	print("сарай: мой = ", s.properties.is_mine("forest_shed"), ", партий = ", s.properties.state.forest_shed.batches.size())
	var picked: Array = city._pick(city.property_anchor_screen_position("forest_shed") + Vector2(0, 30))
	print("клик по сараю → ", picked)

	# Несколько дней торговли, чтобы на графиках была история.
	for i in 6:
		s.clean += 60
		GameState.buy("herbs", 2)
		Clock.finish_day()

	# Рынок: окно рынка и вкладка ларька.
	screen.open_card("market")
	screen.get_node("%CardTravelButton").pressed.emit()
	screen.get_node("%CardMarketButton").pressed.emit()
	s.clean += 400
	GameState.buy_stall()
	screen.open_tab("stall")
	await _frames(10)
	_shot(out_dir.path_join("4_market_window.png"))

	# Прачечная: покупка и сдача грязных в отмыв.
	screen.get_node("%MarketCloseButton").pressed.emit()
	s.clean += 3000
	s.dirty += 900
	GameState.buy_property("laundromat")
	GameState.launder("laundromat")
	screen.open_property_card("laundromat")
	await _frames(10)
	_shot(out_dir.path_join("4b_laundromat.png"))
	print("пыльца в сарае после ночей: ", s.properties.stock_of("forest_shed", "moon_pollen"),
			", в отмыве: ", s.properties.state.laundromat.dirty_queue)

	# Бригада: нанять двоих с биржи, поставить в здания, открыть вкладку «Люди».
	s.clean += 500
	for candidate: Dictionary in s.crew.candidates.duplicate().slice(0, 2):
		GameState.hire(int(candidate.id))
	for person: Dictionary in s.crew.people:
		for place: String in ["forest_shed", "laundromat"]:
			if s.can_assign(int(person.id), place) and person.job == "":
				GameState.assign(int(person.id), place)
	screen.open_tab("crew")
	await _frames(10)
	_shot(out_dir.path_join("4c_crew.png"))
	print("бригада: ", s.crew.people.map(func(p: Dictionary) -> String: return "%s/%s/%s" % [p.role, p.trait, p.job]))

	# Перевозки: курьер и менеджер, фургон с тайником, маршрут сарай → прачечная.
	s.clean += 8000
	s.crew.roll_candidates(s.rng, 3)
	for role: String in ["courier", "manager"]:
		var candidate: Dictionary = s.crew.candidates[0]
		candidate.role = role
		GameState.hire(int(candidate.id))
	var manager: Dictionary = s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "manager")[0]
	GameState.assign(int(manager.id), "forest_shed")
	GameState.give_bonus(int(manager.id))
	GameState.pressure(int(s.crew.people[0].id))
	GameState.buy_vehicle("van")
	GameState.add_hidden(int(s.logistics.vehicles[0].id))
	GameState.buy_vehicle("scooter")
	screen.open_tab("crew")
	await _frames(10)
	_shot(out_dir.path_join("4d_crew_loyalty.png"))
	print("после найма: ", s.crew.people.map(func(p: Dictionary) -> String: return p.role), " деньги ", s.money)
	var courier: Dictionary = s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "courier")[0]
	GameState.add_route("forest_shed", "laundromat", "moon_pollen", int(s.logistics.vehicles[0].id), int(courier.id))
	# Второй маршрут: на рынок клубов, с разведчиком.
	s.crew.roll_candidates(s.rng, 3)
	for role: String in ["courier", "scout"]:
		var candidate: Dictionary = s.crew.candidates[0]
		candidate.role = role
		GameState.hire(int(candidate.id))
	var runners := s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "courier" and s.logistics.route_of(int(p.id)).is_empty())
	var scouts := s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "scout")
	GameState.add_route("laundromat", "@clubs", "mushrooms", int(s.logistics.vehicles[1].id), int(runners[0].id), int(scouts[0].id))
	GameState.add_disguise(int(s.logistics.vehicles[1].id))
	screen.open_tab("routes")
	Clock.elapsed = 0.9 * Clock._day_length
	Clock.paused = true
	await _frames(30)
	_shot(out_dir.path_join("4e_routes.png"))
	print("маршруты: ", s.logistics.routes)
	screen.open_tab("crew")
	await _frames(10)
	_shot(out_dir.path_join("4f_crew_more.png"))
	Clock.elapsed = 0.0

	# Банды: продажи на чужой земле в клубах, влияние; вкладка «Банды» и карточка района с хозяином.
	s.gangs.player_gain("forest", 45.0)
	s.gangs.player_gain("clubs", 22.0)
	s.gangs.change_relation("neon", -40.0)
	s.gangs.turf_sales.clubs = 900
	s._gang_demand("neon")
	s._gang_deal("rails")
	s.gangs.state.bazaar.revenge = true
	GameState.changed.emit()
	screen.open_tab("gangs")
	screen.open_card("clubs")
	await _frames(10)
	_shot(out_dir.path_join("4g_gangs.png"))

	# Разборка: трое бойцов, окно выбора тактики, потом отчёт о бое.
	s.clean += 3000
	s.balance.crew_max = 10
	for i in 3:
		s.crew.roll_candidates(s.rng, 3)
		var fighter: Dictionary = s.crew.candidates[0]
		fighter.role = "fighter"
		fighter.skill = 3
		GameState.hire(int(fighter.id))
	GameState.buy_gear()
	s.energy = 100
	screen.open_tab("gangs")
	screen.open_fight("neon")
	await _frames(10)
	_shot(out_dir.path_join("4h_fight_prep.png"))
	s.balance.fight_wound_chance = 0.5
	GameState.fight("neon", "head_on")
	await _frames(10)
	_shot(out_dir.path_join("4i_fight_report.png"))
	print("разборка: ", s.fight_result)
	GameState.choose_fight_outcome("take" if s.fight_result.win else "ok")
	screen.open_tab("crew")
	await _frames(10)
	_shot(out_dir.path_join("4j_crew_wounded.png"))

	# Дипломатия: договор с Путейцами, встреча с Базарными; вкладка «Банды» прокручена к бандам.
	s.clean += 2000
	GameState.sign_treaty("rails", "peace_tax")
	GameState.meet("bazaar")
	screen.open_tab("gangs")
	await _frames(5)
	var gangs_scroll: ScrollContainer = screen.get_node("%Tabs").get_child(3)
	gangs_scroll.scroll_vertical = 120
	await _frames(10)
	_shot(out_dir.path_join("4k_diplomacy.png"))

	# Полиция: детективы ведут дело в клубах, «крыша» куплена.
	s.police.heat.clubs = 75.0
	s.police.dossier.clubs = 35.0
	GameState.hire_krysha("clubs")
	screen.open_card("clubs")
	await _frames(10)
	_shot(out_dir.path_join("4l_police_card.png"))
	s.police.heat.clubs = 20.0

	# Ночь в клубах.
	screen.get_node("%MarketCloseButton").pressed.emit()
	screen.open_card("clubs")
	screen.get_node("%CardTravelButton").pressed.emit()
	screen.open_tab("stall")
	Clock.elapsed = 0.72 * Clock._day_length
	Clock.paused = true
	await _frames(15)
	_shot(out_dir.path_join("5_night_clubs.png"))
	print("клик в центр клубов → ", city.district_at_screen(city.anchor_screen_position("clubs") + Vector2(0, 40)))

	# Проверка полиции.
	s.balance.check_base = check_base
	GameState.buy("cigarettes", 1)
	s.pending_check = { "bribe": 90 }
	GameState.changed.emit()
	await _frames(10)
	_shot(out_dir.path_join("6_check.png"))
	GameState.resolve_check("surrender")

	for i in 15:
		Clock.finish_day()
	await _frames(10)
	_shot(out_dir.path_join("7_end.png"))
	print("continue: ", GameState.continue_game(), ", day ", GameState.session.day, ", status ", GameState.session.status)

	game.queue_free()
	await _frames(2)
	await _world_shots(out_dir)
	get_tree().quit()


## Все города днём и вечером: свой свет, вода, застройка, подписи.
func _city_shots(out_dir: String) -> void:
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await _frames(5)
	for city: Dictionary in GameState.session.world.cities:
		GameState.session.city = city.id
		GameState.session.district = city.start
		GameState.changed.emit()
		await _frames(10)
		var lighting: Node = game.get_node("City/Lighting")
		lighting.forced_hour = 12.0
		await _frames(5)
		_shot(out_dir.path_join("9_%s_day.png" % city.id))
		lighting.forced_hour = 21.5
		await _frames(5)
		_shot(out_dir.path_join("9_%s_night.png" % city.id))


## Мир: карта, слой розыска с дугой до Майами, перелёт в Амстердам — город пересобирается.
func _world_shots(out_dir: String) -> void:
	GameState.new_game()
	GameState.session.clean = 3000
	GameState.session.documents.passport = "real"
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	await _frames(10)
	screen._world_button.pressed.emit()
	await _frames(10)
	_shot(out_dir.path_join("8_world.png"))
	screen._world_overlay.mode = "heat"
	screen._world_overlay._selected = "miami"
	screen._world_overlay._hovered = "miami"
	screen._world_overlay.refresh()
	screen._world_overlay._globe._zoom(1.2)
	screen._world_overlay._globe._turn(Vector2(60, 0))
	await _frames(5)
	_shot(out_dir.path_join("8a_world_heat.png"))
	screen._world_overlay.visible = false
	GameState.fly("amsterdam")
	await _frames(20)
	screen.open_tab("gangs")
	await _frames(10)
	_shot(out_dir.path_join("8b_amsterdam.png"))
	print("город: ", GameState.session.city, ", район ", GameState.session.district, ", узел города ", game.get_node("City").name)
	# Таможня: прилёт в Марсель с товаром — досмотр.
	var s := GameState.session
	s.inventory.blue_dust = 4
	s.balance.customs.schengen = 10.0
	s.balance.customs_max = 1.0
	GameState.fly("marseille")
	await _frames(20)
	_shot(out_dir.path_join("8c_customs.png"))
	GameState.resolve_check("surrender")
	screen._world_button.pressed.emit()
	await _frames(10)
	_shot(out_dir.path_join("8d_documents.png"))
	# Грузы между городами: склад в доках Марселя, сигареты — в Берлин на рынок.
	screen._world_overlay.visible = false
	s.clean += 5000
	s.properties.state.mrs_warehouse.owned = true
	s.properties.add_stock("mrs_warehouse", "cigarettes", 30)
	GameState.ship("mrs_warehouse", "@clubs", "cigarettes", 10, false)
	screen.open_tab("routes")
	await _frames(5)
	var routes_scroll: ScrollContainer = screen.get_node("%Tabs").get_child(2)
	routes_scroll.scroll_vertical = 400
	await _frames(10)
	_shot(out_dir.path_join("8e_shipments.png"))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## Этап 8.5: склад с дилером и ларёк торгуют по часам, деньги всплывают; легковая едет дневным рейсом.
func _engine_shots(out_dir: String) -> void:
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	var s := GameState.session
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0
	s.clean += 20000
	GameState.buy_property("market_warehouse")
	s.inventory.cigarettes = 25
	GameState.store_goods("market_warehouse", "cigarettes")
	GameState.buy_stall()
	s.inventory.mushrooms = 20
	GameState.stock_stall("mushrooms")
	s.crew.roll_candidates(s.rng, 3)
	for role: String in ["dealer", "courier"]:
		var candidate: Dictionary = s.crew.candidates[0]
		candidate.role = role
		candidate.skill = 3
		GameState.hire(int(candidate.id))
	var dealer: Dictionary = s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "dealer")[0]
	var courier: Dictionary = s.crew.people.filter(func(p: Dictionary) -> bool: return p.role == "courier")[0]
	GameState.assign(int(dealer.id), "market_warehouse")
	GameState.buy_vehicle("car")
	GameState.add_route("market_warehouse", "@clubs", "cigarettes", int(s.logistics.vehicles[0].id), int(courier.id))
	GameState.set_route_shift(int(s.logistics.routes[0].id), "day")
	var money := s.money
	Clock.set_speed(4)
	await _frames(20)
	# Пропускаем к 09:50 — дальше часы идут сами, и в 10:00 деньги всплывают над зданиями.
	Clock.elapsed = 3.83 / 24.0 * Clock._day_length
	while s.hours_done < 4.0:
		await _frames(1)
	await _frames(12)
	_shot(out_dir.path_join("engine_1_popups.png"))
	print("к 10:00: часов отработано ", s.hours_done, ", денег было ", money, " стало ", s.money,
			", сигарет на складе ", s.properties.stock_of("market_warehouse", "cigarettes"), ", доход сегодня ", s.income_today)
	Clock.elapsed = 9.2 / 24.0 * Clock._day_length
	await _frames(30)
	screen.open_tab("routes")
	await _frames(10)
	_shot(out_dir.path_join("engine_2_day_trip.png"))
	print("в 15:10: часов ", s.hours_done, ", маршрут ", s.logistics.routes, ", денег ", s.money)
	Clock.paused = true


## Этап 8.5, часть 2: лаборатория у вокзала с менеджером и дилером, Шрам держит там запас мха.
func _supply_shots(out_dir: String) -> void:
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	var s := GameState.session
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0
	s.clean += 20000
	s.travel("station")
	GameState.buy_property("station_lab")
	s.crew.roll_candidates(s.rng, 3)
	for role: String in ["manager", "dealer"]:
		var candidate: Dictionary = s.crew.candidates[0]
		candidate.role = role
		candidate.skill = 3
		GameState.hire(int(candidate.id))
	for person: Dictionary in s.crew.people:
		GameState.assign(int(person.id), "station_lab")
	GameState.add_supply("shram", "moon_moss", 10, "station_lab", "keep")
	GameState.add_supply("chemsnab", "reagents", 5, "station_lab", "daily")
	GameState.set_order("station_lab", "brew", "moon_pollen")
	screen.open_tab("routes")
	await _frames(15)
	(screen._routes_list.get_parent() as ScrollContainer).scroll_vertical = 100000
	await _frames(5)
	_shot(out_dir.path_join("supply_1_routes_tab.png"))
	Clock.set_speed(4)
	Clock.elapsed = 1.4 / 24.0 * Clock._day_length
	while s.hours_done < 2.0:
		await _frames(1)
	await _frames(20)
	_shot(out_dir.path_join("supply_2_morning_van.png"))
	var life: Node = game.get_node("City/Life")
	var vans: Array = life._route_cars.filter(func(car: Dictionary) -> bool: return car.has("supply"))
	print("машины поставщиков: ", vans.size(), ", видно ", vans.filter(func(car: Dictionary) -> bool: return car.node.visible).size(),
			", где ", vans.map(func(car: Dictionary) -> Vector3: return car.node.position))
	print("утро: склад лаборатории ", s.properties.state.station_lab.stock, ", грязных ", s.dirty, ", чистых ", s.clean)
	Clock.paused = true
	screen.open_property_card("station_lab")
	await _frames(15)
	_shot(out_dir.path_join("supply_3_card_orders.png"))
	for day in 2:
		Clock.finish_day()
		Clock.elapsed = 12.0 / 24.0 * Clock._day_length
		Clock.set_speed(4)
		await _frames(30)
		Clock.paused = true
	print("через 2 дня: склад ", s.properties.state.station_lab.stock, ", грязных ", s.dirty, ", доход сегодня ", s.income_today)
	await _frames(10)
	_shot(out_dir.path_join("supply_4_after_two_days.png"))


## Этап 8.5, часть 3: панель «Дела» — заказ в работе, доска, две ситуации и метки над городом.
func _jobs_shots(out_dir: String) -> void:
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	var s := GameState.session
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0
	s.balance.situation_chance = 0.0
	s.clean += 20000
	GameState.buy_property("market_warehouse")
	s.inventory.phones = 10
	GameState.store_goods("market_warehouse", "phones")
	var offer: Dictionary = s.jobs.offers_in(s.city)[0]
	GameState.accept_order(int(offer.id))
	var now := s.day * 24 + 4
	s.jobs.situations.append({ "id": s.jobs.next_id(), "kind": "cop_visit", "place": "market_warehouse", "target": "",
			"amount": 0, "cost": 260, "expires": now })
	s.jobs.situations.append({ "id": s.jobs.next_id(), "kind": "tip_off", "place": "@clubs", "target": "neon|moon_moss",
			"amount": 8, "cost": 0, "expires": now + 2 })
	screen.close_card()
	screen._offers_open = true
	GameState.changed.emit()
	await _frames(20)
	_shot(out_dir.path_join("jobs_1_panel.png"))
	print("заказы: ", s.jobs.orders, " доска: ", s.jobs.offers_in(s.city).size(), " ситуации: ", s.jobs.situations.size())
	GameState.choose_situation(int(s.jobs.situations[0].id), "bribe")
	screen._offers_open = false
	GameState.changed.emit()
	await _frames(20)
	_shot(out_dir.path_join("jobs_2_after_choice.png"))
	print("после выбора: ситуаций ", s.jobs.situations.size(), ", денег ", s.money)


## Этап 8.5, часть 4: карточка ступени — прогресс до Барыги, потом повышение и вся лестница.
func _rank_shots(out_dir: String) -> void:
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	var screen: Control = game.get_node("Hud/GameScreen")
	var s := GameState.session
	s.balance.situation_chance = 0.0
	s._earn(3200, false)
	s.orders_done = 1
	GameState.tick(1.0)
	screen.close_card()
	await _frames(20)
	_shot(out_dir.path_join("rank_1_progress.png"))
	print("ступень ", s.rank, " ", s.rank_name_key(), ", заработано ", s.earned_total)
	s.orders_done = 2
	s._earn(2000, true)
	GameState.tick(2.0)
	screen._ladder_open = true
	GameState.changed.emit()
	await _frames(20)
	_shot(out_dir.path_join("rank_2_ladder.png"))
	print("после: ступень ", s.rank, " ", s.rank_name_key(), ", заказов в работе до ", s.limit("order_active_max"))
