extends Node
## Текущая партия. Экраны читают отсюда данные и отправляют сюда команды.

signal changed
## Записи для журнала: список [ключ_перевода, аргументы].
signal reported(report: Array)
signal finished(status: GameSession.Status)

var session: GameSession
## Первая запись журнала для экрана игры: [ключ_перевода, аргументы].
var intro: Array = []


func new_game() -> void:
	session = _make_session()
	var b := session.balance
	intro = ["LOG_NEW_GAME", [int(b.start_debt), int(b.payment_min), int(b.payment_interval_days), int(b.start_money)]]
	Clock.reset()
	changed.emit()


func continue_game() -> bool:
	var data := SaveSystem.load_game()
	if data.is_empty():
		return false
	session = _make_session()
	session.load_dict(data)
	intro = ["LOG_LOADED", [session.day]]
	Clock.reset()
	changed.emit()
	return true


func save() -> bool:
	return session != null and session.status == GameSession.Status.PLAYING \
			and session.pending_check.is_empty() and SaveSystem.save_game(session.to_dict())


func buy(id: String, amount: int) -> void:
	if session.buy(id, amount):
		_after_deal()


func sell(id: String, amount: int) -> void:
	if session.sell(id, amount):
		Audio.coin()
		_after_deal()


func travel(district: String) -> void:
	if session.travel(district):
		reported.emit([["LOG_TRAVEL", [session.market.get_district(district).name_key]]])
		changed.emit()
		Clock.advance_hours(session.balance.travel_hours)


## Подработка или сбор: занимает часы, и до конца дня их должно хватить.
func can_do_activity(id: String) -> bool:
	return session.can_do_activity(id) and Clock.hours_left() >= float(session.get_activity(id).hours)


func do_activity(id: String) -> void:
	if not can_do_activity(id):
		return
	var report := session.do_activity(id)
	# Звук по итогу: заплатили — монеты, собрал — «готово», сорвалось или арест — ошибка и сирена.
	match report[0][0] if not report.is_empty() else "":
		"LOG_JOB_DONE":
			Audio.coin()
		"LOG_GATHERED":
			Audio.ui("confirmation")
		"LOG_ACTIVITY_BUSTED":
			Audio.ui("error")
		"LOG_ARRESTED":
			Audio.siren()
	reported.emit(report)
	changed.emit()
	Clock.advance_hours(session.get_activity(id).hours)


func buy_stall() -> void:
	if session.buy_stall():
		reported.emit([["LOG_STALL_BOUGHT", []]])
		changed.emit()


func stock_stall(id: String) -> void:
	if session.stock_stall(id):
		changed.emit()


# --- Недвижимость ---

func buy_property(id: String) -> void:
	if session.buy_property(id):
		Audio.ui("confirmation")
		reported.emit([["LOG_PROPERTY_BOUGHT", [session.properties.get_def(id).name_key]]])
		changed.emit()


func rent_property(id: String) -> void:
	if session.rent_property(id):
		Audio.ui("confirmation")
		reported.emit([["LOG_PROPERTY_RENTED", [session.properties.get_def(id).name_key]]])
		changed.emit()


func store_goods(id: String, good: String) -> void:
	if session.store_goods(id, good) > 0:
		changed.emit()


func take_goods(id: String, good: String) -> void:
	if session.take_goods(id, good) > 0:
		changed.emit()


func start_production(id: String, recipe_id: String) -> void:
	var count := session.start_production(id, recipe_id)
	if count > 0:
		Audio.ui("confirmation")
		reported.emit([["LOG_PRODUCTION_STARTED", [count, session.properties.get_recipe(recipe_id).name_key]]])
		changed.emit()


func upgrade_lab(id: String) -> void:
	if session.upgrade_lab(id):
		Audio.ui("confirmation")
		reported.emit([["LOG_LAB_UPGRADED", [int(session.properties.state[id].level)]]])
		changed.emit()


func sell_property(id: String) -> void:
	var price := session.sell_property(id)
	if price >= 0:
		if price > 0:
			Audio.coin()
		else:
			Audio.ui("confirmation")
		reported.emit([["LOG_PROPERTY_SOLD" if price > 0 else "LOG_PROPERTY_LEFT", [session.properties.get_def(id).name_key, price]]])
		changed.emit()


func buy_upgrade(id: String, upgrade: String) -> void:
	if session.buy_upgrade(id, upgrade):
		Audio.ui("confirmation")
		reported.emit([["LOG_UPGRADE_BOUGHT", [session.balance.upgrades[upgrade].name_key, session.properties.get_def(id).name_key]]])
		changed.emit()


## Уборка занимает часы — до конца дня их должно хватить.
func can_cleanup(id: String) -> bool:
	return session.can_cleanup(id) and Clock.hours_left() >= float(session.balance.cleanup_hours)


func cleanup(id: String) -> void:
	if not can_cleanup(id):
		return
	session.cleanup(id)
	Audio.ui("confirmation")
	reported.emit([["LOG_CLEANED_UP", [session.properties.get_def(id).name_key]]])
	changed.emit()
	Clock.advance_hours(session.balance.cleanup_hours)


# --- Бригада ---

func hire(id: int) -> void:
	var person := session.crew.get_candidate(id)
	if session.hire(id):
		Audio.ui("confirmation")
		reported.emit([["LOG_CREW_HIRED", [person.nick, session.crew.roles[person.role].name_key]]])
		changed.emit()


func fire(id: int) -> void:
	var person := session.crew.get_person(id)
	if session.fire(id):
		reported.emit([["LOG_CREW_FIRED", [person.nick]]])
		changed.emit()


func assign(person_id: int, property_id: String) -> void:
	if session.assign(person_id, property_id):
		Audio.ui("select")
		changed.emit()


func launder(id: String) -> void:
	var amount := session.launder(id)
	if amount > 0:
		Audio.coin()
		reported.emit([["LOG_LAUNDER_QUEUED", [amount]]])
		changed.emit()


func pay(amount: int) -> void:
	if session.pay(amount) > 0:
		changed.emit()
		_check_finished()


func borrow_from_shark() -> void:
	if session.borrow_from_shark():
		reported.emit([["LOG_SHARK_LOAN", [int(session.balance.shark_loan_step)]]])
		changed.emit()


func deposit_clean() -> void:
	if session.deposit_clean():
		changed.emit()


func withdraw_deposit() -> void:
	if session.withdraw_deposit():
		changed.emit()


func take_bank_loan() -> void:
	var amount := session.take_bank_loan()
	if amount > 0:
		reported.emit([["LOG_BANK_LOAN", [amount]]])
		changed.emit()


func repay_bank_loan() -> void:
	if session.repay_bank_loan() > 0:
		changed.emit()


## Ответ на проверку полиции: "bribe", "surrender" или "flee".
func resolve_check(choice: String) -> void:
	var day_before := session.day
	var report: Array = session.call(choice)
	if report.is_empty():
		return
	if report[0][0] == "LOG_ARRESTED":
		Audio.siren()
	reported.emit(report)
	if session.day != day_before:
		Clock.elapsed = 0.0
	changed.emit()
	if not _check_finished():
		Clock.paused = false
		if session.day != day_before:
			save()


func lay_low() -> void:
	var report := session.lay_low()
	if report.is_empty():
		return
	reported.emit(report)
	Clock.finish_day()


func end_day() -> void:
	var report := session.end_day()
	reported.emit(report)
	changed.emit()
	if not _check_finished():
		save()


func _after_deal() -> void:
	if not session.pending_check.is_empty():
		Clock.paused = true
		Audio.siren()
	changed.emit()


func _check_finished() -> bool:
	if session.status == GameSession.Status.PLAYING:
		return false
	Clock.paused = true
	finished.emit(session.status)
	return true


func _make_session() -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events(), GameData.load_activities(),
			GameData.load_properties(), GameData.load_recipes(), GameData.load_crew())
