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
		_after_deal()


func travel(district: String) -> void:
	if session.travel(district):
		reported.emit([["LOG_TRAVEL", [session.market.get_district(district).name_key]]])
		changed.emit()
		Clock.advance_hours(session.balance.travel_hours)


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
	changed.emit()


func _check_finished() -> bool:
	if session.status == GameSession.Status.PLAYING:
		return false
	Clock.paused = true
	finished.emit(session.status)
	return true


func _make_session() -> GameSession:
	return GameSession.new(GameData.load_balance(), GameData.load_goods(),
			GameData.load_districts(), GameData.load_events())
