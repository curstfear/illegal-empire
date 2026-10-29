extends Node
## Текущая партия. Экраны читают отсюда данные и отправляют сюда команды.

signal changed
signal day_ended(report: Array)
signal finished(status: GameSession.Status)

var session: GameSession
## Первая запись журнала для экрана игры: [ключ_перевода, аргументы].
var intro: Array = []


func new_game() -> void:
	session = GameSession.new(GameData.load_balance(), GameData.load_goods())
	var b := session.balance
	intro = ["LOG_NEW_GAME", [int(b.start_debt), int(b.payment_min), int(b.payment_interval_days), int(b.start_money)]]
	Clock.reset()
	changed.emit()


func continue_game() -> bool:
	var data := SaveSystem.load_game()
	if data.is_empty():
		return false
	session = GameSession.new(GameData.load_balance(), GameData.load_goods())
	session.load_dict(data)
	intro = ["LOG_LOADED", [session.day]]
	Clock.reset()
	changed.emit()
	return true


func save() -> bool:
	return session != null and session.status == GameSession.Status.PLAYING \
			and SaveSystem.save_game(session.to_dict())


func buy(id: String, amount: int) -> void:
	if session.buy(id, amount):
		changed.emit()


func sell(id: String, amount: int) -> void:
	if session.sell(id, amount):
		changed.emit()


func pay(amount: int) -> void:
	if session.pay(amount) > 0:
		changed.emit()
		_check_finished()


func end_day() -> void:
	var report := session.end_day()
	day_ended.emit(report)
	changed.emit()
	if not _check_finished():
		save()


func _check_finished() -> bool:
	if session.status == GameSession.Status.PLAYING:
		return false
	Clock.paused = true
	finished.emit(session.status)
	return true
