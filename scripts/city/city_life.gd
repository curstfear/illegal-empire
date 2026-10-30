extends Node3D
## Жизнь на улицах: машины по полосам, прохожие-чудики по тротуарам, полиция, герой.
## Двигаются по улицам сетки туда-обратно; доехав до края — появляются с другой стороны.
## Днём людно, ночью пусто. Полиции больше, когда растёт розыск и во время облавы.
## Машины твоих маршрутов (синие) ночью ездят по улицам между точками маршрута;
## когда открыта вкладка «Перевозки», маршруты видны синими линиями на земле.

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
## Машины маршрутов: модель по типу транспорта, синяя перекраска «твоё», часы, когда ездят.
const ROUTE_MODELS := { "scooter": "car_hatchback.gltf", "car": "car_sedan.gltf", "van": "car_stationwagon.gltf" }
const ROUTE_SCALE := { "scooter": 0.75, "car": 1.0, "van": 1.15 }
const ROUTE_COLOR := Color(0.184, 0.42, 1.0)
const ROUTE_LINE_WIDTH := 0.14
## Сколько игровых часов машина в пути после выезда (туда и обратно).
const ROUTE_TRIP_HOURS := 3.0
## Машина поставщика: оранжевый универсал, въезжает в город с края карты утром и уезжает за SUPPLY_TRIP_HOURS.
const SUPPLY_MODEL := "car_stationwagon.gltf"
const SUPPLY_COLOR := Color(0.98, 0.6, 0.2)
const SUPPLY_TRIP_HOURS := 2.0

@export var city: Node3D

## Всё движущееся: { "node": Node3D, "axis": "x"/"z", "dir": ±1, "speed": число, "kind": строка }.
var _movers: Array = []
var _hero: Chudik
var _rng := RandomNumberGenerator.new()
var _min: float
var _max: float
## Где проходят улицы (координата середины улицы).
var _road_positions: Array[float] = []
## Показывать линии маршрутов (ставит интерфейс, когда открыта вкладка «Перевозки»).
var show_route_lines := false:
	set(value):
		show_route_lines = value
		_route_lines.visible = value
## Машины маршрутов: { "node", "path": PackedVector3Array, "length", "distance", "dir" }.
var _route_cars: Array = []
var _route_lines := Node3D.new()
## Подпись маршрутов, по которой понимаем, что их пора перестроить.
var _routes_key := ""
var _line_material := StandardMaterial3D.new()


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
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(ROUTE_COLOR, 0.85)
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_route_lines.visible = show_route_lines
	add_child(_route_lines)
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
	_update_routes()


# --- Маршруты ---

## Перестроить машины и линии, если маршруты поменялись; машина едет в час своего рейса
## (днём или ночью) и за ROUTE_TRIP_HOURS проезжает туда и обратно.
func _update_routes() -> void:
	var s := GameState.session
	if s == null:
		return
	var key := ""
	for route: Dictionary in s.logistics.routes:
		key += "%d:%s:%s:%s;" % [route.id, s.logistics.get_vehicle(route.vehicle).get("type", ""), route.from, route.to]
	for contract: Dictionary in s.suppliers.contracts:
		key += "s%d:%s;" % [contract.id, contract.to]
	if key != _routes_key:
		_routes_key = key
		_rebuild_routes(s)
	var hour := Clock.hours_passed()
	for car: Dictionary in _route_cars:
		var node: Node3D = car.node
		var t := -1.0
		if car.has("supply"):
			var since := hour - float(s.balance.supply_hour) + SUPPLY_TRIP_HOURS / 2.0
			if since >= 0.0 and since < SUPPLY_TRIP_HOURS:
				t = since / SUPPLY_TRIP_HOURS
		else:
			var route := s.logistics.get_route(car.route)
			for shift: String in s.route_shifts(route) if not route.is_empty() else []:
				var since := hour - float(s.balance.route_shifts[shift].hour)
				if since >= 0.0 and since < ROUTE_TRIP_HOURS:
					t = since / ROUTE_TRIP_HOURS
		node.visible = t >= 0.0 and car.length > 0.0
		if not node.visible:
			continue
		# Первая половина пути — туда, вторая — обратно.
		var dir := 1.0 if t < 0.5 else -1.0
		car.distance = car.length * (t * 2.0 if t < 0.5 else 2.0 - t * 2.0)
		_put_on_path(node, car.path, car.distance, dir)


func _rebuild_routes(s: GameSession) -> void:
	for car: Dictionary in _route_cars:
		car.node.queue_free()
	_route_cars.clear()
	for child in _route_lines.get_children():
		child.queue_free()
	for route: Dictionary in s.logistics.routes:
		var path := road_path(_place_ground(s, route.from), _place_ground(s, route.to))
		_add_route_line(path)
		var type: String = s.logistics.get_vehicle(route.vehicle).get("type", "car")
		var node: Node3D = load(KAY + ROUTE_MODELS.get(type, "car_sedan.gltf")).instantiate()
		node.scale = Vector3.ONE * float(ROUTE_SCALE.get(type, 1.0))
		city.soften(node, ROUTE_COLOR, 0.55)
		add_child(node)
		_route_cars.append({ "node": node, "path": path, "length": _path_length(path),
				"distance": 0.0, "route": int(route.id) })
	# Поставщики въезжают с северного края карты по средней улице и в час доставки стоят у здания.
	var entry := Vector3(_road_positions[_road_positions.size() / 2], 0.06, _min)
	for contract: Dictionary in s.suppliers.contracts:
		if s.world.city_of(s.properties.get_def(contract.to).district) != s.city:
			continue
		var path := road_path(entry, city.property_ground(contract.to))
		var node: Node3D = load(KAY + SUPPLY_MODEL).instantiate()
		city.soften(node, SUPPLY_COLOR, 0.6)
		add_child(node)
		_route_cars.append({ "node": node, "path": path, "length": _path_length(path), "distance": 0.0, "supply": true })


## Точка на земле у места маршрута: здание или главное место района (рынок).
func _place_ground(s: GameSession, place: String) -> Vector3:
	if s.is_market_place(place):
		return city.district_ground_anchor(s.place_district(place))
	return city.property_ground(place)


## Путь по улицам от точки до точки: выезд на ближайшую улицу, не больше двух поворотов, съезд.
func road_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := _snap_to_road(from)
	var b := _snap_to_road(to)
	var pa: Vector3 = a.point
	var pb: Vector3 = b.point
	var path := PackedVector3Array([from, pa])
	if a.horizontal and not b.horizontal:
		path.append(Vector3(pb.x, pa.y, pa.z))
	elif not a.horizontal and b.horizontal:
		path.append(Vector3(pa.x, pa.y, pb.z))
	elif a.horizontal and not is_equal_approx(pa.z, pb.z):
		var cross := _nearest_road_position(pa.x)
		path.append(Vector3(cross, pa.y, pa.z))
		path.append(Vector3(cross, pa.y, pb.z))
	elif not a.horizontal and not is_equal_approx(pa.x, pb.x):
		var cross := _nearest_road_position(pa.z)
		path.append(Vector3(pa.x, pa.y, cross))
		path.append(Vector3(pb.x, pa.y, cross))
	path.append(pb)
	path.append(to)
	return path


## Ближайшая улица: вдоль X (horizontal) или вдоль Z, и точка на её середине.
func _snap_to_road(p: Vector3) -> Dictionary:
	var road_z := _nearest_road_position(p.z)
	var road_x := _nearest_road_position(p.x)
	if absf(p.z - road_z) <= absf(p.x - road_x):
		return { "horizontal": true, "point": Vector3(p.x, 0.06, road_z) }
	return { "horizontal": false, "point": Vector3(road_x, 0.06, p.z) }


func _nearest_road_position(value: float) -> float:
	var best: float = _road_positions[0]
	for road: float in _road_positions:
		if absf(road - value) < absf(best - value):
			best = road
	return best


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Поставить машину на путь: точка на расстоянии distance, своя полоса справа, нос по ходу.
func _put_on_path(node: Node3D, path: PackedVector3Array, distance: float, dir: float) -> void:
	var left := distance
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var segment := a.distance_to(b)
		if left > segment and i < path.size() - 1:
			left -= segment
			continue
		var forward := (b - a).normalized() * dir
		if forward == Vector3.ZERO:
			return
		var right := Vector3(-forward.z, 0, forward.x)
		node.position = a.lerp(b, clampf(left / maxf(segment, 0.001), 0.0, 1.0)) + right * LANE
		node.rotation.y = atan2(forward.x, forward.z)
		return


## Линия маршрута на земле: тонкие плоские полоски по отрезкам пути.
func _add_route_line(path: PackedVector3Array) -> void:
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(ROUTE_LINE_WIDTH, 0.02, length + ROUTE_LINE_WIDTH)
		strip.mesh = box
		strip.material_override = _line_material
		strip.position = (a + b) / 2.0 + Vector3(0, 0.05, 0)
		strip.rotation.y = atan2(b.x - a.x, b.z - a.z)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_route_lines.add_child(strip)


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
	city.soften(car)
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
