extends Node3D
## Жизнь на улицах: машины по полосам, прохожие-чудики по тротуарам, полиция, герой.
## Двигаются по улицам сетки туда-обратно; доехав до края — появляются с другой стороны.
## Днём людно, ночью пусто. Полиции больше, когда растёт розыск и во время облавы.

const KAY := "res://assets/models/kaykit_city/"
const CAR_MODELS := ["car_hatchback.gltf", "car_sedan.gltf", "car_stationwagon.gltf", "car_taxi.gltf"]
const PEOPLE_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.9), Color(0.95, 0.55, 0.25), Color(0.4, 0.75, 0.45), Color(0.85, 0.35, 0.55),
	Color(0.6, 0.45, 0.85), Color(0.95, 0.8, 0.3), Color(0.35, 0.7, 0.75), Color(0.55, 0.55, 0.6),
]
const HERO_COLOR := Color(0.91, 0.23, 0.27)
const POLICE_COLOR := Color(0.18, 0.28, 0.62)

const CARS := 20
const PEOPLE := 56
const POLICE_CARS_MAX := 4
const POLICE_WALKERS_MAX := 4
## Смещение полос и тротуаров от середины улицы (в метрах; улица шириной 2).
const LANE := 0.42
const SIDEWALK := 0.86
const CAR_SPEED := 2.2
const WALK_SPEED := 0.45
const PERSON_SCALE := 1.05

@export var city: Node3D

## Всё движущееся: { "node": Node3D, "axis": "x"/"z", "dir": ±1, "speed": число, "kind": строка }.
var _movers: Array = []
var _hero: Chudik
var _rng := RandomNumberGenerator.new()
var _min: float
var _max: float
## Где проходят улицы (координата середины улицы).
var _road_positions: Array[float] = []


func _ready() -> void:
	# Город строится в своём _ready, а он срабатывает после нашего — ждём.
	set_process(false)
	if not city.is_node_ready():
		await city.ready
	_rng.seed = 11
	var tile: float = city.tile_size()
	for road: int in city.road_indices():
		_road_positions.append(road * tile)
	_min = -tile / 2.0
	_max = (city.grid_size() - 0.5) * tile
	for i in CARS:
		_spawn_car(KAY + CAR_MODELS[i % CAR_MODELS.size()], "car")
	for i in POLICE_CARS_MAX:
		_spawn_car(KAY + "car_police.gltf", "police_car")
	for i in PEOPLE:
		_spawn_person(PEOPLE_COLORS[i % PEOPLE_COLORS.size()], false, "person")
	for i in POLICE_WALKERS_MAX:
		_spawn_person(POLICE_COLOR, true, "police")
	_hero = Chudik.new()
	_hero.body_color = HERO_COLOR
	_hero.walking = false
	_hero.scale = Vector3.ONE * PERSON_SCALE * 1.15
	add_child(_hero)
	set_process(true)


func _process(delta: float) -> void:
	var visible_people := _people_share()
	var police_count := _police_count()
	var people_index := 0
	var police_car_index := 0
	var police_walker_index := 0
	for mover: Dictionary in _movers:
		var node: Node3D = mover.node
		match mover.kind:
			"person":
				node.visible = people_index < roundi(PEOPLE * visible_people)
				people_index += 1
			"police_car":
				node.visible = police_car_index < police_count
				police_car_index += 1
			"police":
				node.visible = police_walker_index < police_count
				police_walker_index += 1
		if not node.visible:
			continue
		var step: float = mover.dir * mover.speed * delta
		if mover.axis == "x":
			node.position.x = _wrap(node.position.x + step)
		else:
			node.position.z = _wrap(node.position.z + step)
	_place_hero()


## Сколько прохожих на улицах (0…1) по времени суток: днём все, ночью почти никого.
func _people_share() -> float:
	var hour := Clock.minutes_of_day() / 60.0
	if hour >= 8.0 and hour < 20.0:
		return 1.0
	if hour >= 22.0 or hour < 5.0:
		return 0.15
	return 0.5


## Сколько полицейских машин и пеших патрулей: 1 всегда, +1 за каждые 2 звезды розыска, +2 в облаву.
func _police_count() -> int:
	var s := GameState.session
	if s == null:
		return 1
	var count := 1 + floori(s.police.max_heat() / 40.0)
	if s.events.today.get("id", "") == "city_raid":
		count += 2
	return mini(count, POLICE_CARS_MAX)


## Герой стоит у главного здания района, где сейчас игрок.
func _place_hero() -> void:
	if GameState.session == null:
		return
	var anchor: Vector3 = city.district_ground_anchor(GameState.session.district)
	_hero.position = anchor
	_hero.look_at(anchor + Vector3(1, 0, 1), Vector3.UP, true)


func _spawn_car(path: String, kind: String) -> void:
	var car: Node3D = load(path).instantiate()
	var lane := _random_lane(LANE)
	car.position = lane.position
	# Машины KayKit смотрят вдоль оси Z.
	car.rotation.y = _heading(lane.axis, lane.dir)
	add_child(car)
	_movers.append({ "node": car, "axis": lane.axis, "dir": lane.dir,
			"speed": CAR_SPEED * _rng.randf_range(0.8, 1.2), "kind": kind })


func _spawn_person(color: Color, is_police: bool, kind: String) -> void:
	var person := Chudik.new()
	person.body_color = color
	person.police = is_police
	person.scale = Vector3.ONE * PERSON_SCALE
	var lane := _random_lane(SIDEWALK)
	person.position = lane.position
	person.rotation.y = _heading(lane.axis, lane.dir)
	add_child(person)
	_movers.append({ "node": person, "axis": lane.axis, "dir": lane.dir,
			"speed": WALK_SPEED * _rng.randf_range(0.8, 1.25), "kind": kind })


## Случайное место на одной из улиц: ось, направление и стартовая точка.
## Правостороннее движение: полоса зависит от направления.
func _random_lane(offset: float) -> Dictionary:
	var axis := "x" if _rng.randf() < 0.5 else "z"
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var along := _rng.randf_range(_min, _max)
	var side := offset * dir
	var road: float = _road_positions[_rng.randi() % _road_positions.size()]
	var pos := Vector3(along, 0.06, road + side) if axis == "x" else Vector3(road - side, 0.06, along)
	return { "axis": axis, "dir": dir, "position": pos }


## Поворот по Y, чтобы модель смотрела вдоль движения (модели смотрят в +Z).
func _heading(axis: String, dir: float) -> float:
	if axis == "x":
		return PI / 2.0 if dir > 0 else -PI / 2.0
	return 0.0 if dir > 0 else PI


func _wrap(value: float) -> float:
	var length := _max - _min
	return _min + fposmod(value - _min, length)
