extends Node
## Сцена партии: 3D-город и интерфейс поверх него.
## Связывает клики по городу с карточками и кнопки камеры с камерой.

@onready var _city: Node3D = $City
@onready var _screen: Control = $Hud/GameScreen


func _ready() -> void:
	_screen.city = _city
	_city.district_clicked.connect(_screen.open_card)
	_city.property_clicked.connect(_screen.open_property_card)
	var rig: Node3D = _city.camera_rig
	_screen.get_node("%RotateLeftButton").pressed.connect(rig.turn.bind(-90.0))
	_screen.get_node("%RotateRightButton").pressed.connect(rig.turn.bind(90.0))
	_screen.get_node("%ZoomOutButton").pressed.connect(rig.zoom_by.bind(1.25))
	_screen.get_node("%ZoomInButton").pressed.connect(rig.zoom_by.bind(0.8))
	_screen.open_card(GameState.session.district)
