class_name Sparkline
extends Control
## Мини-график: линия по значениям, мягкая заливка под ней и точка на последнем значении.

var color := Color(0.45, 0.9, 0.55)

var _values: Array = []


func _init(size_px := Vector2(70, 24)) -> void:
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(values: Array) -> void:
	_values = values
	queue_redraw()


func _draw() -> void:
	if _values.size() < 2:
		# Истории ещё нет: просто тонкая линия посередине.
		draw_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), Color(color, 0.35), 1.5, true)
		return
	var low: float = _values.min()
	var high: float = _values.max()
	var span := maxf(high - low, 0.0001)
	var points := PackedVector2Array()
	for i in _values.size():
		var x := size.x * i / (_values.size() - 1)
		var y := size.y - 2.0 - (float(_values[i]) - low) / span * (size.y - 4.0)
		points.append(Vector2(x, y))
	var fill := points.duplicate()
	fill.append(Vector2(size.x, size.y))
	fill.append(Vector2(0, size.y))
	draw_colored_polygon(fill, Color(color, 0.18))
	draw_polyline(points, color, 1.6, true)
	draw_circle(points[points.size() - 1], 2.6, color)
