class_name GlobeView
extends SubViewportContainer
## 3D-глобус для мировой карты: тёмный шар с материками из светящихся точек, мягкое свечение атмосферы,
## города — светящиеся маркеры с подписями. Тянуть мышью или двумя пальцами — крутить, колесо или щипок —
## приближать; клик по городу — выбрать. Дуга перелёта идёт над поверхностью шара.

signal city_clicked(id: String)
signal city_hovered(id: String)

const FONT_BOLD := preload("res://assets/fonts/inter/Inter-SemiBold.otf")
const RADIUS := 1.0
const OCEAN := Color(0.07, 0.1, 0.18)
const LAND := Color(0.36, 0.48, 0.72)
const ATMOSPHERE := Color(0.3, 0.5, 1.0)
const ARC_COLOR := Color(0.45, 0.65, 1.0)
const TEX_W := 2048
const TEX_H := 1024
const DOT_STEP := 9
## Пределы: наклон (чтобы не перевернуть шар) и приближение камеры.
const PITCH_LIMIT := 70.0
const DIST_MIN := 1.8
const DIST_MAX := 5.0
const CLICK_RADIUS := 20.0

## Города: { id: { lat, lon, name, sub, color, here, selected, left } } (left — подпись слева от точки).
var cities: Dictionary = {}

var _viewport := SubViewport.new()
var _camera := Camera3D.new()
var _pivot := Node3D.new()
var _globe := Node3D.new()
var _markers: Dictionary = {}
var _arc := MeshInstance3D.new()
var _yaw := 0.0
var _pitch := 0.0
var _distance := 3.7
var _dragging := false
var _drag_moved := 0.0
var _hovered := ""


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.own_world_3d = true
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.8)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -35, 0)
	sun.light_energy = 0.9
	_viewport.add_child(sun)
	_viewport.add_child(_pivot)
	_pivot.add_child(_camera)
	_camera.fov = 35.0
	_viewport.add_child(_globe)
	_build_globe()
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_globe.add_child(_arc)
	_apply_camera()


## Шар с картинкой материков (точки нарисованы в текстуре) и полупрозрачное свечение вокруг.
func _build_globe() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var body := MeshInstance3D.new()
	body.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(_land_image())
	mat.roughness = 0.85
	mat.emission_enabled = true
	mat.emission_texture = mat.albedo_texture
	mat.emission_energy_multiplier = 0.55
	body.material_override = mat
	_globe.add_child(body)
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = RADIUS * 1.06
	halo_mesh.height = RADIUS * 2.12
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_front;
uniform vec4 tint : source_color;
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = rim * tint.a;
}
"""
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = shader
	halo_mat.set_shader_parameter("tint", Color(ATMOSPHERE, 0.9))
	halo.material_override = halo_mat
	_globe.add_child(halo)


## Картинка «долгота × широта»: тёмный океан, суша — сетка светлых точек.
func _land_image() -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(OCEAN)
	var polys: Array = []
	for flat: Array in WorldMap.LAND:
		var poly := PackedVector2Array()
		for i in range(0, flat.size(), 2):
			poly.append(Vector2(flat[i], flat[i + 1]))
		polys.append(poly)
	for y in range(DOT_STEP / 2, TEX_H, DOT_STEP):
		var lat := 90.0 - float(y) / TEX_H * 180.0
		# У полюсов точки по долготе реже, чтобы на шаре они не слипались.
		var step := maxi(DOT_STEP, roundi(DOT_STEP / maxf(0.2, cos(deg_to_rad(lat)))))
		for x in range(DOT_STEP / 2, TEX_W, step):
			var lon := float(x) / TEX_W * 360.0 - 180.0
			for poly: PackedVector2Array in polys:
				if Geometry2D.is_point_in_polygon(Vector2(lon, lat), poly):
					image.fill_rect(Rect2i(x - 2, y - 2, 4, 4), LAND)
					break
	return image


## Точка на поверхности шара по широте и долготе (так же, как SphereMesh раскладывает картинку).
static func to_vector(lat: float, lon: float, height: float = RADIUS) -> Vector3:
	var theta := deg_to_rad(lon + 180.0)
	var phi := deg_to_rad(lat)
	return Vector3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta)) * height


## Обновить города: создать маркеры, перекрасить, подписи.
func set_cities(list: Dictionary) -> void:
	cities = list
	for id: String in cities:
		if not _markers.has(id):
			_markers[id] = _make_marker()
		var info: Dictionary = cities[id]
		var marker: Node3D = _markers[id]
		var up := to_vector(float(info.lat), float(info.lon)).normalized()
		marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), up * RADIUS)
		var color: Color = info.color
		var dot: MeshInstance3D = marker.get_node("Dot")
		(dot.material_override as StandardMaterial3D).albedo_color = color
		(dot.material_override as StandardMaterial3D).emission = color
		var ring: MeshInstance3D = marker.get_node("Ring")
		ring.visible = info.here or info.selected or id == _hovered
		(ring.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.65, 1.0) if info.here else Color.WHITE
		var label: Label3D = marker.get_node("Label")
		label.text = "%s\n%s" % [info.name, info.sub]
		var left: bool = info.get("left", false)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		label.offset = Vector2(-22 if left else 22, 4)
		label.modulate = Color.WHITE if info.selected or id == _hovered else Color(0.85, 0.88, 0.95)


func _make_marker() -> Node3D:
	var marker := Node3D.new()
	var dot := MeshInstance3D.new()
	dot.name = "Dot"
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.022
	dot_mesh.height = 0.044
	dot.mesh = dot_mesh
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material_override = mat
	dot.position.y = 0.01
	marker.add_child(dot)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.036
	torus.outer_radius = 0.044
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.position.y = 0.005
	marker.add_child(ring)
	var label := Label3D.new()
	label.name = "Label"
	label.font = FONT_BOLD
	# Подпись одного размера на экране, как ни приближай.
	label.fixed_size = true
	label.font_size = 26
	label.pixel_size = 0.0006
	label.outline_size = 6
	label.outline_modulate = Color(0.05, 0.07, 0.12, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position.y = 0.04
	marker.add_child(label)
	_globe.add_child(marker)
	return marker


## Дуга перелёта по большому кругу, приподнятая над шаром (пусто — убрать).
func set_arc(from_id: String, to_id: String) -> void:
	if from_id == "" or to_id == "" or from_id == to_id or not cities.has(from_id) or not cities.has(to_id):
		_arc.mesh = null
		return
	var a := to_vector(float(cities[from_id].lat), float(cities[from_id].lon)).normalized()
	var b := to_vector(float(cities[to_id].lat), float(cities[to_id].lon)).normalized()
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ARC_COLOR
	var steps := 64
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for i in steps + 1:
		var t := float(i) / steps
		var height := RADIUS * (1.0 + 0.18 * sin(t * PI) * a.angle_to(b) / PI * 2.0)
		mesh.surface_add_vertex(a.slerp(b, t).normalized() * height)
	mesh.surface_end()
	_arc.mesh = mesh


## Повернуть глобус так, чтобы город смотрел на камеру.
func focus(id: String) -> void:
	if not cities.has(id):
		return
	_yaw = -(float(cities[id].lon) + 180.0)
	_pitch = clampf(float(cities[id].lat) * 0.8, -PITCH_LIMIT, PITCH_LIMIT)
	_apply_camera()


func _apply_camera() -> void:
	_globe.rotation_degrees = Vector3(0, _yaw, 0)
	_pivot.rotation_degrees = Vector3(-_pitch, 0, 0)
	_camera.position = Vector3(0, 0, _distance)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0:
					var hit := _city_at(button.position)
					if hit != "":
						city_clicked.emit(hit)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_drag_moved += motion.relative.length()
			_turn(motion.relative)
		var hit := _city_at(motion.position)
		if hit != _hovered:
			_hovered = hit
			city_hovered.emit(hit)
	elif event is InputEventPanGesture:
		_turn(-(event as InputEventPanGesture).delta * 8.0)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)


## Тянешь вправо — шар крутится вправо; чем ближе камера, тем медленнее.
func _turn(relative: Vector2) -> void:
	var speed := 0.25 * (_distance - RADIUS) / (3.7 - RADIUS)
	_yaw += relative.x * speed
	_pitch = clampf(_pitch + relative.y * speed, -PITCH_LIMIT, PITCH_LIMIT)
	_apply_camera()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, DIST_MIN, DIST_MAX)
	_apply_camera()


## Город под курсором: маркер на видимой стороне шара, ближе CLICK_RADIUS пикселей.
func _city_at(pos: Vector2) -> String:
	var best := ""
	var best_dist := CLICK_RADIUS
	var cam_pos := _camera.global_position
	for id: String in _markers:
		var world_pos: Vector3 = (_markers[id] as Node3D).global_position
		if world_pos.normalized().dot((cam_pos - world_pos).normalized()) <= 0.05:
			continue
		var screen := _camera.unproject_position(world_pos) * (size / Vector2(_viewport.size))
		var d := screen.distance_to(pos)
		if d < best_dist:
			best = id
			best_dist = d
	return best
