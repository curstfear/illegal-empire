class_name Skills
extends RefCounted
## Навыки игрока. Растут от дела: опыт копится, уровень от 0 до skill_max.
## На следующий уровень нужно skill_xp_step × (уровень + 1) опыта.

const IDS: Array[String] = ["trade", "charisma", "stealth", "craft"]

var xp: Dictionary = {}

var _balance: Dictionary


func _init(balance: Dictionary) -> void:
	_balance = balance
	for id in IDS:
		xp[id] = 0


func level(id: String) -> int:
	var result := 0
	var left: int = xp[id]
	while result < int(_balance.skill_max) and left >= _need(result):
		left -= _need(result)
		result += 1
	return result


## Доля пути до следующего уровня (0…1), на максимуме — 1.
func progress(id: String) -> float:
	var lvl := level(id)
	if lvl >= int(_balance.skill_max):
		return 1.0
	var spent := 0
	for i in lvl:
		spent += _need(i)
	return float(xp[id] - spent) / _need(lvl)


## Добавить опыт. Возвращает true, если вырос уровень.
func add_xp(id: String, amount: int) -> bool:
	var before := level(id)
	xp[id] += maxi(0, amount)
	return level(id) > before


## Множитель цены продажи от Торговли.
func sell_multiplier() -> float:
	return 1.0 + level("trade") * _balance.trade_bonus_per_level


## Множитель оплаты подработок от Харизмы.
func pay_multiplier() -> float:
	return 1.0 + level("charisma") * _balance.charisma_pay_per_level


## Множитель взятки от Харизмы.
func bribe_multiplier() -> float:
	return maxf(0.2, 1.0 - level("charisma") * _balance.charisma_bribe_per_level)


## Множитель розыска от Скрытности.
func heat_multiplier() -> float:
	return maxf(0.2, 1.0 - level("stealth") * _balance.stealth_heat_per_level)


## Множитель сбора от Ремесла.
func yield_multiplier() -> float:
	return 1.0 + level("craft") * _balance.craft_yield_per_level


func _need(lvl: int) -> int:
	return int(_balance.skill_xp_step) * (lvl + 1)


func to_dict() -> Dictionary:
	return xp.duplicate()


func load_dict(data: Dictionary) -> void:
	for id: String in data:
		if xp.has(id):
			xp[id] = int(data[id])
