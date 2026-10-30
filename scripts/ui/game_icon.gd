class_name GameIcon
extends Control
## Простые векторные иконки, нарисованные кодом (без файлов-картинок):
## деньги, розыск, силы, долг, время, товары.

## Какую иконку рисовать: clean, dirty, debt, heat, energy, day,
## mushrooms, herbs, cigarettes, moon_moss, phones, blue_dust.
var kind := ""


func _init(icon_kind: String = "", size_px: float = 22.0) -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	match kind:
		"clean", "dirty":
			_coin(c, s, Color(0.45, 0.9, 0.55) if kind == "clean" else Color(0.88, 0.72, 0.35))
		"debt":
			draw_circle(c, s * 0.46, Color(0.95, 0.4, 0.42))
			# Стрелка вниз — деньги уходят.
			var w := s * 0.22
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -s * 0.05), c + Vector2(w, -s * 0.05), c + Vector2(0, s * 0.27)]), Color(0.1, 0.05, 0.07))
			draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.3), Vector2(s * 0.16, s * 0.27)), Color(0.1, 0.05, 0.07))
		"heat":
			_star(c, s * 0.48, Color(0.55, 0.7, 1.0))
		"energy":
			var bolt := PackedVector2Array([
				c + Vector2(s * 0.08, -s * 0.48), c + Vector2(-s * 0.3, s * 0.06), c + Vector2(-s * 0.02, s * 0.06),
				c + Vector2(-s * 0.1, s * 0.48), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)])
			draw_colored_polygon(bolt, Color(0.4, 0.85, 0.95))
		"day":
			var ink := Color(0.16, 0.18, 0.26)
			draw_arc(c, s * 0.42, 0, TAU, 32, ink, s * 0.09, true)
			draw_line(c, c + Vector2(0, -s * 0.26), ink, s * 0.09, true)
			draw_line(c, c + Vector2(s * 0.2, 0), ink, s * 0.09, true)
		"mushrooms":
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.02), Vector2(s * 0.2, s * 0.42)), Color(0.95, 0.9, 0.8))
			_half_disc(c + Vector2(0, s * 0.02), s * 0.42, Color(0.85, 0.35, 0.3))
			draw_circle(c + Vector2(-s * 0.15, -s * 0.15), s * 0.06, Color(1, 1, 1, 0.9))
			draw_circle(c + Vector2(s * 0.12, -s * 0.2), s * 0.05, Color(1, 1, 1, 0.9))
		"herbs":
			_leaf(c + Vector2(-s * 0.12, 0), s * 0.36, -0.5, Color(0.45, 0.8, 0.45))
			_leaf(c + Vector2(s * 0.12, -s * 0.05), s * 0.4, 0.45, Color(0.35, 0.7, 0.4))
			draw_line(c + Vector2(0, s * 0.45), c + Vector2(0, -s * 0.1), Color(0.3, 0.55, 0.3), s * 0.07, true)
		"cigarettes":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.42), Vector2(s * 0.6, s * 0.84)), Color(0.85, 0.85, 0.88))
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.42), Vector2(s * 0.6, s * 0.3)), Color(0.85, 0.3, 0.3))
			for x in [-0.15, 0.0, 0.15]:
				draw_rect(Rect2(c + Vector2(s * x - s * 0.05, -s * 0.52), Vector2(s * 0.1, s * 0.12)), Color(0.95, 0.75, 0.45))
		"moon_moss":
			draw_circle(c + Vector2(-s * 0.15, s * 0.08), s * 0.24, Color(0.55, 0.75, 0.6))
			draw_circle(c + Vector2(s * 0.15, s * 0.1), s * 0.22, Color(0.5, 0.7, 0.58))
			draw_circle(c + Vector2(0, -s * 0.12), s * 0.25, Color(0.62, 0.82, 0.68))
			draw_arc(c + Vector2(s * 0.08, -s * 0.18), s * 0.14, PI * 0.6, PI * 1.9, 12, Color(0.95, 0.95, 0.75), s * 0.07, true)
		"phones":
			_rounded_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.46), Vector2(s * 0.52, s * 0.92)), s * 0.1, Color(0.2, 0.22, 0.3))
			draw_rect(Rect2(c + Vector2(-s * 0.19, -s * 0.36), Vector2(s * 0.38, s * 0.62)), Color(0.45, 0.65, 0.95))
			draw_circle(c + Vector2(0, s * 0.36), s * 0.05, Color(0.8, 0.8, 0.85))
		"blue_dust":
			var gem := PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.38, -s * 0.05),
					c + Vector2(0, s * 0.46), c + Vector2(-s * 0.38, -s * 0.05)])
			draw_colored_polygon(gem, Color(0.35, 0.55, 1.0))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.38, -s * 0.05),
					c + Vector2(0, -s * 0.05)]), Color(0.6, 0.78, 1.0))


func _coin(c: Vector2, s: float, color: Color) -> void:
	draw_circle(c, s * 0.46, color)
	draw_arc(c, s * 0.36, 0, TAU, 32, Color(color.darkened(0.35), 0.8), s * 0.06, true)
	# Знак доллара: буква S из двух дуг и вертикальная черта.
	var ink := color.darkened(0.6)
	draw_arc(c + Vector2(0, -s * 0.08), s * 0.11, PI * 0.2, PI * 1.5, 12, ink, s * 0.07, true)
	draw_arc(c + Vector2(0, s * 0.08), s * 0.11, PI * 1.2, PI * 2.5, 12, ink, s * 0.07, true)
	draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), ink, s * 0.05, true)


func _star(c: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _half_disc(c: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 17:
		var angle := PI + PI * i / 16.0
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)


func _leaf(c: Vector2, length: float, tilt: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var y := -length / 2.0 + length * t
		var x := sin(t * PI) * length * 0.32
		points.append(c + Vector2(x, y).rotated(tilt))
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		var y := -length / 2.0 + length * t
		var x := -sin(t * PI) * length * 0.32
		points.append(c + Vector2(x, y).rotated(tilt))
	draw_colored_polygon(points, color)


func _rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)
