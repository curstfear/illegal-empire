extends Node
## Свет города по игровым часам: утро, день, вечер, ночь.
## Ночью включаются фонари и неон.

## Ключевые точки суток: час → цвет солнца, сила солнца, фон, окружающий свет, ночной свет (0…1).
const KEYS := [
	[0.0, Color(0.45, 0.55, 0.9), 0.15, Color(0.03, 0.04, 0.09), Color(0.09, 0.11, 0.22), 1.0],
	[5.0, Color(0.45, 0.55, 0.9), 0.15, Color(0.03, 0.04, 0.09), Color(0.09, 0.11, 0.22), 1.0],
	[7.0, Color(1.0, 0.7, 0.5), 0.7, Color(0.75, 0.68, 0.72), Color(0.7, 0.62, 0.65), 0.2],
	[9.0, Color(1.0, 0.97, 0.92), 1.0, Color(0.86, 0.89, 0.95), Color(0.75, 0.8, 0.9), 0.0],
	[17.0, Color(1.0, 0.95, 0.88), 0.95, Color(0.84, 0.86, 0.93), Color(0.73, 0.77, 0.88), 0.0],
	[19.5, Color(1.0, 0.55, 0.4), 0.6, Color(0.55, 0.35, 0.45), Color(0.55, 0.42, 0.55), 0.5],
	[21.0, Color(0.45, 0.55, 0.9), 0.2, Color(0.04, 0.05, 0.11), Color(0.1, 0.12, 0.24), 1.0],
	[24.0, Color(0.45, 0.55, 0.9), 0.15, Color(0.03, 0.04, 0.09), Color(0.09, 0.11, 0.22), 1.0],
]

@export var sun: DirectionalLight3D
@export var world: WorldEnvironment
@export var city: Node3D

## Для проверок: если не меньше 0 — показывать этот час вместо игрового.
var forced_hour := -1.0


func _process(_delta: float) -> void:
	var hour := forced_hour if forced_hour >= 0.0 else Clock.minutes_of_day() / 60.0
	apply_hour(hour)


func apply_hour(hour: float) -> void:
	var i := 0
	while i < KEYS.size() - 2 and hour >= KEYS[i + 1][0]:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t := clampf((hour - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	sun.light_color = (a[1] as Color).lerp(b[1], t)
	sun.light_energy = lerpf(a[2], b[2], t)
	# Солнце идёт по небу с 6 до 20, ночью светит луна с постоянного угла.
	var day_t := clampf((hour - 6.0) / 14.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-25.0 - sin(day_t * PI) * 40.0, -60.0 + day_t * 120.0, 0)
	var env := world.environment
	env.background_color = (a[3] as Color).lerp(b[3], t)
	env.ambient_light_color = (a[4] as Color).lerp(b[4], t)
	var night := lerpf(a[5], b[5], t)
	for lamp: OmniLight3D in city.streetlights:
		lamp.light_energy = night * 1.6
	for neon: OmniLight3D in city.neon_lights:
		neon.light_energy = night * 3.5
