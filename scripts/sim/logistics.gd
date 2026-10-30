class_name Logistics
extends RefCounted
## Транспорт и маршруты. Машина: тип (скутер, легковая, фургон), тайник, маскировка груза, сколько дней в ремонте.
## Маршрут: каждую ночь курьер везёт товар на машине из твоего здания в другое твоё здание
## или на рынок района (место вида "@station"), где сам продаёт. Разведчик (по желанию) едет впереди.
## Грузы между городами: разовая отправка товара из своего здания в своё здание или на рынок другого города,
## идёт несколько дней (самолётом или контейнером, машины не нужны).
## Риски в пути и деньги считает GameSession — здесь только состояние и правила.

## Типы машин из balance.vehicles.
var types: Dictionary = {}
## Свои машины: { id, type, hidden, disguise, broken }.
var vehicles: Array = []
## Маршруты: { id, from, to, good, vehicle, courier, scout } (scout = 0 — без разведчика).
var routes: Array = []
## Грузы в пути: { id, from, to, good, amount, arrive (день прибытия), disguise }.
var shipments: Array = []

var _next_id := 1


func _init(vehicle_types: Dictionary) -> void:
	types = vehicle_types


func add_vehicle(type: String) -> Dictionary:
	var vehicle := { "id": _next_id, "type": type, "hidden": false, "disguise": false, "broken": 0 }
	_next_id += 1
	vehicles.append(vehicle)
	return vehicle


func get_vehicle(id: int) -> Dictionary:
	for vehicle: Dictionary in vehicles:
		if vehicle.id == id:
			return vehicle
	return {}


func get_route(id: int) -> Dictionary:
	for route: Dictionary in routes:
		if route.id == id:
			return route
	return {}


func capacity(vehicle: Dictionary) -> int:
	return int(types[vehicle.type].capacity)


## Машина или курьер уже заняты другим маршрутом.
func vehicle_busy(id: int) -> bool:
	return routes.any(func(route: Dictionary) -> bool: return route.vehicle == id)


func courier_busy(id: int) -> bool:
	return routes.any(func(route: Dictionary) -> bool: return route.courier == id)


func scout_busy(id: int) -> bool:
	return routes.any(func(route: Dictionary) -> bool: return route.scout == id)


## Маршрут курьера или разведчика, или {}.
func route_of(person_id: int) -> Dictionary:
	for route: Dictionary in routes:
		if route.courier == person_id or route.scout == person_id:
			return route
	return {}


func add_route(from: String, to: String, good: String, vehicle: int, courier: int, scout: int = 0) -> Dictionary:
	var route := { "id": _next_id, "from": from, "to": to, "good": good, "vehicle": vehicle, "courier": courier, "scout": scout }
	_next_id += 1
	routes.append(route)
	return route


func remove_route(id: int) -> void:
	routes.erase(get_route(id))


## Убрать маршруты, которые больше не работают: нет места, машины или курьера.
## Пропал разведчик — маршрут остаётся, просто без него.
func drop_broken_routes(place_ok: Callable, has_person: Callable) -> void:
	routes = routes.filter(func(route: Dictionary) -> bool:
		return place_ok.call(route.from) and place_ok.call(route.to) and not get_vehicle(route.vehicle).is_empty() \
				and has_person.call(route.courier))
	for route: Dictionary in routes:
		if route.scout != 0 and not has_person.call(route.scout):
			route.scout = 0


func add_shipment(from: String, to: String, good: String, amount: int, arrive: int, disguise: bool) -> Dictionary:
	var shipment := { "id": _next_id, "from": from, "to": to, "good": good, "amount": amount, "arrive": arrive,
			"disguise": disguise }
	_next_id += 1
	shipments.append(shipment)
	return shipment


func to_dict() -> Dictionary:
	return { "vehicles": vehicles.duplicate(true), "routes": routes.duplicate(true), "shipments": shipments.duplicate(true),
			"next_id": _next_id }


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	vehicles = []
	for v: Dictionary in data.get("vehicles", []):
		if types.has(v.type):
			vehicles.append({ "id": int(v.id), "type": String(v.type), "hidden": bool(v.hidden),
					"disguise": bool(v.get("disguise", false)), "broken": int(v.broken) })
	routes = []
	for r: Dictionary in data.get("routes", []):
		routes.append({ "id": int(r.id), "from": String(r.from), "to": String(r.to), "good": String(r.good),
				"vehicle": int(r.vehicle), "courier": int(r.courier), "scout": int(r.get("scout", 0)) })
	shipments = []
	for sh: Dictionary in data.get("shipments", []):
		shipments.append({ "id": int(sh.id), "from": String(sh.from), "to": String(sh.to), "good": String(sh.good),
				"amount": int(sh.amount), "arrive": int(sh.arrive), "disguise": bool(sh.disguise) })
