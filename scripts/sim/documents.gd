class_name Documents
extends RefCounted
## Документы игрока: паспорт (нужен для любой границы) и визы по зонам стран (zone в data/world.json).
## Настоящие оформляются несколько дней, поддельные — сразу, но на границе их могут распознать.
## Деньги, проверки и случайности считает GameSession — здесь только состояние и правила.

## Паспорт: "" — нет, "real" или "fake"; если оформляется — день готовности (0 — не оформляется).
var passport: String = ""
var passport_ready: int = 0
## Визы по зонам: { zone: { kind: "real"/"fake", until: последний день } }; оформляемые: { zone: день готовности }.
var visas: Dictionary = {}
var visa_ready: Dictionary = {}


## Нужна ли виза в эту зону (из balance.visas; Шенген — только паспорт).
static func needs_visa(zone: String, balance: Dictionary) -> bool:
	return balance.visas.has(zone)


func has_passport() -> bool:
	return passport != ""


func visa(zone: String, day: int) -> Dictionary:
	var v: Dictionary = visas.get(zone, {})
	return v if not v.is_empty() and int(v.until) >= day else {}


## Готовы ли документы к этой зоне сегодня.
func ready_for(zone: String, day: int, balance: Dictionary) -> bool:
	return has_passport() and (not needs_visa(zone, balance) or not visa(zone, day).is_empty())


## Что из документов поддельное для этой зоны (их и проверяют на границе).
func fakes_for(zone: String, day: int, balance: Dictionary) -> Array:
	var result: Array = []
	if passport == "fake":
		result.append("passport")
	if needs_visa(zone, balance) and visa(zone, day).get("kind", "") == "fake":
		result.append("visa")
	return result


## Утро: готовые документы выдают. Возвращает отчёт.
func collect(day: int, balance: Dictionary) -> Array:
	var report: Array = []
	if passport_ready > 0 and passport_ready <= day:
		passport = "real"
		passport_ready = 0
		report.append(["LOG_PASSPORT_READY", []])
	for zone: String in visa_ready.keys():
		if int(visa_ready[zone]) <= day:
			visas[zone] = { "kind": "real", "until": day + int(balance.visas[zone].valid) }
			visa_ready.erase(zone)
			report.append(["LOG_VISA_READY", [balance.visas[zone].name_key]])
	return report


func to_dict() -> Dictionary:
	return { "passport": passport, "passport_ready": passport_ready, "visas": visas.duplicate(true),
			"visa_ready": visa_ready.duplicate() }


func load_dict(data: Dictionary) -> void:
	passport = String(data.get("passport", ""))
	passport_ready = int(data.get("passport_ready", 0))
	visas = {}
	for zone: String in data.get("visas", {}):
		visas[zone] = { "kind": String(data.visas[zone].kind), "until": int(data.visas[zone].until) }
	visa_ready = {}
	for zone: String in data.get("visa_ready", {}):
		visa_ready[zone] = int(data.visa_ready[zone])
