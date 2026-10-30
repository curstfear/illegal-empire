class_name Gangs
extends RefCounted
## Банды города: у каждой босс с характером, люди, общак, отношение к тебе (−100…100)
## и влияние в районах. Влияние — очки 0–100 на район, сумма в районе не больше 100;
## «player» — твоё влияние, остаток — ничья земля. Хозяин района — у кого больше всех влияния (и не меньше порога).
## Требования и предложения банд ждут ответа игрока несколько дней. С бандой можно заключить договор
## (ненападение, налог за мир, перемирие, союз) — пока он действует, она тебя не трогает.
## Деньги игрока и случайности считает GameSession — здесь только состояние и правила.

const PLAYER := "player"
## Уровни отношения: от верхней границы вниз.
const LEVELS: Array[String] = ["friend", "neutral", "rival", "enemy"]

## Описания банд из data/gangs.json и характеры боссов.
var defs: Array = []
var tempers: Dictionary = {}
## Состояние банды по id: { people, cash, relation, revenge } (revenge — отказал или промолчал, ночью мстят).
var state: Dictionary = {}
## Влияние по районам: { district: { gang_id | "player": очки } }.
var influence: Dictionary = {}
## Уровень отношения, о котором уже сообщили игроку (чтобы сказать, когда он меняется).
var known_level: Dictionary = {}
## Требования и предложения: { id, gang, kind ("demand" — доля, "deal" — товар со скидкой),
## amount (сумма), good, units, expires (последний день для ответа) }.
var offers: Array = []
## Сколько ты наторговал нелегального в каждом районе с прошлой ночи (банды требуют с этого долю). Не сохраняется.
var turf_sales: Dictionary = {}
## Договоры по id банды: { kind, until (последний день; 0 — бессрочно), paid_day (день следующего платежа налога) }.
var treaties: Dictionary = {}
## День последней встречи с боссом по id банды (встречаться можно раз в день).
var met_day: Dictionary = {}

var _next_offer_id := 1

var _balance: Dictionary


func _init(data: Dictionary, district_list: Array, balance: Dictionary) -> void:
	defs = data.gangs
	tempers = data.tempers
	_balance = balance
	for district: Dictionary in district_list:
		influence[district.id] = {}
	for gang: Dictionary in defs:
		state[gang.id] = { "people": int(gang.people), "cash": int(gang.cash), "relation": float(gang.relation), "revenge": false }
		influence[gang.home][gang.id] = float(balance.gang_home_influence)
		known_level[gang.id] = level(gang.id)


func get_def(id: String) -> Dictionary:
	for gang: Dictionary in defs:
		if gang.id == id:
			return gang
	return {}


func temper(id: String) -> Dictionary:
	return tempers[get_def(id).temper]


func color(id: String) -> Color:
	var c: Array = get_def(id).color
	return Color(c[0], c[1], c[2])


func share(district: String, who: String) -> float:
	return float(influence[district].get(who, 0.0))


func free_share(district: String) -> float:
	var used := 0.0
	for who: String in influence[district]:
		used += float(influence[district][who])
	return maxf(0.0, 100.0 - used)


## Хозяин района: id банды, "player" или "" — ничья земля.
func owner(district: String) -> String:
	var best := ""
	var best_points := float(_balance.gang_owner_min) - 0.001
	for who: String in influence[district]:
		if float(influence[district][who]) > best_points:
			best = who
			best_points = influence[district][who]
	return best


## Банда — хозяин района ("" — если район ничей или твой).
func gang_owner(district: String) -> String:
	var who := owner(district)
	return "" if who == PLAYER else who


## Районы, где хозяин — эта банда (или игрок).
func territories(who: String) -> Array:
	return influence.keys().filter(func(d: String) -> bool: return owner(d) == who)


## Твоё влияние растёт: сначала занимаешь ничью землю, потом теснишь самую сильную банду района —
## торговлей медленно (доля push), силой (разборки) — сразу (push = 1). Возвращает, у какой банды отнято (или "").
func player_gain(district: String, amount: float, push: float = -1.0) -> String:
	if push < 0.0:
		push = float(_balance.gang_trade_push)
	var points: Dictionary = influence[district]
	var from_free := minf(amount, free_share(district))
	points[PLAYER] = share(district, PLAYER) + from_free
	var rest := amount - from_free
	if rest <= 0.0:
		return ""
	var rival := ""
	for who: String in points:
		if who != PLAYER and (rival == "" or float(points[who]) > float(points[rival])):
			rival = who
	if rival == "" or float(points[rival]) <= 0.0:
		return ""
	var taken := minf(rest * push, float(points[rival]))
	points[rival] = float(points[rival]) - taken
	points[PLAYER] = share(district, PLAYER) + taken
	return rival


## Отнять влияние у конкретной банды силой (после разборки): её очки переходят тебе.
func take_from(district: String, gang_id: String, amount: float) -> void:
	var taken := minf(amount, share(district, gang_id))
	influence[district][gang_id] = share(district, gang_id) - taken
	influence[district][PLAYER] = share(district, PLAYER) + taken


func relation(id: String) -> float:
	return float(state[id].relation)


func change_relation(id: String, amount: float) -> void:
	state[id].relation = clampf(float(state[id].relation) + amount, -100.0, 100.0)


## Уровень отношения: friend (дружба), neutral, rival (соперники), enemy (вражда).
func level(id: String) -> String:
	var r := relation(id)
	if r >= float(_balance.gang_friend_at):
		return "friend"
	if r > float(_balance.gang_rival_at):
		return "neutral"
	if r > float(_balance.gang_enemy_at):
		return "rival"
	return "enemy"


## Насколько опасно в районе для твоих перевозок: от отношения хозяина района (ничья или твоя земля — немного).
## С кем договор — тот засад не устраивает.
func hostility(district: String) -> float:
	var host := gang_owner(district)
	if host != "" and has_treaty(host):
		return 0.0
	return float(_balance.gang_hostility[level(host) if host != "" else "none"])


func treaty(id: String) -> Dictionary:
	return treaties.get(id, {})


func has_treaty(id: String) -> bool:
	return treaties.has(id)


## Номер уровня отношения: 0 — дружба … 3 — вражда (для условий договоров).
func level_rank(id: String) -> int:
	return LEVELS.find(level(id))


## Случайное действие враждебной банды по весам характера босса (только из allowed).
func pick_action(id: String, allowed: Array, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = temper(id).actions
	var total := 0.0
	for action: String in allowed:
		total += float(weights.get(action, 0))
	var roll := rng.randf() * total
	for action: String in allowed:
		roll -= float(weights.get(action, 0))
		if roll < 0.0:
			return action
	return allowed[-1]


func add_offer(offer: Dictionary) -> Dictionary:
	offer.id = _next_offer_id
	_next_offer_id += 1
	offers.append(offer)
	return offer


func get_offer(id: int) -> Dictionary:
	for offer: Dictionary in offers:
		if offer.id == id:
			return offer
	return {}


func offer_from(gang_id: String) -> Dictionary:
	for offer: Dictionary in offers:
		if offer.gang == gang_id:
			return offer
	return {}


## Сила банды для будущих разборок: люди и деньги на снаряжение.
func strength(id: String) -> int:
	var st: Dictionary = state[id]
	return int(st.people) * int(_balance.gang_strength_per_person) + int(st.cash) / int(_balance.gang_cash_per_strength)


## Ночь у банд: твоё влияние выветривается, банды занимают ничью землю у себя дома,
## получают доход со своих районов и вербуют людей. Отношения понемногу остывают к нулю.
## Возвращает отчёт.
func night(rng: RandomNumberGenerator) -> Array:
	var report: Array = []
	for district: String in influence:
		var points: Dictionary = influence[district]
		if points.has(PLAYER):
			points[PLAYER] = maxf(0.0, float(points[PLAYER]) - float(_balance.player_influence_decay))
	for gang: Dictionary in defs:
		var id: String = gang.id
		var st: Dictionary = state[id]
		var home: String = gang.home
		var regrow := minf(float(_balance.gang_influence_regrow), free_share(home))
		regrow = minf(regrow, maxf(0.0, float(_balance.gang_home_influence) - share(home, id)))
		influence[home][id] = share(home, id) + regrow
		var points := 0.0
		for district: String in influence:
			points += share(district, id)
		st.cash = int(st.cash) + roundi(points * float(_balance.gang_income_per_point))
		if int(st.people) < int(_balance.gang_people_max) and int(st.cash) >= int(_balance.gang_recruit_cost) \
				and rng.randf() < float(_balance.gang_recruit_chance):
			st.cash = int(st.cash) - int(_balance.gang_recruit_cost)
			st.people = int(st.people) + 1
		var drift := float(_balance.gang_relation_drift) * float(temper(id).forgive)
		var r := relation(id)
		change_relation(id, -signf(r) * minf(absf(r), drift))
	return report


func to_dict() -> Dictionary:
	return { "state": state.duplicate(true), "influence": influence.duplicate(true), "known_level": known_level.duplicate(),
			"offers": offers.duplicate(true), "next_offer_id": _next_offer_id, "treaties": treaties.duplicate(true),
			"met_day": met_day.duplicate() }


func load_dict(data: Dictionary) -> void:
	for id: String in data.get("state", {}):
		if state.has(id):
			var st: Dictionary = data.state[id]
			state[id] = { "people": int(st.people), "cash": int(st.cash), "relation": float(st.relation),
					"revenge": bool(st.get("revenge", false)) }
	offers = []
	for offer: Dictionary in data.get("offers", []):
		offers.append({ "id": int(offer.id), "gang": String(offer.gang), "kind": String(offer.kind), "amount": int(offer.amount),
				"good": String(offer.good), "units": int(offer.units), "expires": int(offer.expires) })
	_next_offer_id = int(data.get("next_offer_id", 1))
	treaties = {}
	for id: String in data.get("treaties", {}):
		var t: Dictionary = data.treaties[id]
		treaties[id] = { "kind": String(t.kind), "until": int(t.until), "paid_day": int(t.get("paid_day", 0)) }
	met_day = {}
	for id: String in data.get("met_day", {}):
		met_day[id] = int(data.met_day[id])
	for id: String in data.get("known_level", {}):
		known_level[id] = String(data.known_level[id])
	for district: String in data.get("influence", {}):
		if influence.has(district):
			influence[district] = {}
			for who: String in data.influence[district]:
				influence[district][who] = float(data.influence[district][who])
