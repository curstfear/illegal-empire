class_name Logistics
extends RefCounted
## Транспорт и маршруты. Машина: тип (скутер, легковая, фургон), тайник, сколько дней в ремонте.
## Маршрут: каждую ночь курьер везёт товар на машине из одного твоего здания в другое.
## Риски в пути и деньги считает GameSession — здесь только состояние и правила.

## Типы машин из balance.vehicles.
var types: Dictionary = {}
## Свои машины: { id, type, hidden, broken }.
var vehicles: Array = []
## Маршруты: { id, from, to, good, vehicle, courier }.
var routes: Array = []

var _next_id := 1


func _init(vehicle_types: Dictionary) -> void:
	types = vehicle_types


func add_vehicle(type: String) -> Dictionary:
	var vehicle := { "id": _next_id, "type": type, "hidden": false, "broken": 0 }
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


## Маршрут курьера или {}.
func route_of(courier_id: int) -> Dictionary:
	for route: Dictionary in routes:
		if route.courier == courier_id:
			return route
	return {}


func add_route(from: String, to: String, good: String, vehicle: int, courier: int) -> Dictionary:
	var route := { "id": _next_id, "from": from, "to": to, "good": good, "vehicle": vehicle, "courier": courier }
	_next_id += 1
	routes.append(route)
	return route


func remove_route(id: int) -> void:
	routes.erase(get_route(id))


## Убрать маршруты, которые больше не работают: нет здания, машины или курьера.
func drop_broken_routes(is_mine: Callable, has_person: Callable) -> void:
	routes = routes.filter(func(route: Dictionary) -> bool:
		return is_mine.call(route.from) and is_mine.call(route.to) and not get_vehicle(route.vehicle).is_empty() \
				and has_person.call(route.courier))


func to_dict() -> Dictionary:
	return { "vehicles": vehicles.duplicate(true), "routes": routes.duplicate(true), "next_id": _next_id }


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	vehicles = []
	for v: Dictionary in data.get("vehicles", []):
		if types.has(v.type):
			vehicles.append({ "id": int(v.id), "type": String(v.type), "hidden": bool(v.hidden), "broken": int(v.broken) })
	routes = []
	for r: Dictionary in data.get("routes", []):
		routes.append({ "id": int(r.id), "from": String(r.from), "to": String(r.to), "good": String(r.good),
				"vehicle": int(r.vehicle), "courier": int(r.courier) })
