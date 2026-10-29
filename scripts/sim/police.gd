class_name Police
extends RefCounted
## Розыск по районам (0–100, на экране это 0–5 звёзд) и шанс проверки.

var heat: Dictionary = {}

var _balance: Dictionary


func _init(district_list: Array, balance: Dictionary) -> void:
	_balance = balance
	for district: Dictionary in district_list:
		heat[district.id] = 0.0


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
	return minf(chance, _balance.check_max)


## Шанс убежать при проверке: чем выше розыск, тем меньше.
func flee_chance(district: String) -> float:
	return clampf(_balance.flee_chance - heat[district] * _balance.flee_chance_per_heat, 0.1, 0.9)


func to_dict() -> Dictionary:
	return heat.duplicate()


func load_dict(data: Dictionary) -> void:
	for district: String in data:
		if heat.has(district):
			heat[district] = float(data[district])
