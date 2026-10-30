class_name Police
extends RefCounted
## Розыск по районам (0–100, на экране это 0–5 звёзд) и шанс проверки; дело детективов по районам (0–100)
## и «крыша» — продажный полицейский в районе (платишь раз в неделю, проверок меньше).

var heat: Dictionary = {}
## Дело детективов на тебя по районам (0–100): растёт при высоком розыске, на 100 — облава спецназа.
var dossier: Dictionary = {}
## «Крыша» по районам: { district: день следующей оплаты }.
var krysha: Dictionary = {}

var _balance: Dictionary


func _init(district_list: Array, balance: Dictionary) -> void:
	_balance = balance
	for district: Dictionary in district_list:
		heat[district.id] = 0.0
		dossier[district.id] = 0.0


func stars(district: String) -> int:
	return mini(5, floori(heat[district] / 20.0))


func max_heat() -> float:
	var result := 0.0
	for district: String in heat:
		result = maxf(result, heat[district])
	return result


func add_heat(district: String, amount: float) -> void:
	heat[district] = clampf(heat[district] + amount, 0.0, _balance.heat_max)


## Розыск спадает во всех районах.
func decay(amount: float) -> void:
	for district: String in heat:
		add_heat(district, -amount)


## Шанс, что после нелегальной сделки остановят.
## multiplier — сила полиции района и события дня.
func check_chance(district: String, multiplier: float) -> float:
	var chance: float = (_balance.check_base + heat[district] * _balance.check_per_heat) * multiplier
	if krysha.has(district):
		chance *= float(_balance.krysha_check)
	return minf(chance, _balance.check_max)


func has_krysha(district: String) -> bool:
	return krysha.has(district)


## Детективы работают, когда розыск района не ниже detective_stars звёзд.
func detectives_on(district: String) -> bool:
	return stars(district) >= int(_balance.detective_stars)


func add_dossier(district: String, amount: float) -> void:
	dossier[district] = clampf(float(dossier[district]) + amount, 0.0, float(_balance.dossier_case))


## Шанс убежать при проверке: чем выше розыск, тем меньше.
func flee_chance(district: String) -> float:
	return clampf(_balance.flee_chance - heat[district] * _balance.flee_chance_per_heat, 0.1, 0.9)


func to_dict() -> Dictionary:
	return { "heat": heat.duplicate(), "dossier": dossier.duplicate(), "krysha": krysha.duplicate() }


## Старые сохранения — просто розыск по районам.
func load_dict(data: Dictionary) -> void:
	var heat_data: Dictionary = data.heat if data.get("heat") is Dictionary else data
	for district: String in heat_data:
		if heat.has(district):
			heat[district] = float(heat_data[district])
	for district: String in data.get("dossier", {}):
		if dossier.has(district):
			dossier[district] = float(data.dossier[district])
	krysha = {}
	for district: String in data.get("krysha", {}):
		if heat.has(district):
			krysha[district] = int(data.krysha[district])
