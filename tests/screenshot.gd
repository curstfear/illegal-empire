extends Node
## Служебный прогон партии со скриншотами (для проверки глазами). Окно само закрывается в конце.
## Godot --path . res://tests/screenshot.tscn -- <папка_для_png> [часть]
## Часть: "all" (по умолчанию, вся партия — минуты две), "world" (только мировая карта — секунд 15)
## или "cities" (все города днём и вечером).
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
	Clock.elapsed = 0.9 * 90.0
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
	Clock.elapsed = 0.72 * 90.0
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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
