extends Node3D
## Служебная сцена: пробный квартал из скачанных моделей, чтобы утвердить стиль.
## Godot --path . res://tests/style_preview.tscn -- <папка_для_png>

const KAY := "res://assets/models/kaykit_city/"
const ROADS := "res://assets/models/kenney_city_roads/"
const SHOP := "res://assets/models/kenney_city_commercial/"
const CARS := "res://assets/models/kenney_cars/"


func _ready() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	_print_sizes()
	_build_block()
	_setup_scene()
	await _frames(20)
	_shot(out_dir.path_join("style_day.png"))
	_set_night()
	await _frames(20)
	_shot(out_dir.path_join("style_night.png"))
	get_tree().quit()


## Размеры моделей — чтобы понять масштаб паков относительно друг друга.
func _print_sizes() -> void:
	for path in [KAY + "building_A.gltf", KAY + "road_straight.gltf", KAY + "car_sedan.gltf",
			ROADS + "road-straight.glb", SHOP + "building-a.glb", CARS + "sedan.glb", CARS + "police.glb"]:
		if not ResourceLoader.exists(path):
			print("нет файла: ", path)
			continue
		var node: Node3D = load(path).instantiate()
		print(path.get_file(), " размер: ", _aabb(node).size)
		node.free()


func _build_block() -> void:
	# Квартал KayKit: здания на своих основаниях, сетка 2×2 метра.
	var kay_buildings := ["building_A", "building_B", "building_C", "building_D", "building_E", "building_F", "building_G", "building_H"]
	for i in kay_buildings.size():
		_place(KAY + kay_buildings[i] + ".gltf", Vector3((i % 4) * 2.0, 0, (i / 4) * 2.0))
	for x in 4:
		_place(KAY + "road_straight.gltf", Vector3(x * 2.0, 0, 4.0))
	_place(KAY + "car_police.gltf", Vector3(2.0, 0, 4.0))
	_place(KAY + "car_sedan.gltf", Vector3(5.6, 0, 4.0), PI)
	for x in 4:
		_place(KAY + "base.gltf", Vector3(x * 2.0, 0, 6.0))
	_place(KAY + "bench.gltf", Vector3(1.0, 0, 6.0))
	_place(KAY + "bush.gltf", Vector3(3.0, 0, 6.0))
	# Рядом — то же из Kenney, для сравнения масштаба и стиля.
	for i in 4:
		_place(SHOP + ["building-a", "building-c", "building-e", "building-g"][i] + ".glb", Vector3(-3.0, 0, i * 2.0), 0.0, 2.0)
	_place(CARS + "taxi.glb", Vector3(-1.2, 0, 7.0), 0.0, 0.6)


func _place(path: String, pos: Vector3, rot_y: float = 0.0, scale_k: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		print("нет файла: ", path)
		return
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.rotation.y = rot_y
	node.scale = Vector3.ONE * scale_k
	add_child(node)


func _setup_scene() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(14, 14, 18)
	add_child(camera)
	camera.look_at(Vector3(2.5, 0, 3.5))

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.89, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	var world := WorldEnvironment.new()
	world.name = "World"
	world.environment = env
	add_child(world)


func _set_night() -> void:
	var sun: DirectionalLight3D = get_node("Sun")
	sun.light_color = Color(0.45, 0.55, 0.9)
	sun.light_energy = 0.25
	var env: Environment = get_node("World").environment
	env.background_color = Color(0.04, 0.05, 0.1)
	env.ambient_light_color = Color(0.25, 0.3, 0.55)
	env.ambient_light_energy = 0.5
	# Пара фонарей-заглушек, чтобы увидеть, как выглядит ночной свет.
	for pos in [Vector3(1, 1.5, 5), Vector3(5, 1.5, 5), Vector3(3, 1.5, 3)]:
		var lamp := OmniLight3D.new()
		lamp.position = pos
		lamp.light_color = Color(1.0, 0.75, 0.45)
		lamp.light_energy = 2.0
		lamp.omni_range = 4.0
		add_child(lamp)
	var neon := OmniLight3D.new()
	neon.position = Vector3(-2, 1.5, 3)
	neon.light_color = Color(0.95, 0.2, 0.5)
	neon.light_energy = 3.0
	neon.omni_range = 4.0
	add_child(neon)


func _aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_aabb: AABB = child.get_aabb()
		if first:
			result = mesh_aabb
			first = false
		else:
			result = result.merge(mesh_aabb)
	return result


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
