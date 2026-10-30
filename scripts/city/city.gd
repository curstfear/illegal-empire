extends Node3D
## Город в 3D: собирается из модулей по data/city.json.
## Сетка улиц делит город на кварталы; центральные улицы делят его на 4 района.
## В кварталах — дома, площади, скверы и парковки. Клик по кварталу выбирает район,
## наведение курсора подсвечивает район.
## Только картинка: про игру знает лишь, в каком районе сейчас игрок и какие здания его.
## Вид — «воздушный», как в референсе: модели приглушены шейдером soft.gdshader, земля светлая,
## твои здания перекрашены в синий, над зданиями на продажу — булавки.

signal district_clicked(district: String)
## Клик по зданию, которое можно купить или арендовать (или уже твоё).
signal property_clicked(id: String)

## На сколько пикселей можно сдвинуть палец/мышь, чтобы это ещё считалось кликом.
const CLICK_SLOP := 8.0

const CITY_PATH := "res://data/city.json"
const MODELS := "res://assets/models/"
const KAY := MODELS + "kaykit_city/"
const IND := MODELS + "kenney_city_industrial/"
const SOFT_SHADER := preload("res://scenes/city/soft.gdshader")
## Цвета «воздушного» города.
const COLOR_GROUND := Color(0.9, 0.92, 0.95)
const COLOR_GRASS := Color(0.67, 0.88, 0.56)
const COLOR_WATER := Color(0.38, 0.68, 0.96)
const COLOR_CROWN := Color(0.36, 0.7, 0.38)
const COLOR_TRUNK := Color(0.6, 0.46, 0.36)
## Скругление внешних углов газона (доля клетки).
const LAWN_RADIUS := 0.4
const COLOR_MINE := Color(0.184, 0.42, 1.0)
const COLOR_FOR_SALE := Color(0.98, 0.6, 0.2)
## Фонари: сколько света ночью и какого цвета.
const LAMP_COLOR := Color(1.0, 0.78, 0.5)

var streetlights: Array[OmniLight3D] = []
var neon_lights: Array[OmniLight3D] = []

var _data: Dictionary
var _size: int
## Номера рядов/столбцов клеток, где идут улицы, и центральная улица (граница районов).
var _roads: Array[int] = []
var _center: int
var _tile: float
## Точка над главным зданием района — сюда крепится карточка.
var _anchors: Dictionary = {}
## Точка на тротуаре перед главным зданием района — тут стоит герой.
var _ground_anchors: Dictionary = {}
var _player_marker: MeshInstance3D
var _select_ring: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _press_position := Vector2.ZERO
## Невидимые «коробки» клеток для клика: [AABB, район]. Высота — как у здания.
var _hit_boxes: Array = []
## Здания на продажу (data/properties.json): подписи, булавки, модели и точки для карточки по id.
var _properties: Array = []
var _property_tags: Dictionary = {}
var _property_pins: Dictionary = {}
var _property_nodes: Dictionary = {}
var _property_anchors: Dictionary = {}
## Чьё здание было на прошлом кадре — перекрашиваем модель только при смене.
var _property_owned: Dictionary = {}
## Мягкие материалы: ключ «исходный материал + перекраска» → ShaderMaterial.
var _soft_materials: Dictionary = {}
## Общие меши булавок: [шар, конус].
var _pin_meshes: Array = []
## Подсветка земли района под курсором и подписи главных зданий по районам.
var _highlights: Dictionary = {}
var _main_tags: Dictionary = {}
## Рамки земель: по району — узел с полосками по краям, красится в цвет хозяина района.
var _turf_frames: Dictionary = {}
## Хозяин района на прошлом кадре — перекрашиваем рамку только при смене.
var _turf_owner: Dictionary = {}
var _tags: Array[MapTag] = []
## Слой подписей: поверх 3D, но под интерфейсом.
var _tag_layer := CanvasLayer.new()
var _hovered: String = ""
## Общие меши деревьев: [ствол, крона].
var _tree_meshes: Array = []
## Клетки газона (парки, лесопарк, пруды): рисуются одним сплошным полем в _build_lawns.
var _lawn: Dictionary = {}
## Общие материалы по цвету.
var _materials: Dictionary = {}

@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(CITY_PATH))
	_size = int(_data.size)
	for road: float in _data.roads:
		_roads.append(int(road))
	_center = int(_data.center)
	_tile = float(_data.tile)
	_rng.seed = int(_data.seed)
	_build_ground()
	_build_roads()
	_build_pois()
	_build_properties()
	_build_districts()
	_build_lawns()
	_build_ponds()
	_build_markers()
	_build_highlights()
	_build_turf_frames()
	camera_rig.target = _tile_center(_center, _center)


func _process(delta: float) -> void:
	_refresh_property_tags()
	_refresh_turf()
	# Подписи-плашки следуют за зданиями.
	for tag: MapTag in _tags:
		tag.follow(camera_rig.camera)
	# Маркер «ты здесь» висит над героем на тротуаре.
	if _player_marker != null and GameState.session != null:
		var anchor: Vector3 = _ground_anchors.get(GameState.session.district, Vector3.ZERO)
		_player_marker.position = anchor + Vector3(0, 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.08, 0)
		_player_marker.rotate_y(delta * 1.5)


## Клик (не перетаскивание) → район под курсором. Наведение → подсветка района.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask == 0:
			_set_hovered(district_at_screen(event.position))
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_position = event.position
		return
	if event.position.distance_to(_press_position) > CLICK_SLOP:
		return
	var picked := _pick(event.position)
	if picked[1] != "":
		select_property(picked[1])
		property_clicked.emit(picked[1])
		get_viewport().set_input_as_handled()
	elif picked[0] != "":
		select(picked[0])
		district_clicked.emit(picked[0])
		get_viewport().set_input_as_handled()


## Район под точкой экрана: ближайшая «коробка» здания на луче от камеры.
## Если луч не задел ни одного здания — смотрим, на какую клетку земли он упал.
func district_at_screen(screen_pos: Vector2) -> String:
	return _pick(screen_pos)[0]


## Что под точкой экрана: [район, id здания на продажу или ""].
func _pick(screen_pos: Vector2) -> Array:
	var camera: Camera3D = camera_rig.camera
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var best: Array = []
	var best_distance := INF
	# Здания на продажу важнее: если луч их задел, выбираем их, даже если перед ними деревья или дома.
	var best_property: Array = []
	var best_property_distance := INF
	for entry: Array in _hit_boxes:
		var hit: Variant = (entry[0] as AABB).intersects_ray(origin, direction)
		if hit == null:
			continue
		var distance := origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = entry
		if entry[2] != "" and distance < best_property_distance:
			best_property_distance = distance
			best_property = entry
	if not best_property.is_empty():
		return [best_property[1], best_property[2]]
	if not best.is_empty():
		return [best[1], best[2]]
	if absf(direction.y) < 0.0001:
		return ["", ""]
	var ground := origin + direction * (-origin.y / direction.y)
	return [district_at_tile(floori(ground.x / _tile + 0.5), floori(ground.z / _tile + 0.5)), ""]


func _set_hovered(district: String) -> void:
	if district == _hovered:
		return
	_hovered = district
	for id: String in _highlights:
		_highlights[id].visible = id == district
	for id: String in _main_tags:
		_main_tags[id].highlight(id == district)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if district != "" else Input.CURSOR_ARROW)


func district_at_tile(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= _size or r >= _size or _roads.has(c) or _roads.has(r):
		return ""
	var quadrant := ("n" if r < _center else "s") + ("w" if c < _center else "e")
	for district: String in _data.quadrants:
		if _data.quadrants[district] == quadrant:
			return district
	return ""


func tile_size() -> float:
	return _tile


func road_indices() -> Array[int]:
	return _roads


func grid_size() -> int:
	return _size


## Где на тротуаре стоит герой, когда он в этом районе.
func district_ground_anchor(district: String) -> Vector3:
	return _ground_anchors.get(district, Vector3.ZERO)


## Тротуар у ближайшей улицы перед клеткой (главные здания стоят вплотную к улице).
func _sidewalk_in_front(c: int, r: int) -> Vector3:
	return _tile_center(c, r) + _toward_road(c, r) * (_tile / 2.0 + 0.15) + Vector3(0, 0.06, 0)


## Направление от клетки к ближайшей улице (по одной оси).
func _toward_road(c: int, r: int) -> Vector3:
	var best_row := _nearest_road(r)
	var best_col := _nearest_road(c)
	if absi(best_row - r) <= absi(best_col - c):
		return Vector3(0, 0, signf(best_row - r))
	return Vector3(signf(best_col - c), 0, 0)


func _nearest_road(i: int) -> int:
	var best := _roads[0]
	for road in _roads:
		if absi(road - i) < absi(best - i):
			best = road
	return best


## Где на земле стоит здание (центр его клетки).
func property_ground(id: String) -> Vector3:
	var anchor: Vector3 = _property_anchors.get(id, Vector3.ZERO)
	return Vector3(anchor.x, 0.06, anchor.z)


## Точка на экране над главным зданием района (для карточки).
func anchor_screen_position(district: String) -> Vector2:
	var camera: Camera3D = camera_rig.camera
	var anchor: Vector3 = _anchors.get(district, Vector3.ZERO)
	return camera.unproject_position(anchor + Vector3(0, 0.6, 0))


## Точка на экране над зданием на продажу (для его карточки).
func property_anchor_screen_position(id: String) -> Vector2:
	var camera: Camera3D = camera_rig.camera
	return camera.unproject_position(_property_anchors.get(id, Vector3.ZERO) + Vector3(0, 0.6, 0))


func select_property(id: String) -> void:
	var anchor: Vector3 = _property_anchors[id]
	_select_ring.visible = true
	_select_ring.position = Vector3(anchor.x, 0.12, anchor.z)


## Подсветить выбранный район кольцом на земле.
func select(district: String) -> void:
	_select_ring.visible = district != ""
	if district != "":
		var anchor: Vector3 = _anchors[district]
		_select_ring.position = Vector3(anchor.x, 0.12, anchor.z)


# --- Сборка ---

func _tile_center(c: int, r: int) -> Vector3:
	return Vector3(c * _tile, 0, r * _tile)


func _place(path: String, pos: Vector3, rot_deg: float = 0.0, scale_k: float = 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Нет модели: %s" % path)
		return null
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.rotation_degrees.y = rot_deg
	node.scale = Vector3.ONE * scale_k
	soften(node)
	add_child(node)
	return node


## Приглушить цвета модели (и перекрасить, если tint_amount > 0). Материалы общие для одинаковых исходников.
func soften(node: Node3D, tint: Color = Color.WHITE, tint_amount: float = 0.0) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i)
			if not source is StandardMaterial3D:
				continue
			var key := "%d|%s|%.2f" % [source.get_instance_id(), tint.to_html(), tint_amount]
			if not _soft_materials.has(key):
				var soft := ShaderMaterial.new()
				soft.shader = SOFT_SHADER
				soft.set_shader_parameter("albedo_tex", (source as StandardMaterial3D).albedo_texture)
				soft.set_shader_parameter("albedo_color", (source as StandardMaterial3D).albedo_color)
				soft.set_shader_parameter("tint", tint)
				soft.set_shader_parameter("tint_amount", tint_amount)
				_soft_materials[key] = soft
			mesh.set_surface_override_material(i, _soft_materials[key])


func _build_ground() -> void:
	var extent := _size * _tile
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent + 400.0, extent + 400.0)
	ground.mesh = plane
	ground.position = Vector3(extent / 2.0 - _tile / 2.0, -0.02, extent / 2.0 - _tile / 2.0)
	ground.material_override = _flat_material(COLOR_GROUND)
	add_child(ground)


## Улицы: перекрёстки, рядом с ними — пешеходные переходы, между ними — прямые куски.
func _build_roads() -> void:
	for r in _size:
		for c in _size:
			var on_col := _roads.has(c)
			var on_row := _roads.has(r)
			if not on_col and not on_row:
				continue
			var pos := _tile_center(c, r)
			if on_col and on_row:
				_place(KAY + "road_junction.gltf", pos)
				continue
			# Вдоль столбца улица идёт по Z, вдоль ряда — по X.
			var along := r if on_col else c
			var crossing := _roads.has(along - 1) or _roads.has(along + 1)
			var model := KAY + ("road_straight_crossing.gltf" if crossing else "road_straight.gltf")
			_place(model, pos, 0.0 if on_col else 90.0)
			# Фонари через клетку, по очереди на разных сторонах улицы.
			if along % 2 == 0 and not crossing:
				var side := 1.0 if along % 4 == 0 else -1.0
				if on_col:
					_add_streetlight(pos + Vector3(side * _tile * 0.42, 0, 0), 90.0 * side)
				else:
					_add_streetlight(pos + Vector3(0, 0, side * _tile * 0.42), 90.0 - 90.0 * side)


func _add_streetlight(pos: Vector3, rot_deg: float) -> void:
	_place(KAY + "streetlight.gltf", pos, rot_deg, 1.2)
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0, 1.15, 0)
	lamp.light_color = LAMP_COLOR
	lamp.omni_range = 3.2
	lamp.light_energy = 0.0
	add_child(lamp)
	streetlights.append(lamp)


func _build_pois() -> void:
	for poi: Dictionary in _data.pois:
		var pos := _tile_center(int(poi.tile[0]), int(poi.tile[1]))
		if not String(poi.model).begins_with("kaykit_city/building"):
			_place(KAY + "base.gltf", pos)
		var node := _place(MODELS + poi.model, pos, float(poi.rot), float(poi.scale))
		var height := _height_of(node) if node != null else 1.0
		if poi.get("main", false):
			_anchors[poi.district] = pos + Vector3(0, height, 0)
			_ground_anchors[poi.district] = _sidewalk_in_front(int(poi.tile[0]), int(poi.tile[1]))
		var tag := _add_name_tag(poi.name_key, pos + Vector3(0, height + 0.35, 0))
		if poi.get("main", false):
			_main_tags[poi.district] = tag
		# Подпись над зданием тоже кликабельна — коробка выше здания.
		_add_hit_box(pos, maxf(height, 1.0) + 0.8, poi.district)
		if poi.has("neon"):
			var neon := OmniLight3D.new()
			neon.position = pos + _toward_road(int(poi.tile[0]), int(poi.tile[1])) * _tile * 0.6 + Vector3(0, 0.6, 0)
			neon.light_color = Color(poi.neon[0], poi.neon[1], poi.neon[2])
			neon.omni_range = 4.0
			neon.light_energy = 0.0
			add_child(neon)
			neon_lights.append(neon)


## Кварталы: часть клеток — дома (доля = density стиля района), остальное — открытые места.
func _build_districts() -> void:
	var taken := {}
	for poi: Dictionary in _data.pois + _properties:
		taken[Vector2i(int(poi.tile[0]), int(poi.tile[1]))] = true
	var pond := {}
	for tile: Array in _data.pond:
		pond[Vector2i(int(tile[0]), int(tile[1]))] = true
	for r in _size:
		for c in _size:
			var district := district_at_tile(c, r)
			if district == "" or taken.has(Vector2i(c, r)):
				continue
			var pos := _tile_center(c, r)
			if pond.has(Vector2i(c, r)):
				_build_pond_tile(pos)
				_add_hit_box(pos, 0.3, district)
				continue
			var style: Dictionary = _data.styles[district]
			if _rng.randf() >= float(style.density):
				_add_hit_box(pos, _build_open_tile(pos, district, c, r), district)
				continue
			if style.on_base:
				_place(KAY + "base.gltf", pos)
			var model: String = style.models[_rng.randi() % style.models.size()]
			# Здания смотрят фасадом на ближайшую улицу.
			var facing := _toward_road(c, r)
			var rot := rad_to_deg(atan2(facing.x, facing.z))
			var node := _place(MODELS + model, pos, rot, float(style.scale))
			_add_hit_box(pos, _height_of(node) if node != null else 1.0, district)


## Открытая клетка: площадь, сквер или парковка (в лесопарке — луг с деревьями).
## Возвращает высоту для «коробки» клика.
func _build_open_tile(pos: Vector3, district: String, c: int, r: int) -> float:
	if district == "forest":
		_build_park_tile(pos, _rng.randi_range(1, 4))
		return 1.5
	var weights: Dictionary = _data.open_space
	var roll := _rng.randf()
	if roll < float(weights.plaza):
		_place(KAY + "base.gltf", pos)
		var facing := _toward_road(c, r)
		_place(KAY + "bench.gltf", pos - facing * 0.4, rad_to_deg(atan2(facing.x, facing.z)), 1.6)
		_add_tree(pos + Vector3(0.55, 0, 0.55), 0.8)
		_add_tree(pos + Vector3(-0.55, 0, -0.55), 0.7)
		return 0.8
	if roll < float(weights.plaza) + float(weights.park):
		_build_park_tile(pos, _rng.randi_range(1, 2))
		return 1.2
	# Парковка: пара машин бок о бок.
	_place(KAY + "base.gltf", pos)
	var cars := ["car_sedan.gltf", "car_hatchback.gltf", "car_stationwagon.gltf", "car_taxi.gltf"]
	for x in [-0.4, 0.4]:
		if _rng.randf() < 0.8:
			_place(KAY + cars[_rng.randi() % cars.size()], pos + Vector3(x, 0.05, 0), 0.0 if _rng.randf() < 0.5 else 180.0)
	return 0.5


## Невидимая «коробка» клетки для клика: вся клетка от земли до верха здания.
func _add_hit_box(pos: Vector3, height: float, district: String, property_id: String = "") -> void:
	var half := _tile / 2.0
	_hit_boxes.append([AABB(pos - Vector3(half, 0, half), Vector3(_tile, height, _tile)), district, property_id])


## Здания на продажу: модель, подпись «Продаётся»/«Твоё», своя «коробка» для клика.
func _build_properties() -> void:
	_properties = GameData.load_properties()
	for prop: Dictionary in _properties:
		var c := int(prop.tile[0])
		var r := int(prop.tile[1])
		var pos := _tile_center(c, r)
		if not String(prop.model).begins_with("kaykit_city/building"):
			_place(KAY + "base.gltf", pos)
		var facing := _toward_road(c, r)
		var node := _place(MODELS + prop.model, pos, rad_to_deg(atan2(facing.x, facing.z)), float(prop.scale))
		var height := _height_of(node) if node != null else 1.0
		_property_nodes[prop.id] = node
		_property_anchors[prop.id] = pos + Vector3(0, height, 0)
		_property_pins[prop.id] = _add_pin(pos + Vector3(0, height + 0.25, 0))
		_property_tags[prop.id] = _add_name_tag("", pos + Vector3(0, height + 1.85, 0), true)
		_add_hit_box(pos, maxf(height, 1.0) + 1.2, prop.district, prop.id)
		# У складов — контейнеры во дворе, как паллеты у склада в референсе.
		if prop.kind == "warehouse":
			var side := Vector3(facing.z, 0, facing.x)
			for k in 3:
				var model := IND + "shipping-container-%s.glb" % ["a", "b", "c"][k]
				_place(model, pos + facing * 0.75 + side * (0.85 - k * 0.4), 90.0 + rad_to_deg(atan2(facing.x, facing.z)), 1.0)


## Булавки и подписи зданий: на продажу — оранжевая булавка и «название · цена», твоё — синяя булавка
## с названием и синяя перекраска модели. Булавки слегка покачиваются.
func _refresh_property_tags() -> void:
	if GameState.session == null:
		return
	var bob := sin(Time.get_ticks_msec() / 400.0) * 0.06
	for id: String in _property_tags:
		var tag: MapTag = _property_tags[id]
		var mine: bool = GameState.session.properties.is_mine(id)
		var def := GameState.session.properties.get_def(id)
		tag.set_text(tr(def.name_key) if mine else tr("PROP_FOR_SALE_TAG") % [tr(def.name_key), _money_text(int(def.buy_price))])
		tag.set_dot(COLOR_MINE if mine else COLOR_FOR_SALE)
		var pin: Node3D = _property_pins[id]
		pin.position.y = _property_anchors[id].y + 0.25 + bob
		var color := COLOR_MINE if mine else COLOR_FOR_SALE
		(pin.get_child(0) as MeshInstance3D).material_override = _pin_material(color)
		(pin.get_child(1) as MeshInstance3D).material_override = _pin_material(color)
		if _property_owned.get(id, false) != mine and _property_nodes[id] != null:
			_property_owned[id] = mine
			soften(_property_nodes[id], COLOR_MINE, 0.7 if mine else 0.0)


## 1500 → «1 500».
static func _money_text(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = " " + digits.right(3) + result
		digits = digits.left(-3)
	return digits + result


## Булавка на карте: шар на острие вниз, как метки в референсе.
func _add_pin(pos: Vector3) -> Node3D:
	if _pin_meshes.is_empty():
		var head := SphereMesh.new()
		head.radius = 0.22
		head.height = 0.44
		var tip := CylinderMesh.new()
		tip.top_radius = 0.17
		tip.bottom_radius = 0.0
		tip.height = 0.36
		_pin_meshes = [head, tip]
	var pin := Node3D.new()
	pin.position = pos
	pin.scale = Vector3.ONE * 1.8
	var head_node := MeshInstance3D.new()
	head_node.mesh = _pin_meshes[0]
	head_node.position.y = 0.5
	pin.add_child(head_node)
	var tip_node := MeshInstance3D.new()
	tip_node.mesh = _pin_meshes[1]
	tip_node.position.y = 0.26
	pin.add_child(tip_node)
	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot.mesh = dot_mesh
	dot.position = Vector3(0, 0.52, 0.16)
	dot.material_override = _pin_material(Color.WHITE)
	pin.add_child(dot)
	add_child(pin)
	return pin


func _pin_material(color: Color) -> StandardMaterial3D:
	var key := "pin" + color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.4
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.25
		_materials[key] = mat
	return _materials[key]


## Подсветка земли каждого района (видна в просветах между домами и на краях).
func _build_highlights() -> void:
	var span := _center * _tile
	for district: String in _data.quadrants:
		var quadrant: String = _data.quadrants[district]
		var first_c := 0 if quadrant.ends_with("w") else _center + 1
		var first_r := 0 if quadrant.begins_with("n") else _center + 1
		var plane := PlaneMesh.new()
		plane.size = Vector2(span, span)
		var quad := MeshInstance3D.new()
		quad.mesh = plane
		var corner := _tile_center(first_c, first_r) - Vector3(_tile / 2.0, 0, _tile / 2.0)
		quad.position = corner + Vector3(span / 2.0, 0.13, span / 2.0)
		var mat := _flat_material(Color(0.184, 0.42, 1.0, 0.1))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material_override = mat
		quad.visible = false
		add_child(quad)
		_highlights[district] = quad


## Рамка земель каждого района: тонкие полоски у краёв четверти (на тротуарах), цвет — хозяин района.
func _build_turf_frames() -> void:
	var span := _center * _tile
	var inset := _tile * 0.3
	var width := 0.14
	for district: String in _data.quadrants:
		var quadrant: String = _data.quadrants[district]
		var first_c := 0 if quadrant.ends_with("w") else _center + 1
		var first_r := 0 if quadrant.begins_with("n") else _center + 1
		var corner := _tile_center(first_c, first_r) - Vector3(_tile / 2.0, 0, _tile / 2.0)
		var middle := corner + Vector3(span / 2.0, 0.14, span / 2.0)
		var frame := Node3D.new()
		var long := span - inset * 2.0
		for side: Array in [[Vector3(0, 0, -1), true], [Vector3(0, 0, 1), true], [Vector3(-1, 0, 0), false], [Vector3(1, 0, 0), false]]:
			var plane := PlaneMesh.new()
			plane.size = Vector2(long, width) if side[1] else Vector2(width, long)
			var strip := MeshInstance3D.new()
			strip.mesh = plane
			strip.position = middle + (side[0] as Vector3) * (span / 2.0 - inset)
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			frame.add_child(strip)
		frame.visible = false
		add_child(frame)
		_turf_frames[district] = frame


## Рамки земель и точки на подписях районов: цвет банды-хозяина, синий — твой район, без цвета — ничей.
func _refresh_turf() -> void:
	if GameState.session == null:
		return
	var gangs := GameState.session.gangs
	for district: String in _turf_frames:
		var who := gangs.owner(district)
		if _turf_owner.get(district, "-") == who:
			continue
		_turf_owner[district] = who
		var frame: Node3D = _turf_frames[district]
		frame.visible = who != ""
		var color := Color(0, 0, 0, 0)
		if who == Gangs.PLAYER:
			color = COLOR_MINE
		elif who != "":
			color = gangs.color(who)
		if frame.visible:
			var mat := _flat_material(Color(color, 0.75))
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for strip: MeshInstance3D in frame.get_children():
				strip.material_override = mat
		if _main_tags.has(district):
			_main_tags[district].set_dot(color)


## Газон с деревьями (сама трава — в _build_lawns, чтобы соседние клетки слились).
func _build_park_tile(pos: Vector3, trees: int) -> void:
	_lawn[Vector2i(roundi(pos.x / _tile), roundi(pos.z / _tile))] = true
	for i in trees:
		var offset := Vector3(_rng.randf_range(-0.65, 0.65), 0, _rng.randf_range(-0.65, 0.65))
		_add_tree(pos + offset, _rng.randf_range(0.8, 1.3))


## Клетка пруда: под водой — газон (вода рисуется целиком в _build_ponds).
func _build_pond_tile(pos: Vector3) -> void:
	_lawn[Vector2i(roundi(pos.x / _tile), roundi(pos.z / _tile))] = true


## Сплошной газон: каждая клетка — во всю ширину, скруглены только внешние углы
## (где по обеим сторонам угла газона нет). Так парк — одно поле с мягкими краями.
func _build_lawns() -> void:
	var r := _tile * LAWN_RADIUS
	for tile: Vector2i in _lawn:
		var radii := []
		for corner: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
			var open := not _lawn.has(tile + Vector2i(corner.x, 0)) and not _lawn.has(tile + Vector2i(0, corner.y))
			radii.append(r if open else 0.0)
		_add_rounded(_tile_center(tile.x, tile.y), Vector2.ONE * _tile, 0.0, COLOR_GRASS, radii)


## Пруды: каждая группа соседних клеток — одна скруглённая гладь на газоне.
func _build_ponds() -> void:
	var left := {}
	for tile: Array in _data.pond:
		left[Vector2i(int(tile[0]), int(tile[1]))] = true
	while not left.is_empty():
		var first: Vector2i = left.keys()[0]
		var group: Array[Vector2i] = [first]
		left.erase(first)
		var i := 0
		while i < group.size():
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = group[i] + step
				if left.has(next):
					left.erase(next)
					group.append(next)
			i += 1
		var lo := group[0]
		var hi := group[0]
		for tile in group:
			lo = Vector2i(mini(lo.x, tile.x), mini(lo.y, tile.y))
			hi = Vector2i(maxi(hi.x, tile.x), maxi(hi.y, tile.y))
		var center := (_tile_center(lo.x, lo.y) + _tile_center(hi.x, hi.y)) / 2.0
		var size := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1) * _tile - Vector2.ONE * _tile * 0.35
		var water := _add_rounded(center + Vector3(0, 0.01, 0), size, minf(size.x, size.y) * 0.4, COLOR_WATER)
		var mat: StandardMaterial3D = water.material_override
		mat.roughness = 0.12
		mat.metallic_specular = 0.9


## Плоская скруглённая плашка на земле (газон, вода): прямоугольник со скруглёнными углами.
## corner_radii — свой радиус для каждого угла (+x+z, −x+z, −x−z, +x−z); иначе у всех radius.
func _add_rounded(pos: Vector3, size: Vector2, radius: float, color: Color, corner_radii: Array = []) -> MeshInstance3D:
	var limit := minf(size.x, size.y) / 2.0
	var outline := PackedVector3Array()
	var signs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for k in 4:
		var corner_r: float = minf(corner_radii[k] if not corner_radii.is_empty() else radius, limit)
		var center: Vector2 = signs[k] * (size / 2.0 - Vector2.ONE * corner_r)
		for j in 9:
			var angle := (k + j / 8.0) * PI / 2.0
			var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * corner_r
			outline.append(Vector3(p.x, 0, p.y))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for k in outline.size():
		vertices.append_array([Vector3.ZERO, outline[(k + 1) % outline.size()], outline[k]])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos + Vector3(0, 0.012, 0)
	node.material_override = _flat_material(color)
	add_child(node)
	return node


## Плоская цветная клетка (газон, вода).
func _add_flat(pos: Vector3, color: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(_tile, _tile)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.position = pos + Vector3(0, 0.01, 0)
	node.material_override = _flat_material(color)
	add_child(node)
	return node


## Круглое дерево: ствол и шар-крона (в паках деревьев нет, позже можно сделать в Blender).
func _add_tree(pos: Vector3, size: float) -> void:
	if _tree_meshes.is_empty():
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.05
		trunk.bottom_radius = 0.07
		trunk.height = 0.45
		trunk.material = _flat_material(COLOR_TRUNK)
		var crown := SphereMesh.new()
		crown.radius = 0.32
		crown.height = 0.6
		crown.material = _flat_material(COLOR_CROWN)
		_tree_meshes = [trunk, crown]
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * size
	var trunk_node := MeshInstance3D.new()
	trunk_node.mesh = _tree_meshes[0]
	trunk_node.position.y = 0.22
	tree.add_child(trunk_node)
	var crown_node := MeshInstance3D.new()
	crown_node.mesh = _tree_meshes[1]
	crown_node.position.y = 0.62
	tree.add_child(crown_node)
	add_child(tree)


func _build_markers() -> void:
	# Маркер «ты здесь» над районом игрока.
	_player_marker = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.3, 0.32, 0.3)
	_player_marker.mesh = prism
	_player_marker.rotation_degrees.x = 180.0
	var marker_mat := _flat_material(Color(0.91, 0.23, 0.27))
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.91, 0.23, 0.27)
	marker_mat.emission_energy_multiplier = 0.6
	_player_marker.material_override = marker_mat
	add_child(_player_marker)
	# Кольцо выбранного района.
	_select_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.25
	torus.outer_radius = 1.4
	torus.rings = 48
	_select_ring.mesh = torus
	_select_ring.scale = Vector3(1, 0.05, 1)
	var ring_mat := _flat_material(Color(0.184, 0.42, 1.0, 0.85))
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.184, 0.42, 1.0)
	ring_mat.emission_energy_multiplier = 0.4
	_select_ring.material_override = ring_mat
	_select_ring.visible = false
	add_child(_select_ring)


## Подпись-плашка над зданием (см. MapTag); у твоих зданий — с синей точкой.
func _add_name_tag(key: String, pos: Vector3, mine: bool = false) -> MapTag:
	if _tag_layer.get_parent() == null:
		_tag_layer.layer = 0
		add_child(_tag_layer)
	var tag := MapTag.new(key, pos, mine)
	_tag_layer.add_child(tag)
	_tags.append(tag)
	return tag


func _height_of(node: Node3D) -> float:
	var top := 0.0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


## Материал одного цвета; одинаковые цвета делят один материал (газоны, вода, деревья).
func _flat_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	_materials[key] = mat
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
