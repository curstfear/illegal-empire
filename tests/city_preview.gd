extends Node
## Служебный прогон города: скриншоты в разное время суток,
## проверка кликов по всем зданиям и жестов трекпада.
## Godot --path . res://tests/city_preview.tscn -- <папка_для_png>

const GAME_SCENE := preload("res://scenes/game.tscn")

var _clicked: Array[String] = []


func _ready() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	TranslationServer.set_locale("ru")
	GameState.new_game()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	Clock.paused = true
	var city: Node3D = game.get_node("City")
	var screen: Control = game.get_node("Hud/GameScreen")
	screen.close_card()
	city.district_clicked.connect(func(d: String) -> void: _clicked.append(d))
	await _frames(10)

	_check_all_buildings(city)
	await _check_hover_and_click(city)
	await _check_gestures(city)

	# Полдень по игровым часам: на улицах людно. Розыск высокий — полиции больше.
	Clock.elapsed = 0.25 * Clock._day_length
	GameState.session.police.heat.market = 90.0
	var rig: Node3D = city.camera_rig
	rig.target = city.district_ground_anchor("market") + Vector3(1.5, 0, 1.5)
	rig._set_zoom(14.0, false)
	await _frames(40)
	_shot(out_dir.path_join("city_life.png"))
	var life := city.get_node("Life")
	var shown := { "car": 0, "police_car": 0, "person": 0, "police": 0 }
	for mover: Dictionary in life._movers:
		if mover.node.visible:
			shown[mover.kind] += 1
	print("на улицах днём при розыске 90: ", shown)
	rig._set_zoom(5.0, false)
	rig.target = city.district_ground_anchor("market")
	await _frames(10)
	_shot(out_dir.path_join("city_hero.png"))

	rig._set_zoom(34.0, false)
	rig.target = Vector3(22, 0, 22)
	var lighting := city.get_node("Lighting")
	for hour in [12.0, 22.0]:
		lighting.forced_hour = hour
		await _frames(10)
		_shot(out_dir.path_join("city_%02d.png" % int(hour)))
	# Скорость: ночь (все фонари), весь город в кадре, жизнь на улицах идёт.
	rig._set_zoom(64.0, false)
	Clock.paused = false
	await get_tree().create_timer(3.0).timeout
	print("кадров в секунду: ", Engine.get_frames_per_second(),
			", объектов на сцене: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			", вызовов отрисовки: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


## Для каждой коробки здания: точки верха, середины и чуть выше (подпись) → тот же район.
func _check_all_buildings(city: Node3D) -> void:
	var camera: Camera3D = city.camera_rig.camera
	var screen_rect := get_viewport().get_visible_rect()
	var total := 0
	var wrong := 0
	for entry: Array in city._hit_boxes:
		var box: AABB = entry[0]
		var center := box.get_center()
		for point in [Vector3(center.x, box.end.y * 0.5, center.z), Vector3(center.x, box.end.y - 0.05, center.z)]:
			var screen_pos := camera.unproject_position(point)
			if not screen_rect.has_point(screen_pos):
				continue
			total += 1
			var got: String = city.district_at_screen(screen_pos)
			if got != entry[1]:
				wrong += 1
	print("клики по зданиям: %d точек, мимо района %d (%.1f%%)" % [total, wrong, 100.0 * wrong / maxi(total, 1)])
	for district in ["market", "station", "clubs", "forest"]:
		var tag_pos: Vector2 = city.anchor_screen_position(district)
		print("  подпись/верх «%s» → %s" % [district, city.district_at_screen(tag_pos + Vector2(0, 12))])


## Настоящие события мыши: наведение подсвечивает район, клик открывает карточку.
func _check_hover_and_click(city: Node3D) -> void:
	var pos: Vector2 = city.anchor_screen_position("station") + Vector2(0, 30)
	_mouse_move(pos, 0)
	await _frames(2)
	print("наведение на вокзал: подсвечен = ", city._hovered)
	_mouse_button(pos, true)
	_mouse_button(pos, false)
	await _frames(2)
	print("клик по вокзалу → карточка: ", _clicked)


## Жесты трекпада и перетаскивание.
func _check_gestures(city: Node3D) -> void:
	var rig: Node3D = city.camera_rig
	var target_before: Vector3 = rig.target
	var pan := InputEventPanGesture.new()
	pan.position = Vector2(500, 500)
	pan.delta = Vector2(10, 4)
	get_viewport().push_input(pan)
	await _frames(2)
	print("два пальца: камера сдвинулась на ", (rig.target - target_before).length())

	var zoom_before: float = rig.camera.size
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = Vector2(500, 500)
	pinch.factor = 1.3
	get_viewport().push_input(pinch)
	await _frames(2)
	print("щипок: масштаб ", zoom_before, " → ", rig.camera.size)

	# Перетаскивание с зажатым кликом двигает карту и не открывает карточку.
	_clicked.clear()
	var start := Vector2(600, 600)
	target_before = rig.target
	_mouse_button(start, true)
	for i in 10:
		_mouse_move(start + Vector2(i * 8, i * 3), MOUSE_BUTTON_MASK_LEFT, Vector2(8, 3))
	_mouse_button(start + Vector2(80, 30), false)
	await _frames(2)
	print("перетаскивание: сдвиг ", (rig.target - target_before).length(), ", лишних кликов ", _clicked.size())


func _mouse_move(pos: Vector2, mask: int, relative := Vector2.ZERO) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.relative = relative
	motion.button_mask = mask
	Input.parse_input_event(motion)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.position = pos
	button.global_position = pos
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	Input.parse_input_event(button)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
