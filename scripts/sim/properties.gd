class_name Properties
extends RefCounted
## Недвижимость игрока: склады, лаборатории, фасады (прачечная, кафе).
## Хранит, что куплено или арендовано, что лежит внутри, какие партии варятся,
## сколько грязных денег ждёт отмыва и внимание налоговой.
## Деньги, розыск и случайности считает GameSession — здесь только состояние и правила.

var defs: Array = []
var recipes: Array = []
## Состояние по id здания: { owned, rented, stock: {товар: шт}, level, batches: [...], dirty_queue, frozen_days,
## upgrades: [id улучшений], evidence: улики 0–100 }.
var state: Dictionary = {}
## Внимание налоговой к отмыву (0–100).
var tax_attention: float = 0.0

var _sizes: Dictionary = {}
## Какая доля товара портится за ночь вне холодильника (грибы, травы, чай, мох).
var _perish: Dictionary = {}


func _init(property_list: Array, recipe_list: Array, goods: Array) -> void:
	defs = property_list
	recipes = recipe_list
	for good: Dictionary in goods:
		_sizes[good.id] = int(good.get("size", 1))
		_perish[good.id] = float(good.get("perish", 0.0))
	for prop: Dictionary in defs:
		state[prop.id] = _empty_state()


func _empty_state() -> Dictionary:
	return { "owned": false, "rented": false, "stock": {}, "level": 1, "batches": [], "dirty_queue": 0, "frozen_days": 0,
			"upgrades": [], "evidence": 0.0 }


## Вернуть здание в исходный вид. keep_lease — оставить за игроком (после взрыва), иначе — освободить.
func reset(id: String, keep_lease: bool = false) -> void:
	var fresh := _empty_state()
	if keep_lease:
		fresh.owned = state[id].owned
		fresh.rented = state[id].rented
	state[id] = fresh


func get_def(id: String) -> Dictionary:
	for prop: Dictionary in defs:
		if prop.id == id:
			return prop
	return {}


func get_recipe(id: String) -> Dictionary:
	for recipe: Dictionary in recipes:
		if recipe.id == id:
			return recipe
	return {}


func is_mine(id: String) -> bool:
	return state[id].owned or state[id].rented


func mine() -> Array:
	return defs.filter(func(prop: Dictionary) -> bool: return is_mine(prop.id))


## Сколько мест занимает товар внутри здания.
func stock_used(id: String) -> int:
	var used := 0
	for good: String in state[id].stock:
		used += state[id].stock[good] * _sizes.get(good, 1)
	return used


func stock_free(id: String) -> int:
	return int(get_def(id).capacity) - stock_used(id)


func stock_of(id: String, good: String) -> int:
	return int(state[id].stock.get(good, 0))


func add_stock(id: String, good: String, amount: int) -> void:
	state[id].stock[good] = stock_of(id, good) + amount
	if state[id].stock[good] <= 0:
		state[id].stock.erase(good)


## Рецепты, которые можно варить в этом здании: в лаборатории — лабораторные, на кухне кафе — кухонные.
func recipes_for(id: String) -> Array:
	var prop := get_def(id)
	var where := "lab" if prop.kind == "lab" else ("kitchen" if prop.get("kitchen", false) else "")
	return recipes.filter(func(recipe: Dictionary) -> bool: return recipe.where == where)


## Сколько партий хватит сырья в здании.
func max_batches(id: String, recipe_id: String) -> int:
	var recipe := get_recipe(recipe_id)
	var best := 1000000
	for good: String in recipe.inputs:
		best = mini(best, stock_of(id, good) / int(recipe.inputs[good]))
	return best


## Запустить партии: сырьё уходит сразу, продукт появится через nights ночей.
func start_batches(id: String, recipe_id: String, count: int) -> void:
	var recipe := get_recipe(recipe_id)
	for good: String in recipe.inputs:
		add_stock(id, good, -int(recipe.inputs[good]) * count)
	state[id].batches.append({ "recipe": recipe_id, "count": count, "nights_left": int(recipe.nights) })


## Сколько штук каждого товара испортится за ночь (холодильник спасает всё).
func spoilage(id: String) -> Dictionary:
	var lost := {}
	if has_upgrade(id, "fridge"):
		return lost
	for good: String in state[id].stock:
		var rate: float = _perish.get(good, 0.0)
		if rate > 0.0:
			lost[good] = ceili(stock_of(id, good) * rate)
	return lost


func has_upgrade(id: String, upgrade: String) -> bool:
	return state[id].upgrades.has(upgrade)


## Улучшения, которые подходят этому зданию (по типу; кухня кафе — тоже «front»).
func upgrades_for(id: String, all_upgrades: Dictionary) -> Array:
	var def := get_def(id)
	var kind: String = def.kind
	# Подпольный покер — только в казино.
	return all_upgrades.keys().filter(func(upgrade: String) -> bool:
		return all_upgrades[upgrade].kinds.has(kind) and (not all_upgrades[upgrade].get("casino", false) or def.get("casino", false)))


## Здание пустое и ничего не варится — только такое можно продать или сдать.
func is_empty(id: String) -> bool:
	return state[id].stock.is_empty() and state[id].batches.is_empty() and state[id].dirty_queue == 0


## Есть ли внутри нелегальный товар или варится что-то нелегальное (это и ищет полиция).
func has_illegal(id: String, goods_legal: Dictionary) -> bool:
	for good: String in state[id].stock:
		if not goods_legal.get(good, true):
			return true
	for batch: Dictionary in state[id].batches:
		if get_recipe(batch.recipe).smell > 0:
			return true
	return false


func to_dict() -> Dictionary:
	return { "state": state.duplicate(true), "tax_attention": tax_attention }


func load_dict(data: Dictionary) -> void:
	tax_attention = float(data.get("tax_attention", 0.0))
	var saved: Dictionary = data.get("state", {})
	for id: String in saved:
		if not state.has(id):
			continue
		var s: Dictionary = saved[id]
		var restored := _empty_state()
		restored.owned = bool(s.owned)
		restored.rented = bool(s.rented)
		restored.level = int(s.level)
		restored.dirty_queue = int(s.dirty_queue)
		restored.frozen_days = int(s.frozen_days)
		restored.evidence = float(s.get("evidence", 0.0))
		for upgrade: String in s.get("upgrades", []):
			restored.upgrades.append(upgrade)
		for good: String in s.stock:
			restored.stock[good] = int(s.stock[good])
		for batch: Dictionary in s.batches:
			restored.batches.append({ "recipe": batch.recipe, "count": int(batch.count), "nights_left": int(batch.nights_left) })
		state[id] = restored
