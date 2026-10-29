extends Node
## Игровые часы: время внутри дня, пауза и скорости ×1/×2/×4.
## Когда день заканчивается, просит GameState закрыть день.

signal speed_changed

const SPEEDS: Array[int] = [1, 2, 4]
const DAY_START_HOUR := 6

## Сколько реальных секунд прошло с начала дня (при ×1).
var elapsed: float = 0.0
var speed: int = 1
var paused: bool = true:
	set(value):
		paused = value
		speed_changed.emit()

var _day_length: float = 90.0


func _ready() -> void:
	_day_length = GameData.load_balance().day_length_sec


func _process(delta: float) -> void:
	if paused or GameState.session == null:
		return
	elapsed += delta * speed
	if elapsed >= _day_length:
		finish_day()


func reset() -> void:
	elapsed = 0.0
	speed = 1
	paused = true


func set_speed(value: int) -> void:
	speed = value
	paused = false


## Промотать время (переезд). Если день кончился — закрываем его.
func advance_hours(hours: float) -> void:
	elapsed += hours / 24.0 * _day_length
	if elapsed >= _day_length:
		finish_day()


## Закончить день сразу (кнопка «Закончить день»).
func finish_day() -> void:
	elapsed = 0.0
	GameState.end_day()


## Время суток в минутах от полуночи: день идёт с 06:00 до 06:00 следующего утра.
func minutes_of_day() -> int:
	return (DAY_START_HOUR * 60 + int(elapsed / _day_length * 24 * 60)) % (24 * 60)
