class_name DayTrack
extends Control
## Трекер срока, как отслеживание доставки: дни от начала срока до платежа — точки на линии.
## Прошедшие дни залиты, сегодняшний обведён, у важных дней (проценты, платёж) — подписи.

const COLOR_LINE := Color(0.89, 0.905, 0.935)
const COLOR_DONE := Color(0.184, 0.42, 1.0)
const COLOR_TEXT := Color(0.106, 0.122, 0.165)
const COLOR_MUTED := Color(0.42, 0.45, 0.52)

var first_day := 1
var last_day := 14
var today := 1
## Подписи под точками: { номер_дня: [заголовок, подзаголовок] }.
var marks: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_state(from_day: int, to_day: int, current: int, day_marks: Dictionary) -> void:
	first_day = from_day
	last_day = to_day
	today = current
	marks = day_marks
	queue_redraw()


func _draw() -> void:
	var count := last_day - first_day + 1
	if count < 2:
		return
	var pad := 26.0
	var y := 10.0
	var step := (size.x - pad * 2.0) / (count - 1)
	var font := get_theme_default_font()
	var done_x := pad + step * clampf(today - first_day, 0, count - 1)
	draw_line(Vector2(pad, y), Vector2(size.x - pad, y), COLOR_LINE, 3.0, true)
	draw_line(Vector2(pad, y), Vector2(done_x, y), COLOR_DONE, 3.0, true)
	for i in count:
		var day := first_day + i
		var x := pad + step * i
		var marked := marks.has(day)
		var radius := 7.0 if marked or day == today else 3.5
		if day < today:
			draw_circle(Vector2(x, y), radius, COLOR_DONE)
		elif day == today:
			draw_circle(Vector2(x, y), radius + 2.0, Color(COLOR_DONE, 0.18))
			draw_circle(Vector2(x, y), radius, Color.WHITE)
			draw_arc(Vector2(x, y), radius, 0, TAU, 24, COLOR_DONE, 2.5, true)
		else:
			draw_circle(Vector2(x, y), radius, Color.WHITE)
			draw_arc(Vector2(x, y), radius, 0, TAU, 24, COLOR_LINE, 2.0, true)
		if not marked:
			continue
		var lines: Array = marks[day]
		_center_text(font, String(lines[0]), x, y + 24.0, 11, COLOR_TEXT)
		_center_text(font, String(lines[1]), x, y + 37.0, 10, COLOR_MUTED)


func _center_text(font: Font, text: String, x: float, baseline: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := clampf(x - width / 2.0, 0.0, size.x - width)
	draw_string(font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
