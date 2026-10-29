extends Node3D
## Город в 3D: собирается из модулей по data/city.json.
## Две улицы крест-накрест делят город на 4 района. Клик по кварталу выбирает район,
## наведение курсора подсвечивает район.
## Только картинка: про игру знает лишь, в каком районе сейчас игрок.

signal district_clicked(district: String)

## На сколько пикселей можно сдвинуть палец/мышь, чтобы это ещё считалось кликом.
const CLICK_SLOP := 8.0

const CITY_PATH := "res://data/city.json"
const MODELS := "res://assets/models/"
const KAY := MODELS + "kaykit_city/"
## Фонари: сколько света ночью и какого цвета.
const LAMP_COLOR := Color(1.0, 0.78, 0.5)

var streetlights: Array[OmniLight3D] = []
var neon_lights: Array[OmniLight3D] = []

var _data: Dictionary
var _size: int
var _road: int
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
## Подсветка земли района под курсором и подписи главных зданий по районам.
var _highlights: Dictionary = {}
var _main_tags: Dictionary = {}
var _hovered: String = ""
## Общие меши деревьев: [ствол, крона].
var _tree_meshes: Array = []

@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(CITY_PATH))
	_size = int(_data.size)
	_road = int(_data.road)
	_tile = float(_data.tile)
	_rng.seed = int(_data.seed)
	_build_ground()
	_build_roads()
	_build_pois()
	_build_districts()
	_build_markers()
	_build_highlights()
	camera_rig.target = _tile_center(_road, _road)


func _process(delta: float) -> void:
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
	var district := district_at_screen(event.position)
	if district != "":
		select(district)
		district_clicked.emit(district)
		get_viewport().set_input_as_handled()


## Район под точкой экрана: ближайшая «коробка» здания на луче от камеры.
## Если луч не задел ни одного здания — смотрим, на какую клетку земли он упал.
func district_at_screen(screen_pos: Vector2) -> String:
	var camera: Camera3D = camera_rig.camera
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var best := ""
	var best_distance := INF
	for entry: Array in _hit_boxes:
		var hit: Variant = (entry[0] as AABB).intersects_ray(origin, direction)
		if hit == null:
			continue
		var distance := origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = entry[1]
	if best != "" or absf(direction.y) < 0.0001:
		return best
	var ground := origin + direction * (-origin.y / direction.y)
	return district_at_tile(floori(ground.x / _tile + 0.5), floori(ground.z / _tile + 0.5))


func _set_hovered(district: String) -> void:
	if district == _hovered:
		return
	_hovered = district
	for id: String in _highlights:
		_highlights[id].visible = id == district
	for id: String in _main_tags:
		_main_tags[id].modulate = Color(1.0, 0.85, 0.35) if id == district else Color.WHITE
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if district != "" else Input.CURSOR_ARROW)


func district_at_tile(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= _size or r >= _size or c == _road or r == _road:
		return ""
	var quadrant := ("n" if r < _road else "s") + ("w" if c < _road else "e")
	for district: String in _data.quadrants:
		if _data.quadrants[district] == quadrant:
			return district
	return ""


func tile_size() -> float:
	return _tile


func road_index() -> int:
	return _road


func grid_size() -> int:
	return _size


## Где на тротуаре стоит герой, когда он в этом районе.
func district_ground_anchor(district: String) -> Vector3:
	return _ground_anchors.get(district, Vector3.ZERO)


## Тротуар у ближайшей улицы перед клеткой (главные здания стоят вплотную к улице).
func _sidewalk_in_front(c: int, r: int) -> Vector3:
	var pos := _tile_center(c, r)
	var toward := Vector3.ZERO
	if absi(r - _road) == 1:
		toward.z = signf(_road - r)
	else:
		toward.x = signf(_road - c)
	return pos + toward * (_tile / 2.0 + 0.15) + Vector3(0, 0.06, 0)


## Точка на экране над главным зданием района (для карточки).
func anchor_screen_position(district: String) -> Vector2:
	var camera: Camera3D = camera_rig.camera
	var anchor: Vector3 = _anchors.get(district, Vector3.ZERO)
	return camera.unproject_position(anchor + Vector3(0, 0.6, 0))


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
	add_child(node)
	return node


func _build_ground() -> void:
	var extent := _size * _tile
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent + 400.0, extent + 400.0)
	ground.mesh = plane
	ground.position = Vector3(extent / 2.0 - _tile / 2.0, -0.02, extent / 2.0 - _tile / 2.0)
	ground.material_override = _flat_material(Color(0.42, 0.45, 0.52))
	add_child(ground)


func _build_roads() -> void:
	for i in _size:
		if i == _road:
			_place(KAY + "road_junction.gltf", _tile_center(_road, _road))
			continue
		var crossing := i == _road - 1 or i == _road + 1
		var model := KAY + ("road_straight_crossing.gltf" if crossing else "road_straight.gltf")
		_place(model, _tile_center(_road, i))
		_place(model, _tile_center(i, _road), 90.0)
		# Фонари по обе стороны дорог, через клетку.
		if i % 2 == 0:
			_add_streetlight(_tile_center(_road, i) + Vector3(_tile * 0.42, 0, 0), 90.0)
			_add_streetlight(_tile_center(i, _road) + Vector3(0, 0, -_tile * 0.42), 0.0)


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
			neon.position = pos + Vector3(0, 0.6, _tile * 0.6)
			neon.light_color = Color(poi.neon[0], poi.neon[1], poi.neon[2])
			neon.omni_range = 4.0
			neon.light_energy = 0.0
			add_child(neon)
			neon_lights.append(neon)


func _build_districts() -> void:
	var taken := {}
	for poi: Dictionary in _data.pois:
		taken[Vector2i(int(poi.tile[0]), int(poi.tile[1]))] = true
	for r in _size:
		for c in _size:
			var district := district_at_tile(c, r)
			if district == "" or taken.has(Vector2i(c, r)):
				continue
			var pos := _tile_center(c, r)
			if district == "forest":
				_build_forest_tile(pos)
				_add_hit_box(pos, 1.5, district)
				continue
			var style: Dictionary = _data.styles[district]
			# Немного пустых площадок, чтобы кварталы дышали.
			if _rng.randf() < 0.12:
				_place(KAY + "base.gltf", pos)
				_place(KAY + ["bench.gltf", "dumpster.gltf", "watertower.gltf"][_rng.randi() % 3], pos, _rng.randi_range(0, 3) * 90.0, 1.5)
				_add_hit_box(pos, 0.6, district)
				continue
			if style.on_base:
				_place(KAY + "base.gltf", pos)
			var model: String = style.models[_rng.randi() % style.models.size()]
			# Здания смотрят фасадом на ближайшую улицу.
			var rot := 0.0
			if absi(r - _road) <= absi(c - _road):
				rot = 180.0 if r > _road else 0.0
			else:
				rot = -90.0 if c > _road else 90.0
			var node := _place(MODELS + model, pos, rot, float(style.scale))
			_add_hit_box(pos, _height_of(node) if node != null else 1.0, district)


## Невидимая «коробка» клетки для клика: вся клетка от земли до верха здания.
func _add_hit_box(pos: Vector3, height: float, district: String) -> void:
	var half := _tile / 2.0
	_hit_boxes.append([AABB(pos - Vector3(half, 0, half), Vector3(_tile, height, _tile)), district])


## Подсветка земли каждого района (видна в просветах между домами и на краях).
func _build_highlights() -> void:
	var span := _road * _tile
	for district: String in _data.quadrants:
		var quadrant: String = _data.quadrants[district]
		var first_c := 0 if quadrant.ends_with("w") else _road + 1
		var first_r := 0 if quadrant.begins_with("n") else _road + 1
		var plane := PlaneMesh.new()
		plane.size = Vector2(span, span)
		var quad := MeshInstance3D.new()
		quad.mesh = plane
		var corner := _tile_center(first_c, first_r) - Vector3(_tile / 2.0, 0, _tile / 2.0)
		quad.position = corner + Vector3(span / 2.0, 0.13, span / 2.0)
		var mat := _flat_material(Color(1.0, 0.85, 0.35, 0.22))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material_override = mat
		quad.visible = false
		add_child(quad)
		_highlights[district] = quad


func _build_forest_tile(pos: Vector3) -> void:
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_tile, _tile)
	grass.mesh = plane
	grass.position = pos + Vector3(0, 0.01, 0)
	grass.material_override = _flat_material(Color(0.36, 0.62, 0.38))
	add_child(grass)
	for i in _rng.randi_range(2, 3):
		var offset := Vector3(_rng.randf_range(-0.65, 0.65), 0, _rng.randf_range(-0.65, 0.65))
		_add_tree(pos + offset, _rng.randf_range(0.8, 1.3))


## Круглое дерево: ствол и шар-крона (в паках деревьев нет, позже можно сделать в Blender).
func _add_tree(pos: Vector3, size: float) -> void:
	if _tree_meshes.is_empty():
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.05
		trunk.bottom_radius = 0.07
		trunk.height = 0.45
		trunk.material = _flat_material(Color(0.5, 0.34, 0.24))
		var crown := SphereMesh.new()
		crown.radius = 0.32
		crown.height = 0.6
		crown.material = _flat_material(Color(0.3, 0.66, 0.42))
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
	var ring_mat := _flat_material(Color(1, 1, 1, 0.9))
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1, 1, 1)
	ring_mat.emission_energy_multiplier = 0.4
	_select_ring.material_override = ring_mat
	_select_ring.visible = false
	add_child(_select_ring)


func _add_name_tag(key: String, pos: Vector3) -> Label3D:
	var tag := Label3D.new()
	tag.text = key
	tag.position = pos
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.006
	tag.font_size = 48
	tag.outline_size = 16
	tag.modulate = Color(1, 1, 1)
	tag.outline_modulate = Color(0.05, 0.06, 0.1, 0.85)
	tag.no_depth_test = true
	add_child(tag)
	return tag


func _height_of(node: Node3D) -> float:
	var top := 0.0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
