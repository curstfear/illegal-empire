extends Node
## Служебный прогон экрана игры со скриншотами (для проверки глазами).
## Godot --path . res://tests/screenshot.tscn -- <папка_для_png>

const GAME_SCENE := preload("res://scenes/ui/game_screen.tscn")


func _ready() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	TranslationServer.set_locale("ru")
	GameState.new_game()
	var screen := GAME_SCENE.instantiate()
	add_child(screen)
	await _frames(10)
	_shot(out_dir.path_join("1_start.png"))

	# Без случайных проверок, чтобы прогон был предсказуемым.
	var s := GameState.session
	var check_base: float = s.balance.check_base
	s.balance.check_base = 0.0
	s.balance.check_per_heat = 0.0

	# Лесопарк: сбор.
	GameState.travel("forest")
	GameState.do_activity("pick_mushrooms")
	GameState.do_activity("pick_herbs")
	await _frames(10)
	_shot(out_dir.path_join("2_forest.png"))
	print("лес: грибов ", s.inventory.mushrooms, ", трав ", s.inventory.herbs, ", сил ", s.energy, ", время ", Clock.minutes_of_day())

	# Рынок: левая посылка, ларёк, вкладка ларька.
	GameState.travel("market")
	GameState.do_activity("shady_parcel")
	s.clean += 400
	GameState.buy_stall()
	GameState.stock_stall("mushrooms")
	var tabs: TabContainer = screen.get_node("%Tabs")
	tabs.current_tab = 1
	await _frames(10)
	_shot(out_dir.path_join("3_market_stall.png"))
	print("рынок: грязных ", s.dirty, ", ларёк ", s.stall.owned, ", в ларьке грибов ", s.stall.stock.mushrooms)

	Clock.finish_day()
	tabs.current_tab = 2
	s.skills.add_xp("charisma", 70)
	GameState.changed.emit()
	await _frames(10)
	_shot(out_dir.path_join("4_skills.png"))

	# Проверка полиции и арест.
	s.balance.check_base = check_base
	tabs.current_tab = 0
	GameState.buy("cigarettes", 1)
	s.pending_check = { "bribe": 90 }
	GameState.changed.emit()
	await _frames(10)
	_shot(out_dir.path_join("5_check.png"))
	var day_before := s.day
	GameState.resolve_check("arrest")
	await _frames(10)
	print("арест: дней прошло = ", s.day - day_before, ", часы на паузе = ", Clock.paused)

	for i in 14:
		Clock.finish_day()
	await _frames(10)
	_shot(out_dir.path_join("6_end.png"))
	print("continue: ", GameState.continue_game(), ", day ", GameState.session.day, ", status ", GameState.session.status)
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
