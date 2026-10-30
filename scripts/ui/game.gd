extends Node
## Сцена партии: 3D-город и интерфейс поверх него.
## Связывает клики по городу с карточками и кнопки камеры с камерой.
## Перелетел в другой город — 3D-город собирается заново по его раскладке.

const CITY_SCENE := preload("res://scenes/city/city.tscn")

@onready var _city: Node3D = $City
@onready var _screen: Control = $Hud/GameScreen

## Город, для которого собрана сцена.
var _city_id: String = ""


func _ready() -> void:
	_screen.get_node("%RotateLeftButton").pressed.connect(func() -> void: _city.camera_rig.turn(-90.0))
	_screen.get_node("%RotateRightButton").pressed.connect(func() -> void: _city.camera_rig.turn(90.0))
	_screen.get_node("%ZoomOutButton").pressed.connect(func() -> void: _city.camera_rig.zoom_by(1.25))
	_screen.get_node("%ZoomInButton").pressed.connect(func() -> void: _city.camera_rig.zoom_by(0.8))
	_attach_city()
	GameState.changed.connect(_on_changed)


func _attach_city() -> void:
	_city_id = GameState.session.city
	_screen.city = _city
	_city.district_clicked.connect(_screen.open_card)
	_city.property_clicked.connect(_screen.open_property_card)
	_screen.open_card(GameState.session.district)


func _on_changed() -> void:
	if GameState.session == null or GameState.session.city == _city_id:
		return
	var old := _city
	var index := old.get_index()
	remove_child(old)
	old.queue_free()
	_city = CITY_SCENE.instantiate()
	add_child(_city)
	move_child(_city, index)
	_attach_city()
