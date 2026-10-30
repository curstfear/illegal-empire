class_name Suppliers
extends RefCounted
## Поставщики сырья (data/world.json, "suppliers"): в каждом городе свои контакты — надёжные (дороже,
## почти без риска) и «палёные» (дешевле, но бывают недовес и «хвост» полиции). Договор: каждое утро
## поставщик сам привозит товар в твоё здание того же города. Режим "daily" — привезти amount штук,
## "keep" — довезти до amount штук на складе (нужен менеджер в здании).
## Деньги и риски считает GameSession — здесь только состояние и правила.

## Поставщики: { id, city, name_key, goods: [товары], price (доля от цены рынка), risk (шанс беды за доставку) }.
var defs: Array = []
## Договоры: { id, supplier, good, amount, to (id здания), mode ("daily" или "keep") }.
var contracts: Array = []

var _next_id := 1


func _init(supplier_list: Array) -> void:
	defs = supplier_list


func get_def(id: String) -> Dictionary:
	for supplier: Dictionary in defs:
		if supplier.id == id:
			return supplier
	return {}


func in_city(city: String) -> Array:
	return defs.filter(func(supplier: Dictionary) -> bool: return supplier.city == city)


func get_contract(id: int) -> Dictionary:
	for contract: Dictionary in contracts:
		if contract.id == id:
			return contract
	return {}


func add_contract(supplier: String, good: String, amount: int, to: String, mode: String) -> Dictionary:
	var contract := { "id": _next_id, "supplier": supplier, "good": good, "amount": amount, "to": to, "mode": mode }
	_next_id += 1
	contracts.append(contract)
	return contract


func remove_contract(id: int) -> void:
	contracts.erase(get_contract(id))


func to_dict() -> Dictionary:
	return { "contracts": contracts.duplicate(true), "next_id": _next_id }


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	contracts = []
	for c: Dictionary in data.get("contracts", []):
		if not get_def(String(c.supplier)).is_empty():
			contracts.append({ "id": int(c.id), "supplier": String(c.supplier), "good": String(c.good),
					"amount": int(c.amount), "to": String(c.to), "mode": String(c.get("mode", "daily")) })
