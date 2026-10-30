class_name GameSession
extends RefCounted
## Одна партия: деньги (чистые и грязные), долги, карман с товаром, день, район,
## рынок, розыск, события, банк, силы, навыки, подработки, сбор, ларёк,
## карман ограниченного размера, недвижимость (склады, лаборатории, фасады и отмыв),
## бригада (повара, дилеры, охрана, курьеры, менеджеры, бухгалтеры, адвокаты, разведчики;
## лояльность, страх, усталость, рост, предательство), перевозки (в том числе на рынок)
## и банды (хозяева районов, отношение к тебе, твоё влияние; ночью требуют долю, сбивают цены,
## нападают на здания и перевозки, переманивают людей, предлагают сделки; разборки с ними — бойцы, снаряжение,
## раненые и погибшие, отчёт о бое и выбор последствий; дипломатия — встречи с боссами, договоры
## о ненападении, налог за мир, перемирие, союз; предательство договоров с обеих сторон)
## и полиция посложнее: детективы ведут дело, спецназ на крупных облавах, «крыша» — продажный полицейский;
## мир из нескольких городов в разных странах (у каждого свои районы, рынок, полиция и банды), перелёты,
## документы (паспорт, визы, подделки) и таможня на границе, грузы между городами (фрахт, пошлина, досмотр);
## бизнес работает по часам, поставщики сами привозят сырьё по утрам, менеджеры выполняют приказы;
## заказы с дедлайном от банд и контактов, ситуации с выбором прямо в городе; ступени карьеры
## (balance.ranks): требования, бонусы к лимитам, дань с твоих районов; крупные дела (ограбления с подготовкой);
## режимы (карьера, песочница, железный), родной город и прошлое героя, цели и концовки (balance.goals, balance.endings);
## события в каждом городе и утренняя газета; мини-истории контактов (data/stories.json): шаги с выбором и заданиями.
## Только логика и числа, никаких узлов сцены — так её легко тестировать и сохранять.
## Действия, о которых надо рассказать игроку, возвращают отчёт: список [ключ_перевода, аргументы].

enum Status { PLAYING, LOST, WON }

const SAVE_VERSION := 3
const START_DISTRICT := "market"

var balance: Dictionary
var market: Market
var police: Police
var events: EventDeck
var bank: Bank
var skills: Skills
var stall: Stall
var properties: Properties
var crew: Crew
var logistics: Logistics
var gangs: Gangs
var world: World
var suppliers: Suppliers
var jobs: Jobs
var documents := Documents.new()
## Подработки и сбор (data/activities.json).
var activities: Array = []
var rng := RandomNumberGenerator.new()

var day: int = 1
var district: String = START_DISTRICT
## Город, где ты сейчас (в нём текущий район).
var city: String
## Силы: тратятся на подработки и сбор, за ночь восстанавливаются.
var energy: int
## Чистые — от легальной торговли, грязные — от нелегальной.
var clean: int
var dirty: int
## Сколько чистых денег заработано за игру (это «честная история» для банка).
var clean_earned: int = 0
var debt: int
var status: Status = Status.PLAYING
## Срок ближайшего платежа (номер дня, в конце которого проверяем).
var next_payment_day: int
## Сколько заплачено ростовщику с прошлого срока.
var paid_this_period: int = 0
## Сколько штук каждого товара в кармане и сколько за них заплачено всего.
var inventory: Dictionary = {}
var spent_on: Dictionary = {}
## Идёт проверка полиции: { "bribe": сумма }. Пока не решена, торговать нельзя.
var pending_check: Dictionary = {}
## Чемодан с двойным дном: на таможне досматривают реже.
var smuggle_case: bool = false
## День последнего ареста (для визы в США нужна чистая история).
var last_arrest_day: int = -1000
## Итоги прошлых дней для графиков: все деньги (с вкладом) и самый большой розыск.
var money_history: Array = []
var heat_history: Array = []
## Снаряжение бригады: уровень 0–3 (balance.gear_levels), усиливает бойцов и охрану в драке.
var gear: int = 0
## Итог последней разборки, пока игрок не закрыл отчёт: { gang, district, tactic, win, power, defense,
## wounded: [клички], dead: [клички], gang_losses, heat }. Пока он есть, действовать нельзя
## (после победы надо выбрать последствия).
var fight_result: Dictionary = {}
## Сколько часов текущего дня уже отработал бизнес (0–24 от 06:00): ларёк, касса, дилеры, рейсы.
var hours_done: float = 0.0
## Дробные остатки почасовой работы (полпачки, $0.4 кассы): { ключ: доля }.
var _carry: Dictionary = {}
## Продажи за день для итога в журнале: { ключ: { "income", "sold", "args" } }.
var _sales: Dictionary = {}
## Сколько принесло каждое место сегодня: { id здания или "@район": $ } — для подписей в городе.
var income_today: Dictionary = {}
## Деньги, которые всплывут над городом: [[место, сумма, чистые]]. Забирает и очищает GameState.
var popups: Array = []
## Приказы менеджерам по зданиям: { id здания: { "brew": "auto" | "none" | id рецепта,
## "launder_keep": сколько грязных оставлять на руках (−1 — не отмывать) } }.
var manager_orders: Dictionary = {}
## Соседи лабораторий сегодня: { id здания: "calm" (заплатили — не донесут) или "angry" (донесут вдвое охотнее) }.
var neighbor_mood: Dictionary = {}
## Ступень карьеры (номер в balance.ranks) — только растёт. Для неё: всего заработано и сдано заказов.
var rank: int = 0
var earned_total: int = 0
var orders_done: int = 0
## Крупные дела мира (data/world.json, "operations") и их состояние: { id: { "preps": [подготовка], "ready": день } }.
var op_defs: Array = []
var operations: Dictionary = {}
## Удачных крупных дел всего и из них — хранилищ банков (для высших ступеней).
var ops_done: int = 0
var vaults_done: int = 0
## Свой человек на таможне по зонам (schengen, turkey, usa): { зона: день следующей платы }.
var insiders: Dictionary = {}
## Режим партии (balance.modes): career — с долгом, sandbox — без долга, iron — одна жизнь (сохранение стирается).
var mode: String = "career"
## Родной город (паспорт оформляют здесь) и прошлое героя (balance.backgrounds, "" — без прошлого).
var home_city: String
var background: String = ""
## Сколько раз арестован (в железном режиме последний арест — пожизненный срок).
var arrests: int = 0
## Где побывал (для цели «5 городов в 3 странах»).
var visited: Dictionary = {}
## Сколько заработано грязными (доля грязного решает «чистую» концовку).
var dirty_earned: int = 0
## Чем кончилась партия (ключ balance.endings или "debt" / "prison" для провала); "" — ещё играем.
var ending: String = ""
## Концовка, которую можно взять прямо сейчас (игрок решает: закончить или играть дальше),
## и концовки, от которых он уже отказался (второй раз не предлагаем).
var ending_offer: String = ""
var endings_declined: Array = []
## Утренняя газета: заголовки [ключ, аргументы, вид] (вид: event, rumor, world, you, tip, joke) и прочитана ли.
var news: Array = []
var news_read: bool = true
## Мини-истории контактов (data/stories.json). Идущие: { id: { "step", "city", "show" (день, с которого видно),
## "deadline" (последний день задания, −1 — без срока) } }; закончившиеся: { id: true }.
## Бонусы историй складываются с бонусами ступеней (см. perk): { ключ: число }.
var story_defs: Array = []
var stories: Dictionary = {}
var stories_done: Dictionary = {}
var story_perks: Dictionary = {}

var money: int:
	get:
		return clean + dirty


func _init(balance_data: Dictionary, goods: Array, districts: Array, event_list: Array,
		activity_list: Array, property_list: Array, recipe_list: Array, crew_data: Dictionary,
		gang_data: Dictionary, world_data: Dictionary, seed_value: int = 0) -> void:
	balance = balance_data
	market = Market.new(goods, districts, balance)
	police = Police.new(districts, balance)
	events = EventDeck.new(event_list, balance)
	bank = Bank.new(balance)
	skills = Skills.new(balance)
	stall = Stall.new(goods)
	properties = Properties.new(property_list, recipe_list, goods)
	crew = Crew.new(crew_data, int(balance_data.crew_skill_max), float(balance_data.loyalty_start))
	logistics = Logistics.new(balance_data.vehicles)
	gangs = Gangs.new(gang_data, districts, balance)
	world = World.new(world_data, districts, balance)
	suppliers = Suppliers.new(world_data.get("suppliers", []))
	jobs = Jobs.new(world_data.get("clients", []))
	op_defs = world_data.get("operations", [])
	story_defs = GameData.load_stories()
	city = world.home
	home_city = city
	visited[city] = true
	activities = activity_list
	energy = balance.energy_max
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	clean = balance.start_money
	dirty = 0
	debt = balance.start_debt
	next_payment_day = balance.payment_interval_days
	for good: Dictionary in goods:
		inventory[good.id] = 0
		spent_on[good.id] = 0
	_roll_events(day + 1)
	crew.roll_candidates(rng, int(balance.crew_candidates))
	_roll_offers()
	news = _make_news()
	news_read = false


## Старт новой партии: режим, родной город и прошлое героя (раздел 3.1). Зовётся сразу после создания.
func setup(new_mode: String, home: String, past: String) -> void:
	mode = new_mode if balance.modes.has(new_mode) else "career"
	if balance.home_cities.has(home):
		var start: Dictionary = balance.home_cities[home]
		home_city = home
		city = home
		district = world.get_city(home).start
		visited = { city: true }
		clean = int(start.money)
		debt = int(start.debt)
	var rules: Dictionary = balance.modes[mode]
	if not rules.debt:
		debt = 0
	if rules.has("money"):
		clean = int(rules.money)
	background = past if balance.backgrounds.has(past) else ""
	if background != "":
		var info: Dictionary = balance.backgrounds[background]
		skills.set_level(info.skill, int(info.level))
		if info.has("vehicle"):
			logistics.add_vehicle(info.vehicle)
	_roll_offers()


## Бонус прошлого героя (balance.backgrounds): скидка на подделки, меньше брака и т.п.; 0 — нет.
func background_perk(key: String) -> float:
	return float(balance.backgrounds[background].get(key, 0.0)) if background != "" else 0.0


# --- Мини-истории контактов ---

func story_def(id: String) -> Dictionary:
	for def: Dictionary in story_defs:
		if def.id == id:
			return def
	return {}


func story_step(id: String) -> Dictionary:
	return story_def(id).steps[stories[id].step]


## Истории, которые сейчас видно (шаг уже наступил), в порядке начала.
func visible_stories() -> Array:
	return stories.keys().filter(func(id: String) -> bool: return int(stories[id].show) <= day)


## Можно ли начать историю: ещё не была, условия "when" выполнены.
func story_ready(def: Dictionary) -> bool:
	if stories.has(def.id) or stories_done.has(def.id):
		return false
	for key: String in def.when:
		var need := int(def.when[key])
		var ok := true
		match key:
			"day":
				ok = day >= need
			"debt":
				ok = debt > 0
			"rank":
				ok = rank >= need
			"heat":
				ok = police.max_heat() >= need
			"arrests":
				ok = arrests >= need
			_:
				ok = rank_stat(key) >= need
		if not ok:
			return false
	return true


## Утро: с шансом начинается новая история (не больше двух сразу). Контакт ищет тебя в твоём городе,
## а «родные» контакты ("city": "home") — только в родном.
func _stories_morning() -> Array:
	if stories.size() >= int(balance.story_active_max) or rng.randf() >= float(balance.story_chance):
		return []
	var ready := story_defs.filter(func(def: Dictionary) -> bool:
		return story_ready(def) and (def.city != "home" or city == home_city))
	if ready.is_empty():
		return []
	var def: Dictionary = ready[rng.randi() % ready.size()]
	stories[def.id] = { "step": "start", "city": city, "show": day, "deadline": day + int(balance.story_choice_days) }
	return [["LOG_STORY_NEW", [def.contact_key]]]


## Задание шага выполнимо прямо сейчас (быть в районе нужного вида в городе истории или отдать товар).
func story_task_ready(id: String) -> bool:
	var task: Dictionary = story_step(id).get("task", {})
	match String(task.get("kind", "")):
		"visit":
			return city == stories[id].city and market.get_district(district).get("kind", "") == task.district_kind
		"goods":
			return inventory.get(task.good, 0) >= int(task.amount)
	return false


func can_story_choose(id: String, choice_id: String) -> bool:
	if not can_act() or not stories.has(id) or int(stories[id].show) > day:
		return false
	for choice: Dictionary in story_step(id).get("choices", []):
		if choice.id == choice_id:
			return money >= int(choice.get("cost", 0))
	return false


## Выбор в истории: платим, бросаем кубик (если есть шанс), применяем последствия, идём дальше.
func story_choose(id: String, choice_id: String) -> Array:
	if not can_story_choose(id, choice_id):
		return []
	var step_id: String = stories[id].step
	var choice: Dictionary = story_step(id).choices.filter(func(c: Dictionary) -> bool: return c.id == choice_id)[0]
	var key := "STORY_%s_%s_%s" % [String(id).to_upper(), step_id.to_upper(), choice_id.to_upper()]
	_spend(int(choice.get("cost", 0)))
	var outcome := choice
	var log_key := key + "_LOG"
	if choice.has("chance") and rng.randf() >= float(choice.chance):
		outcome = choice.get("lose", {})
		log_key = key + "_LOSE_LOG"
	return _story_outcome(id, outcome, log_key)


func story_do_task(id: String) -> Array:
	if not can_act() or not stories.has(id) or int(stories[id].show) > day or not story_task_ready(id):
		return []
	var step := story_step(id)
	var task: Dictionary = step.task
	if task.kind == "goods":
		_remove_from_inventory(task.good, int(task.amount))
	return _story_outcome(id, step.done, "STORY_%s_%s_DONE_LOG" % [String(id).to_upper(), String(stories[id].step).to_upper()])


## Последствия и переход: "next" — следующий шаг (через "wait" дней), без него история закончена.
func _story_outcome(id: String, outcome: Dictionary, log_key: String) -> Array:
	var story_city: String = stories[id].city
	_story_effects(outcome.get("effects", {}), story_city)
	var report := [["LOG_STORY", [story_def(id).contact_key, log_key]]]
	var next := String(outcome.get("next", ""))
	if next == "":
		stories.erase(id)
		stories_done[id] = true
		return report
	var step: Dictionary = story_def(id).steps[next]
	var show := day + int(outcome.get("wait", 0))
	var days := int(step.get("days", balance.story_choice_days))
	stories[id] = { "step": next, "city": story_city, "show": show, "deadline": show + days }
	return report


## Последствия истории: деньги, долг, розыск и дело детективов в городе истории, отношение банд города,
## опыт навыков, постоянные бонусы (как у ступеней) и товар в карман.
func _story_effects(effects: Dictionary, story_city: String) -> void:
	for key: String in effects:
		var value: Variant = effects[key]
		match key:
			"clean":
				_earn(int(value), true)
			"dirty":
				_earn(int(value), false)
			"debt":
				debt = maxi(0, debt + int(value))
			"heat":
				for d: Dictionary in world.districts_of(story_city):
					police.add_heat(d.id, float(value))
			"dossier":
				for d: Dictionary in world.districts_of(story_city):
					police.add_dossier(d.id, float(value))
			"relation":
				for gang: Dictionary in gangs.defs:
					if world.city_of(gang.home) == story_city:
						gangs.change_relation(gang.id, float(value))
			"xp":
				for skill: String in value:
					skills.add_xp(skill, int(value[skill]))
			"perk":
				for perk_key: String in value:
					story_perks[perk_key] = float(story_perks.get(perk_key, 0.0)) + float(value[perk_key])
			"goods":
				for good: String in value:
					inventory[good] += int(value[good])


## Конец дня: просроченное задание — провал; на выбор не ответил — контакт перестаёт звонить.
func _expire_stories() -> Array:
	var report: Array = []
	for id: String in visible_stories():
		if int(stories[id].deadline) > day:
			continue
		var step := story_step(id)
		if step.has("task"):
			report.append_array(_story_outcome(id, step.fail, "STORY_%s_%s_FAIL_LOG" % [String(id).to_upper(), String(stories[id].step).to_upper()]))
		else:
			stories.erase(id)
			stories_done[id] = true
			report.append(["LOG_STORY_IGNORED", [story_def(id).contact_key]])
	return report


# --- События и газета ---

## Ночь: новые «завтрашние» события во всех городах; рынку — сегодняшние (своё + мировое по городам).
## for_day — день, когда новые события начнутся (для времени года).
func _roll_events(for_day: int) -> void:
	events.roll(rng, world.cities.map(func(c: Dictionary) -> String: return c.id), for_day, city)
	market.city_events = {}
	for c: Dictionary in world.cities:
		market.city_events[c.id] = events.active_in(c.id)


## Утро: событие в твоём городе — в журнал; разовое влияние событий (розыск, отношение банд) — во всех городах.
func _events_morning() -> Array:
	var report: Array = []
	for c: Dictionary in world.cities:
		for event: Dictionary in events.active_in(c.id):
			if event.has("heat"):
				for d: String in world.districts_of(c.id).map(func(x: Dictionary) -> String: return x.id):
					police.add_heat(d, float(event.heat))
			if event.has("relation"):
				for gang: Dictionary in gangs.defs:
					if world.city_of(gang.home) == c.id:
						gangs.change_relation(gang.id, float(event.relation))
	for event: Dictionary in events.active_in(city):
		report.append(["LOG_EVENT", [event.text_key]])
	news = _make_news()
	news_read = false
	report.append_array(_stories_morning())
	return report


## Утренняя газета: события по городам, мировое, слухи на завтра, заметки о тебе, подсказка по ценам и шутка.
## Заголовок: [ключ, аргументы, вид]; строковые аргументы — ключи перевода.
func _make_news() -> Array:
	var result: Array = []
	if not events.world_today.is_empty():
		result.append([events.world_today.news_key, [], "world"])
	for c: Dictionary in world.cities:
		if events.today.has(c.id):
			result.append([events.today[c.id].news_key, [c.name_key], "event"])
	for c: Dictionary in world.cities:
		if events.rumor_known(c.id):
			result.append(["NEWS_RUMOR", [c.name_key, events.tomorrow[c.id].rumor_key], "rumor"])
	if events.rumors.has("@world") and not events.world_tomorrow.is_empty():
		result.append(["NEWS_RUMOR_WORLD", [events.world_tomorrow.rumor_key], "rumor"])
	result.append_array(_news_about_you())
	var tip := _news_tip()
	if not tip.is_empty():
		result.append(tip)
	result.append(["NEWS_JOKE_%d" % (rng.randi() % int(balance.news_jokes) + 1), [], "joke"])
	return result


## Мир замечает тебя: громкий розыск, свои районы, война с бандой, слава высоких ступеней.
func _news_about_you() -> Array:
	var result: Array = []
	var hottest := ""
	for d: String in police.heat:
		if hottest == "" or police.heat[d] > police.heat[hottest]:
			hottest = d
	if hottest != "" and police.heat[hottest] >= float(balance.news_heat):
		result.append(["NEWS_YOU_HEAT", [market.get_district(hottest).name_key], "you"])
	var mine := gangs.territories(Gangs.PLAYER)
	if not mine.is_empty():
		result.append(["NEWS_YOU_DISTRICT", [market.get_district(mine[rng.randi() % mine.size()]).name_key], "you"])
	for gang: Dictionary in gangs.defs:
		if gangs.level(gang.id) == "enemy":
			result.append(["NEWS_GANG_WAR", [gang.name_key, world.get_city(world.city_of(gang.home)).name_key], "you"])
			break
	if rank >= int(balance.news_legend_rank):
		result.append(["NEWS_YOU_LEGEND", [rank_name_key()], "you"])
	return result


## Подсказка дня: товар с самой большой разницей цен между городами — где купить и где продать.
func _news_tip() -> Array:
	var best := 0.0
	var tip: Array = []
	for good: Dictionary in market.goods:
		var low := { "price": 0, "city": "" }
		var high := { "price": 0, "city": "" }
		for d: Dictionary in market.districts:
			if not d.has_market or not market.trades(d.id, good.id):
				continue
			var buy := market.buy_price(d.id, good.id)
			var sell := market.sell_price(d.id, good.id)
			if low.city == "" or buy < low.price:
				low = { "price": buy, "city": String(d.city) }
			if sell > high.price:
				high = { "price": sell, "city": String(d.city) }
		if low.city == "" or low.city == high.city:
			continue
		var ratio := float(high.price) / maxf(1.0, low.price)
		if ratio > best:
			best = ratio
			tip = ["NEWS_TIP", [good.name_key, world.get_city(low.city).name_key, world.get_city(high.city).name_key], "tip"]
	return tip if best >= float(balance.news_tip_ratio) else []


## Газету прочитали (закрыли карточку) — до следующего утра не показываем.
func read_news() -> void:
	news_read = true


## Все деньги: чистые, грязные и вклад в банке.
func net_money() -> int:
	return money + bank.deposit


## Ряды для графиков: прошлые дни и сейчас (старые слева).
func money_series() -> Array:
	return money_history + [net_money()]


func heat_series() -> Array:
	return heat_history + [police.max_heat()]


func _remember_day() -> void:
	money_history.append(net_money())
	heat_history.append(police.max_heat())
	if money_history.size() > Market.HISTORY_DAYS - 1:
		money_history.pop_front()
		heat_history.pop_front()


func can_act() -> bool:
	return status == Status.PLAYING and pending_check.is_empty() and fight_result.is_empty()


# --- Рынок ---

func buy_price(id: String) -> int:
	return market.buy_price(district, id)


## Сколько дадут за 1 штуку (с учётом Торговли).
func sell_price(id: String) -> int:
	return roundi(market.sell_price(district, id) * skills.sell_multiplier())


## Сколько дадут за amount штук подряд (с учётом Торговли и насыщения).
func quote_sell(id: String, amount: int) -> int:
	return roundi(market.quote_sell(district, id, amount) * skills.sell_multiplier())


func has_market() -> bool:
	return market.get_district(district).has_market


## Сколько штук можно купить: хватает и денег, и места в кармане.
func max_affordable(id: String) -> int:
	return mini(market.max_affordable(district, id, money), pocket_free() / good_size(id))


# --- Карман ---

func good_size(id: String) -> int:
	return int(market.get_good(id).get("size", 1))


## Сколько мест в кармане занято (тяжёлый товар занимает больше).
func pocket_used() -> int:
	var used := 0
	for id: String in inventory:
		used += inventory[id] * good_size(id)
	return used


func pocket_free() -> int:
	return maxi(0, int(balance.pocket_size) - pocket_used())


func buy(id: String, amount: int) -> bool:
	if not can_act() or not market.trades(district, id) or amount <= 0 or amount * good_size(id) > pocket_free():
		return false
	var cost := market.quote_buy(district, id, amount)
	if cost > money:
		return false
	_spend(cost)
	inventory[id] += amount
	spent_on[id] += cost
	market.apply_trade(district, id, amount)
	_after_deal(id, amount)
	return true


func sell(id: String, amount: int) -> bool:
	if not can_act() or not market.trades(district, id) or amount <= 0 or amount > inventory[id]:
		return false
	var revenue := quote_sell(id, amount)
	_remove_from_inventory(id, amount)
	market.apply_trade(district, id, -amount)
	_earn(revenue, market.get_good(id).legal)
	skills.add_xp("trade", ceili(float(revenue) / balance.xp_trade_per_dollars))
	if not market.get_good(id).legal:
		_gang_notice(district, revenue)
	_after_deal(id, amount)
	return true


func _remove_from_inventory(id: String, amount: int) -> void:
	spent_on[id] -= roundi(float(spent_on[id]) * amount / inventory[id])
	inventory[id] -= amount


func _earn(amount: int, is_clean: bool) -> void:
	earned_total += amount
	if is_clean:
		clean += amount
		clean_earned += amount
	else:
		dirty += amount
		dirty_earned += amount


## Средняя цена, по которой куплен товар в кармане (0, если пусто).
func average_cost(id: String) -> int:
	if inventory[id] == 0:
		return 0
	return roundi(float(spent_on[id]) / inventory[id])


## Сколько стоит весь нелегальный товар в кармане по ценам этого района.
func illegal_goods_value() -> int:
	var total := 0
	for good: Dictionary in market.goods:
		if not good.legal:
			total += sell_price(good.id) * inventory[good.id]
	return total


## Переезд в другой район своего города. Время в пути отсчитывают часы.
func travel(to_district: String) -> bool:
	if not can_act() or to_district == district or market.get_district(to_district).is_empty() \
			or world.city_of(to_district) != city:
		return false
	district = to_district
	skills.add_xp("driving", int(balance.xp_travel))
	return true


## Сколько часов занимает переезд (Вождение сокращает).
func travel_hours() -> float:
	return float(balance.travel_hours) * skills.travel_multiplier()


# --- Дела: подработки и сбор ---

func get_activity(id: String) -> Dictionary:
	for activity: Dictionary in activities:
		if activity.id == id:
			return activity
	return {}


## Дела, доступные в текущем районе.
func local_activities() -> Array:
	return activities.filter(func(a: Dictionary) -> bool: return a.district == district)


## Сколько заплатят за подработку (с учётом Харизмы).
func activity_pay(activity: Dictionary) -> int:
	var mult := skills.hack_pay_multiplier() if activity.skill == "hacking" else skills.pay_multiplier()
	return roundi(activity.pay * mult)


## Сколько примерно соберёшь: [от, до] (с учётом Ремесла).
func activity_yield(activity: Dictionary) -> Array:
	var mult := skills.yield_multiplier()
	return [roundi(activity.yield_min * mult), roundi(activity.yield_max * mult)]


## Можно ли взяться за дело. Хватит ли часов в дне — решают часы (GameState).
func can_do_activity(id: String) -> bool:
	var activity := get_activity(id)
	# Угнанную машину надо куда-то поставить — нужно свободное место в гараже.
	if activity.get("kind", "") == "steal_car" and logistics.vehicles.size() >= limit("vehicles_max"):
		return false
	if activity.get("kind", "") == "ring_fight" and ring_fighter().is_empty():
		return false
	if activity.get("kind", "") == "street_race" and (race_vehicle().is_empty() or money < int(balance.race_entry)):
		return false
	return can_act() and not activity.is_empty() and activity.district == district \
			and energy >= int(activity.energy)


## Сделать дело. Нелегальное может сорваться, если заметит полиция,
## а при большом розыске провал заканчивается арестом.
func do_activity(id: String) -> Array:
	if not can_do_activity(id):
		return []
	var activity := get_activity(id)
	energy -= int(activity.energy)
	var level_before := skills.level(activity.skill)
	skills.add_xp(activity.skill, int(balance.xp_activity))
	var report: Array = []
	if not activity.legal:
		_add_heat(activity.heat)
		if _police_noticed():
			if police.heat[district] >= float(balance.activity_arrest_heat):
				return arrest()
			police.add_heat(district, balance.activity_bust_heat)
			return [["LOG_ACTIVITY_BUSTED", [activity.name_key]]]
	if activity.kind == "job":
		var pay := activity_pay(activity)
		_earn(pay, activity.legal)
		report.append(["LOG_JOB_DONE", [activity.name_key, pay]])
	elif activity.kind == "steal_car":
		report.append_array(_steal_car())
	elif activity.kind == "ring_fight":
		report.append_array(_ring_fight())
	elif activity.kind == "street_race":
		report.append_array(_street_race())
	else:
		var range_ := activity_yield(activity)
		var found := rng.randi_range(range_[0], range_[1])
		# Сколько влезло в карман — столько и унёс.
		var amount := mini(found, pocket_free() / good_size(activity.good))
		inventory[activity.good] += amount
		report.append(["LOG_GATHERED", [amount, market.get_good(activity.good).name_key]])
		if amount < found:
			report.append(["LOG_POCKET_FULL", [found - amount]])
	if skills.level(activity.skill) > level_before:
		report.append(["LOG_SKILL_UP", ["SKILL_" + activity.skill.to_upper(), skills.level(activity.skill)]])
	return report


# --- Ларёк ---

func can_buy_stall() -> bool:
	return can_act() and not stall.owned and clean >= int(balance.stall_price)


## Ларёк покупается только на чистые деньги.
func buy_stall() -> bool:
	if not can_buy_stall():
		return false
	clean -= int(balance.stall_price)
	stall.owned = true
	return true


## Выложить в ларёк весь товар этого вида из кармана. Только стоя на рынке.
func can_stock_stall(id: String) -> bool:
	return can_act() and stall.owned and district == Stall.DISTRICT and stall.accepts(id) and inventory[id] > 0


func stock_stall(id: String) -> bool:
	if not can_stock_stall(id):
		return false
	stall.stock[id] += inventory[id]
	_remove_from_inventory(id, inventory[id])
	return true


## Ларёк продаёт весь день понемногу (share — доля дня) по полной цене рынка.
func _stall_hours(share: float) -> void:
	if not stall.owned:
		return
	for id: String in stall.stock:
		var good := market.get_good(id)
		var sold := mini(stall.stock[id], _take_carry("stall:" + id, float(good.stall_daily) * share))
		if sold == 0:
			continue
		# Ларёк продаёт без наценки перекупщика, но насыщение рынка действует.
		var revenue := roundi(market.quote_sell(Stall.DISTRICT, id, sold) / balance.sell_spread)
		stall.stock[id] -= sold
		market.apply_trade(Stall.DISTRICT, id, -sold)
		if not good.legal:
			police.add_heat(Stall.DISTRICT, good.heat * sold * skills.heat_multiplier())
		_earn(revenue, good.legal)
		_add_sales("stall:" + ("clean" if good.legal else "dirty"), revenue, sold)
		_popup("@" + Stall.DISTRICT, revenue, good.legal)


## Ночью — итог ларька за день в журнал и плата за место.
func _run_stall() -> Array:
	if not stall.owned:
		return []
	var report: Array = []
	var total_clean := int(_sales.get("stall:clean", {}).get("income", 0))
	var total_dirty := int(_sales.get("stall:dirty", {}).get("income", 0))
	if total_dirty > 0:
		report.append(["LOG_STALL_SOLD", [total_clean, total_dirty]])
	elif total_clean > 0:
		report.append(["LOG_STALL_SOLD_CLEAN", [total_clean]])
	var fee: int = balance.stall_daily_fee
	var from_clean := mini(fee, clean)
	clean -= from_clean
	debt += fee - from_clean
	return report


# --- Недвижимость ---

## Стоишь ли в районе здания (всё, кроме просмотра, — только на месте).
func at_property(id: String) -> bool:
	return properties.get_def(id).district == district


func can_buy_property(id: String) -> bool:
	return can_act() and at_property(id) and not properties.state[id].owned \
			and clean >= int(properties.get_def(id).buy_price)


## Покупка — только на чистые деньги (сделка с документами).
func buy_property(id: String) -> bool:
	if not can_buy_property(id):
		return false
	clean -= int(properties.get_def(id).buy_price)
	properties.state[id].owned = true
	properties.state[id].rented = false
	return true


## Аренду платим каждую ночь; чтобы начать, нужны чистые на первые сутки.
func can_rent_property(id: String) -> bool:
	return can_act() and at_property(id) and not properties.is_mine(id) \
			and clean >= int(properties.get_def(id).rent)


func rent_property(id: String) -> bool:
	if not can_rent_property(id):
		return false
	properties.state[id].rented = true
	return true


func can_use_property(id: String) -> bool:
	return can_act() and at_property(id) and properties.is_mine(id)


## Положить весь товар этого вида из кармана в здание (сколько влезет).
func store_goods(id: String, good: String) -> int:
	if not can_use_property(id):
		return 0
	var amount := mini(inventory[good], properties.stock_free(id) / good_size(good))
	if amount <= 0:
		return 0
	_remove_from_inventory(good, amount)
	properties.add_stock(id, good, amount)
	return amount


## Забрать весь товар этого вида из здания в карман (сколько влезет).
func take_goods(id: String, good: String) -> int:
	if not can_use_property(id):
		return 0
	var amount := mini(properties.stock_of(id, good), pocket_free() / good_size(good))
	if amount <= 0:
		return 0
	properties.add_stock(id, good, -amount)
	inventory[good] += amount
	return amount


## Запустить варку: столько партий, на сколько хватает сырья в здании.
func start_production(id: String, recipe_id: String) -> int:
	if not can_use_property(id):
		return 0
	var count := properties.max_batches(id, recipe_id)
	if count <= 0:
		return 0
	properties.start_batches(id, recipe_id, count)
	return count


func lab_upgrade_cost(id: String) -> int:
	var level: int = properties.state[id].level
	if level >= int(balance.lab_levels):
		return 0
	return int(balance.lab_upgrade_cost[level])


## Оборудование покупается «с рук» — подходят любые деньги.
func can_upgrade_lab(id: String) -> bool:
	return can_use_property(id) and lab_upgrade_cost(id) > 0 and money >= lab_upgrade_cost(id)


func upgrade_lab(id: String) -> bool:
	if not can_upgrade_lab(id):
		return false
	_spend(lab_upgrade_cost(id))
	properties.state[id].level += 1
	return true


## Продать купленное здание (часть цены чистыми) или съехать из арендованного.
## Только пустое: без товара, варки и денег в кассе.
func can_sell_property(id: String) -> bool:
	return can_use_property(id) and properties.is_empty(id)


func property_sell_price(id: String) -> int:
	if not properties.state[id].owned:
		return 0
	return roundi(int(properties.get_def(id).buy_price) * float(balance.property_sell_share))


func sell_property(id: String) -> int:
	if not can_sell_property(id):
		return -1
	var price := property_sell_price(id)
	_earn(price, true)
	properties.reset(id)
	crew.unassign_from(id)
	_drop_broken_routes()
	return price


## Улучшение здания (вентиляция, огнетушители, сигнализация, тайник, холодильник, двойная бухгалтерия).
## Ставится «с рук» — подходят любые деньги. Пропадает при продаже и взрыве.
func can_buy_upgrade(id: String, upgrade: String) -> bool:
	return can_use_property(id) and properties.upgrades_for(id, balance.upgrades).has(upgrade) \
			and not properties.has_upgrade(id, upgrade) and money >= int(balance.upgrades[upgrade].cost)


func buy_upgrade(id: String, upgrade: String) -> bool:
	if not can_buy_upgrade(id, upgrade):
		return false
	_spend(int(balance.upgrades[upgrade].cost))
	properties.state[id].upgrades.append(upgrade)
	return true


## Множитель от улучшения: если стоит — его factor, иначе 1.
func _upgrade_factor(id: String, upgrade: String) -> float:
	return float(balance.upgrades[upgrade].factor) if properties.has_upgrade(id, upgrade) else 1.0


## Прибраться: вынести мусор и следы — улики обнуляются, тратятся силы.
func can_cleanup(id: String) -> bool:
	return can_use_property(id) and properties.state[id].evidence > 0.0 and energy >= int(balance.cleanup_energy)


func cleanup(id: String) -> bool:
	if not can_cleanup(id):
		return false
	energy -= int(balance.cleanup_energy)
	properties.state[id].evidence = 0.0
	return true


## Шанс брака партии: от уровня оборудования, меньше с Ремеслом и с поваром.
func defect_chance(id: String) -> float:
	var level: int = properties.state[id].level
	return maxf(0.02, float(balance.lab_defect_chance[level - 1]) - skills.level("craft") * float(balance.defect_per_craft_level)
			- background_perk("defect_cut")
			- _best_skill(id, "cook") * float(balance.cook_defect_per_skill))


## Шанс удачной партии (продукта больше): от оборудования, Ремесла и повара.
func great_chance(id: String) -> float:
	var level: int = properties.state[id].level
	return float(balance.great_batch_chance[level - 1]) + skills.level("craft") * float(balance.great_per_craft_level) \
			+ _best_skill(id, "cook") * float(balance.cook_great_per_skill)


func _best_skill(property_id: String, role: String) -> int:
	var best := crew.best_at(property_id, role)
	return 0 if best.is_empty() else int(best.skill)


## Сколько запаха даст варка этой ночью (вентиляция глушит).
func smell_tonight(id: String) -> float:
	var smell := 0.0
	for batch: Dictionary in properties.state[id].batches:
		smell += float(properties.get_recipe(batch.recipe).smell) * int(batch.count)
	return smell * _upgrade_factor(id, "vent") * skills.heat_multiplier()


## Шанс, что соседи донесут на запах.
func snitch_chance(id: String) -> float:
	var neighbors := float(properties.get_def(id).get("neighbors", 1.0))
	# Соседям заплатили — молчат; проигнорировали жалобу — донесут охотнее.
	match neighbor_mood.get(id, ""):
		"calm":
			return 0.0
		"angry":
			neighbors *= 2.0
	return minf(float(balance.snitch_max), smell_tonight(id) * neighbors * float(balance.snitch_per_smell))


## Комиссия отмыва фасада: бухгалтер в здании её снижает.
func launder_fee(id: String) -> float:
	return maxf(0.02, float(properties.get_def(id).launder_fee) - _best_skill(id, "accountant") * float(balance.accountant_fee_per_skill))


func can_launder(id: String) -> bool:
	return can_use_property(id) and properties.get_def(id).kind == "front" and dirty > 0 \
			and properties.state[id].frozen_days == 0


## Сдать все грязные в кассу фасада: по ночам они выходят чистыми в пределах лимита.
func launder(id: String) -> int:
	if not can_launder(id):
		return 0
	var amount := dirty
	dirty = 0
	properties.state[id].dirty_queue += amount
	return amount


## Ночь для недвижимости: аренда, порча, варка, запах и доносы, пожары и взрывы, улики и облавы,
## отмыв, налоговая. Касса фасадов, кафе и дилеры работают весь день — см. _properties_hours.
func _run_properties() -> Array:
	var report: Array = []
	var goods_legal := {}
	for good: Dictionary in market.goods:
		goods_legal[good.id] = good.legal
	var laundered_share := 0.0
	report.append_array(_roll_presence())
	for prop: Dictionary in properties.mine():
		var id: String = prop.id
		var s: Dictionary = properties.state[id]
		var where: String = prop.district
		if s.rented:
			report.append_array(_pay_property_rent(prop))
		# Вспыльчивые шумят — розыск района растёт.
		for person: Dictionary in crew.working_at(id):
			if crew.present.get(person.id, true):
				police.add_heat(where, float(crew.trait_value(person, "heat", 0)))
		report.append_array(_spoil(prop))
		report.append_array(_run_manager(prop))
		var snitched := false
		if not s.batches.is_empty() and rng.randf() < snitch_chance(id):
			snitched = true
			police.add_heat(where, balance.snitch_heat)
			report.append(["LOG_SNITCHED", [prop.name_key]])
		if prop.kind == "lab" or prop.get("kitchen", false):
			report.append_array(_run_batches(prop))
		var illegal := properties.has_illegal(id, goods_legal)
		var raided := illegal and _property_raided(prop, snitched)
		# «Крыша» предупреждает об облаве — успевают всё вывезти.
		if raided and police.has_krysha(where) and rng.randf() < float(balance.krysha_warn):
			raided = false
			report.append(["LOG_KRYSHA_WARNED", [prop.name_key]])
		if raided:
			var swat := is_swat(id)
			var defenders := _defenders(id)
			var hidden := _lose_property_goods(id, goods_legal, swat)
			police.add_heat(where, balance.activity_bust_heat)
			report.append(["LOG_SWAT_RAID" if swat else "LOG_PROPERTY_RAID", [prop.name_key]])
			if swat:
				report.append_array(_wound_defenders(defenders, float(balance.swat_wound)))
			# Трусливые при облаве сбегают насовсем, остальные злятся.
			for person: Dictionary in crew.working_at(id):
				if crew.trait_value(person, "flees", false):
					crew.fire(person.id)
					report.append(["LOG_CREW_FLED", [person.nick]])
				else:
					_change_loyalty(person, float(balance.loyalty_raid))
			if hidden > 0:
				report.append(["LOG_STASH_SAVED", [hidden]])
		# Улики копятся, пока внутри нелегальное, и сами выветриваются, когда чисто.
		if illegal:
			s.evidence = minf(100.0, s.evidence + float(balance.evidence_per_night))
		else:
			s.evidence = maxf(0.0, s.evidence - float(balance.evidence_decay))
		if prop.kind == "front":
			var limit: int = prop.launder_limit
			var amount := 0 if s.frozen_days > 0 else mini(s.dirty_queue, limit)
			if amount > 0:
				s.dirty_queue -= amount
				var out := roundi(amount * (1.0 - launder_fee(id)))
				# Отмытое уже было заработано грязными — в «всего заработано» второй раз не считаем.
				clean += out
				clean_earned += out
				laundered_share += float(amount) / limit * _upgrade_factor(id, "books") \
						* maxf(0.0, 1.0 - _best_skill(id, "accountant") * float(balance.accountant_tax_per_skill))
				report.append(["LOG_LAUNDERED", [prop.name_key, out]])
			s.frozen_days = maxi(0, s.frozen_days - 1)
	report.append_array(_run_tax(laundered_share))
	return report


# --- Бригада ---

func can_hire(id: int) -> bool:
	var person := crew.get_candidate(id)
	return can_act() and not person.is_empty() and crew.people.size() < limit("crew_max") \
			and money >= int(person.wage)


## Нанять: первый день оплачиваешь сразу (любыми деньгами).
func hire(id: int) -> bool:
	if not can_hire(id):
		return false
	_spend(int(crew.get_candidate(id).wage))
	crew.hire(id)
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


## Уволить. Обиженный (низкая лояльность), который много знает, может пойти в полицию.
func fire(id: int) -> Array:
	var person := crew.get_person(id)
	if not can_act() or person.is_empty():
		return []
	crew.fire(id)
	_drop_broken_routes()
	var report: Array = [["LOG_CREW_FIRED", [person.nick]]]
	if float(person.loyalty) < float(balance.fired_snitch_loyalty) \
			and rng.randf() < knows_share(person) * float(balance.fired_snitch_chance):
		_snitch(person)
		report.append(["LOG_FIRED_SNITCHED", [person.nick]])
	return report


## Сколько человек знает о делах: 0 (новичок) – 1 (знает всё).
func knows_share(person: Dictionary) -> float:
	return minf(1.0, float(person.knows) / float(balance.knows_max))


## Премия: два дня зарплаты сверху — лояльность растёт. Не чаще раза в день.
func bonus_cost(id: int) -> int:
	return int(crew.get_person(id).get("wage", 0)) * int(balance.bonus_wage_days)


func can_give_bonus(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and int(person.bonus_day) != day and money >= bonus_cost(id)


func give_bonus(id: int) -> bool:
	if not can_give_bonus(id):
		return false
	var person := crew.get_person(id)
	_spend(bonus_cost(id))
	person.bonus_day = day
	_change_loyalty(person, float(balance.bonus_loyalty))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


## Надавить: страх растёт (предаёт реже), лояльность падает. Вспыльчивый может хлопнуть дверью.
func can_pressure(id: int) -> bool:
	return can_act() and not crew.get_person(id).is_empty()


func pressure(id: int) -> Array:
	if not can_pressure(id):
		return []
	var person := crew.get_person(id)
	if rng.randf() < float(crew.trait_value(person, "quits_on_pressure", 0.0)):
		crew.fire(id)
		_drop_broken_routes()
		return [["LOG_PRESSURE_QUIT", [person.nick]]]
	person.fear = minf(100.0, float(person.fear) + float(balance.pressure_fear) * float(crew.trait_value(person, "fear_mult", 1.0)))
	_change_loyalty(person, float(balance.pressure_loyalty))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return [["LOG_PRESSURED", [person.nick]]]


## Работал ли человек этой ночью: вышел и был при деле (здание, маршрут или адвокат на связи).
func worked_tonight(person: Dictionary) -> bool:
	if not crew.present.get(person.id, true):
		return false
	return person.job != "" or not logistics.route_of(int(person.id)).is_empty() or person.role == "lawyer"


## Опыт и усталость за ночь. Опыта набралось — навык растёт, а с ним и зарплата.
func _grow(person: Dictionary) -> Array:
	if not worked_tonight(person):
		if int(person.off_day) != day:
			person.fatigue = maxf(0.0, float(person.fatigue) - float(balance.fatigue_rest))
		return []
	person.fatigue = minf(100.0, float(person.fatigue) + float(balance.fatigue_per_night))
	if int(person.skill) >= int(balance.crew_skill_max):
		return []
	person.xp = int(person.xp) + 1
	if int(person.xp) < int(balance.crew_xp_step) * maxi(1, int(person.skill)):
		return []
	person.xp = 0
	person.skill = int(person.skill) + 1
	person.wage = crew.wage_for(person.role, person.skill, person.trait)
	return [["LOG_CREW_SKILL_UP", [person.nick, int(person.skill), int(person.wage)]]]


## Выходной: этой ночью человек не работает и хорошо отдыхает. Раз в день.
func can_give_day_off(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and int(person.off_day) != day


func give_day_off(id: int) -> bool:
	if not can_give_day_off(id):
		return false
	var person := crew.get_person(id)
	person.off_day = day
	person.fatigue = maxf(0.0, float(person.fatigue) - float(balance.fatigue_day_off))
	return true


## Повысить до менеджера: опытный и верный. Зарплата — как у менеджера, лояльность растёт.
func can_promote(id: int) -> bool:
	var person := crew.get_person(id)
	return can_act() and not person.is_empty() and not ["manager", "accountant", "lawyer"].has(person.role) \
			and int(person.skill) >= int(balance.promote_skill) and float(person.loyalty) >= float(balance.promote_loyalty)


func promote(id: int) -> bool:
	if not can_promote(id):
		return false
	var person := crew.get_person(id)
	person.role = "manager"
	person.wage = crew.wage_for("manager", person.skill, person.trait)
	if person.job != "" and not crew.can_work_in(person, properties.get_def(person.job).kind):
		person.job = ""
	for route: Dictionary in logistics.routes.duplicate():
		if route.courier == id:
			logistics.remove_route(route.id)
		elif route.scout == id:
			route.scout = 0
	_change_loyalty(person, float(balance.promote_loyalty_gain))
	skills.add_xp("leadership", int(balance.xp_leadership))
	return true


func _change_loyalty(person: Dictionary, amount: float) -> void:
	person.loyalty = clampf(float(person.loyalty) + amount, 0.0, 100.0)


## Шанс предательства за ночь: только у нелояльных; страх сдерживает.
func betray_chance(person: Dictionary) -> float:
	var below := float(balance.betray_loyalty) - float(person.loyalty)
	if below <= 0.0:
		return 0.0
	return maxf(0.0, below * float(balance.betray_chance_per_point) * (1.0 - float(person.fear) * float(balance.fear_betray_cut))) \
			* skills.betray_multiplier()


## Ночь для отношений: оплаченные чуть больше доверяют, знают больше, страх спадает;
## кто работал — набирается опыта и устаёт, кто отдыхал — восстанавливается;
## нелояльные могут предать: украсть и сбежать, донести или уйти к конкурентам.
func _run_loyalty() -> Array:
	var report: Array = []
	if not crew.people.is_empty():
		skills.add_xp("leadership", 1)
	for person: Dictionary in crew.people.duplicate():
		person.knows = mini(int(balance.knows_max), int(person.knows) + 1)
		report.append_array(_grow(person))
		var change := float(balance.loyalty_paid) + float(crew.trait_value(person, "drift", 0)) + skills.loyalty_bonus()
		if float(person.fear) > float(balance.fear_resent):
			change -= 1.0
		if float(person.fatigue) >= float(balance.fatigue_tired):
			change -= 1.0
		_change_loyalty(person, change)
		person.fear = maxf(0.0, float(person.fear) - float(balance.fear_decay))
		if rng.randf() >= betray_chance(person):
			continue
		crew.fire(person.id)
		var kind: String = crew.trait_value(person, "betray", ["steal", "snitch", "leave"][rng.randi() % 3])
		if kind == "steal":
			report.append(_steal(person))
		elif kind == "snitch":
			_snitch(person)
			report.append(["LOG_BETRAY_SNITCH", [person.nick]])
		else:
			report.append(["LOG_BETRAY_LEFT", [person.nick]])
	_drop_broken_routes()
	return report


## Кража: с места работы — часть товара, иначе — часть грязной налички.
func _steal(person: Dictionary) -> Array:
	var job: String = person.job
	if job != "" and properties.is_mine(job):
		var taken := 0
		for good: String in properties.state[job].stock.keys():
			var n := ceili(properties.stock_of(job, good) * float(balance.betray_steal_share))
			properties.add_stock(job, good, -n)
			taken += n
		if taken > 0:
			return ["LOG_BETRAY_STOLE_GOODS", [person.nick, taken, properties.get_def(job).name_key]]
	var cash := roundi(dirty * float(balance.betray_steal_cash_share))
	dirty -= cash
	return ["LOG_BETRAY_STOLE_CASH", [person.nick, cash]]


## Донос: розыск растёт тем сильнее, чем больше человек знает; на месте работы — улики.
func _snitch(person: Dictionary) -> void:
	var job: String = person.job
	var where := district
	if job != "" and properties.is_mine(job):
		where = properties.get_def(job).district
		var s: Dictionary = properties.state[job]
		s.evidence = minf(100.0, float(s.evidence) + float(balance.betray_snitch_evidence))
	police.add_heat(where, float(balance.betray_snitch_heat) + float(person.knows))


func _drop_broken_routes() -> void:
	# Здание продано или брошено — договоры поставки в него тоже закрываются.
	suppliers.contracts = suppliers.contracts.filter(func(c: Dictionary) -> bool: return properties.is_mine(c.to))
	logistics.drop_broken_routes(place_ok, func(id: int) -> bool: return not crew.get_person(id).is_empty())


## Менеджер в здании делает рутину сам: прибирает улики, в лаборатории/на кухне
## перезапускает варку из того, что лежит на складе (по приказу: дорогое первым, один рецепт или ничего),
## в фасаде сдаёт грязные в отмыв (по приказу оставляет часть на руках или не отмывает).
func _run_manager(prop: Dictionary) -> Array:
	var manager := crew.best_at(prop.id, "manager")
	if manager.is_empty():
		return []
	var report: Array = []
	var id: String = prop.id
	var s: Dictionary = properties.state[id]
	s.evidence = maxf(0.0, float(s.evidence) - int(manager.skill) * float(balance.manager_evidence_per_skill))
	var orders := manager_order(id)
	if s.batches.is_empty() and orders.brew != "none":
		var options := properties.recipes_for(id)
		if orders.brew != "auto":
			options = options.filter(func(r: Dictionary) -> bool: return r.id == orders.brew)
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(market.get_good(a.output).base_price) > int(market.get_good(b.output).base_price))
		for recipe: Dictionary in options:
			var count := properties.max_batches(id, recipe.id)
			if count > 0:
				properties.start_batches(id, recipe.id, count)
				report.append(["LOG_MANAGER_BREW", [manager.nick, count, recipe.name_key]])
				break
	var keep := int(orders.launder_keep)
	if prop.kind == "front" and s.frozen_days == 0 and keep >= 0 and dirty > keep:
		var amount := mini(dirty - keep, maxi(0, int(prop.launder_limit) - int(s.dirty_queue)))
		if amount > 0:
			dirty -= amount
			s.dirty_queue += amount
			report.append(["LOG_MANAGER_LAUNDER", [manager.nick, amount]])
	return report


# --- Поставщики и приказы ---

## Приказы менеджеру здания (по умолчанию — варить самое дорогое и отмывать всё).
func manager_order(id: String) -> Dictionary:
	var orders: Dictionary = manager_orders.get(id, {})
	return { "brew": String(orders.get("brew", "auto")), "launder_keep": int(orders.get("launder_keep", 0)) }


func has_manager(id: String) -> bool:
	return not crew.working_at(id, "manager").is_empty()


func can_set_order(id: String, key: String, value: Variant) -> bool:
	if not properties.is_mine(id) or not has_manager(id):
		return false
	match key:
		"brew":
			return value == "auto" or value == "none" or properties.recipes_for(id).any(
					func(r: Dictionary) -> bool: return r.id == value)
		"launder_keep":
			return balance.manager_launder_keep.has(float(value)) or balance.manager_launder_keep.has(int(value))
	return false


func set_order(id: String, key: String, value: Variant) -> bool:
	if not can_set_order(id, key, value):
		return false
	var orders := manager_order(id)
	orders[key] = int(value) if key == "launder_keep" else String(value)
	manager_orders[id] = orders
	return true


## Цена поставщика за штуку: цена рынка в его городе (район прилёта) × его доля.
func supply_price(supplier_id: String, good: String) -> int:
	var supplier := suppliers.get_def(supplier_id)
	var where := String(world.get_city(supplier.city).start)
	return maxi(1, roundi(market.buy_price(where, good) * float(supplier.price)))


func can_add_supply(supplier_id: String, good: String, amount: int, to: String, mode: String) -> bool:
	var supplier := suppliers.get_def(supplier_id)
	if supplier.is_empty() or not supplier.goods.has(good) or not properties.is_mine(to):
		return false
	if world.city_of(properties.get_def(to).district) != supplier.city:
		return false
	if mode == "keep" and not has_manager(to):
		return false
	var same := suppliers.contracts.any(func(c: Dictionary) -> bool:
		return c.supplier == supplier_id and c.good == good and c.to == to)
	return can_act() and not same and ["daily", "keep"].has(mode) and balance.supply_amounts.has(float(amount)) \
			and suppliers.contracts.size() < limit("supply_max")


## Договориться с поставщиком (по телефону — ехать никуда не надо).
func add_supply(supplier_id: String, good: String, amount: int, to: String, mode: String) -> bool:
	if not can_add_supply(supplier_id, good, amount, to, mode):
		return false
	suppliers.add_contract(supplier_id, good, amount, to, mode)
	return true


func remove_supply(id: int) -> bool:
	if not can_act() or suppliers.get_contract(id).is_empty():
		return false
	suppliers.remove_contract(id)
	return true


## Сколько привезут по договору завтра утром: по режиму, сколько влезет.
func supply_amount(contract: Dictionary) -> int:
	var want := int(contract.amount)
	if contract.mode == "keep":
		want = maxi(0, want - properties.stock_of(contract.to, contract.good))
	return mini(want, properties.stock_free(contract.to) / good_size(contract.good))


## Утро: поставщики привозят товар. Платишь при доставке: за легальное — сначала чистыми,
## за нелегальное — сначала грязными. «Палёные» иногда недовозят или приводят за собой полицию.
func _run_supplies() -> Array:
	var report: Array = []
	for contract: Dictionary in suppliers.contracts.duplicate():
		var supplier := suppliers.get_def(contract.supplier)
		var prop := properties.get_def(contract.to)
		var good := market.get_good(contract.good)
		if contract.mode == "keep" and not has_manager(contract.to):
			report.append(["LOG_SUPPLY_NO_MANAGER", [supplier.name_key, prop.name_key]])
			continue
		var amount := supply_amount(contract)
		if amount <= 0:
			if contract.mode == "daily":
				report.append(["LOG_SUPPLY_NO_ROOM", [supplier.name_key, prop.name_key]])
			continue
		var cost := amount * supply_price(contract.supplier, contract.good)
		if cost > money:
			report.append(["LOG_SUPPLY_NO_MONEY", [supplier.name_key, cost]])
			continue
		if good.legal:
			var from_clean := mini(cost, clean)
			clean -= from_clean
			dirty -= cost - from_clean
		else:
			_spend(cost)
		if rng.randf() < float(supplier.risk):
			if rng.randf() < 0.5:
				var got := ceili(amount * float(balance.supply_short_share))
				properties.add_stock(contract.to, contract.good, got)
				report.append(["LOG_SUPPLY_SHORT", [supplier.name_key, got, amount, good.name_key, cost]])
				continue
			# За машиной поставщика приехал «хвост»: розыск района и улики в здании.
			police.add_heat(prop.district, float(balance.supply_tail_heat))
			var st: Dictionary = properties.state[contract.to]
			st.evidence = minf(100.0, float(st.evidence) + float(balance.supply_tail_evidence))
			report.append(["LOG_SUPPLY_TAIL", [supplier.name_key, prop.name_key]])
		properties.add_stock(contract.to, contract.good, amount)
		report.append(["LOG_SUPPLY_DELIVERED", [supplier.name_key, amount, good.name_key, prop.name_key, cost]])
	return report


# --- Заказы ---

## Кто заказчик: имя банды или контакта.
func client_name_key(client: String) -> String:
	var id := client.get_slice(":", 1)
	if client.begins_with("gang:"):
		return gangs.get_def(id).name_key
	return jobs.get_client(id).name_key


func _client_gang(job: Dictionary) -> String:
	return job.client.get_slice(":", 1) if job.client.begins_with("gang:") else ""


## Доска заказов: старые снимаются, в текущем городе — добор до balance.order_offers.
func _roll_offers() -> void:
	jobs.offers = jobs.offers.filter(func(o: Dictionary) -> bool: return int(o.expires) >= day)
	var tries := 0
	while jobs.offers_in(city).size() < limit("order_offers") and tries < 10:
		tries += 1
		var offer := _make_offer()
		if not offer.is_empty():
			jobs.offers.append(offer)


func _make_offer() -> Dictionary:
	var markets := world.districts_of(city).filter(func(d: Dictionary) -> bool: return d.has_market)
	if markets.is_empty():
		return {}
	var where: String = markets[rng.randi_range(0, markets.size() - 1)].id
	# Банды города (кроме тех, с кем война) хотят нелегальное, контакты — своё.
	var gang_ids := gangs.defs.filter(func(g: Dictionary) -> bool:
		return world.city_of(g.home) == city and gangs.level(g.id) != "enemy").map(func(g: Dictionary) -> String: return g.id)
	var client := ""
	var goods: Array = []
	if not gang_ids.is_empty() and rng.randf() < 0.5:
		var gang_id: String = gang_ids[rng.randi_range(0, gang_ids.size() - 1)]
		client = "gang:" + gang_id
		goods = market.goods.filter(func(g: Dictionary) -> bool: return not g.legal).map(func(g: Dictionary) -> String: return g.id)
	else:
		var contacts := jobs.clients_in(city)
		if contacts.is_empty():
			return {}
		var contact: Dictionary = contacts[rng.randi_range(0, contacts.size() - 1)]
		client = "contact:" + String(contact.id)
		goods = contact.goods
	var good: String = goods[rng.randi_range(0, goods.size() - 1)]
	# Сдают туда, где этот товар берут (редкости — не на каждом рынке).
	var buyers := markets.filter(func(d: Dictionary) -> bool: return market.trades(d.id, good))
	if buyers.is_empty():
		return {}
	where = buyers[rng.randi_range(0, buyers.size() - 1)].id
	var unit := maxi(1, market.sell_price(where, good))
	var value := (float(balance.order_value_base) + float(balance.order_value_per_day) * day) * rng.randf_range(0.7, 1.4)
	var amount := clampi(roundi(value / unit), 3, 40)
	var premium := rng.randf_range(float(balance.order_premium[0]), float(balance.order_premium[1]))
	return { "id": jobs.next_id(), "client": client, "city": city, "district": where, "good": good, "amount": amount,
			"reward": roundi(unit * amount * premium), "days": rng.randi_range(int(balance.order_days[0]), int(balance.order_days[1])),
			"expires": day + int(balance.order_offer_days) }


func can_accept_order(id: int) -> bool:
	return can_act() and not jobs.find(jobs.offers, id).is_empty() and jobs.orders.size() < limit("order_active_max")


## Взять заказ: срок пошёл (до конца дня day + days − 1).
func accept_order(id: int) -> bool:
	if not can_accept_order(id):
		return false
	var offer := jobs.find(jobs.offers, id)
	jobs.offers.erase(offer)
	var order := offer.duplicate()
	order.erase("expires")
	order.erase("days")
	order.deadline = day + int(offer.days) - 1
	jobs.orders.append(order)
	return true


## Сколько товара для заказа есть под рукой: в кармане и в твоих зданиях этого города (люди поднесут).
func order_have(order: Dictionary) -> int:
	var total: int = inventory[order.good]
	for prop: Dictionary in properties.mine():
		if world.city_of(prop.district) == order.city:
			total += properties.stock_of(prop.id, order.good)
	return total


## Сдать можно, только стоя в районе заказа.
func can_deliver_order(id: int) -> bool:
	var order := jobs.find(jobs.orders, id)
	return can_act() and not order.is_empty() and district == order.district and order_have(order) >= int(order.amount)


func deliver_order(id: int) -> Array:
	if not can_deliver_order(id):
		return []
	var order := jobs.find(jobs.orders, id)
	var left: int = order.amount
	var from_pocket := mini(left, inventory[order.good])
	if from_pocket > 0:
		_remove_from_inventory(order.good, from_pocket)
		left -= from_pocket
	for prop: Dictionary in properties.mine():
		if left > 0 and world.city_of(prop.district) == order.city:
			var n := mini(left, properties.stock_of(prop.id, order.good))
			properties.add_stock(prop.id, order.good, -n)
			left -= n
	var good := market.get_good(order.good)
	_earn(int(order.reward), good.legal)
	skills.add_xp("trade", ceili(float(order.reward) / balance.xp_trade_per_dollars))
	jobs.orders.erase(order)
	orders_done += 1
	var gang := _client_gang(order)
	if gang != "":
		gangs.change_relation(gang, float(balance.order_gang_success))
	return [["LOG_ORDER_DONE", [client_name_key(order.client), int(order.amount), good.name_key, int(order.reward)]]] \
			+ _check_rank()


## Подставить клиента-банду: сдать сделку полиции. Немного чистых денег и розыск района спадает,
## но банда может узнать.
func can_snitch_order(id: int) -> bool:
	var order := jobs.find(jobs.orders, id)
	return can_act() and not order.is_empty() and _client_gang(order) != ""


func snitch_order(id: int) -> Array:
	if not can_snitch_order(id):
		return []
	var order := jobs.find(jobs.orders, id)
	jobs.orders.erase(order)
	var pay := roundi(int(order.reward) * float(balance.order_snitch_share))
	_earn(pay, true)
	police.add_heat(order.district, -float(balance.order_snitch_heat))
	var gang := _client_gang(order)
	var report: Array = [["LOG_ORDER_SNITCHED", [client_name_key(order.client), pay]]]
	if rng.randf() < float(balance.order_snitch_found):
		gangs.change_relation(gang, -float(balance.order_snitch_relation))
		report.append(["LOG_ORDER_SNITCH_FOUND", [gangs.get_def(gang).name_key]])
	return report


## Отказаться от взятого заказа — как сорвать срок.
func drop_order(id: int) -> Array:
	var order := jobs.find(jobs.orders, id)
	if not can_act() or order.is_empty():
		return []
	jobs.orders.erase(order)
	return _fail_order(order)


func _fail_order(order: Dictionary) -> Array:
	var gang := _client_gang(order)
	if gang != "":
		gangs.change_relation(gang, -float(balance.order_gang_fail))
	return [["LOG_ORDER_FAILED", [client_name_key(order.client), int(order.amount), market.get_good(order.good).name_key]]]


func _expire_orders() -> Array:
	var report: Array = []
	for order: Dictionary in jobs.orders.duplicate():
		if int(order.deadline) <= day:
			jobs.orders.erase(order)
			report.append_array(_fail_order(order))
	return report


# --- Ступени карьеры ---

func rank_def(index: int = -1) -> Dictionary:
	return balance.ranks[rank if index < 0 else index]


func rank_name_key(index: int = -1) -> String:
	return "RANK_" + String(rank_def(index).id).to_upper()


func is_top_rank() -> bool:
	return rank >= balance.ranks.size() - 1


## Сумма бонуса всех взятых ступеней (лимиты прибавляются, скидки складываются).
func perk(key: String) -> float:
	var total := float(story_perks.get(key, 0.0))
	for i in rank + 1:
		total += float(rank_def(i).perks.get(key, 0.0))
	return total


## Лимит из balance с бонусами ступеней: бригада, поставщики, заказы, машины, грузы.
func limit(key: String) -> int:
	return int(balance[key]) + int(perk(key))


## Сколько сейчас набрано по требованию ступени.
func rank_stat(key: String) -> int:
	match key:
		"earned":
			return earned_total
		"orders":
			return orders_done
		"operations":
			return ops_done
		"vaults":
			return vaults_done
		"crew":
			return crew.people.size()
		"buildings":
			return properties.mine().size()
		"districts":
			return gangs.territories(Gangs.PLAYER).size()
		"city_districts":
			var best := 0
			for c: Dictionary in world.cities:
				best = maxi(best, _owned_in(c.id))
			return best
		"cities":
			var cities := {}
			for prop: Dictionary in properties.mine():
				cities[world.city_of(prop.district)] = true
			return cities.size()
		"kingdoms":
			return world.cities.filter(func(c: Dictionary) -> bool: return _owned_in(c.id) >= 3).size()
		"debt_free":
			return 1 if debt <= 0 else 0
		"visited":
			return visited.size()
		"countries":
			var countries := {}
			for c: String in visited:
				countries[world.get_city(c).country] = true
			return countries.size()
		"capital":
			return net_money()
		"clean_capital":
			return clean + bank.deposit
		"dirty_share_max":
			return roundi(100.0 * dirty_earned / maxf(1.0, earned_total))
		"top_rank":
			return 1 if is_top_rank() else 0
	return 0


## Выполнено ли требование: обычные — «не меньше», с окончанием _max — «не больше».
func need_met(key: String, need: int) -> bool:
	return rank_stat(key) <= need if key.ends_with("_max") else rank_stat(key) >= need


# --- Цели и концовки ---

func goal_done(goal: Dictionary) -> bool:
	return goal.needs.keys().all(func(key: String) -> bool: return need_met(key, int(goal.needs[key])))


func ending_ready(id: String) -> bool:
	return goal_done(balance.endings[id])


## Конец дня: если какая-то концовка стала доступна — предлагаем (по одной, отказ запоминаем).
func _check_endings() -> Array:
	if ending_offer != "":
		return []
	for id: String in balance.endings:
		if not endings_declined.has(id) and ending_ready(id):
			ending_offer = id
			return [["LOG_ENDING_READY", ["ENDING_" + id.to_upper()]]]
	return []


## Игрок взял предложенную концовку — партия окончена победой.
func take_ending() -> bool:
	if ending_offer == "" or status != Status.PLAYING:
		return false
	ending = ending_offer
	ending_offer = ""
	status = Status.WON
	return true


## Играть дальше: эту концовку больше не предлагаем (её можно взять позже из карточки целей).
func decline_ending() -> void:
	if ending_offer != "":
		endings_declined.append(ending_offer)
		ending_offer = ""


## Взять концовку позже, из карточки целей (если условия всё ещё выполнены).
func offer_ending(id: String) -> bool:
	if status != Status.PLAYING or not balance.endings.has(id) or not ending_ready(id):
		return false
	ending_offer = id
	return true


func _owned_in(city_id: String) -> int:
	return gangs.territories(Gangs.PLAYER).filter(func(d: String) -> bool: return world.city_of(d) == city_id).size()


func rank_ready(index: int) -> bool:
	var needs: Dictionary = rank_def(index).needs
	return needs.keys().all(func(key: String) -> bool: return rank_stat(key) >= int(needs[key]))


## Повышение: пока выполнены требования следующей ступени — растём.
func _check_rank() -> Array:
	var report: Array = []
	while not is_top_rank() and rank_ready(rank + 1):
		rank += 1
		report.append(["LOG_RANK_UP", [rank_name_key()]])
	return report


## С «Босса района»: районы, где хозяин ты, платят дань каждую ночь (грязными, немного розыска).
func _run_tribute() -> Array:
	var level := perk("tribute")
	if level <= 0.0:
		return []
	var mine := gangs.territories(Gangs.PLAYER)
	if mine.is_empty():
		return []
	var total := roundi(float(balance.tribute_per_district) * level) * mine.size()
	for where: String in mine:
		police.add_heat(where, float(balance.tribute_heat))
	_earn(total, false)
	return [["LOG_TRIBUTE", [mine.size(), total]]]


# --- Ситуации ---

## Выборы ситуации по её виду; первый — что случится само, если ничего не решить к сроку
## (см. _situation_default).
const SITUATION_CHOICES := {
	"cop_visit": ["bribe", "hide", "dump"],
	"advance": ["pay", "refuse", "pressure"],
	"bulk_buyer": ["sell", "decline"],
	"neighbors": ["pay", "ignore", "vent"],
	"tip_off": ["rob", "police", "ignore"],
	"high_roller": ["play", "decline", "cheat"],
}


## Каждый игровой час — шанс новой ситуации; просроченные решаются сами.
func _situations_hours(from: float, to_hour: float) -> Array:
	var report: Array = []
	var now := day * 24 + int(to_hour)
	for sit: Dictionary in jobs.situations.duplicate():
		if int(sit.expires) <= now:
			report.append_array(choose_situation(int(sit.id), _situation_default(sit.kind), true))
	for hour in range(int(from) + 1, int(to_hour) + 1):
		if jobs.situations.size() < int(balance.situation_max) and rng.randf() < float(balance.situation_chance):
			var sit := _make_situation(day * 24 + hour)
			if not sit.is_empty():
				jobs.situations.append(sit)
				report.append(["LOG_SITUATION", [situation_title_key(sit.kind)]])
	return report


func situation_title_key(kind: String) -> String:
	return "SIT_" + kind.to_upper()


func _situation_default(kind: String) -> String:
	return { "cop_visit": "hide", "advance": "refuse", "bulk_buyer": "decline", "neighbors": "ignore", "tip_off": "ignore",
			"high_roller": "decline" }[kind]


func _illegal_value(id: String) -> int:
	var total := 0
	for good: Dictionary in market.goods:
		if not good.legal:
			total += properties.stock_of(id, good.id) * int(good.base_price)
	return total


## Новая ситуация из тех, что сейчас возможны (в текущем городе).
func _make_situation(now: int) -> Dictionary:
	var here := properties.mine().filter(func(p: Dictionary) -> bool:
		return world.city_of(p.district) == city and not jobs.situations.any(func(x: Dictionary) -> bool: return x.place == p.id))
	var options: Array = []
	for prop: Dictionary in here:
		if prop.kind != "front" and _illegal_value(prop.id) > 0:
			options.append({ "kind": "cop_visit", "place": prop.id, "cost": int(balance.sit_cop_bribe_base)
					+ roundi(_illegal_value(prop.id) * float(balance.sit_cop_bribe_share)) })
		if prop.get("casino", false):
			options.append({ "kind": "high_roller", "place": prop.id, "cost": int(balance.sit_whale_stake) })
		if prop.kind == "lab" and not properties.state[prop.id].batches.is_empty():
			options.append({ "kind": "neighbors", "place": prop.id, "cost": int(balance.sit_neighbors_cost) })
		var stock: Dictionary = properties.state[prop.id].stock
		var goods := stock.keys().filter(func(g: String) -> bool: return int(stock[g]) >= 5 and market.trades(prop.district, g))
		if not goods.is_empty():
			var good: String = goods[rng.randi_range(0, goods.size() - 1)]
			var amount := mini(int(stock[good]), rng.randi_range(5, 15))
			options.append({ "kind": "bulk_buyer", "place": prop.id, "target": good, "amount": amount,
					"cost": roundi(market.sell_price(prop.district, good) * amount * float(balance.sit_buyer_premium)) })
	var people := crew.people.filter(func(p: Dictionary) -> bool: return p.job != "")
	if not people.is_empty():
		var person: Dictionary = people[rng.randi_range(0, people.size() - 1)]
		var place: String = person.job if world.city_of(properties.get_def(person.job).district) == city else "@" + district
		options.append({ "kind": "advance", "place": place, "target": int(person.id), "cost": int(person.wage) * int(balance.sit_advance_wages) })
	for gang: Dictionary in gangs.defs:
		if world.city_of(gang.home) == city and gangs.level(gang.id) != "friend" and not gangs.has_treaty(gang.id) \
				and market.get_district(gang.home).has_market:
			var illegal := market.goods.filter(func(g: Dictionary) -> bool: return not g.legal)
			var good: Dictionary = illegal[rng.randi_range(0, illegal.size() - 1)]
			options.append({ "kind": "tip_off", "place": "@" + String(gang.home), "target": String(gang.id) + "|" + String(good.id),
					"amount": rng.randi_range(5, 12) })
	if options.is_empty():
		return {}
	var sit: Dictionary = options[rng.randi_range(0, options.size() - 1)]
	sit.id = jobs.next_id()
	sit.expires = now + int(balance.situation_hours)
	for key: String in ["target", "amount", "cost"]:
		if not sit.has(key):
			sit[key] = 0 if key != "target" else ""
	return sit


func can_choose_situation(id: int, choice: String) -> bool:
	var sit := jobs.find(jobs.situations, id)
	if sit.is_empty() or not can_act() or not SITUATION_CHOICES[sit.kind].has(choice):
		return false
	match [sit.kind, choice]:
		["cop_visit", "bribe"], ["advance", "pay"], ["neighbors", "pay"]:
			return money >= int(sit.cost)
		["high_roller", "play"]:
			return money >= roundi(int(sit.cost) * float(balance.sit_whale_loss))
		["neighbors", "vent"]:
			return not properties.has_upgrade(sit.place, "vent") and clean >= int(balance.upgrades.vent.cost)
		["bulk_buyer", "sell"]:
			return properties.stock_of(sit.place, sit.target) >= int(sit.amount)
		["advance", _]:
			return not crew.get_person(int(sit.target)).is_empty()
	return true


## Шанс отбить склад банды по наводке: от силы бригады.
func tip_rob_chance() -> float:
	return clampf(0.35 + crew_power() / 100.0, 0.35, 0.85)


## Решить ситуацию. forced — срок вышел, решилось само (проверки денег не нужны).
func choose_situation(id: int, choice: String, forced: bool = false) -> Array:
	if not forced and not can_choose_situation(id, choice):
		return []
	var sit := jobs.find(jobs.situations, id)
	if sit.is_empty():
		return []
	jobs.situations.erase(sit)
	var place: String = sit.place
	var where := place.substr(1) if place.begins_with("@") else String(properties.get_def(place).get("district", district))
	var report: Array = [["LOG_SIT_TIMEOUT", [situation_title_key(sit.kind)]]] if forced else []
	match [sit.kind, choice]:
		["cop_visit", "bribe"]:
			_spend(int(sit.cost))
			police.add_heat(where, -5.0)
			report.append(["LOG_SIT_COP_BRIBED", [int(sit.cost)]])
		["cop_visit", "hide"]:
			var chance := float(balance.sit_hide_chance) + skills.level("stealth") * float(balance.sit_hide_per_stealth)
			if not forced and rng.randf() < chance:
				report.append(["LOG_SIT_COP_HIDDEN", []])
			elif properties.is_mine(place):
				var st: Dictionary = properties.state[place]
				st.evidence = minf(100.0, float(st.evidence) + float(balance.sit_cop_evidence))
				police.add_heat(where, float(balance.sit_cop_heat))
				report.append(["LOG_SIT_COP_NOTICED", [properties.get_def(place).name_key]])
		["cop_visit", "dump"]:
			for good: Dictionary in market.goods:
				if not good.legal and properties.is_mine(place):
					properties.add_stock(place, good.id, -properties.stock_of(place, good.id))
			if properties.is_mine(place):
				properties.state[place].evidence = 0.0
			report.append(["LOG_SIT_COP_DUMPED", []])
		["advance", "pay"]:
			var person := crew.get_person(int(sit.target))
			_spend(int(sit.cost))
			_change_loyalty(person, float(balance.sit_advance_loyalty))
			report.append(["LOG_SIT_ADVANCE_PAID", [person.nick, int(sit.cost)]])
		["advance", "refuse"]:
			var person := crew.get_person(int(sit.target))
			if not person.is_empty():
				_change_loyalty(person, -float(balance.sit_refuse_loyalty))
				report.append(["LOG_SIT_ADVANCE_REFUSED", [person.nick]])
		["advance", "pressure"]:
			var person := crew.get_person(int(sit.target))
			person.fear = minf(100.0, float(person.fear) + float(balance.pressure_fear))
			_change_loyalty(person, -float(balance.sit_refuse_loyalty) / 2.0)
			report.append(["LOG_SIT_ADVANCE_PRESSED", [person.nick]])
		["bulk_buyer", "sell"]:
			var good := market.get_good(sit.target)
			properties.add_stock(place, sit.target, -int(sit.amount))
			if not good.legal and rng.randf() < float(balance.sit_buyer_sting):
				police.add_heat(where, float(balance.sit_buyer_sting_heat))
				report.append(["LOG_SIT_BUYER_STING", [int(sit.amount), good.name_key]])
			else:
				_earn(int(sit.cost), good.legal)
				_popup(place, int(sit.cost), good.legal)
				report.append(["LOG_SIT_BUYER_SOLD", [int(sit.amount), good.name_key, int(sit.cost)]])
		["neighbors", "pay"]:
			_spend(int(sit.cost))
			neighbor_mood[place] = "calm"
			report.append(["LOG_SIT_NEIGHBORS_PAID", [int(sit.cost)]])
		["neighbors", "ignore"]:
			neighbor_mood[place] = "angry"
			report.append(["LOG_SIT_NEIGHBORS_ANGRY", [properties.get_def(place).name_key]])
		["neighbors", "vent"]:
			clean -= int(balance.upgrades.vent.cost)
			properties.state[place].upgrades.append("vent")
			neighbor_mood[place] = "calm"
			report.append(["LOG_SIT_NEIGHBORS_VENT", [properties.get_def(place).name_key]])
		["tip_off", "rob"]:
			var gang := String(sit.target).get_slice("|", 0)
			var good := market.get_good(String(sit.target).get_slice("|", 1))
			gangs.change_relation(gang, -float(balance.sit_tip_relation))
			if rng.randf() < tip_rob_chance():
				var got := mini(int(sit.amount), pocket_free() / good_size(good.id))
				inventory[good.id] += got
				report.append(["LOG_SIT_TIP_ROBBED", [gangs.get_def(gang).name_key, got, good.name_key]])
			else:
				police.add_heat(where, float(balance.sit_tip_heat))
				report.append(["LOG_SIT_TIP_FAILED", [gangs.get_def(gang).name_key]])
		["high_roller", "play"]:
			# Честная игра: у заведения преимущество, но крупный игрок может и сорвать банк.
			if rng.randf() < float(balance.sit_whale_win):
				_earn(int(sit.cost), true)
				_popup(place, int(sit.cost), true)
				report.append(["LOG_SIT_WHALE_WON", [int(sit.cost)]])
			else:
				var loss := roundi(int(sit.cost) * float(balance.sit_whale_loss))
				_spend(loss)
				report.append(["LOG_SIT_WHALE_LOST", [loss]])
		["high_roller", "cheat"]:
			if rng.randf() < float(balance.sit_whale_caught):
				police.add_heat(where, float(balance.sit_whale_heat))
				properties.state[place].frozen_days = maxi(int(properties.state[place].frozen_days), 2)
				report.append(["LOG_SIT_WHALE_CAUGHT", [properties.get_def(place).name_key]])
			else:
				var win := roundi(int(sit.cost) * float(balance.sit_whale_cheat))
				_earn(win, true)
				_popup(place, win, true)
				report.append(["LOG_SIT_WHALE_CHEATED", [win]])
		["tip_off", "police"]:
			var gang := String(sit.target).get_slice("|", 0)
			_earn(int(balance.sit_tip_police_pay), true)
			report.append(["LOG_SIT_TIP_POLICE", [int(balance.sit_tip_police_pay)]])
			if rng.randf() < float(balance.order_snitch_found):
				gangs.change_relation(gang, -float(balance.order_snitch_relation))
				report.append(["LOG_ORDER_SNITCH_FOUND", [gangs.get_def(gang).name_key]])
		[_, _]:
			if not forced:
				report.append(["LOG_SIT_IGNORED", []])
	return report


# --- Перевозки ---

## Курьер продаёт привезённое на рынке района: легальное — чистыми, нелегальное — грязными и с розыском.
func _route_sell(route: Dictionary, courier: Dictionary, amount: int) -> Array:
	var where := place_district(route.to)
	var good := market.get_good(route.good)
	var income := route_sale_quote(route, amount)
	market.apply_trade(where, route.good, -amount)
	_earn(income, good.legal)
	_popup(route.to, income, good.legal)
	if not good.legal:
		police.add_heat(where, float(good.heat) * amount * float(balance.dealer_heat_share) * skills.heat_multiplier())
		_gang_notice(where, income)
	return ["LOG_ROUTE_SOLD", [courier.nick, amount, good.name_key, market.get_district(where).name_key, income]]

# --- Ринг и гонки ---

## Кого выставить на подпольный ринг: самого сильного здорового бойца.
func ring_fighter() -> Dictionary:
	var best := {}
	for person: Dictionary in fighters_ready():
		if person.role == "fighter" and (best.is_empty() or int(person.skill) > int(best.skill)):
			best = person
	return best


func ring_chance() -> float:
	var fighter := ring_fighter()
	if fighter.is_empty():
		return 0.0
	return clampf(float(balance.ring_base) + int(fighter.skill) * float(balance.ring_per_skill), 0.0, 0.85)


## Подпольный бой на ставках: победил — приз грязными, проиграл — боец выбывает раненым.
func _ring_fight() -> Array:
	var fighter := ring_fighter()
	if rng.randf() < ring_chance():
		_earn(int(balance.ring_prize), false)
		_change_loyalty(fighter, 5.0)
		return [["LOG_RING_WON", [fighter.nick, int(balance.ring_prize)]]]
	fighter.wounded = rng.randi_range(int(balance.ring_wound_days[0]), int(balance.ring_wound_days[1]))
	return [["LOG_RING_LOST", [fighter.nick, int(fighter.wounded)]]]


## На чём гонять: самая быстрая свободная исправная машина (легковая лучше фургона, фургон — скутера).
func race_vehicle() -> Dictionary:
	var best := {}
	for vehicle: Dictionary in logistics.vehicles:
		if int(vehicle.broken) > 0 or logistics.vehicle_busy(int(vehicle.id)):
			continue
		if best.is_empty() or float(balance.race_chance[vehicle.type]) > float(balance.race_chance[best.type]):
			best = vehicle
	return best


func race_chance() -> float:
	var vehicle := race_vehicle()
	if vehicle.is_empty():
		return 0.0
	return minf(0.85, float(balance.race_chance[vehicle.type]) + skills.level("driving") * float(balance.race_per_driving))


## Уличная гонка на ставках: взнос, победа — приз грязными; бывает, разбиваешь машину.
func _street_race() -> Array:
	var vehicle := race_vehicle()
	var chance := race_chance()
	_spend(int(balance.race_entry))
	var report: Array = []
	if rng.randf() < chance:
		_earn(int(balance.race_prize), false)
		report.append(["LOG_RACE_WON", [int(balance.race_prize)]])
	else:
		report.append(["LOG_RACE_LOST", [int(balance.race_entry)]])
	if rng.randf() < float(balance.race_crash):
		vehicle.broken = 2
		report.append(["LOG_RACE_CRASH", [balance.vehicles[vehicle.type].name_key]])
	return report


# --- Угон ---

## Шанс угнать машину: от Вождения и Взлома (электронные ключи).
func steal_car_chance() -> float:
	return minf(0.9, float(balance.steal_car_chance) + skills.level("driving") * float(balance.steal_car_per_driving)
			+ skills.level("hacking") * float(balance.steal_car_per_hacking))


func _steal_car() -> Array:
	if rng.randf() >= steal_car_chance():
		police.add_heat(district, float(balance.steal_car_alarm_heat))
		return [["LOG_CAR_ALARM", []]]
	var roll := rng.randf()
	var type := "car"
	for t: String in balance.steal_car_types:
		roll -= float(balance.steal_car_types[t])
		if roll < 0.0:
			type = t
			break
	var vehicle := logistics.add_vehicle(type)
	vehicle.stolen = true
	return [["LOG_CAR_STOLEN", [balance.vehicles[type].name_key]]]


func _stolen_vehicle(id: int) -> Dictionary:
	var vehicle := logistics.get_vehicle(id)
	return vehicle if vehicle.get("stolen", false) else {}


## Где разобрать угнанную: своё здание в этом городе, куда влезут запчасти.
func strip_target(id: int) -> String:
	var vehicle := _stolen_vehicle(id)
	if vehicle.is_empty():
		return ""
	var need := int(balance.strip_parts[vehicle.type]) * good_size("car_parts")
	for prop: Dictionary in properties.mine():
		if world.city_of(prop.district) == city and properties.stock_free(prop.id) >= need:
			return prop.id
	return ""


func can_strip_vehicle(id: int) -> bool:
	return can_act() and strip_target(id) != "" and not logistics.vehicle_busy(id)


## Разобрать угнанную на запчасти: машины нет, на склад — запчасти с угона.
func strip_vehicle(id: int) -> Array:
	if not can_strip_vehicle(id):
		return []
	var vehicle := _stolen_vehicle(id)
	var target := strip_target(id)
	var parts := int(balance.strip_parts[vehicle.type])
	properties.add_stock(target, "car_parts", parts)
	logistics.vehicles.erase(vehicle)
	return [["LOG_CAR_STRIPPED", [parts, properties.get_def(target).name_key]]]


func can_relabel_vehicle(id: int) -> bool:
	return can_act() and not _stolen_vehicle(id).is_empty() and money >= int(balance.relabel_cost)


## Перебить номера: машина больше не числится в угоне.
func relabel_vehicle(id: int) -> bool:
	if not can_relabel_vehicle(id):
		return false
	_spend(int(balance.relabel_cost))
	logistics.get_vehicle(id).stolen = false
	return true


func fence_price(id: int) -> int:
	var vehicle := _stolen_vehicle(id)
	return 0 if vehicle.is_empty() else roundi(vehicle_price(vehicle.type) * float(balance.fence_vehicle_share))


func can_fence_vehicle(id: int) -> bool:
	return can_act() and not _stolen_vehicle(id).is_empty() and not logistics.vehicle_busy(id)


## Скинуть угнанную перекупщику — сразу грязные.
func fence_vehicle(id: int) -> Array:
	if not can_fence_vehicle(id):
		return []
	var price := fence_price(id)
	logistics.vehicles.erase(_stolen_vehicle(id))
	_earn(price, false)
	return [["LOG_CAR_FENCED", [price]]]


## Ночью полиция может найти угнанную машину с родными номерами: машину забирают, маршрут закрыт.
func _run_stolen_cars() -> Array:
	var report: Array = []
	for vehicle: Dictionary in logistics.vehicles.duplicate():
		if vehicle.get("stolen", false) and rng.randf() < float(balance.stolen_found_chance):
			logistics.vehicles.erase(vehicle)
			police.add_heat(district, float(balance.stolen_found_heat))
			report.append(["LOG_CAR_FOUND", [balance.vehicles[vehicle.type].name_key]])
	_drop_broken_routes()
	return report


func vehicle_price(type: String) -> int:
	return int(balance.vehicles[type].price)


## Машину покупаешь «с рук» — любые деньги.
func can_buy_vehicle(type: String) -> bool:
	return can_act() and balance.vehicles.has(type) and logistics.vehicles.size() < limit("vehicles_max") \
			and money >= vehicle_price(type)


func buy_vehicle(type: String) -> bool:
	if not can_buy_vehicle(type):
		return false
	_spend(vehicle_price(type))
	logistics.add_vehicle(type)
	return true


## Тайник в машине (ложное дно): патруль находит груз вдвое реже.
func can_add_hidden(vehicle_id: int) -> bool:
	var vehicle := logistics.get_vehicle(vehicle_id)
	return can_act() and not vehicle.is_empty() and not vehicle.hidden and money >= int(balance.hidden_compartment_cost)


func add_hidden(vehicle_id: int) -> bool:
	if not can_add_hidden(vehicle_id):
		return false
	_spend(int(balance.hidden_compartment_cost))
	logistics.get_vehicle(vehicle_id).hidden = true
	return true


## Маскировка груза (мешки с картошкой сверху): патруль находит реже, дешевле тайника. Вместе — сильнее.
func can_add_disguise(vehicle_id: int) -> bool:
	var vehicle := logistics.get_vehicle(vehicle_id)
	return can_act() and not vehicle.is_empty() and not vehicle.disguise and money >= int(balance.disguise_cost)


func add_disguise(vehicle_id: int) -> bool:
	if not can_add_disguise(vehicle_id):
		return false
	_spend(int(balance.disguise_cost))
	logistics.get_vehicle(vehicle_id).disguise = true
	return true


## Место маршрута: id своего здания или рынок района "@district".
func is_market_place(place: String) -> bool:
	return place.begins_with("@")


func market_place(district_id: String) -> String:
	return "@" + district_id


## Район места маршрута.
func place_district(place: String) -> String:
	return place.substr(1) if is_market_place(place) else String(properties.get_def(place).district)


## Ключ перевода для названия места маршрута.
func place_name_key(place: String) -> String:
	if is_market_place(place):
		return market.get_district(place.substr(1)).name_key
	return properties.get_def(place).name_key


## Место ещё годится: своё здание или район с рынком.
func place_ok(place: String) -> bool:
	if not is_market_place(place) and properties.get_def(place).is_empty():
		return false
	if is_market_place(place):
		return market.get_district(place.substr(1)).get("has_market", false)
	return properties.is_mine(place)


## Маршрут: из своего здания в другое своё или на рынок района, свободная машина и курьер;
## разведчик — по желанию (0 — без него).
func can_add_route(from: String, to: String, good: String, vehicle_id: int, courier_id: int, scout_id: int = 0) -> bool:
	var courier := crew.get_person(courier_id)
	if scout_id != 0:
		var scout := crew.get_person(scout_id)
		if scout.is_empty() or scout.role != "scout" or logistics.scout_busy(scout_id):
			return false
	# Пока маршруты только внутри одного города (между городами — через таможню, позже).
	if not properties.get_def(from).is_empty() and place_ok(to) \
			and world.city_of(place_district(from)) != world.city_of(place_district(to)):
		return false
	if is_market_place(to) and not market.trades(place_district(to), good):
		return false
	return can_act() and from != to and properties.is_mine(from) and place_ok(to) \
			and not market.get_good(good).is_empty() and not logistics.get_vehicle(vehicle_id).is_empty() \
			and not logistics.vehicle_busy(vehicle_id) and not courier.is_empty() and courier.role == "courier" \
			and not logistics.courier_busy(courier_id)


func add_route(from: String, to: String, good: String, vehicle_id: int, courier_id: int, scout_id: int = 0) -> bool:
	if not can_add_route(from, to, good, vehicle_id, courier_id, scout_id):
		return false
	logistics.add_route(from, to, good, vehicle_id, courier_id, scout_id)
	return true


## Смена рейсов маршрута: "day", "night" или "both".
func set_route_shift(id: int, shift: String) -> bool:
	var route := logistics.get_route(id)
	if not can_act() or route.is_empty() or not ["day", "night", "both"].has(shift):
		return false
	route.shift = shift
	return true


func remove_route(id: int) -> bool:
	if not can_act() or logistics.get_route(id).is_empty():
		return false
	logistics.remove_route(id)
	return true


## Шанс, что патруль остановит машину с нелегальным грузом: от заметности машины,
## розыска и силы полиции в обоих районах; тайник и опытный курьер снижают.
func route_police_chance(route: Dictionary, shift: String = "night") -> float:
	var good := market.get_good(route.good)
	if good.legal:
		return 0.0
	var vehicle := logistics.get_vehicle(route.vehicle)
	var courier := crew.get_person(route.courier)
	var chance := float(balance.route_police_base) * float(balance.vehicles[vehicle.type].notice)
	if police.has_krysha(place_district(route.from)) or police.has_krysha(place_district(route.to)):
		chance *= float(balance.krysha_check)
	var heat := 0.0
	var force := 0.0
	for place: String in [route.from, route.to]:
		var where := place_district(place)
		heat += police.heat[where] / 2.0
		force += float(market.get_district(where).police) * market.event_police(where) / 2.0
	chance *= force * (1.0 + heat * float(balance.route_heat_per_point))
	if vehicle.hidden:
		chance *= float(balance.hidden_compartment_factor)
	if vehicle.disguise:
		chance *= float(balance.disguise_factor)
	chance *= maxf(0.2, 1.0 - int(courier.get("skill", 0)) * float(balance.route_courier_skill_cut))
	chance *= 1.0 - _scout_skill(route) * float(balance.scout_police_per_skill)
	chance *= skills.route_police_multiplier()
	# Угнанную машину с родными номерами ищут.
	if vehicle.get("stolen", false):
		chance *= float(balance.stolen_route_factor)
	# Днём свидетелей и патрулей больше, ночью — меньше (раздел 3.2).
	chance *= float(balance.route_shifts[shift].police)
	return minf(1.0, chance)


## Навык разведчика маршрута, если он вышел этой ночью (0 — нет разведчика).
func _scout_skill(route: Dictionary) -> int:
	if int(route.get("scout", 0)) == 0 or not crew.present.get(route.scout, true):
		return 0
	return int(crew.get_person(route.scout).get("skill", 0))


## Шанс засады конкурентов: чем дороже нелегальный груз, тем выше.
func route_ambush_chance(route: Dictionary, amount: int, shift: String = "night") -> float:
	var good := market.get_good(route.good)
	if good.legal:
		return 0.0
	var value := float(good.base_price) * amount
	var chance := float(balance.route_ambush_base) + value / 1000.0 * float(balance.route_ambush_per_1000)
	# Засады устраивают банды районов в начале и конце пути — чем хуже отношение, тем чаще.
	chance = minf(float(balance.route_ambush_max), chance * _route_hostility(route))
	# Засады — дело ночное: днём на людной улице нападают реже.
	chance *= float(balance.route_shifts[shift].ambush)
	return chance * (float(balance.scout_ambush_factor) if _scout_skill(route) > 0 else 1.0)


func _route_hostility(route: Dictionary) -> float:
	return maxf(gangs.hostility(place_district(route.from)), gangs.hostility(place_district(route.to)))


## Какая банда устроила засаду: самая враждебная из хозяев районов пути ("" — неизвестные).
func _ambusher(route: Dictionary) -> String:
	var best := ""
	for where: String in [place_district(route.from), place_district(route.to)]:
		var host := gangs.gang_owner(where)
		if host != "" and (best == "" or gangs.relation(host) < gangs.relation(best)):
			best = host
	return best


## Сколько штук увезёт маршрут этой ночью: сколько есть, влезет в машину и в здание назначения
## (на рынке места не надо — там продают).
func route_amount(route: Dictionary) -> int:
	var size := good_size(route.good)
	var vehicle := logistics.get_vehicle(route.vehicle)
	if vehicle.is_empty():
		return 0
	var fits := logistics.capacity(vehicle) / size
	if not is_market_place(route.to):
		fits = mini(fits, properties.stock_free(route.to) / size)
	return mini(properties.stock_of(route.from, route.good), fits)


## Сколько примерно выручит курьер на рынке за amount штук (цена района, насыщение, наценка перекупщика).
func route_sale_quote(route: Dictionary, amount: int) -> int:
	if not is_market_place(route.to) or amount <= 0:
		return 0
	return roundi(market.quote_sell(place_district(route.to), route.good, amount) * float(balance.route_sell_price))


## Рейсы маршрутов днём: каждый уезжает в час своей смены (balance.route_shifts).
func _routes_hours(from_hour: float, to_hour: float) -> Array:
	var report: Array = []
	for route: Dictionary in logistics.routes.duplicate():
		for shift: String in route_shifts(route):
			var hour := float(balance.route_shifts[shift].hour)
			if hour > from_hour and hour <= to_hour and logistics.routes.has(route):
				report.append_array(_route_trip(route, shift))
	_drop_broken_routes()
	return report


## В какие смены ездит маршрут: "day" — днём, "night" — ночью, "both" — оба рейса.
func route_shifts(route: Dictionary) -> Array:
	var shift := String(route.get("shift", "night"))
	return ["day", "night"] if shift == "both" else [shift]


## Ночью машины чинятся.
func _run_routes() -> Array:
	for vehicle: Dictionary in logistics.vehicles:
		vehicle.broken = maxi(0, int(vehicle.broken) - 1)
	return []


## Один рейс: поломка, патруль, засада; доехало — товар в здании назначения или продан на рынке.
func _route_trip(route: Dictionary, shift: String) -> Array:
	var report: Array = []
	var vehicle := logistics.get_vehicle(route.vehicle)
	var courier := crew.get_person(route.courier)
	if vehicle.is_empty() or courier.is_empty() or not crew.present.get(courier.id, true) or vehicle.broken > 0:
		return report
	var amount := route_amount(route)
	if amount <= 0:
		return report
	var good_key: String = market.get_good(route.good).name_key
	if rng.randf() < float(balance.vehicles[vehicle.type].breakdown):
		vehicle.broken = 1
		report.append(["LOG_ROUTE_BREAKDOWN", [courier.nick, balance.vehicles[vehicle.type].name_key]])
		return report
	if rng.randf() < route_police_chance(route, shift):
		# Груз забрали, машину увезли на штрафстоянку, курьера посадили (адвокат может вытащить).
		properties.add_stock(route.from, route.good, -amount)
		police.add_heat(properties.get_def(route.from).district, float(balance.route_bust_heat))
		logistics.vehicles.erase(vehicle)
		report.append(["LOG_ROUTE_BUSTED", [courier.nick, amount, good_key]])
		if rng.randf() < crew.best_skill("lawyer") * float(balance.lawyer_free_per_skill):
			report.append(["LOG_LAWYER_FREED", [courier.nick]])
		else:
			crew.fire(courier.id)
			report.append(["LOG_COURIER_JAILED", [courier.nick]])
		return report
	if rng.randf() < route_ambush_chance(route, amount, shift):
		properties.add_stock(route.from, route.good, -amount)
		_change_loyalty(courier, float(balance.loyalty_ambush))
		var ambusher := _ambusher(route)
		if ambusher == "":
			report.append(["LOG_ROUTE_AMBUSH", [courier.nick, amount, good_key]])
		else:
			gangs.state[ambusher].cash = int(gangs.state[ambusher].cash) + roundi(
					market.get_good(route.good).base_price * amount * float(balance.gang_ambush_loot_share))
			report.append(["LOG_GANG_AMBUSH", [gangs.get_def(ambusher).name_key, courier.nick, amount, good_key]])
		return report
	properties.add_stock(route.from, route.good, -amount)
	if is_market_place(route.to):
		report.append(_route_sell(route, courier, amount))
		return report
	properties.add_stock(route.to, route.good, amount)
	report.append(["LOG_ROUTE_DELIVERED", [courier.nick, amount, good_key,
			properties.get_def(route.from).name_key, properties.get_def(route.to).name_key]])
	return report


## Поставить человека в своё здание подходящего типа ("" — снять с работы).
func can_assign(person_id: int, property_id: String) -> bool:
	var person := crew.get_person(person_id)
	if person.is_empty() or not can_act():
		return false
	if property_id == "":
		return true
	return properties.is_mine(property_id) and crew.can_work_in(person, properties.get_def(property_id).kind)


func assign(person_id: int, property_id: String) -> bool:
	if not can_assign(person_id, property_id):
		return false
	crew.get_person(person_id).job = property_id
	return true


## Кто вышел на работу: пьющий иногда не приходит.
func _roll_presence() -> Array:
	var report: Array = []
	crew.present.clear()
	for person: Dictionary in crew.people:
		# Раненый лечится: ночь не работает, срок уменьшается.
		if int(person.wounded) > 0:
			person.wounded = int(person.wounded) - 1
			crew.present[person.id] = false
			continue
		if int(person.off_day) == day:
			crew.present[person.id] = false
			continue
		var tired := float(person.fatigue) >= float(balance.fatigue_tired)
		var no_show := float(crew.trait_value(person, "no_show", 0.0)) + (float(balance.fatigue_no_show) if tired else 0.0)
		var here := rng.randf() >= no_show
		crew.present[person.id] = here
		var busy: bool = person.job != "" or not logistics.route_of(int(person.id)).is_empty()
		if not here and busy:
			report.append(["LOG_CREW_TIRED" if tired else "LOG_CREW_NO_SHOW", [person.nick]])
	return report


## Днём здания зарабатывают понемногу (share — доля дня): касса фасадов, чай в кафе, дилеры.
func _properties_hours(share: float) -> void:
	for prop: Dictionary in properties.mine():
		var id: String = prop.id
		if prop.kind == "front":
			var revenue := _take_carry("front:" + id, float(prop.revenue) * share)
			if revenue > 0:
				_earn(revenue, true)
				_popup(id, revenue, true)
			# Кафе продаёт свой чай посетителям по полной цене района — чистыми.
			if prop.get("kitchen", false):
				var sold := mini(properties.stock_of(id, "tea"), _take_carry("cafe:" + id,
						float(market.get_good("tea").stall_daily) * 2.0 * share))
				if sold > 0:
					var income := sold * market.buy_price(prop.district, "tea")
					properties.add_stock(id, "tea", -sold)
					_earn(income, true)
					_add_sales("cafe:" + id, income, sold)
					_popup(id, income, true)
		_dealers_hours(prop, share)
		_hackers_hours(prop, share)
		_backroom_hours(prop, share)


## Дилеры в здании продают нелегальное из его склада (дорогое — первым) по цене района со скидкой.
## Деньги грязные, розыск — району. Где нет рынка, покупателей нет.
func _dealers_hours(prop: Dictionary, share: float) -> void:
	var where: String = prop.district
	if not market.get_district(where).has_market:
		return
	# Что сюда возит поставщик — сырьё, его не продают.
	var inputs := {}
	for contract: Dictionary in suppliers.contracts:
		if contract.to == prop.id:
			inputs[contract.good] = true
	var goods := market.goods.filter(func(good: Dictionary) -> bool:
		return not good.legal and not inputs.has(good.id) and market.trades(where, good.id))
	goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.base_price) > int(b.base_price))
	for dealer: Dictionary in crew.working_at(prop.id, "dealer"):
		if not crew.present.get(dealer.id, true):
			continue
		var left := _take_carry("dealer:%d" % int(dealer.id),
				(int(balance.dealer_units_base) + int(balance.dealer_units_per_skill) * int(dealer.skill)) * share)
		var mult := float(balance.dealer_price_base) + float(balance.dealer_price_per_skill) * int(dealer.skill) \
				+ float(crew.trait_value(dealer, "price", 0.0))
		var sold := 0
		var income := 0
		for good: Dictionary in goods:
			var n := mini(left, properties.stock_of(prop.id, good.id))
			if n <= 0:
				continue
			income += roundi(market.quote_sell(where, good.id, n) * mult)
			market.apply_trade(where, good.id, -n)
			properties.add_stock(prop.id, good.id, -n)
			police.add_heat(where, float(good.heat) * n * float(balance.dealer_heat_share) * skills.heat_multiplier())
			sold += n
			left -= n
		if sold > 0:
			_earn(income, false)
			_gang_notice(where, income)
			_add_sales("dealer:%d" % int(dealer.id), income, sold, [dealer.nick])
			_popup(prop.id, income, false)


## Хакеры в здании весь день воруют данные и продают их: грязные деньги понемногу, чуть розыска району.
## Твой Взлом помогает (сам их учишь).
func _hackers_hours(prop: Dictionary, share: float) -> void:
	for hacker: Dictionary in crew.working_at(prop.id, "hacker"):
		if not crew.present.get(hacker.id, true):
			continue
		var daily := (float(balance.hacker_base) + float(balance.hacker_per_skill) * int(hacker.skill)) \
				* (1.0 + skills.level("hacking") * float(balance.hacker_per_hacking))
		var income := _take_carry("hacker:%d" % int(hacker.id), daily * share)
		if income <= 0:
			continue
		_earn(income, false)
		police.add_heat(prop.district, float(balance.hacker_heat) * share)
		_add_sales("hacker:%d" % int(hacker.id), income, 0, [hacker.nick])
		_popup(prop.id, income, false)


## Подпольный покер в казино: весь день грязные деньги со столов, розыск району и внимание налоговой.
func _backroom_hours(prop: Dictionary, share: float) -> void:
	if not properties.has_upgrade(prop.id, "backroom"):
		return
	var income := _take_carry("backroom:" + String(prop.id), float(balance.backroom_income) * share)
	police.add_heat(prop.district, float(balance.backroom_heat) * share)
	properties.tax_attention += float(balance.backroom_tax) * share
	if income > 0:
		_earn(income, false)
		_add_sales("backroom:" + String(prop.id), income, 0)
		_popup(prop.id, income, false)


## Хакер в здании города чистит базы полиции: дело детективов растёт медленнее (не меньше половины).
func hacker_cover(city_id: String) -> float:
	var best := 0
	for prop: Dictionary in properties.mine():
		if world.city_of(prop.district) == city_id:
			for hacker: Dictionary in crew.working_at(prop.id, "hacker"):
				best = maxi(best, int(hacker.skill))
	return maxf(0.5, 1.0 - best * float(balance.hacker_dossier_per_skill))


## Зарплаты за ночь: сначала грязными (наличка), потом чистыми. Кому не хватило — уходит.
func _pay_crew() -> Array:
	var report: Array = []
	var total := 0
	for person: Dictionary in crew.people.duplicate():
		var wage := int(person.wage)
		if money < wage:
			crew.fire(person.id)
			report.append(["LOG_CREW_UNPAID", [person.nick]])
			continue
		_spend(wage)
		total += wage
	if total > 0:
		report.append(["LOG_CREW_WAGES", [total]])
	return report


## Порча: скоропортящееся (грибы, травы, чай, мох) гниёт без холодильника.
func _spoil(prop: Dictionary) -> Array:
	var report: Array = []
	var lost := properties.spoilage(prop.id)
	for good: String in lost:
		properties.add_stock(prop.id, good, -int(lost[good]))
		report.append(["LOG_SPOILED", [prop.name_key, int(lost[good]), market.get_good(good).name_key]])
	return report


func _pay_property_rent(prop: Dictionary) -> Array:
	var rent: int = prop.rent
	var from_clean := mini(rent, clean)
	clean -= from_clean
	var rest := rent - from_clean
	var from_dirty := mini(rest, dirty)
	dirty -= from_dirty
	debt += rest - from_dirty
	if from_dirty > 0:
		police.add_heat(prop.district, balance.dirty_rent_heat)
	return [] if rest == 0 else [["LOG_PROPERTY_RENT_DIRTY", [prop.name_key]]]


## Варка: партии идут к готовности; готовые — в склад здания (с риском брака), запах — в розыск района.
func _run_batches(prop: Dictionary) -> Array:
	var id: String = prop.id
	var s: Dictionary = properties.state[id]
	var report: Array = []
	if s.batches.is_empty():
		return report
	var level: int = s.level
	var safety := _upgrade_factor(id, "extinguisher")
	var volatile: bool = s.batches.any(func(batch: Dictionary) -> bool:
		return properties.get_recipe(batch.recipe).get("volatile", false))
	if prop.kind == "lab" and volatile and rng.randf() < float(balance.lab_explosion_chance[level - 1]) * safety:
		# Взрыв: всё внутри пропало, оборудование и улучшения разбиты, на шум съезжается полиция.
		properties.reset(id, true)
		police.add_heat(prop.district, balance.explosion_heat)
		report.append(["LOG_LAB_EXPLOSION", [prop.name_key]])
		return report
	if prop.kind == "lab" and rng.randf() < float(balance.lab_fire_chance[level - 1]) * safety:
		s.batches.clear()
		for good: String in s.stock.keys():
			properties.add_stock(id, good, -int(s.stock[good]) / 2)
		report.append(["LOG_LAB_FIRE", [prop.name_key]])
		return report
	police.add_heat(prop.district, smell_tonight(id))
	var still: Array = []
	for batch: Dictionary in s.batches:
		var recipe := properties.get_recipe(batch.recipe)
		batch.nights_left -= 1
		if batch.nights_left > 0:
			still.append(batch)
			continue
		var made: int = batch.count * int(recipe.amount)
		var defects := 0
		for i in batch.count:
			if rng.randf() < defect_chance(id):
				defects += 1
		made -= defects * ceili(float(recipe.amount) / 2.0)
		# Удачные партии (из небракованных) дают на половину больше.
		var great := 0
		for i in batch.count - defects:
			if rng.randf() < great_chance(id):
				great += 1
		made += great * ceili(float(recipe.amount) * float(balance.great_batch_bonus))
		properties.add_stock(id, recipe.output, made)
		skills.add_xp("craft", int(balance.xp_activity) * batch.count)
		report.append(["LOG_BATCH_DONE", [prop.name_key, made, market.get_good(recipe.output).name_key]])
		if defects > 0:
			report.append(["LOG_BATCH_DEFECT", [defects]])
		if great > 0:
			report.append(["LOG_BATCH_GREAT", [great]])
	s.batches = still
	return report


## Облава на здание: лаборатории — от розыска района и силы полиции; склады — реже.
## Улики и донос соседей повышают шанс, сигнализация — снижает (успеваешь прибрать).
func raid_chance(id: String, snitched: bool = false) -> float:
	var prop := properties.get_def(id)
	var where: String = prop.district
	var multiplier: float = market.get_district(where).police * market.event_police(where)
	var chance := police.check_chance(where, multiplier)
	chance *= float(balance.lab_raid_factor) if prop.kind == "lab" else float(balance.warehouse_raid_factor)
	chance *= 1.0 + properties.state[id].evidence * float(balance.evidence_raid_per_point)
	chance *= _upgrade_factor(id, "alarm")
	# Охрана: каждый вышедший охранник снижает шанс (вместе — не больше чем на 80%).
	var guarded := 0.0
	for guard: Dictionary in crew.working_at(id, "guard"):
		if crew.present.get(guard.id, true):
			guarded += int(guard.skill) * float(balance.guard_raid_per_skill)
	if is_swat(id):
		guarded *= float(balance.swat_guard_factor)
	chance *= 1.0 - minf(0.8, guarded)
	chance *= 1.0 + float(police.dossier[where]) * float(balance.dossier_raid_per_point)
	if snitched:
		chance *= float(balance.snitch_raid_mult)
	return minf(1.0, chance)


## Облаву на здание ведёт спецназ: розыск района высокий или товара внутри много.
## Охрана против спецназа помогает вдвое хуже, тайник находят, защитников ранят.
func is_swat(id: String) -> bool:
	var where: String = properties.get_def(id).district
	return police.stars(where) >= int(balance.swat_stars) or properties.stock_used(id) >= int(balance.swat_stock)


func _property_raided(prop: Dictionary, snitched: bool) -> bool:
	return rng.randf() < raid_chance(prop.id, snitched)


## Облава забирает нелегальное. Что влезло в тайник — уцелело. Возвращает, сколько штук спасено.
func _lose_property_goods(id: String, goods_legal: Dictionary, find_stash: bool = false) -> int:
	var s: Dictionary = properties.state[id]
	var places := int(balance.upgrades.stash.places) if properties.has_upgrade(id, "stash") and not find_stash else 0
	var saved := 0
	for good: String in s.stock.keys():
		if goods_legal.get(good, true):
			continue
		var kept := mini(int(s.stock[good]), places / good_size(good))
		places -= kept * good_size(good)
		saved += kept
		if kept > 0:
			s.stock[good] = kept
		else:
			s.stock.erase(good)
	s.batches = s.batches.filter(func(batch: Dictionary) -> bool:
		return properties.get_recipe(batch.recipe).smell == 0)
	s.level = 1
	return saved


## Налоговая: отмыв на полный лимит поднимает внимание, со временем оно спадает.
## Когда внимание высокое — может прийти проверка: штраф и заморозка отмыва.
func _run_tax(laundered_share: float) -> Array:
	properties.tax_attention += laundered_share * float(balance.tax_attention_per_full_day)
	properties.tax_attention = clampf(properties.tax_attention - float(balance.tax_attention_decay), 0.0, 100.0)
	if properties.tax_attention < float(balance.tax_audit_threshold) or rng.randf() >= float(balance.tax_audit_chance):
		return []
	var fine := roundi(float(balance.tax_fine_base) + clean * float(balance.tax_fine_share))
	var from_clean := mini(fine, clean)
	clean -= from_clean
	debt += fine - from_clean
	for prop: Dictionary in properties.mine():
		if prop.kind == "front":
			properties.state[prop.id].frozen_days = int(balance.tax_freeze_days)
	properties.tax_attention = 30.0
	return [["LOG_TAX_AUDIT", [fine, int(balance.tax_freeze_days)]]]


# --- Полиция ---

## После нелегальной сделки растёт розыск и может начаться проверка.
func _after_deal(id: String, amount: int) -> void:
	var good := market.get_good(id)
	if good.legal:
		return
	_add_heat(good.heat * amount)
	if illegal_goods_value() == 0:
		return
	if _police_noticed():
		var bribe_value: float = (balance.bribe_base + illegal_goods_value() * balance.bribe_share) * skills.bribe_multiplier()
		pending_check = { "bribe": roundi(bribe_value) }


## Розыск в текущем районе с учётом Скрытности. Скрытность растёт от риска.
func _add_heat(amount: float) -> void:
	police.add_heat(district, amount * skills.heat_multiplier())
	skills.add_xp("stealth", ceili(amount))


## Бросок: заметила ли полиция (по розыску района, силе полиции и событию).
func _police_noticed() -> bool:
	var multiplier: float = market.get_district(district).police * market.event_police(district)
	return rng.randf() < police.check_chance(district, multiplier)


func flee_chance() -> float:
	return police.flee_chance(district)


func can_bribe() -> bool:
	return not pending_check.is_empty() and money >= pending_check.bribe


func bribe() -> Array:
	if not can_bribe():
		return []
	_spend(pending_check.bribe)
	police.add_heat(district, balance.bribe_heat)
	skills.add_xp("charisma", int(balance.xp_bribe))
	var report := [["LOG_BRIBED", [pending_check.bribe]]]
	pending_check = {}
	return report


func surrender() -> Array:
	if pending_check.is_empty():
		return []
	_lose_illegal_goods()
	# На таможне сдал товар — тебя запомнили; полиции — розыск меньше.
	if pending_check.get("customs", false):
		police.add_heat(district, float(balance.customs_heat))
	else:
		police.add_heat(district, -balance.surrender_heat_drop)
	pending_check = {}
	return [["LOG_SURRENDERED", []]]


func flee() -> Array:
	# С таможни не убежишь.
	if pending_check.is_empty() or pending_check.get("customs", false):
		return []
	pending_check = {}
	if rng.randf() < flee_chance():
		police.add_heat(district, balance.flee_heat)
		return [["LOG_FLED", []]]
	return arrest()


## Арест: товар и часть грязных денег забирают, несколько дней сидишь.
## Дни в камере идут как обычные: аренда, проценты и срок платежа никуда не деваются.
## Адвокат в бригаде: штраф меньше, а опытный (от 3 ур.) сокращает срок на день.
func arrest() -> Array:
	last_arrest_day = day
	arrests += 1
	if is_last_arrest():
		_lose_illegal_goods()
		status = Status.LOST
		ending = "prison"
		return [["LOG_LIFE_SENTENCE", [arrests]]]
	_lose_illegal_goods()
	var lawyer := crew.best_skill("lawyer")
	var fine := floori(dirty * float(balance.arrest_dirty_fine) * maxf(0.0, 1.0 - lawyer * float(balance.lawyer_fine_per_skill)))
	dirty -= fine
	police.heat[district] = float(balance.arrest_heat)
	var days := arrest_days()
	var report := [["LOG_ARRESTED", [fine, days]]]
	if lawyer > 0:
		report.append(["LOG_LAWYER_HELPED", []])
	for i in days:
		report.append_array(end_day())
		if status != Status.PLAYING:
			break
	return report


## Железный режим: этот арест — последний (пожизненный срок, конец игры).
func is_last_arrest() -> bool:
	var most := int(balance.modes[mode].get("max_arrests", 0))
	return most > 0 and arrests >= most


## Сколько арестов ещё можно пережить (−1 — без ограничений).
func arrests_left() -> int:
	var most := int(balance.modes[mode].get("max_arrests", 0))
	return maxi(0, most - arrests) if most > 0 else -1


func arrest_days() -> int:
	var short := (1 if crew.best_skill("lawyer") >= int(balance.lawyer_short_skill) else 0) + int(perk("arrest_short"))
	return maxi(1, int(balance.arrest_days) - short)


func _lose_illegal_goods() -> void:
	for good: Dictionary in market.goods:
		if not good.legal:
			inventory[good.id] = 0
			spent_on[good.id] = 0


# --- Деньги и долги ---

## Тратим сначала грязные, потом чистые. Сумма должна быть по карману.
func _spend(amount: int) -> void:
	var from_dirty := mini(amount, dirty)
	dirty -= from_dirty
	clean -= amount - from_dirty


## Сколько ещё нужно внести до ближайшего срока.
func payment_left() -> int:
	return maxi(0, mini(balance.payment_min, debt) - paid_this_period)


## Заплатить ростовщику (он берёт любые деньги). Возвращает, сколько реально ушло.
func pay(amount: int) -> int:
	if not can_act():
		return 0
	var paid := mini(amount, mini(money, debt))
	if paid <= 0:
		return 0
	_spend(paid)
	debt -= paid
	paid_this_period += paid
	return paid


## Занять у ростовщика ещё: деньги сразу (грязные), в долг ложится больше.
func borrow_from_shark() -> bool:
	if not can_act():
		return false
	var amount: int = balance.shark_loan_step
	dirty += amount
	debt += roundi(amount * (1.0 + balance.shark_loan_fee))
	return true


func deposit_clean() -> bool:
	if not can_act() or clean <= 0:
		return false
	bank.deposit += clean
	clean = 0
	return true


func withdraw_deposit() -> bool:
	if not can_act() or bank.deposit <= 0:
		return false
	clean += bank.deposit
	bank.deposit = 0
	return true


func can_take_loan() -> bool:
	return can_act() and bank.trusts(police.max_heat()) and bank.loan_limit(clean_earned) > 0


func take_bank_loan() -> int:
	if not can_take_loan():
		return 0
	var amount := bank.loan_limit(clean_earned)
	bank.loan += amount
	clean += amount
	return amount


## Банку возвращаем только чистыми.
func repay_bank_loan() -> int:
	if not can_act():
		return 0
	var amount := mini(clean, bank.loan)
	clean -= amount
	bank.loan -= amount
	return amount


# --- День ---

## Залечь на дно: день без дел, розыск спадает сильнее.
func lay_low() -> Array:
	if not can_act():
		return []
	police.decay(balance.lay_low_decay - balance.heat_decay)
	return [["LOG_LAY_LOW", []]]


## Бизнес работает до часа to_hour (0–24 от 06:00): ларёк, касса фасадов, кафе, дилеры, рейсы.
## Вызывается каждый игровой час; что не успело за день — доделывает конец дня.
func run_hours(to_hour: float) -> Array:
	to_hour = minf(to_hour, 24.0)
	if status != Status.PLAYING or to_hour <= hours_done:
		return []
	var from := hours_done
	var share := (to_hour - from) / 24.0
	hours_done = to_hour
	var report: Array = []
	if float(balance.supply_hour) > from and float(balance.supply_hour) <= to_hour:
		report.append_array(_run_supplies())
	_stall_hours(share)
	_properties_hours(share)
	report.append_array(_routes_hours(from, to_hour))
	report.append_array(_situations_hours(from, to_hour))
	report.append_array(_check_rank())
	return report


## Взять из почасовой работы целые штуки (или доллары), дробный остаток копится до следующего часа.
func _take_carry(key: String, amount: float) -> int:
	var total := float(_carry.get(key, 0.0)) + amount
	var whole := floori(total + 0.0001)
	_carry[key] = total - whole
	return whole


func _add_sales(key: String, income: int, sold: int, args: Array = []) -> void:
	var entry: Dictionary = _sales.get(key, { "income": 0, "sold": 0, "args": args })
	entry.income = int(entry.income) + income
	entry.sold = int(entry.sold) + sold
	_sales[key] = entry


func _popup(place: String, amount: int, is_clean: bool) -> void:
	if amount <= 0:
		return
	income_today[place] = int(income_today.get(place, 0)) + amount
	popups.append([place, amount, is_clean])


## Итог дневных продаж дилеров и кафе — в журнал (ларёк подводит итог сам).
func _sales_report() -> Array:
	var report: Array = []
	for key: String in _sales:
		var entry: Dictionary = _sales[key]
		if key.begins_with("dealer:"):
			report.append(["LOG_DEALER_SOLD", [entry.args[0], int(entry.sold), int(entry.income)]])
		elif key.begins_with("cafe:"):
			report.append(["LOG_CAFE_SOLD", [int(entry.sold), int(entry.income)]])
		elif key.begins_with("backroom:"):
			report.append(["LOG_BACKROOM", [properties.get_def(key.substr(9)).name_key, int(entry.income)]])
		elif key.begins_with("hacker:"):
			report.append(["LOG_HACKER_DONE", [entry.args[0], int(entry.income)]])
	return report


## Закрыть день: ларёк, аренда, проценты, проверка платежа, новые цены, события, сон.
func end_day() -> Array:
	var report: Array = []
	if status != Status.PLAYING:
		return report
	pending_check = {}
	report.append_array(_run_properties())
	# Остаток дня, который не успели отработать по часам (или весь день, если его пропустили).
	report.append_array(run_hours(24.0))
	report.append_array(_sales_report())
	report.append_array(_run_routes())
	report.append_array(_run_stolen_cars())
	report.append_array(_run_lines())
	report.append_array(_run_insiders())
	report.append_array(_run_shipments())
	report.append_array(_pay_crew())
	report.append_array(_run_loyalty())
	report.append_array(_run_stall())
	report.append_array(_pay_rent())
	report.append_array(_run_gangs())
	report.append_array(_run_tribute())
	if day % 7 == 0 and debt > 0:
		var interest := roundi(debt * float(balance.weekly_interest))
		debt += interest
		report.append(["LOG_INTEREST", [interest]])
		if bank.loan > 0:
			report.append(["LOG_BANK_INTEREST", [bank.add_interest()]])
	if day == next_payment_day and debt <= 0:
		next_payment_day += int(balance.payment_interval_days)
		paid_this_period = 0
	elif day == next_payment_day:
		if payment_left() > 0:
			status = Status.LOST
			ending = "debt"
			report.append(["LOG_PAYMENT_MISSED", []])
			return report
		report.append(["LOG_PAYMENT_OK", []])
		next_payment_day += int(balance.payment_interval_days)
		paid_this_period = 0
	report.append_array(_run_police())
	_remember_day()
	police.decay(balance.heat_decay)
	report.append_array(_expire_stories())
	# Вечер дня day: «завтрашнее» станет сегодняшним завтра, а новое начнётся послезавтра.
	_roll_events(day + 2)
	market.roll_day(rng)
	crew.roll_candidates(rng, int(balance.crew_candidates))
	report.append_array(_expire_orders())
	report.insert(0, ["LOG_DAY_ENDED", [day]])
	day += 1
	neighbor_mood = {}
	_roll_offers()
	report.append_array(_check_rank())
	report.append_array(_check_endings())
	hours_done = 0.0
	_sales = {}
	income_today = {}
	report.append_array(documents.collect(day, balance))
	energy = balance.energy_max
	report.append_array(_events_morning())
	return report


# --- Мир ---

func can_fly(to_city: String) -> bool:
	return can_act() and to_city != city and not world.get_city(to_city).is_empty() \
			and money >= flight_cost(to_city) and docs_ok(to_city)


func zone_of(city_id: String) -> String:
	return String(world.country_of(city_id).get("zone", ""))


## Перелёт через границу: в другую страну.
func crosses_border(to_city: String) -> bool:
	return world.get_city(to_city).country != world.get_city(city).country


## Есть ли документы для перелёта: паспорт за любую границу, виза — куда она нужна.
func docs_ok(to_city: String) -> bool:
	return not crosses_border(to_city) or documents.ready_for(zone_of(to_city), day, balance)


## Шанс досмотра на таможне при прилёте с нелегальным товаром: строгость страны, розыск района прилёта,
## стоимость товара; чемодан с двойным дном — реже.
func customs_chance(to_city: String) -> float:
	var value := 0.0
	for good: Dictionary in market.goods:
		if not good.legal:
			value += float(good.base_price) * inventory[good.id]
	if value <= 0.0 or not crosses_border(to_city):
		return 0.0
	var start: String = world.get_city(to_city).start
	var chance := float(balance.customs[zone_of(to_city)]) + float(police.heat[start]) * float(balance.customs_per_heat) \
			+ value / 1000.0 * float(balance.customs_per_1000)
	if smuggle_case:
		chance *= float(balance.smuggle_case_factor)
	chance *= 1.0 - perk("customs_cut")
	if has_insider(zone_of(to_city)):
		chance *= float(balance.insider_flight)
	chance *= events.factor(to_city, "customs")
	return minf(float(balance.customs_max), chance)


## Цена билета: по расстоянию, а события (шторм, дорогое топливо) в обоих городах её поднимают.
func flight_cost(to_city: String) -> int:
	return roundi(world.flight_cost(city, to_city) * events.factor(city, "flight") * events.factor(to_city, "flight"))


## Перелёт в другой город: билет, часы в пути (их отсчитывают часы игры); прилетаешь в главный район.
## На границе проверяют поддельные документы (распознали — разворот, штраф, подделку забрали)
## и, если везёшь нелегальное, может быть досмотр (pending_check с customs — откупиться или сдать товар).
func fly(to_city: String) -> Array:
	if not can_fly(to_city):
		return []
	var cost := flight_cost(to_city)
	_spend(cost)
	var report: Array = []
	if crosses_border(to_city):
		for fake: String in documents.fakes_for(zone_of(to_city), day, balance):
			if rng.randf() < float(balance.fake_detect[fake]):
				if fake == "passport":
					documents.passport = ""
				else:
					documents.visas.erase(zone_of(to_city))
				var fine := mini(money, int(balance.fake_caught_fine))
				_spend(fine)
				police.add_heat(district, float(balance.fake_caught_heat))
				return [["LOG_FAKE_CAUGHT", [world.get_city(to_city).name_key, fine]]]
	var chance := customs_chance(to_city)
	city = to_city
	visited[to_city] = true
	district = world.get_city(to_city).start
	_roll_offers()
	report.append(["LOG_FLEW", [world.get_city(to_city).name_key, cost]])
	if rng.randf() < chance:
		var bribe_value := illegal_goods_value() * float(balance.customs_bribe_share) \
				* float(balance.customs_bribe_mult[zone_of(to_city)]) * skills.bribe_multiplier()
		pending_check = { "bribe": maxi(50, roundi(bribe_value)), "customs": true }
		report.append(["LOG_CUSTOMS_STOP", []])
	return report


# --- Грузы между городами ---

## Куда можно отправить груз из здания: свои здания и рынки в других городах.
func shipment_targets(from: String) -> Array:
	var here := world.city_of(place_district(from))
	var result: Array = properties.mine().filter(func(p: Dictionary) -> bool: return world.city_of(p.district) != here) \
			.map(func(p: Dictionary) -> String: return p.id)
	for d: Dictionary in market.districts:
		if d.has_market and d.get("city", "") != here:
			result.append(market_place(d.id))
	return result


## Расчёт груза: фрахт (за место и расстояние), пошлина за легальный товар при въезде в другую зону,
## маскировка нелегального (доля стоимости), дни в пути, риск досмотра и выручка на рынке назначения.
func shipment_quote(from: String, to: String, good: String, amount: int, disguise: bool, transport: String = "") -> Dictionary:
	var info := market.get_good(good)
	var from_city := world.city_of(place_district(from))
	var to_city := world.city_of(place_district(to))
	var km := world.distance_km(from_city, to_city)
	var value := float(info.base_price) * amount
	var freight := float(balance.freight_base) + amount * good_size(good) * float(balance.freight_per_unit_1000km) * km / 1000.0
	var zone := zone_of(to_city)
	var duty := value * float(balance.duty[zone]) if info.legal and zone != zone_of(from_city) else 0.0
	var mask := value * float(balance.shipment_disguise_share) if disguise and not info.legal else 0.0
	var risk := 0.0
	if not info.legal:
		risk = minf(float(balance.shipment_customs_max), float(balance.shipment_customs[zone])
				+ value / 1000.0 * float(balance.shipment_customs_per_1000))
		if disguise:
			risk *= float(balance.shipment_disguise_factor)
		# Свой человек на таможне страны назначения закрывает глаза; бонус ступени тоже.
		if has_insider(zone):
			risk *= float(balance.insider_cut)
		risk *= 1.0 - perk("customs_cut")
		risk = minf(float(balance.shipment_customs_max), risk * events.factor(to_city, "customs"))
	# Свой транспорт: катер дешевле и незаметнее, но дольше; самолёт дорогой, зато за день.
	var days := 1 + floori(km / float(balance.freight_km_per_day))
	if transport != "":
		var info_t: Dictionary = balance.transports[transport]
		freight *= float(info_t.freight)
		risk *= float(info_t.risk)
		days = 1 if info_t.get("fast", false) else days + int(info_t.extra_days)
	var sale := 0
	if is_market_place(to):
		sale = roundi(market.quote_sell(place_district(to), good, amount, float(balance.shipment_saturation))
				* float(balance.shipment_sale_price))
	return { "cost": roundi(freight + duty + mask), "duty": roundi(duty), "days": days, "risk": risk, "sale": sale }


func can_ship(from: String, to: String, good: String, amount: int, disguise: bool = false) -> bool:
	if not can_act() or not properties.is_mine(from) or amount <= 0 or properties.stock_of(from, good) < amount \
			or logistics.single_shipments() >= limit("shipments_max") or not shipment_targets(from).has(to) \
			or (is_market_place(to) and not market.trades(place_district(to), good)):
		return false
	if not is_market_place(to) and properties.stock_free(to) < amount * good_size(good):
		return false
	return money >= int(shipment_quote(from, to, good, amount, disguise).cost)


## Отправить груз: товар уходит со склада сразу, платишь сразу; прибудет через несколько дней.
func ship(from: String, to: String, good: String, amount: int, disguise: bool = false) -> bool:
	if not can_ship(from, to, good, amount, disguise):
		return false
	var quote := shipment_quote(from, to, good, amount, disguise)
	_spend(int(quote.cost))
	properties.add_stock(from, good, -amount)
	logistics.add_shipment(from, to, good, amount, day + int(quote.days), disguise)
	return true


## Ночь для грузов: прибывшие к утру проходят досмотр (нелегальное могут забрать), потом — на склад
## или скупщику на рынке назначения.
func _run_shipments() -> Array:
	var report: Array = []
	for shipment: Dictionary in logistics.shipments.duplicate():
		if int(shipment.arrive) > day + 1:
			continue
		logistics.shipments.erase(shipment)
		var good := market.get_good(shipment.good)
		var where := place_district(shipment.to)
		var to_name := place_name_key(shipment.to)
		var amount := int(shipment.amount)
		if not good.legal:
			var quote := shipment_quote(shipment.from, shipment.to, shipment.good, amount, shipment.disguise,
					String(shipment.get("transport", "")))
			if rng.randf() < float(quote.risk):
				police.add_heat(where, float(balance.shipment_seized_heat))
				report.append(["LOG_SHIPMENT_SEIZED", [amount, good.name_key, to_name]])
				continue
		if is_market_place(shipment.to):
			# Скупщик продаёт оптом через свою сеть — цена в районе падает слабее, чем от твоей продажи.
			var saturation := float(balance.shipment_saturation)
			var income := roundi(market.quote_sell(where, shipment.good, amount, saturation) * float(balance.shipment_sale_price))
			market.apply_wholesale(where, shipment.good, amount, saturation)
			_earn(income, good.legal)
			if not good.legal:
				_gang_notice(where, income)
			report.append(["LOG_SHIPMENT_SOLD", [amount, good.name_key, to_name, income]])
			continue
		if not properties.is_mine(shipment.to):
			report.append(["LOG_SHIPMENT_LOST", [amount, good.name_key]])
			continue
		var fits := mini(amount, properties.stock_free(shipment.to) / good_size(shipment.good))
		properties.add_stock(shipment.to, shipment.good, fits)
		report.append(["LOG_SHIPMENT_ARRIVED", [fits, good.name_key, to_name]])
		if fits < amount:
			report.append(["LOG_SHIPMENT_OVERFLOW", [amount - fits]])
	return report


# --- Крупные дела ---

func op_def(id: String) -> Dictionary:
	for op: Dictionary in op_defs:
		if op.id == id:
			return op
	return {}


func op_kind(id: String) -> Dictionary:
	return balance.operation_kinds[op_def(id).kind]


func operations_in(where: String) -> Array:
	return op_defs.filter(func(op: Dictionary) -> bool: return op.district == where)


func op_state(id: String) -> Dictionary:
	if not operations.has(id):
		operations[id] = { "preps": [], "ready": 0 }
	return operations[id]


## Кто пойдёт на дело: по каждой нужной роли — лучшие здоровые люди. { роль: [люди] }.
func op_crew(id: String) -> Dictionary:
	var result := {}
	for role: String in op_kind(id).roles:
		var people := crew.people.filter(func(p: Dictionary) -> bool:
			return p.role == role and int(p.wounded) == 0 and int(p.off_day) != day and crew.present.get(p.id, true))
		people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.skill) > int(b.skill))
		result[role] = people.slice(0, int(op_kind(id).roles[role]))
	return result


## Кого не хватает: [[роль, нужно, есть]].
func op_missing(id: String) -> Array:
	var missing: Array = []
	var team := op_crew(id)
	for role: String in op_kind(id).roles:
		var need := int(op_kind(id).roles[role])
		if team[role].size() < need:
			missing.append([role, need, team[role].size()])
	return missing


## Сколько стоит добыча (для цены подготовки).
func op_value(id: String) -> int:
	var kind := op_kind(id)
	var value := int(kind.get("money", 0))
	for good: String in kind.get("goods", {}):
		value += int(market.get_good(good).base_price) * int(kind.goods[good])
	return value


## Шанс: база дела + подготовка + опыт команды + вооружённые бойцы (не выше op_max_chance).
func op_chance(id: String) -> float:
	var chance := float(op_kind(id).base)
	for prep: String in op_state(id).preps:
		chance += float(balance.op_preps[prep].bonus)
	var team := op_crew(id)
	var skill := 0
	var count := 0
	var fighters: Array = []
	for role: String in team:
		for person: Dictionary in team[role]:
			skill += int(person.skill)
			count += 1
			if role == "fighter":
				fighters.append(person)
	if count > 0:
		chance += float(skill) / count * float(balance.op_skill_bonus)
	var arms := _arm(fighters, arsenal())
	chance += arms.values().filter(func(a: Dictionary) -> bool: return a.weapon != "").size() * float(balance.op_armed_bonus)
	return clampf(chance, 0.0, float(balance.op_max_chance))


func prep_cost(id: String, prep: String) -> int:
	return roundi(op_value(id) * float(balance.op_preps[prep].get("cost_share", 0.0)))


func op_cooling(id: String) -> int:
	return maxi(0, int(op_state(id).ready) - day)


## Подготовка — только на месте дела; разведку делаешь сам (часы и силы), снаряжение и своего человека — за деньги.
func can_prep(id: String, prep: String) -> bool:
	var op := op_def(id)
	if op.is_empty() or not balance.op_preps.has(prep) or op_state(id).preps.has(prep) or op_cooling(id) > 0:
		return false
	var info: Dictionary = balance.op_preps[prep]
	return can_act() and district == op.district and energy >= int(info.get("energy", 0)) and money >= prep_cost(id, prep)


func do_prep(id: String, prep: String) -> Array:
	if not can_prep(id, prep):
		return []
	var info: Dictionary = balance.op_preps[prep]
	energy -= int(info.get("energy", 0))
	_spend(prep_cost(id, prep))
	op_state(id).preps.append(prep)
	if prep == "recon":
		skills.add_xp("stealth", int(balance.xp_activity))
	return [["LOG_OP_PREP", [info.name_key, op_kind(id).name_key]]]


func can_launch(id: String) -> bool:
	var op := op_def(id)
	return not op.is_empty() and can_act() and district == op.district and rank >= int(op_kind(id).min_rank) \
			and op_missing(id).is_empty() and energy >= int(balance.op_energy) and op_cooling(id) == 0


## Дело. Удача — добыча (грязные или товар на склад города/в карман), розыск района, банда хозяина района злится.
## Провал — людей ранят и сажают, розыска больше. Подготовка сгорает, повторить можно через op_cooldown дней.
func launch_operation(id: String) -> Array:
	if not can_launch(id):
		return []
	var op := op_def(id)
	var kind := op_kind(id)
	var chance := op_chance(id)
	var team := op_crew(id)
	energy -= int(balance.op_energy)
	var fighters: Array = team.get("fighter", [])
	_spend_ammo(_arm(fighters, arsenal()).values().filter(func(a: Dictionary) -> bool: return a.weapon != "").size())
	var state := op_state(id)
	state.preps = []
	state.ready = day + int(balance.op_cooldown)
	skills.add_xp("leadership", int(balance.xp_leadership) * 3)
	var host := gangs.gang_owner(op.district)
	if host != "":
		gangs.change_relation(host, -float(balance.op_gang_relation))
	var report: Array = []
	if rng.randf() < chance:
		police.add_heat(op.district, float(kind.heat) * skills.heat_multiplier())
		ops_done += 1
		if kind.get("vault", false):
			vaults_done += 1
		var money_won := int(kind.get("money", 0))
		if money_won > 0:
			_earn(money_won, false)
			_popup("@" + String(op.district), money_won, false)
		report.append(["LOG_OP_WON", [kind.name_key, money_won]] if money_won > 0 else ["LOG_OP_WON_GOODS", [kind.name_key]])
		for good: String in kind.get("goods", {}):
			report.append_array(_stash_loot(good, int(kind.goods[good])))
		for role: String in team:
			for person: Dictionary in team[role]:
				_change_loyalty(person, 10.0)
		report.append_array(_check_rank())
		return report
	police.add_heat(op.district, float(kind.heat) * float(balance.op_fail_heat))
	report.append(["LOG_OP_FAILED", [kind.name_key]])
	for role: String in team:
		for person: Dictionary in team[role]:
			if rng.randf() < float(balance.op_fail_arrest):
				crew.fire(person.id)
				report.append(["LOG_OP_ARRESTED", [person.nick]])
			elif rng.randf() < float(balance.op_fail_wound):
				person.wounded = rng.randi_range(int(balance.fight_wound_days[0]), int(balance.fight_wound_days[1]))
				report.append(["LOG_FIGHT_WOUNDED", [person.nick, int(person.wounded)]])
	_drop_broken_routes()
	return report


## Добыча-товар: в своё здание этого города, где есть место, остальное — в карман (что не влезло — бросили).
func _stash_loot(good: String, amount: int) -> Array:
	var left := amount
	for prop: Dictionary in properties.mine():
		if left > 0 and world.city_of(prop.district) == city:
			var n := mini(left, properties.stock_free(prop.id) / good_size(good))
			properties.add_stock(prop.id, good, n)
			left -= n
	var pocket := mini(left, pocket_free() / good_size(good))
	inventory[good] += pocket
	left -= pocket
	var report: Array = [["LOG_OP_LOOT", [amount - left, market.get_good(good).name_key]]]
	if left > 0:
		report.append(["LOG_POCKET_FULL", [left]])
	return report


# --- Порт и контрабанда ---

## Какой транспорт есть у здания: причал — катер, ангар — самолёт (пусто — не порт).
func port_transports(id: String) -> Array:
	return properties.get_def(id).get("port", [])


## Куда может идти линия из порта: катер — только в свой причал другого города, самолёт — в любое своё здание
## другого города (аэропорт есть везде).
func line_targets(from: String, transport: String) -> Array:
	var here := world.city_of(place_district(from))
	return properties.mine().filter(func(p: Dictionary) -> bool:
		return world.city_of(p.district) != here and (transport == "plane" or p.get("port", []).has("boat"))) \
			.map(func(p: Dictionary) -> String: return p.id)


func can_add_line(from: String, to: String, good: String, amount: int, transport: String) -> bool:
	return can_act() and properties.is_mine(from) and port_transports(from).has(transport) \
			and line_targets(from, transport).has(to) and not market.get_good(good).is_empty() \
			and balance.line_amounts.has(float(amount)) and amount * good_size(good) <= int(balance.transports[transport].capacity) \
			and logistics.lines.size() < limit("lines_max")


## Регулярная линия: катер раз в 3 дня или самолёт раз в 2 дня возит товар из порта в другой город.
func add_line(from: String, to: String, good: String, amount: int, transport: String) -> bool:
	if not can_add_line(from, to, good, amount, transport):
		return false
	logistics.add_line(from, to, good, amount, transport, day)
	return true


func remove_line(id: int) -> bool:
	if not can_act() or logistics.get_line(id).is_empty():
		return false
	logistics.lines.erase(logistics.get_line(id))
	return true


## Ночью линии, у которых подошёл день, отправляют рейс: сколько есть на складе (до нормы), фрахт сразу,
## нелегальное всегда в маскировке. Рейс идёт как груз — с таможней на прибытии.
func _run_lines() -> Array:
	var report: Array = []
	for line: Dictionary in logistics.lines.duplicate():
		if not properties.is_mine(line.from) or not properties.is_mine(line.to):
			logistics.lines.erase(line)
			report.append(["LOG_LINE_CLOSED", [market.get_good(line.good).name_key]])
			continue
		if int(line.next) > day:
			continue
		var info: Dictionary = balance.transports[line.transport]
		line.next = day + int(info.every)
		var amount := mini(int(line.amount), properties.stock_of(line.from, line.good))
		if amount <= 0:
			report.append(["LOG_LINE_EMPTY", [place_name_key(line.from), market.get_good(line.good).name_key]])
			continue
		var disguise: bool = not market.get_good(line.good).legal
		var quote := shipment_quote(line.from, line.to, line.good, amount, disguise, line.transport)
		if money < int(quote.cost):
			report.append(["LOG_LINE_NO_MONEY", [int(quote.cost)]])
			continue
		_spend(int(quote.cost))
		properties.add_stock(line.from, line.good, -amount)
		logistics.add_shipment(line.from, line.to, line.good, amount, day + int(quote.days), disguise, line.transport, true)
		report.append(["LOG_LINE_SENT", [info.name_key, amount, market.get_good(line.good).name_key, place_name_key(line.to), int(quote.cost)]])
	return report


## Свой человек на таможне: груз и твой багаж в его стране досматривают реже. Платишь раз в неделю.
func has_insider(zone: String) -> bool:
	return insiders.has(zone)


func insider_fee(zone: String) -> int:
	return int(balance.insider_fee.get(zone, 0))


## Договориться можно, только будучи в этой стране.
func can_hire_insider(zone: String) -> bool:
	return can_act() and balance.insider_fee.has(zone) and not has_insider(zone) and zone_of(city) == zone \
			and money >= insider_fee(zone)


func hire_insider(zone: String) -> bool:
	if not can_hire_insider(zone):
		return false
	_spend(insider_fee(zone))
	insiders[zone] = day + 7
	return true


func fire_insider(zone: String) -> bool:
	if not can_act() or not has_insider(zone):
		return false
	insiders.erase(zone)
	return true


## Раз в неделю — плата; не хватило — уходит. Изредка свой человек сдаёт тебя: розыск в городе.
func _run_insiders() -> Array:
	var report: Array = []
	for zone: String in insiders.keys():
		if int(insiders[zone]) > day + 1:
			continue
		if rng.randf() < float(balance.insider_rat):
			insiders.erase(zone)
			police.add_heat(district, float(balance.insider_rat_heat))
			report.append(["LOG_INSIDER_RAT", ["ZONE_" + zone.to_upper()]])
			continue
		if money < insider_fee(zone):
			insiders.erase(zone)
			report.append(["LOG_INSIDER_LEFT", ["ZONE_" + zone.to_upper()]])
			continue
		_spend(insider_fee(zone))
		insiders[zone] = int(insiders[zone]) + 7
		report.append(["LOG_INSIDER_PAID", ["ZONE_" + zone.to_upper(), insider_fee(zone)]])
	return report


## Паспорт оформляют только в родном городе, несколько дней.
func can_apply_passport() -> bool:
	return can_act() and documents.passport != "real" and documents.passport_ready == 0 and city == home_city \
			and money >= int(balance.passport_cost)


func apply_passport() -> bool:
	if not can_apply_passport():
		return false
	_spend(int(balance.passport_cost))
	documents.passport_ready = day + int(balance.passport_days)
	return true


## Виза: нужен паспорт. В США не дают при высоком розыске или недавнем аресте.
func visa_refused(zone: String) -> bool:
	var info: Dictionary = balance.visas[zone]
	return (info.has("max_heat") and police.max_heat() >= float(info.max_heat)) \
			or (info.has("arrest_days") and day - last_arrest_day < int(info.arrest_days))


func can_apply_visa(zone: String) -> bool:
	return can_act() and balance.visas.has(zone) and documents.has_passport() and documents.visa(zone, day).get("kind", "") != "real" \
			and not documents.visa_ready.has(zone) and not visa_refused(zone) and money >= int(balance.visas[zone].cost)


## Оформить визу: без ожидания — сразу, иначе через несколько дней.
func apply_visa(zone: String) -> bool:
	if not can_apply_visa(zone):
		return false
	var info: Dictionary = balance.visas[zone]
	_spend(int(info.cost))
	if int(info.days) == 0:
		documents.visas[zone] = { "kind": "real", "until": day + int(info.valid) }
	else:
		documents.visa_ready[zone] = day + int(info.days)
	return true


## Подделыватель сидит в нескольких районах (balance.forger_districts).
func at_forger() -> bool:
	return balance.forger_districts.has(district)


func can_buy_fake_passport() -> bool:
	return can_act() and at_forger() and not documents.has_passport() and money >= fake_cost("passport")


## Цена подделки: паспорт ("passport") или виза зоны; бывшему айтишнику дешевле.
func fake_cost(what: String) -> int:
	var base := int(balance.fake_passport_cost) if what == "passport" else int(balance.fake_visa_cost[what])
	return roundi(base * (1.0 - background_perk("fake_discount")))


func buy_fake_passport() -> bool:
	if not can_buy_fake_passport():
		return false
	_spend(fake_cost("passport"))
	documents.passport = "fake"
	return true


func can_buy_fake_visa(zone: String) -> bool:
	return can_act() and at_forger() and balance.fake_visa_cost.has(zone) and documents.visa(zone, day).is_empty() \
			and money >= fake_cost(zone)


func buy_fake_visa(zone: String) -> bool:
	if not can_buy_fake_visa(zone):
		return false
	_spend(fake_cost(zone))
	documents.visas[zone] = { "kind": "fake", "until": day + int(balance.fake_visa_valid) }
	return true


func can_buy_smuggle_case() -> bool:
	return can_act() and not smuggle_case and money >= int(balance.smuggle_case_cost)


func buy_smuggle_case() -> bool:
	if not can_buy_smuggle_case():
		return false
	_spend(int(balance.smuggle_case_cost))
	smuggle_case = true
	return true


## Самый высокий розыск среди районов города (0–100).
func city_heat(city_id: String) -> float:
	var result := 0.0
	for d: Dictionary in world.districts_of(city_id):
		result = maxf(result, float(police.heat[d.id]))
	return result


## Твоё влияние в городе: среднее по его районам (0–100).
func city_influence(city_id: String) -> float:
	var list := world.districts_of(city_id)
	var total := 0.0
	for d: Dictionary in list:
		total += gangs.share(d.id, Gangs.PLAYER)
	return total / maxf(1.0, list.size())


## Лучшая цена товара в городе: buy — самая низкая цена покупки, иначе — самая высокая цена продажи (0 — рынков нет).
## Лучшая цена товара в городе (0 — в этом городе им не торгуют).
func city_price(city_id: String, good: String, buy: bool) -> int:
	var best := 0
	for d: Dictionary in world.districts_of(city_id):
		if not market.trades(d.id, good):
			continue
		var price := market.buy_price(d.id, good) if buy else market.sell_price(d.id, good)
		if best == 0 or (price < best if buy else price > best):
			best = price
	return best


# --- Банды ---

## Нелегальная продажа на сумму value в районе: твоё влияние растёт, банды района злятся
## (тем сильнее, чем больше их доля и чем вспыльчивее босс).
func _gang_notice(where: String, value: int) -> void:
	if value <= 0:
		return
	var hundreds := float(value) / 100.0
	gangs.turf_sales[where] = int(gangs.turf_sales.get(where, 0)) + value
	for id: String in gangs.influence[where].keys():
		if id != Gangs.PLAYER and gangs.treaty(id).get("kind", "") not in ["peace_tax", "alliance"]:
			gangs.change_relation(id, -hundreds * float(balance.gang_relation_per_100)
					* float(gangs.temper(id).anger) * gangs.share(where, id) / 100.0)
	gangs.player_gain(where, hundreds * float(balance.player_influence_per_100))


## Ночь у банд: твои нелегальные точки (лаборатории и здания с нелегальным товаром) держат влияние
## и раздражают хозяев района; потом банды живут сами. Сообщаем, если отношение перешло на новый уровень.
func _run_gangs() -> Array:
	var report: Array = []
	var goods_legal := {}
	for good: Dictionary in market.goods:
		goods_legal[good.id] = good.legal
	for prop: Dictionary in properties.mine():
		if prop.kind != "lab" and not properties.has_illegal(prop.id, goods_legal):
			continue
		var where: String = prop.district
		var host := gangs.gang_owner(where)
		if host != "":
			gangs.change_relation(host, -float(balance.gang_relation_property) * float(gangs.temper(host).anger))
		gangs.player_gain(where, float(balance.player_influence_property))
	report.append_array(_expire_offers())
	report.append_array(_run_treaties())
	report.append_array(gangs.night(rng))
	for gang: Dictionary in gangs.defs:
		report.append_array(_gang_turn(gang.id))
	gangs.turf_sales.clear()
	for gang: Dictionary in gangs.defs:
		var now := gangs.level(gang.id)
		if now != gangs.known_level.get(gang.id, now):
			report.append(["LOG_GANG_NOW_" + now.to_upper(), [gang.name_key, gang.boss_key]])
		gangs.known_level[gang.id] = now
	return report


## Не ответил на требование вовремя — это отказ.
func _expire_offers() -> Array:
	var report: Array = []
	for offer: Dictionary in gangs.offers.duplicate():
		if int(offer.expires) > day:
			continue
		gangs.offers.erase(offer)
		if offer.kind == "demand":
			_refuse_demand(offer)
			report.append(["LOG_GANG_DEMAND_IGNORED", [gangs.get_def(offer.gang).name_key]])
	return report


## Ход банды ночью. Обиженная (отказ платить) мстит наверняка — нападает. Соперники и враги действуют
## по характеру босса; нейтральные изредка просят долю; друзья и нейтральные предлагают товар со скидкой.
## Действие, которое сделать нельзя (нечего требовать, некого переманить), заменяется другим.
func _gang_turn(id: String) -> Array:
	var st: Dictionary = gangs.state[id]
	var level := gangs.level(id)
	# По договору банда не трогает: только предлагает сделки.
	if gangs.has_treaty(id):
		if rng.randf() < float(balance.gang_deal_chance[level]) and gangs.offer_from(id).is_empty():
			return _gang_deal(id)
		return []
	if st.revenge:
		st.revenge = false
		var revenge := _gang_attack(id, true)
		if not revenge.is_empty():
			return revenge
	if rng.randf() < float(balance.gang_deal_chance[level]) and gangs.offer_from(id).is_empty():
		return _gang_deal(id)
	if rng.randf() >= float(balance.gang_act_chance[level]):
		return []
	var allowed: Array = ["demand"] if level == "neutral" else ["demand", "dump", "attack", "poach", "retake"]
	while not allowed.is_empty():
		var action := gangs.pick_action(id, allowed, rng)
		allowed.erase(action)
		var report: Array = call("_gang_" + action, id)
		if not report.is_empty():
			return report
	return []


## Требование доли с твоих нелегальных продаж на их земле (или «за постой», если у тебя там здания).
func _gang_demand(id: String) -> Array:
	if not gangs.offer_from(id).is_empty():
		return []
	var sales := 0
	for district: String in gangs.territories(id):
		sales += int(gangs.turf_sales.get(district, 0))
	var has_place := properties.mine().any(func(p: Dictionary) -> bool: return gangs.gang_owner(p.district) == id)
	if sales <= 0 and not has_place:
		return []
	var amount := maxi(int(balance.gang_demand_min), roundi(sales * float(balance.gang_demand_share)))
	gangs.add_offer({ "gang": id, "kind": "demand", "amount": amount, "good": "", "units": 0,
			"expires": day + int(balance.gang_offer_days) })
	var gang := gangs.get_def(id)
	return [["LOG_GANG_DEMAND", [gang.name_key, gang.boss_key, amount]]]


## Банда отбивает землю: забирает часть твоего влияния в районе, где у неё есть доля (сначала — дома).
## Твоя сила бригады отпугивает: чем сильнее, тем меньше отберут.
func _gang_retake(id: String) -> Array:
	var home: String = gangs.get_def(id).home
	var places: Array = gangs.influence.keys().filter(func(d: String) -> bool:
		return gangs.share(d, Gangs.PLAYER) > 0.0 and gangs.share(d, id) > 0.0)
	if places.is_empty():
		return []
	var where: String = home if places.has(home) else places[0]
	var amount := float(balance.gang_retake) / (1.0 + crew_power() * float(balance.gang_retake_defense_per_power))
	var taken := minf(amount, gangs.share(where, Gangs.PLAYER))
	gangs.influence[where][Gangs.PLAYER] = gangs.share(where, Gangs.PLAYER) - taken
	gangs.influence[where][id] = gangs.share(where, id) + taken
	return [["LOG_GANG_RETAKE", [gangs.get_def(id).name_key, market.get_district(where).name_key, roundi(taken)]]]


## Банда сбрасывает на своём рынке самый дорогой нелегальный товар — цена падает.
func _gang_dump(id: String) -> Array:
	var turf: Array = gangs.territories(id).filter(func(d: String) -> bool: return market.get_district(d).has_market)
	if turf.is_empty():
		return []
	var where: String = turf[0]
	var goods := market.goods.filter(func(good: Dictionary) -> bool: return not good.legal and market.trades(where, good.id))
	if goods.is_empty():
		return []
	goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.base_price) > int(b.base_price))
	var good: Dictionary = goods[0]
	market.apply_trade(where, good.id, -int(balance.gang_dump_units))
	return [["LOG_GANG_DUMP", [gangs.get_def(id).name_key, good.name_key, market.get_district(where).name_key]]]


## Шанс, что налёт банды на здание удастся: сила банды против охраны (и сигнализации).
func gang_attack_chance(id: String, property_id: String) -> float:
	var attack := float(balance.gang_attack_base) + gangs.strength(id) * float(balance.gang_attack_share)
	var defense := 0.0
	# Охрана отстреливается тем, что лежит на складе этого здания.
	var arms := _arm(_defenders(property_id), properties.state[property_id].stock)
	for person: Dictionary in _defenders(property_id):
		var per_skill := float(balance.defense_fighter_per_skill) if person.role == "fighter" else float(balance.guard_defense_per_skill)
		var weapon: String = arms.get(person.id, {}).get("weapon", "")
		defense += int(person.skill) * per_skill * (1.0 + float(balance.weapon_power.get(weapon, 0.0)))
	defense *= gear_power()
	if properties.has_upgrade(property_id, "alarm"):
		defense += float(balance.alarm_defense)
	# Нападать некому (и защищаться некому) — налёта нет, а не 0/0.
	return attack / (attack + defense) if attack > 0.0 else 0.0


## Налёт на твоё здание с товаром: на их земле, а врагу или мстителю — любое. Удался — забирают долю товара;
## отбились — банда теряет человека.
func _gang_attack(id: String, anywhere: bool = false) -> Array:
	var targets := properties.mine().filter(func(p: Dictionary) -> bool:
		return properties.stock_used(p.id) > 0 and (anywhere or gangs.level(id) == "enemy" or gangs.gang_owner(p.district) == id))
	if targets.is_empty():
		return []
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return properties.stock_used(a.id) > properties.stock_used(b.id))
	var prop: Dictionary = targets[0]
	var gang := gangs.get_def(id)
	var defenders := _defenders(prop.id)
	if rng.randf() >= gang_attack_chance(id, prop.id):
		gangs.state[id].people = maxi(1, int(gangs.state[id].people) - 1)
		var held: Array = [["LOG_GANG_RAID_REPELLED", [gang.name_key, prop.name_key]]]
		held.append_array(_wound_defenders(defenders, float(balance.defender_wound_won)))
		return held
	var taken := 0
	var stock: Dictionary = properties.state[prop.id].stock
	for good: String in stock.keys():
		var n := ceili(int(stock[good]) * float(balance.gang_attack_steal_share))
		properties.add_stock(prop.id, good, -n)
		taken += n
	for person: Dictionary in crew.working_at(prop.id):
		_change_loyalty(person, float(balance.gang_attack_loyalty))
	var raided: Array = [["LOG_GANG_RAID", [gang.name_key, prop.name_key, taken]]]
	raided.append_array(_wound_defenders(defenders, float(balance.defender_wound_lost)))
	return raided


## Кто вышел защищать здание от банды: охранники и бойцы на месте.
func _defenders(property_id: String) -> Array:
	return crew.working_at(property_id).filter(func(p: Dictionary) -> bool:
		return p.role in ["guard", "fighter"] and crew.present.get(p.id, true) and int(p.wounded) == 0)


func _wound_defenders(defenders: Array, chance: float) -> Array:
	var report: Array = []
	for person: Dictionary in defenders:
		if rng.randf() < chance:
			person.wounded = rng.randi_range(int(balance.fight_wound_days[0]), int(balance.fight_wound_days[1]))
			report.append(["LOG_FIGHT_WOUNDED", [person.nick, int(person.wounded)]])
	return report


# --- Разборки ---

func gear_power() -> float:
	return float(balance.gear_levels[gear].power)


func can_buy_gear() -> bool:
	return can_act() and gear + 1 < balance.gear_levels.size() and money >= int(balance.gear_levels[gear + 1].cost)


func buy_gear() -> bool:
	if not can_buy_gear():
		return false
	_spend(int(balance.gear_levels[gear + 1].cost))
	gear += 1
	return true


## Кто пойдёт на разборку днём: бойцы и охранники, не раненые и не на выходном.
func fighters_ready() -> Array:
	return crew.people.filter(func(p: Dictionary) -> bool:
		return p.role in ["fighter", "guard"] and int(p.wounded) == 0 and int(p.off_day) != day)


## Оружие и броня на складах твоих зданий в этом городе: { товар: шт }.
func arsenal() -> Dictionary:
	var stock := {}
	for id: String in ["ammo", "armor"] + balance.weapon_power.keys():
		stock[id] = 0
	for prop: Dictionary in properties.mine():
		if world.city_of(prop.district) == city:
			for id: String in stock:
				stock[id] += properties.stock_of(prop.id, id)
	return stock


## Кто чем вооружён: { id человека: { "weapon": товар или "", "armor": bool } }. Лучшие стволы — самым
## опытным; ствол без патронов (balance.ammo_per_fight на бой) не считается.
func armament() -> Dictionary:
	return _arm(fighters_ready(), arsenal())


## Раздать людям оружие и броню из запаса stock (он не меняется).
func _arm(fighters: Array, supply: Dictionary) -> Dictionary:
	var stock := supply.duplicate()
	for id: String in ["ammo", "armor"] + balance.weapon_power.keys():
		stock[id] = int(stock.get(id, 0))
	var ammo: int = stock.ammo
	var people := fighters.duplicate()
	people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.skill) > int(b.skill))
	var arms: Array = balance.weapon_power.keys()
	arms.sort_custom(func(a: String, b: String) -> bool: return float(balance.weapon_power[a]) > float(balance.weapon_power[b]))
	var result := {}
	for person: Dictionary in people:
		var weapon := ""
		for id: String in arms:
			if stock[id] > 0 and ammo >= int(balance.ammo_per_fight):
				weapon = id
				stock[id] -= 1
				ammo -= int(balance.ammo_per_fight)
				break
		var armored: bool = stock.armor > 0
		if armored:
			stock.armor -= 1
		result[person.id] = { "weapon": weapon, "armor": armored }
	return result


## После боя вооружённые расстреляли патроны — списываем со складов города.
func _spend_ammo(armed: int) -> void:
	var left := armed * int(balance.ammo_per_fight)
	for prop: Dictionary in properties.mine():
		if left > 0 and world.city_of(prop.district) == city:
			var n := mini(left, properties.stock_of(prop.id, "ammo"))
			properties.add_stock(prop.id, "ammo", -n)
			left -= n


## Сила бригады: бойцы сильнее охранников; оружие из арсенала, снаряжение и Лидерство усиливают.
func crew_power() -> float:
	var power := 0.0
	var arms := armament()
	for person: Dictionary in fighters_ready():
		var per_skill := float(balance.fighter_power_per_skill) if person.role == "fighter" else float(balance.guard_power_per_skill)
		var weapon: String = arms.get(person.id, {}).get("weapon", "")
		power += int(person.skill) * per_skill * (1.0 + float(balance.weapon_power.get(weapon, 0.0)))
	return power * gear_power() * (1.0 + skills.level("leadership") * float(balance.leadership_power_per_level))


## Район банды, куда наезжать: где у неё больше всего влияния ("" — земель нет).
func fight_district(gang_id: String) -> String:
	var best := ""
	for where: String in gangs.territories(gang_id):
		if best == "" or gangs.share(where, gang_id) > gangs.share(best, gang_id):
			best = where
	return best


## Сколько банда выставит в своём районе: часть её силы, тем больше, чем крепче она там держится.
func fight_defense(gang_id: String) -> float:
	var where := fight_district(gang_id)
	var share := gangs.share(where, gang_id) if where != "" else 0.0
	return gangs.strength(gang_id) * (float(balance.fight_defense_base) + float(balance.fight_defense_share) * share / 100.0)


## Сила с учётом тактики: хитростью — слабее, но с разведчиком без потерь в силе.
func fight_power(tactic: String, target: String = "") -> float:
	var info: Dictionary = balance.fight_tactics[tactic]
	var mult := float(info.power)
	if info.has("scout_power") and crew.best_skill("scout") > 0:
		mult = float(info.scout_power)
	return crew_power() * mult + ally_power(target)


## Союзники помогают в разборке против других банд частью своей силы.
func ally_power(target: String) -> float:
	var power := 0.0
	for gang: Dictionary in gangs.defs:
		if gang.id != target and gangs.treaty(gang.id).get("kind", "") == "alliance":
			power += gangs.strength(gang.id) * float(balance.ally_power_share)
	return power


func fight_chance(gang_id: String, tactic: String) -> float:
	var power := fight_power(tactic, gang_id)
	var defense := fight_defense(gang_id)
	return power / (power + defense) if power + defense > 0.0 else 0.0


func can_fight(gang_id: String) -> bool:
	return can_act() and energy >= int(balance.fight_energy) and not fighters_ready().filter(
			func(p: Dictionary) -> bool: return p.role == "fighter").is_empty() and fight_district(gang_id) != ""


## Разборка: твои бойцы и охрана против банды в её районе. Сила каждой стороны чуть колеблется.
## Потери: раненые выбывают на несколько дней, погибшие уходят из бригады (остальные злятся и боятся).
## Банда теряет людей; после победы надо выбрать последствия (choose_fight_outcome).
func fight(gang_id: String, tactic: String) -> Array:
	if not can_fight(gang_id) or not balance.fight_tactics.has(tactic):
		return []
	var info: Dictionary = balance.fight_tactics[tactic]
	var where := fight_district(gang_id)
	var spread := float(balance.fight_roll_spread)
	var power := fight_power(tactic, gang_id)
	# Напал на того, с кем договор, — это предательство: договор разорван, остальные банды запомнят.
	var betrayal: Array = _break_treaty(gang_id, float(balance.break_relation)) if gangs.has_treaty(gang_id) else []
	var defense := fight_defense(gang_id)
	var win := power * rng.randf_range(1.0 - spread, 1.0 + spread) > defense * rng.randf_range(1.0 - spread, 1.0 + spread)
	energy -= int(balance.fight_energy)
	var heat := float(info.heat) * skills.heat_multiplier()
	police.add_heat(where, heat)
	gangs.change_relation(gang_id, -float(balance.fight_relation) - (0.0 if win else float(balance.fight_lost_relation)))
	skills.add_xp("leadership", int(balance.xp_leadership))
	var mult := float(info.wound) * (1.0 if win else float(balance.fight_lost_mult))
	var wounded: Array = []
	var dead: Array = []
	var arms := armament()
	_spend_ammo(arms.values().filter(func(a: Dictionary) -> bool: return a.weapon != "").size())
	for person: Dictionary in fighters_ready():
		# Бронежилет вдвое снижает шанс погибнуть или выбыть раненым.
		var cut := float(balance.armor_wound_cut) if arms.get(person.id, {}).get("armor", false) else 1.0
		if rng.randf() < float(balance.fight_death_chance) * mult * cut:
			dead.append(person.nick)
			crew.fire(person.id)
		elif rng.randf() < float(balance.fight_wound_chance) * mult * cut:
			person.wounded = rng.randi_range(int(balance.fight_wound_days[0]), int(balance.fight_wound_days[1]))
			wounded.append(person.nick)
	for person: Dictionary in crew.people:
		if not dead.is_empty():
			_change_loyalty(person, float(balance.fight_death_loyalty) * dead.size())
		var fear := float(balance.fight_death_fear) * dead.size() + (float(balance.fight_win_fear) if win else 0.0)
		person.fear = clampf(float(person.fear) + fear, 0.0, 100.0)
	if not dead.is_empty():
		_drop_broken_routes()
	var losses: Array = balance.fight_gang_losses_win if win else balance.fight_gang_losses_lose
	var gang_losses := rng.randi_range(int(losses[0]), int(losses[1]))
	gangs.state[gang_id].people = maxi(1, int(gangs.state[gang_id].people) - gang_losses)
	fight_result = { "gang": gang_id, "district": where, "tactic": tactic, "win": win, "power": roundi(power),
			"defense": roundi(defense), "wounded": wounded, "dead": dead, "gang_losses": gang_losses, "heat": roundi(heat) }
	var gang := gangs.get_def(gang_id)
	var report: Array = betrayal
	report.append(["LOG_FIGHT_WON" if win else "LOG_FIGHT_LOST", [gang.name_key, market.get_district(where).name_key]])
	if win:
		for ally: Dictionary in gangs.defs:
			if ally.id != gang_id and gangs.treaty(ally.id).get("kind", "") == "alliance":
				gangs.change_relation(ally.id, float(balance.ally_win_relation))
	for nick: String in dead:
		report.append(["LOG_FIGHT_DIED", [nick]])
	for nick: String in wounded:
		report.append(["LOG_FIGHT_WOUNDED_DAYS", [nick]])
	return report


# --- Полиция: детективы, спецназ, «крыша» ---

func krysha_fee(where: String) -> int:
	return roundi(float(balance.krysha_fee) * float(market.get_district(where).police) * (1.0 - perk("krysha_discount")))


func can_hire_krysha(where: String) -> bool:
	return can_act() and not police.has_krysha(where) and money >= krysha_fee(where)


## Купить «крышу» в районе: первая неделя сразу.
func hire_krysha(where: String) -> bool:
	if not can_hire_krysha(where):
		return false
	_spend(krysha_fee(where))
	police.krysha[where] = day + 7
	return true


func drop_krysha(where: String) -> bool:
	if not can_act() or not police.has_krysha(where):
		return false
	police.krysha.erase(where)
	return true


## Шанс, что «крыша» сдаст тебя этой ночью: тем выше, чем толще дело детективов.
## «Крыша» может замять дело детективов: дорого (от толщины дела), дело худеет на hush_amount.
func hush_cost(where: String) -> int:
	return roundi(float(police.dossier[where]) * float(balance.hush_cost_per_point))


func can_hush(where: String) -> bool:
	return can_act() and police.has_krysha(where) and float(police.dossier[where]) > 0.0 and money >= hush_cost(where)


func hush_case(where: String) -> bool:
	if not can_hush(where):
		return false
	_spend(hush_cost(where))
	police.add_dossier(where, -float(balance.hush_amount))
	return true


func krysha_rat_chance(where: String) -> float:
	return float(balance.krysha_rat_base) + float(police.dossier[where]) * float(balance.krysha_rat_per_dossier)


## Ночь у полиции. «Крыша»: оплата раз в неделю (нечем — уходит, розыск растёт), может сдать (дело толстеет),
## гасит розыск района. Детективы при высоком розыске ведут дело: улики в твоих нелегальных точках растут;
## дело дошло до конца — спецназ берёт все нелегальные точки района. Адвокат и «крыша» дело замедляют.
func _run_police() -> Array:
	var report: Array = []
	var goods_legal := {}
	for good: Dictionary in market.goods:
		goods_legal[good.id] = good.legal
	for where: String in police.heat.keys():
		var name_key: String = market.get_district(where).name_key
		if police.has_krysha(where):
			if int(police.krysha[where]) <= day:
				var fee := krysha_fee(where)
				if money < fee:
					police.krysha.erase(where)
					police.add_heat(where, float(balance.krysha_leave_heat))
					report.append(["LOG_KRYSHA_LEFT", [name_key]])
				else:
					_spend(fee)
					police.krysha[where] = int(police.krysha[where]) + 7
					report.append(["LOG_KRYSHA_PAID", [name_key, fee]])
			if police.has_krysha(where) and rng.randf() < krysha_rat_chance(where):
				police.krysha.erase(where)
				police.add_dossier(where, float(balance.krysha_rat_dossier))
				report.append(["LOG_KRYSHA_RATTED", [name_key]])
			if police.has_krysha(where):
				police.add_heat(where, -float(balance.krysha_heat_decay))
		var spots := properties.mine().filter(func(p: Dictionary) -> bool:
			return p.district == where and properties.has_illegal(p.id, goods_legal))
		if not police.detectives_on(where):
			police.add_dossier(where, -float(balance.dossier_decay))
			continue
		if float(police.dossier[where]) == 0.0:
			report.append(["LOG_DETECTIVES_START", [name_key]])
		var grow := (float(police.heat[where]) - float(balance.detective_stars) * 20.0) * float(balance.dossier_per_heat) \
				+ spots.size() * float(balance.dossier_per_property)
		grow *= maxf(0.0, 1.0 - crew.best_skill("lawyer") * float(balance.lawyer_dossier_per_skill))
		grow *= hacker_cover(world.city_of(where))
		if police.has_krysha(where):
			grow *= float(balance.krysha_dossier)
		police.add_dossier(where, maxf(1.0, grow))
		for prop: Dictionary in spots:
			var st: Dictionary = properties.state[prop.id]
			st.evidence = minf(100.0, float(st.evidence) + float(balance.dossier_evidence))
		if float(police.dossier[where]) < float(balance.dossier_case):
			continue
		police.dossier[where] = float(balance.dossier_after_case)
		if spots.is_empty():
			report.append(["LOG_CASE_EMPTY", [name_key]])
			continue
		report.append(["LOG_CASE_RAID", [name_key, spots.size()]])
		for prop: Dictionary in spots:
			var defenders := _defenders(prop.id)
			_lose_property_goods(prop.id, goods_legal, true)
			police.add_heat(where, float(balance.swat_heat))
			report.append(["LOG_SWAT_RAID", [prop.name_key]])
			report.append_array(_wound_defenders(defenders, float(balance.swat_wound)))
	return report


# --- Дипломатия ---

func can_meet(gang_id: String) -> bool:
	return can_act() and money >= int(balance.meet_gift) and int(gangs.met_day.get(gang_id, 0)) != day


## Встреча с боссом: подарок, отношение лучше (Харизма помогает). Враги могут устроить ловушку — тогда тебя
## помнут (минус силы), подарок пропал.
func meet(gang_id: String) -> Array:
	if not can_meet(gang_id):
		return []
	gangs.met_day[gang_id] = day
	_spend(int(balance.meet_gift))
	gangs.state[gang_id].cash = int(gangs.state[gang_id].cash) + int(balance.meet_gift)
	var gang := gangs.get_def(gang_id)
	if gangs.level(gang_id) == "enemy" and rng.randf() < float(balance.meet_trap_chance):
		energy = maxi(0, energy - int(balance.meet_trap_energy))
		return [["LOG_MEET_TRAP", [gang.name_key]]]
	var gain := float(balance.meet_relation) * (1.0 + skills.level("charisma") * float(balance.meet_charisma_per_level))
	gangs.change_relation(gang_id, gain)
	skills.add_xp("charisma", int(balance.xp_meet))
	return [["LOG_MEET_DONE", [gang.boss_key, gang.name_key, roundi(gain)]]]


## Стоимость договора: налог за мир — в неделю, перемирие — разово (от силы банды); остальные бесплатны.
func treaty_cost(gang_id: String, kind: String) -> int:
	var info: Dictionary = balance.treaties[kind]
	if info.has("tax_per_strength"):
		return gangs.strength(gang_id) * int(info.tax_per_strength)
	if info.has("cost_per_strength"):
		return gangs.strength(gang_id) * int(info.cost_per_strength)
	return 0


## Согласна ли банда: ненападение — если отношение не хуже порога, союз — только с друзьями,
## перемирие — только когда воюете (соперники или враги), налог за мир берут всегда.
func treaty_allowed(gang_id: String, kind: String) -> bool:
	var info: Dictionary = balance.treaties[kind]
	if info.has("min_relation") and gangs.relation(gang_id) < float(info.min_relation):
		return false
	if info.has("min_level") and gangs.level_rank(gang_id) > Gangs.LEVELS.find(info.min_level):
		return false
	if info.has("max_level") and gangs.level_rank(gang_id) < Gangs.LEVELS.find(info.max_level):
		return false
	return true


func can_sign(gang_id: String, kind: String) -> bool:
	return can_act() and balance.treaties.has(kind) and not gangs.has_treaty(gang_id) \
			and treaty_allowed(gang_id, kind) and money >= treaty_cost(gang_id, kind)


## Заключить договор. Налог за мир платится сразу за первую неделю, перемирие — разово.
func sign_treaty(gang_id: String, kind: String) -> Array:
	if not can_sign(gang_id, kind):
		return []
	var cost := treaty_cost(gang_id, kind)
	_spend(cost)
	gangs.state[gang_id].cash = int(gangs.state[gang_id].cash) + cost
	var days := int(balance.treaties[kind].days)
	gangs.treaties[gang_id] = { "kind": kind, "until": day + days if days > 0 else 0,
			"paid_day": day + 7 if kind == "peace_tax" else 0 }
	gangs.state[gang_id].revenge = false
	gangs.change_relation(gang_id, float(balance.treaty_sign_relation))
	# Требования этой банды по договору снимаются.
	for offer: Dictionary in gangs.offers.duplicate():
		if offer.gang == gang_id and offer.kind == "demand":
			gangs.offers.erase(offer)
	return [["LOG_TREATY_SIGNED", [gangs.get_def(gang_id).name_key, balance.treaties[kind].name_key]]]


## Разорвать договор самому: налог за мир — просто перестать платить (небольшая обида),
## остальные досрочно — предательство (остальные банды тоже запомнят).
func cancel_treaty(gang_id: String) -> Array:
	if not can_act() or not gangs.has_treaty(gang_id):
		return []
	if gangs.treaty(gang_id).kind == "peace_tax":
		gangs.treaties.erase(gang_id)
		gangs.change_relation(gang_id, -float(balance.cancel_relation))
		return [["LOG_TREATY_CANCELLED", [gangs.get_def(gang_id).name_key]]]
	return _break_treaty(gang_id, float(balance.cancel_relation) * 2.0)


## Ты нарушил договор: обида банды и твоя слава «нарушает слово» у остальных.
func _break_treaty(gang_id: String, relation_drop: float) -> Array:
	var kind: String = gangs.treaty(gang_id).kind
	gangs.treaties.erase(gang_id)
	gangs.change_relation(gang_id, -relation_drop)
	for gang: Dictionary in gangs.defs:
		if gang.id != gang_id:
			gangs.change_relation(gang.id, -float(balance.break_others_relation))
	return [["LOG_TREATY_BROKEN_BY_YOU", [gangs.get_def(gang_id).name_key, balance.treaties[kind].name_key]]]


## Шанс, что банда сама нарушит договор этой ночью: от характера босса, выше при плохом отношении
## и если ты заметно слабее неё.
func gang_betray_chance(gang_id: String) -> float:
	var chance := float(gangs.temper(gang_id).betray)
	if gangs.relation(gang_id) < float(balance.betray_low_relation):
		chance *= 2.0
	if crew_power() + ally_power(gang_id) < gangs.strength(gang_id) * float(balance.betray_weak_ratio):
		chance *= float(balance.betray_weak_mult)
	return minf(1.0, chance)


## Ночь для договоров: налог за мир (не хватило денег — договор сорван, банда мстит), сроки,
## предательство банд (договор кончается, и той же ночью — налёт).
func _run_treaties() -> Array:
	var report: Array = []
	for gang: Dictionary in gangs.defs:
		var id: String = gang.id
		if not gangs.has_treaty(id):
			continue
		var t: Dictionary = gangs.treaty(id)
		if t.kind == "peace_tax" and int(t.paid_day) <= day:
			var tax := treaty_cost(id, "peace_tax")
			if money < tax:
				gangs.treaties.erase(id)
				gangs.change_relation(id, -float(balance.tax_missed_relation))
				gangs.state[id].revenge = true
				report.append(["LOG_TAX_MISSED", [gang.name_key]])
				continue
			_spend(tax)
			gangs.state[id].cash = int(gangs.state[id].cash) + tax
			t.paid_day = int(t.paid_day) + 7
			report.append(["LOG_TAX_PAID", [gang.name_key, tax]])
		if int(t.until) > 0 and int(t.until) <= day:
			gangs.treaties.erase(id)
			report.append(["LOG_TREATY_ENDED", [gang.name_key, balance.treaties[t.kind].name_key]])
			continue
		if rng.randf() < gang_betray_chance(id):
			gangs.treaties.erase(id)
			gangs.state[id].revenge = true
			gangs.change_relation(id, -float(balance.break_others_relation))
			report.append(["LOG_TREATY_BETRAYED", [gang.name_key, gang.boss_key, balance.treaties[t.kind].name_key]])
	return report


## Что сделать после разборки. Победа: "take" — забрать влияние в районе, "tribute" — взять выкуп из общака,
## "mercy" — отпустить (обида меньше). Поражение — только "ok".
func choose_fight_outcome(option: String) -> Array:
	if fight_result.is_empty():
		return []
	var result := fight_result
	var id: String = result.gang
	var gang := gangs.get_def(id)
	if not result.win:
		fight_result = {}
		return []
	match option:
		"take":
			gangs.take_from(result.district, id, float(balance.fight_take_influence))
			gangs.change_relation(id, -float(balance.fight_take_relation))
			fight_result = {}
			return [["LOG_FIGHT_TOOK", [gang.name_key, market.get_district(result.district).name_key]]]
		"tribute":
			var amount := roundi(int(gangs.state[id].cash) * float(balance.fight_tribute_share))
			gangs.state[id].cash = int(gangs.state[id].cash) - amount
			dirty += amount
			gangs.change_relation(id, -float(balance.fight_tribute_relation))
			fight_result = {}
			return [["LOG_FIGHT_TRIBUTE", [gang.name_key, amount]]]
		"mercy":
			gangs.take_from(result.district, id, float(balance.fight_mercy_influence))
			gangs.change_relation(id, float(balance.fight_mercy_relation))
			fight_result = {}
			return [["LOG_FIGHT_MERCY", [gang.name_key]]]
	return []


## Переманивают самого недовольного из твоих людей (если лояльность ниже порога).
func _gang_poach(id: String) -> Array:
	var unhappy := crew.people.filter(func(p: Dictionary) -> bool: return float(p.loyalty) < float(balance.gang_poach_loyalty))
	if unhappy.is_empty():
		return []
	unhappy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.loyalty) < float(b.loyalty))
	var person: Dictionary = unhappy[0]
	var gang := gangs.get_def(id)
	if rng.randf() >= float(balance.gang_poach_chance):
		_change_loyalty(person, float(balance.gang_poach_refused_loyalty))
		return [["LOG_GANG_POACH_FAILED", [person.nick, gang.name_key]]]
	crew.fire(person.id)
	_drop_broken_routes()
	gangs.state[id].people = int(gangs.state[id].people) + 1
	return [["LOG_GANG_POACHED", [person.nick, gang.name_key]]]


## Предложение купить у банды партию нелегального товара дешевле рынка.
func _gang_deal(id: String) -> Array:
	var where: String = gangs.get_def(id).home
	# Редкостями банды не торгуют оптом.
	var goods := market.goods.filter(func(good: Dictionary) -> bool:
		return not good.legal and good.get("category", "") != "rare" and market.trades(where, good.id))
	if goods.is_empty():
		return []
	var good: Dictionary = goods[rng.randi() % goods.size()]
	var units := int(balance.gang_deal_units)
	var amount := roundi(market.buy_price(where, good.id) * units * float(balance.gang_deal_price))
	gangs.add_offer({ "gang": id, "kind": "deal", "amount": amount, "good": good.id, "units": units,
			"expires": day + int(balance.gang_offer_days) })
	return [["LOG_GANG_DEAL_OFFER", [gangs.get_def(id).name_key, units, good.name_key, amount]]]


func can_accept_offer(offer_id: int) -> bool:
	var offer := gangs.get_offer(offer_id)
	if not can_act() or offer.is_empty() or money < int(offer.amount):
		return false
	return offer.kind == "demand" or int(offer.units) * good_size(offer.good) <= pocket_free()


## Ответ на требование или предложение: accept — заплатить долю / купить товар (сначала грязными).
func answer_offer(offer_id: int, accept: bool) -> Array:
	var offer := gangs.get_offer(offer_id)
	if offer.is_empty() or not can_act() or accept and not can_accept_offer(offer_id):
		return []
	gangs.offers.erase(offer)
	var gang := gangs.get_def(offer.gang)
	if offer.kind == "demand":
		if not accept:
			_refuse_demand(offer)
			return [["LOG_GANG_DEMAND_REFUSED", [gang.name_key]]]
		_spend(int(offer.amount))
		gangs.state[offer.gang].cash = int(gangs.state[offer.gang].cash) + int(offer.amount)
		gangs.change_relation(offer.gang, float(balance.gang_demand_paid_relation))
		return [["LOG_GANG_DEMAND_PAID", [gang.name_key, int(offer.amount)]]]
	if not accept:
		return [["LOG_GANG_DEAL_DECLINED", [gang.name_key]]]
	_spend(int(offer.amount))
	inventory[offer.good] += int(offer.units)
	spent_on[offer.good] += int(offer.amount)
	gangs.state[offer.gang].cash = int(gangs.state[offer.gang].cash) + int(offer.amount)
	gangs.change_relation(offer.gang, float(balance.gang_deal_relation))
	return [["LOG_GANG_DEAL_DONE", [gang.name_key, int(offer.units), market.get_good(offer.good).name_key]]]


func _refuse_demand(offer: Dictionary) -> void:
	gangs.change_relation(offer.gang, -float(balance.gang_demand_refused_relation))
	gangs.state[offer.gang].revenge = true


## Аренда комнаты — только чистыми. Не хватает: доплачиваешь грязными, и это замечают.
## Совсем нечем: ростовщик платит за тебя и добавляет в долг.
func _pay_rent() -> Array:
	var rent: int = balance.rent_per_day
	var from_clean := mini(rent, clean)
	clean -= from_clean
	var rest := rent - from_clean
	if rest == 0:
		return []
	var from_dirty := mini(rest, dirty)
	dirty -= from_dirty
	rest -= from_dirty
	var report: Array = []
	if from_dirty > 0:
		police.add_heat(district, balance.dirty_rent_heat)
		report.append(["LOG_RENT_DIRTY", []])
	if rest > 0:
		debt += rest
		report.append(["LOG_RENT_DEBT", [rest]])
	return report


# --- Сохранение ---

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"district": district,
		"city": city,
		"news": news.duplicate(true),
		"stories": stories.duplicate(true),
		"stories_done": stories_done.keys(),
		"story_perks": story_perks.duplicate(),
		"news_read": news_read,
		"energy": energy,
		"skills": skills.to_dict(),
		"stall": stall.to_dict(),
		"properties": properties.to_dict(),
		"crew": crew.to_dict(),
		"logistics": logistics.to_dict(),
		"gangs": gangs.to_dict(),
		"clean": clean,
		"dirty": dirty,
		"clean_earned": clean_earned,
		"debt": debt,
		"status": status,
		"next_payment_day": next_payment_day,
		"paid_this_period": paid_this_period,
		"inventory": inventory.duplicate(),
		"spent_on": spent_on.duplicate(),
		"pending_check": pending_check.duplicate(),
		"documents": documents.to_dict(),
		"smuggle_case": smuggle_case,
		"last_arrest_day": last_arrest_day,
		"money_history": money_history.duplicate(),
		"heat_history": heat_history.duplicate(),
		"gear": gear,
		"fight_result": fight_result.duplicate(true),
		"hours_done": hours_done,
		"carry": _carry.duplicate(),
		"sales": _sales.duplicate(true),
		"income_today": income_today.duplicate(),
		"suppliers": suppliers.to_dict(),
		"manager_orders": manager_orders.duplicate(true),
		"jobs": jobs.to_dict(),
		"neighbor_mood": neighbor_mood.duplicate(),
		"rank": rank,
		"earned_total": earned_total,
		"orders_done": orders_done,
		"insiders": insiders.duplicate(),
		"operations": operations.duplicate(true),
		"ops_done": ops_done,
		"vaults_done": vaults_done,
		"mode": mode,
		"home_city": home_city,
		"background": background,
		"arrests": arrests,
		"visited": visited.keys(),
		"dirty_earned": dirty_earned,
		"ending": ending,
		"ending_offer": ending_offer,
		"endings_declined": endings_declined.duplicate(),
		"rng_state": str(rng.state),
		"market": market.to_dict(),
		"police": police.to_dict(),
		"events": events.to_dict(),
		"bank": bank.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	day = int(data.day)
	district = data.district
	city = String(data.get("city", world.city_of(district)))
	energy = int(data.energy)
	skills.load_dict(data.skills)
	stall.load_dict(data.stall)
	properties.load_dict(data.get("properties", {}))
	crew.load_dict(data.get("crew", {}))
	logistics.load_dict(data.get("logistics", {}))
	gangs.load_dict(data.get("gangs", {}))
	documents.load_dict(data.get("documents", {}))
	smuggle_case = bool(data.get("smuggle_case", false))
	last_arrest_day = int(data.get("last_arrest_day", -1000))
	clean = int(data.clean)
	dirty = int(data.dirty)
	clean_earned = int(data.clean_earned)
	debt = int(data.debt)
	status = int(data.status) as Status
	next_payment_day = int(data.next_payment_day)
	paid_this_period = int(data.paid_this_period)
	for id: String in inventory:
		inventory[id] = int(data.inventory.get(id, 0))
		spent_on[id] = int(data.spent_on.get(id, 0))
	pending_check = {}
	if not data.pending_check.is_empty():
		pending_check = { "bribe": int(data.pending_check.bribe) }
		if data.pending_check.get("customs", false):
			pending_check.customs = true
	money_history = data.get("money_history", []).map(func(v: Variant) -> int: return int(v))
	heat_history = data.get("heat_history", []).map(func(v: Variant) -> float: return float(v))
	gear = int(data.get("gear", 0))
	fight_result = data.get("fight_result", {})
	hours_done = float(data.get("hours_done", 0.0))
	_carry = data.get("carry", {})
	_sales = data.get("sales", {})
	income_today = data.get("income_today", {})
	suppliers.load_dict(data.get("suppliers", {}))
	jobs.load_dict(data.get("jobs", {}))
	neighbor_mood = data.get("neighbor_mood", {})
	rank = int(data.get("rank", 0))
	# Старые сохранения: заработанное до этапа 8.5 не считали — берём хотя бы честное.
	earned_total = int(data.get("earned_total", data.clean_earned))
	orders_done = int(data.get("orders_done", 0))
	operations = {}
	for id: String in data.get("operations", {}):
		var st: Dictionary = data.operations[id]
		operations[id] = { "preps": Array(st.get("preps", [])).map(func(p: Variant) -> String: return String(p)), "ready": int(st.get("ready", 0)) }
	ops_done = int(data.get("ops_done", 0))
	vaults_done = int(data.get("vaults_done", 0))
	mode = String(data.get("mode", "career"))
	home_city = String(data.get("home_city", world.home))
	background = String(data.get("background", ""))
	arrests = int(data.get("arrests", 0))
	visited = {}
	for c: Variant in data.get("visited", [home_city, city]):
		visited[String(c)] = true
	# Старые сохранения: грязные не считали — всё, что не чистое.
	dirty_earned = int(data.get("dirty_earned", maxi(0, earned_total - clean_earned)))
	ending = String(data.get("ending", ""))
	ending_offer = String(data.get("ending_offer", ""))
	endings_declined = Array(data.get("endings_declined", [])).map(func(e: Variant) -> String: return String(e))
	insiders = {}
	for zone: String in data.get("insiders", {}):
		insiders[zone] = int(data.insiders[zone])
	manager_orders = {}
	for id: String in data.get("manager_orders", {}):
		var orders: Dictionary = data.manager_orders[id]
		manager_orders[id] = { "brew": String(orders.get("brew", "auto")), "launder_keep": int(orders.get("launder_keep", 0)) }
	if not fight_result.is_empty():
		fight_result.win = bool(fight_result.win)
		for key: String in ["power", "defense", "gang_losses", "heat"]:
			fight_result[key] = int(fight_result[key])
	rng.state = int(data.rng_state)
	police.load_dict(data.police)
	events.load_dict(data.events, String(data.get("event_city", city)))
	bank.load_dict(data.bank)
	market.city_events = {}
	for c: Dictionary in world.cities:
		market.city_events[c.id] = events.active_in(c.id)
	news = data.get("news", [])
	stories = {}
	for id: String in data.get("stories", {}):
		var st: Dictionary = data.stories[id]
		stories[id] = { "step": String(st.step), "city": String(st.city), "show": int(st.show), "deadline": int(st.deadline) }
	stories_done = {}
	for id: Variant in data.get("stories_done", []):
		stories_done[String(id)] = true
	story_perks = {}
	for key: String in data.get("story_perks", {}):
		story_perks[key] = float(data.story_perks[key])
	news_read = bool(data.get("news_read", true))
	market.load_dict(data.market)
