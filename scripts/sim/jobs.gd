class_name Jobs
extends RefCounted
## Заказы и ситуации — цели на ближайшие минуты.
## Заказ: клиент (банда города или контакт из data/world.json, "clients") хочет N штук товара в районе
## к сроку и платит сверху рынка. Доска предложений — по городу; взятые заказы — до срока.
## Ситуация: что-то случилось прямо сейчас (участковый у лаборатории, человек просит аванс, перекупщик,
## соседи, наводка на склад банды) — у неё несколько выборов и срок, после которого всё решается само.
## Деньги, риски и последствия считает GameSession — здесь только состояние.

## Контакты-заказчики: { id, city ("*" — любой), name_key, goods: [товары] }.
var clients: Array = []
## Предложения на доске: { id, client ("gang:<id>" или "contact:<id>"), city, district, good, amount, reward,
## days (срок на выполнение после взятия), expires (до какого дня висит) }.
var offers: Array = []
## Взятые заказы: как предложение, но вместо days и expires — deadline (номер дня, до конца которого сдать).
var orders: Array = []
## Ситуации: { id, kind, place (id здания или "@район"), target, amount, cost, expires (день × 24 + час) }.
var situations: Array = []

var _next_id := 1


func _init(client_list: Array) -> void:
	clients = client_list


func next_id() -> int:
	_next_id += 1
	return _next_id - 1


func get_client(id: String) -> Dictionary:
	for client: Dictionary in clients:
		if client.id == id:
			return client
	return {}


func clients_in(city: String) -> Array:
	return clients.filter(func(c: Dictionary) -> bool: return c.city == "*" or c.city == city)


func offers_in(city: String) -> Array:
	return offers.filter(func(o: Dictionary) -> bool: return o.city == city)


func find(list: Array, id: int) -> Dictionary:
	for item: Dictionary in list:
		if item.id == id:
			return item
	return {}


func to_dict() -> Dictionary:
	return { "offers": offers.duplicate(true), "orders": orders.duplicate(true), "situations": situations.duplicate(true),
			"next_id": _next_id }


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	offers = []
	for o: Dictionary in data.get("offers", []):
		offers.append(_job_from(o, { "days": int(o.days), "expires": int(o.expires) }))
	orders = []
	for o: Dictionary in data.get("orders", []):
		orders.append(_job_from(o, { "deadline": int(o.deadline) }))
	situations = []
	for s: Dictionary in data.get("situations", []):
		situations.append({ "id": int(s.id), "kind": String(s.kind), "place": String(s.place), "target": s.target,
				"amount": int(s.amount), "cost": int(s.cost), "expires": int(s.expires) })


func _job_from(o: Dictionary, extra: Dictionary) -> Dictionary:
	var job := { "id": int(o.id), "client": String(o.client), "city": String(o.city), "district": String(o.district),
			"good": String(o.good), "amount": int(o.amount), "reward": int(o.reward) }
	job.merge(extra)
	return job
