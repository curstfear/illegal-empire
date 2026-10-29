class_name Stall
extends RefCounted
## Ларёк на рынке. Сам продаёт выложенный товар каждый день по полной цене рынка,
## но не больше stall_daily штук каждого товара. Сигареты идут «из-под прилавка».

const DISTRICT := "market"

var owned: bool = false
## Сколько каждого товара выложено.
var stock: Dictionary = {}


func _init(goods: Array) -> void:
	for good: Dictionary in goods:
		if int(good.stall_daily) > 0:
			stock[good.id] = 0


func accepts(id: String) -> bool:
	return stock.has(id)


func to_dict() -> Dictionary:
	return { "owned": owned, "stock": stock.duplicate() }


func load_dict(data: Dictionary) -> void:
	owned = bool(data.owned)
	for id: String in data.stock:
		if stock.has(id):
			stock[id] = int(data.stock[id])
