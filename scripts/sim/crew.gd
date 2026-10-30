class_name Crew
extends RefCounted
## Бригада: кандидаты на бирже и нанятые люди (повар, дилер, охранник, курьер, менеджер, бухгалтер, адвокат, разведчик, боец).
## У человека: кличка, роль, навык 1–5, черта характера, зарплата за день, место работы (id здания или ""),
## лояльность, страх и усталость (0–100), «что знает» (ночей в бригаде), опыт к следующему уровню,
## день последней премии, день выходного и сколько дней ещё лечиться после разборки.
## Деньги, розыск и случайности считает GameSession — здесь только состояние и правила.

## Роли и черты из data/crew.json; клички — ключи перевода.
var roles: Dictionary = {}
var traits: Dictionary = {}
var nicknames: Array = []
## Нанятые и кандидаты: { id, nick, role, skill, trait, wage, job, loyalty, fear, knows, bonus_day, xp, fatigue, off_day, wounded }.
var people: Array = []
var candidates: Array = []
## Кто из нанятых вышел на работу этой ночью (пьющий может не прийти). Не сохраняется.
var present: Dictionary = {}

var _next_id := 1
var _skill_max := 5
var _loyalty_start := 55.0


func _init(data: Dictionary, skill_max: int, loyalty_start: float) -> void:
	roles = data.roles
	traits = data.traits
	nicknames = data.nicknames
	_skill_max = skill_max
	_loyalty_start = loyalty_start


## Новые кандидаты на бирже (старые уходят).
func roll_candidates(rng: RandomNumberGenerator, count: int) -> void:
	candidates.clear()
	for i in count:
		candidates.append(_make_person(rng))


## Кандидат: случайная роль и черта; навык 1–3 (иногда 4), черта может добавить;
## зарплата — от роли и навыка, черта её меняет.
func _make_person(rng: RandomNumberGenerator) -> Dictionary:
	var role: String = roles.keys()[rng.randi() % roles.size()]
	var trait_id: String = traits.keys()[rng.randi() % traits.size()]
	var base := rng.randi_range(1, 3) + (1 if rng.randf() < 0.15 else 0)
	var skill := clampi(base + int(traits[trait_id].skill), 1, _skill_max)
	var wage := wage_for(role, skill, trait_id)
	var person := { "id": _next_id, "nick": nicknames[rng.randi() % nicknames.size()], "role": role,
			"skill": skill, "trait": trait_id, "wage": wage, "job": "",
			"loyalty": float(traits[trait_id].get("loyalty", _loyalty_start)), "fear": 0.0, "knows": 0, "bonus_day": 0,
			"xp": 0, "fatigue": 0.0, "off_day": 0, "wounded": 0 }
	_next_id += 1
	return person


## Зарплата за день: от роли и навыка, черта её меняет.
func wage_for(role: String, skill: int, trait_id: String) -> int:
	var info: Dictionary = roles[role]
	return roundi((float(info.wage_base) + float(info.wage_per_skill) * skill) * float(traits[trait_id].wage))


## Лучший навык среди нанятых этой роли (где бы ни работали), 0 — нет таких.
func best_skill(role: String) -> int:
	var best := 0
	for person: Dictionary in people:
		if person.role == role:
			best = maxi(best, int(person.skill))
	return best


func get_person(id: int) -> Dictionary:
	for person: Dictionary in people:
		if person.id == id:
			return person
	return {}


func get_candidate(id: int) -> Dictionary:
	for person: Dictionary in candidates:
		if person.id == id:
			return person
	return {}


## Перевести кандидата в бригаду.
func hire(id: int) -> Dictionary:
	var person := get_candidate(id)
	if person.is_empty():
		return person
	candidates.erase(person)
	people.append(person)
	return person


func fire(id: int) -> void:
	people.erase(get_person(id))


## Может ли человек этой роли работать в здании такого типа.
func can_work_in(person: Dictionary, kind: String) -> bool:
	return roles[person.role].works_in.has(kind)


## Кто работает в здании (с ролью role, если указана).
func working_at(property_id: String, role: String = "") -> Array:
	return people.filter(func(person: Dictionary) -> bool:
		return person.job == property_id and (role == "" or person.role == role))


## Лучший по навыку из тех, кто вышел на работу в здании, или {}.
func best_at(property_id: String, role: String) -> Dictionary:
	var best := {}
	for person: Dictionary in working_at(property_id, role):
		if present.get(person.id, true) and (best.is_empty() or person.skill > best.skill):
			best = person
	return best


## Здание продано или съехали — люди остаются без места.
func unassign_from(property_id: String) -> void:
	for person: Dictionary in working_at(property_id):
		person.job = ""


func trait_value(person: Dictionary, key: String, default: Variant) -> Variant:
	return traits[person.trait].get(key, default)


func total_wages() -> int:
	var total := 0
	for person: Dictionary in people:
		total += int(person.wage)
	return total


func to_dict() -> Dictionary:
	return { "people": people.duplicate(true), "candidates": candidates.duplicate(true), "next_id": _next_id }


func load_dict(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	people = _restore(data.get("people", []))
	candidates = _restore(data.get("candidates", []))


func _restore(list: Array) -> Array:
	var result: Array = []
	for p: Dictionary in list:
		if not roles.has(p.role) or not traits.has(p.trait):
			continue
		result.append({ "id": int(p.id), "nick": String(p.nick), "role": String(p.role), "skill": int(p.skill),
				"trait": String(p.trait), "wage": int(p.wage), "job": String(p.job),
				"loyalty": float(p.get("loyalty", traits[p.trait].get("loyalty", _loyalty_start))),
				"fear": float(p.get("fear", 0.0)), "knows": int(p.get("knows", 0)), "bonus_day": int(p.get("bonus_day", 0)),
				"xp": int(p.get("xp", 0)), "fatigue": float(p.get("fatigue", 0.0)), "off_day": int(p.get("off_day", 0)),
				"wounded": int(p.get("wounded", 0)) })
	return result
