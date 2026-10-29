class_name Chudik
extends Node3D
## Округлый «игрушечный» человечек: тело-капсула, большая круглая голова, глазки, ручки.
## Собирается из простых фигур прямо в Godot. Ходит вперевалку.
## Меши и материалы общие для всех чудиков — так их можно делать много.

const HEIGHT := 0.55

## Цвет тела и головы (голова чуть светлее), фуражка для полицейских.
var body_color := Color(0.3, 0.5, 0.9)
var police := false
## Идёт ли сейчас (тогда переваливается и подпрыгивает).
var walking := true

var _phase := randf() * TAU
var _body_pivot: Node3D

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not walking:
		_body_pivot.position.y = 0.0
		_body_pivot.rotation.z = 0.0
		return
	_phase += delta * 9.0
	# Вперевалку: качается из стороны в сторону и чуть подпрыгивает на каждом шаге.
	_body_pivot.rotation.z = sin(_phase) * 0.12
	_body_pivot.position.y = absf(sin(_phase)) * 0.035


func _build() -> void:
	_body_pivot = Node3D.new()
	add_child(_body_pivot)
	var body_mat := _material(body_color)
	var head_mat := _material(body_color.lerp(Color.WHITE, 0.55))
	_add(_mesh("body"), body_mat, Vector3(0, 0.17, 0))
	_add(_mesh("head"), head_mat, Vector3(0, 0.38, 0))
	for side in [-1.0, 1.0]:
		_add(_mesh("eye"), _material(Color(0.06, 0.06, 0.09)), Vector3(side * 0.055, 0.4, 0.125))
		var arm := _add(_mesh("arm"), body_mat, Vector3(side * 0.125, 0.17, 0.0))
		arm.rotation.z = side * 0.35
	if police:
		var cap_mat := _material(Color(0.12, 0.16, 0.35))
		_add(_mesh("cap"), cap_mat, Vector3(0, 0.5, 0))
		_add(_mesh("visor"), cap_mat, Vector3(0, 0.47, 0.07))


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	_body_pivot.add_child(node)
	return node


static func _mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var mesh: Mesh
	match id:
		"body":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.1
			capsule.height = 0.3
			mesh = capsule
		"head":
			var sphere := SphereMesh.new()
			sphere.radius = 0.14
			sphere.height = 0.26
			mesh = sphere
		"eye":
			var sphere := SphereMesh.new()
			sphere.radius = 0.022
			sphere.height = 0.044
			mesh = sphere
		"arm":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.03
			capsule.height = 0.14
			mesh = capsule
		"cap":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.1
			cylinder.bottom_radius = 0.12
			cylinder.height = 0.07
			mesh = cylinder
		"visor":
			var box := BoxMesh.new()
			box.size = Vector3(0.14, 0.015, 0.08)
			mesh = box
	_meshes[id] = mesh
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	_materials[key] = mat
	return mat
