extends Node
## Свет города по игровым часам: утро, день, вечер, ночь.
## Ночью включаются фонари и неон. У каждого города свой оттенок ("lighting" в раскладке):
## днём — солнце и окружающий свет, ночью — небо; плюс насыщенность картинки.

## Ключевые точки суток: час → цвет солнца, сила солнца, фон, окружающий свет, ночной свет (0…1).
## Днём свет яркий и чистый, тени чёткие, но мягкие; ночь — синяя, а не чёрная.
const KEYS := [
	[0.0, Color(0.55, 0.62, 0.95), 0.25, Color(0.12, 0.15, 0.26), Color(0.3, 0.34, 0.5), 1.0],
	[5.0, Color(0.55, 0.62, 0.95), 0.25, Color(0.12, 0.15, 0.26), Color(0.3, 0.34, 0.5), 1.0],
	[7.0, Color(1.0, 0.84, 0.7), 0.95, Color(0.9, 0.9, 0.94), Color(0.72, 0.72, 0.8), 0.2],
	[9.0, Color(1.0, 0.98, 0.94), 1.25, Color(0.93, 0.95, 0.98), Color(0.7, 0.76, 0.88), 0.0],
	[17.0, Color(1.0, 0.96, 0.9), 1.2, Color(0.93, 0.95, 0.98), Color(0.7, 0.75, 0.86), 0.0],
	[19.5, Color(1.0, 0.7, 0.55), 0.6, Color(0.8, 0.7, 0.78), Color(0.72, 0.64, 0.74), 0.5],
	[21.0, Color(0.55, 0.62, 0.95), 0.3, Color(0.14, 0.17, 0.3), Color(0.32, 0.36, 0.52), 1.0],
	[24.0, Color(0.55, 0.62, 0.95), 0.25, Color(0.12, 0.15, 0.26), Color(0.3, 0.34, 0.5), 1.0],
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
	var night := lerpf(a[5], b[5], t)
	var tint: Dictionary = city.lighting
	var day_tint := _tint(tint, "day")
	var night_tint := _tint(tint, "night")
	var mix := Color.WHITE.lerp(day_tint, 1.0 - night) * Color.WHITE.lerp(night_tint, night)
	sun.light_color = (a[1] as Color).lerp(b[1], t) * mix
	sun.light_energy = lerpf(a[2], b[2], t) * float(tint.get("energy", 1.0))
	# Солнце идёт по небу с 6 до 20, ночью светит луна с постоянного угла.
	var day_t := clampf((hour - 6.0) / 14.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-25.0 - sin(day_t * PI) * 40.0, -60.0 + day_t * 120.0, 0)
	var env := world.environment
	env.background_color = (a[3] as Color).lerp(b[3], t) * mix
	env.ambient_light_color = (a[4] as Color).lerp(b[4], t) * mix
	env.adjustment_saturation = float(tint.get("saturation", 1.12))
	for lamp: OmniLight3D in city.streetlights:
		lamp.light_energy = night * 1.6
	for neon: OmniLight3D in city.neon_lights:
		neon.light_energy = night * 3.5


static func _tint(tint: Dictionary, key: String) -> Color:
	var c: Array = tint.get(key, [])
	return Color(c[0], c[1], c[2]) if c.size() == 3 else Color.WHITE
