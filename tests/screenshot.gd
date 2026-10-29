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

	GameState.buy("mushrooms", 5)
	GameState.buy("cigarettes", 1)
	Clock.finish_day()
	await _frames(10)
	_shot(out_dir.path_join("2_after_day.png"))

	for i in 13:
		Clock.finish_day()
	await _frames(10)
	_shot(out_dir.path_join("3_lost.png"))
	# Автосохранение было в конце 13-го дня, проигрыш не сохраняется.
	print("continue: ", GameState.continue_game(), ", day ", GameState.session.day, ", status ", GameState.session.status)
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
