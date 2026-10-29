extends Node3D
## Изометрическая камера города. Удобна и с мышью, и с трекпадом MacBook.
## Трекпад: два пальца — двигать, щипок — приближение, зажать и тянуть — двигать.
## Мышь: колесо — приближение, перетаскивание левой/правой кнопкой — двигать.
## Клавиатура: WASD / стрелки — двигать, Q / E — повернуть на 90°, + / − — приближение.

const ZOOM_MIN := 8.0
const ZOOM_MAX := 64.0
const PAN_SPEED := 14.0
## Сдвиг картинки вбок в долях высоты кадра (под правую панель).
const SCREEN_SHIFT := 0.24
## Насколько сильно жесты трекпада двигают и приближают.
const GESTURE_PAN := 0.25
const GESTURE_ZOOM := 1.0
## С какого сдвига (в пикселях) зажатая кнопка — это уже перетаскивание, а не клик.
const DRAG_START := 8.0

## Точка, вокруг которой крутится камера.
var target := Vector3.ZERO:
	set(value):
		target = value
		position = value

var _zoom := 34.0
var _yaw := 45.0
## Перетаскивание: какая кнопка зажата, где нажали и началось ли движение.
var _drag_button := MOUSE_BUTTON_NONE
var _drag_from := Vector2.ZERO
var _dragging := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	rotation_degrees = Vector3(-35.0, _yaw, 0)


func _process(delta: float) -> void:
	# Справа панель интерфейса: сдвигаем картинку влево, чтобы город был в центре свободного места.
	camera.h_offset = camera.size * SCREEN_SHIFT
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y += 1
	if move != Vector2.ZERO:
		_pan(move.limit_length() * PAN_SPEED * delta * (_zoom / 20.0))


func _unhandled_input(event: InputEvent) -> void:
	# Жесты помечаем обработанными, иначе Godot отдаёт их повторно и карта едет вдвое дальше.
	if event is InputEventPanGesture:
		# Два пальца по трекпаду — двигаем карту.
		_pan(event.delta * GESTURE_PAN * (_zoom / 20.0))
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		# Щипок: factor > 1 — пальцы разводят, приближаем.
		_set_zoom(_zoom / pow(event.factor, GESTURE_ZOOM), false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _drag_button != MOUSE_BUTTON_NONE:
		if not _dragging and event.position.distance_to(_drag_from) > DRAG_START:
			_dragging = true
		if _dragging:
			var world_per_pixel := _zoom / get_viewport().get_visible_rect().size.y
			_pan(-event.relative * world_per_pixel)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				turn(-90.0)
			KEY_E:
				turn(90.0)
			KEY_EQUAL, KEY_KP_ADD:
				zoom_by(0.8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(1.25)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.9)
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.1)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_drag_button = event.button_index
				_drag_from = event.position
				_dragging = false
			elif event.button_index == _drag_button:
				_drag_button = MOUSE_BUTTON_NONE
				# Отпустили после перетаскивания — это не клик по району.
				if _dragging:
					get_viewport().set_input_as_handled()
				_dragging = false


## Повернуть камеру вокруг города (кнопки на экране, Q / E).
func turn(degrees: float) -> void:
	_yaw += degrees
	create_tween().tween_property(self, "rotation_degrees:y", _yaw, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Приблизить (factor < 1) или отдалить (factor > 1) — кнопки на экране, колесо, + / −.
func zoom_by(factor: float) -> void:
	_set_zoom(_zoom * factor, true)


## Сдвиг в плоскости земли относительно того, куда смотрит камера.
func _pan(screen_delta: Vector2) -> void:
	var yaw := deg_to_rad(_yaw)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	target += right * screen_delta.x + forward * screen_delta.y


func _set_zoom(value: float, smooth: bool) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	if smooth:
		create_tween().tween_property(camera, "size", _zoom, 0.12)
	else:
		camera.size = _zoom
