extends Node
## Служебный прогон партии со скриншотами (для проверки глазами).
## Godot --path . res://tests/screenshot.tscn -- <папка_для_png>

const GAME_SCENE := preload("res://scenes/game.tscn")


func _ready() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	TranslationServer.set_locale("ru")
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
	screen.get_node("%Tabs").current_tab = 1
	await _frames(10)
	_shot(out_dir.path_join("4_market_window.png"))

	# Ночь в клубах.
	screen.get_node("%MarketCloseButton").pressed.emit()
	screen.open_card("clubs")
	screen.get_node("%CardTravelButton").pressed.emit()
	screen.get_node("%Tabs").current_tab = 0
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
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
