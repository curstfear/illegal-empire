class_name GameIcon
extends Control
## Простые векторные иконки, нарисованные кодом (без файлов-картинок):
## деньги, розыск, силы, долг, время, товары.

## Какую иконку рисовать: clean, dirty, debt, heat, energy, day,
## mushrooms, herbs, cigarettes, moon_moss, phones, blue_dust, ammo, pistol, shotgun, rifle, armor, watches,
## car_parts, jewelry, antique, painting, district, warehouse, lab, front, van, globe, news.
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
		"tea":
			# Чашка с паром.
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.05), Vector2(s * 0.5, s * 0.4)), Color(0.85, 0.55, 0.35))
			draw_arc(c + Vector2(s * 0.24, s * 0.12), s * 0.11, -PI / 2.0, PI / 2.0, 10, Color(0.85, 0.55, 0.35), s * 0.07, true)
			draw_line(c + Vector2(-s * 0.36, s * 0.38), c + Vector2(s * 0.26, s * 0.38), Color(0.6, 0.45, 0.35), s * 0.07, true)
			for x in [-0.15, 0.05]:
				draw_arc(c + Vector2(s * x, -s * 0.28), s * 0.09, PI * 0.5, PI * 1.5, 8, Color(0.6, 0.65, 0.75), s * 0.05, true)
		"reagents":
			# Колба с жидкостью.
			draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.46), Vector2(s * 0.16, s * 0.3)), Color(0.75, 0.8, 0.88))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.16), c + Vector2(s * 0.08, -s * 0.16),
					c + Vector2(s * 0.36, s * 0.42), c + Vector2(-s * 0.36, s * 0.42)]), Color(0.75, 0.8, 0.88))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.1), c + Vector2(s * 0.2, s * 0.1),
					c + Vector2(s * 0.33, s * 0.38), c + Vector2(-s * 0.33, s * 0.38)]), Color(0.55, 0.85, 0.4))
		"moon_pollen":
			# Мешочек с мерцающей пыльцой.
			draw_circle(c + Vector2(0, s * 0.12), s * 0.32, Color(0.7, 0.62, 0.85))
			draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.36), Vector2(s * 0.24, s * 0.2)), Color(0.6, 0.52, 0.78))
			for p in [Vector2(-0.12, 0.05), Vector2(0.1, 0.18), Vector2(0.0, -0.05)]:
				draw_circle(c + p * s, s * 0.05, Color(1.0, 0.97, 0.7))
		"blue_dust":
			var gem := PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.38, -s * 0.05),
					c + Vector2(0, s * 0.46), c + Vector2(-s * 0.38, -s * 0.05)])
			draw_colored_polygon(gem, Color(0.35, 0.55, 1.0))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.38, -s * 0.05),
					c + Vector2(0, -s * 0.05)]), Color(0.6, 0.78, 1.0))
		"ammo":
			# Три патрона.
			for x in [-0.24, 0.0, 0.24]:
				var base := c + Vector2(s * x, s * 0.4)
				draw_rect(Rect2(base + Vector2(-s * 0.08, -s * 0.45), Vector2(s * 0.16, s * 0.45)), Color(0.85, 0.65, 0.3))
				_half_disc(base + Vector2(0, -s * 0.44), s * 0.08, Color(0.7, 0.45, 0.25))
				draw_rect(Rect2(base + Vector2(-s * 0.08, -s * 0.08), Vector2(s * 0.16, s * 0.08)), Color(0.65, 0.5, 0.25))
		"pistol":
			var steel := Color(0.3, 0.33, 0.4)
			_rounded_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.28), Vector2(s * 0.78, s * 0.22)), s * 0.05, steel)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.06, -s * 0.08), c + Vector2(s * 0.34, -s * 0.08),
					c + Vector2(s * 0.28, s * 0.42), c + Vector2(s * 0.02, s * 0.42)]), steel.darkened(0.25))
			draw_arc(c + Vector2(-s * 0.02, s * 0.02), s * 0.1, 0, PI, 8, steel, s * 0.05, true)
		"shotgun":
			var wood := Color(0.6, 0.38, 0.22)
			draw_line(c + Vector2(-s * 0.48, -s * 0.12), c + Vector2(s * 0.2, -s * 0.12), Color(0.3, 0.33, 0.4), s * 0.12, true)
			draw_line(c + Vector2(-s * 0.3, s * 0.0), c + Vector2(-s * 0.05, s * 0.0), wood, s * 0.12, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.12, -s * 0.2), c + Vector2(s * 0.48, s * 0.05),
					c + Vector2(s * 0.44, s * 0.3), c + Vector2(s * 0.12, s * 0.02)]), wood)
		"rifle":
			var steel := Color(0.25, 0.28, 0.33)
			draw_line(c + Vector2(-s * 0.5, -s * 0.15), c + Vector2(s * 0.3, -s * 0.15), steel, s * 0.11, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.1), c + Vector2(s * 0.06, -s * 0.1),
					c + Vector2(-s * 0.02, s * 0.36), c + Vector2(-s * 0.16, s * 0.3)]), Color(0.45, 0.35, 0.25))
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s * 0.2), c + Vector2(s * 0.5, -s * 0.05),
					c + Vector2(s * 0.48, s * 0.18), c + Vector2(s * 0.2, s * 0.0)]), steel.lightened(0.15))
		"armor":
			var olive := Color(0.38, 0.45, 0.32)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.15, -s * 0.44),
					c + Vector2(0, -s * 0.3), c + Vector2(s * 0.15, -s * 0.44), c + Vector2(s * 0.4, -s * 0.3),
					c + Vector2(s * 0.36, s * 0.44), c + Vector2(-s * 0.36, s * 0.44)]), olive)
			for y in [-0.08, 0.18]:
				_rounded_rect(Rect2(c + Vector2(-s * 0.26, s * y), Vector2(s * 0.52, s * 0.18)), s * 0.04, olive.lightened(0.2))
		"watches":
			draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.48), Vector2(s * 0.28, s * 0.96)), Color(0.35, 0.25, 0.2))
			draw_circle(c, s * 0.3, Color(0.9, 0.72, 0.3))
			draw_circle(c, s * 0.23, Color(0.98, 0.97, 0.93))
			draw_line(c, c + Vector2(0, -s * 0.16), Color(0.2, 0.2, 0.25), s * 0.05, true)
			draw_line(c, c + Vector2(s * 0.12, 0), Color(0.2, 0.2, 0.25), s * 0.05, true)
		"car_parts":
			# Шестерёнка.
			var grey := Color(0.55, 0.58, 0.65)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.25, c + Vector2(cos(a), sin(a)) * s * 0.46, grey, s * 0.16)
			draw_circle(c, s * 0.32, grey)
			draw_circle(c, s * 0.12, Color(0.95, 0.95, 0.97))
		"jewelry":
			draw_arc(c + Vector2(0, s * 0.12), s * 0.28, 0, TAU, 32, Color(0.92, 0.75, 0.3), s * 0.1, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.48), c + Vector2(s * 0.16, -s * 0.3),
					c + Vector2(0, -s * 0.12), c + Vector2(-s * 0.16, -s * 0.3)]), Color(0.55, 0.85, 0.95))
		"antique":
			# Ваза.
			var clay := Color(0.8, 0.45, 0.3)
			draw_circle(c + Vector2(0, s * 0.12), s * 0.3, clay)
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.38), Vector2(s * 0.2, s * 0.3)), clay)
			draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.44), Vector2(s * 0.36, s * 0.08)), clay.darkened(0.2))
			draw_line(c + Vector2(-s * 0.26, s * 0.1), c + Vector2(s * 0.26, s * 0.1), Color(0.95, 0.85, 0.6), s * 0.06)
		"painting":
			draw_rect(Rect2(c - Vector2(s * 0.46, s * 0.36), Vector2(s * 0.92, s * 0.72)), Color(0.85, 0.65, 0.25))
			draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.26), Vector2(s * 0.72, s * 0.52)), Color(0.55, 0.75, 0.95))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.36, s * 0.26), c + Vector2(-s * 0.1, -s * 0.05),
					c + Vector2(s * 0.12, s * 0.12), c + Vector2(s * 0.36, -s * 0.02), c + Vector2(s * 0.36, s * 0.26)]),
					Color(0.35, 0.65, 0.4))
			draw_circle(c + Vector2(s * 0.18, -s * 0.12), s * 0.07, Color(1.0, 0.9, 0.5))
		"save":
			# Дискета.
			var ink := Color(0.27, 0.3, 0.38)
			_rounded_rect(Rect2(c - Vector2(s * 0.4, s * 0.4), Vector2(s * 0.8, s * 0.8)), s * 0.1, ink)
			draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.4), Vector2(s * 0.4, s * 0.26)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-s * 0.26, s * 0.06), Vector2(s * 0.52, s * 0.3)), Color(1, 1, 1, 0.9))
		"news":
			# Газета: лист, заголовок и строки.
			var ink := Color(0.27, 0.3, 0.38)
			_rounded_rect(Rect2(c - Vector2(s * 0.4, s * 0.36), Vector2(s * 0.8, s * 0.72)), s * 0.08, ink)
			draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.25), Vector2(s * 0.56, s * 0.14)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.03), Vector2(s * 0.24, s * 0.24)), Color(1, 1, 1, 0.75))
			for y in [-0.02, 0.08, 0.18]:
				draw_rect(Rect2(c + Vector2(s * 0.02, s * y), Vector2(s * 0.26, s * 0.05)), Color(1, 1, 1, 0.75))
		"globe":
			# Глобус: круг, экватор, меридиан-овал.
			var ink := Color(0.27, 0.3, 0.38)
			draw_arc(c, s * 0.4, 0, TAU, 32, ink, s * 0.08, true)
			draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), ink, s * 0.07, true)
			var oval := PackedVector2Array()
			for i in 33:
				var a := TAU * i / 32.0
				oval.append(c + Vector2(cos(a) * s * 0.17, sin(a) * s * 0.4))
			draw_polyline(oval, ink, s * 0.07, true)
		"menu":
			var ink := Color(0.27, 0.3, 0.38)
			for i in 3:
				var y := -s * 0.26 + i * s * 0.26
				draw_line(c + Vector2(-s * 0.32, y), c + Vector2(s * 0.32, y), ink, s * 0.09, true)
		"district":
			# Булавка на карте.
			var blue := Color(0.184, 0.42, 1.0)
			draw_circle(c + Vector2(0, -s * 0.12), s * 0.3, blue)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.0), c + Vector2(s * 0.26, -s * 0.0),
					c + Vector2(0, s * 0.46)]), blue)
			draw_circle(c + Vector2(0, -s * 0.12), s * 0.12, Color.WHITE)
		"warehouse":
			# Ангар: стены и покатая крыша, ворота.
			var blue := Color(0.184, 0.42, 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.44, -s * 0.05), c + Vector2(0, -s * 0.4),
					c + Vector2(s * 0.44, -s * 0.05)]), blue.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-s * 0.38, -s * 0.05), Vector2(s * 0.76, s * 0.45)), blue)
			draw_rect(Rect2(c + Vector2(-s * 0.16, s * 0.1), Vector2(s * 0.32, s * 0.3)), Color(1, 1, 1, 0.85))
		"lab":
			# Колба.
			var green := Color(0.2, 0.68, 0.45)
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.44), Vector2(s * 0.2, s * 0.3)), green.lightened(0.3))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.16), c + Vector2(s * 0.1, -s * 0.16),
					c + Vector2(s * 0.38, s * 0.42), c + Vector2(-s * 0.38, s * 0.42)]), green)
			draw_circle(c + Vector2(-s * 0.08, s * 0.22), s * 0.06, Color(1, 1, 1, 0.8))
		"front":
			# Лавка с полосатым навесом.
			var orange := Color(0.95, 0.55, 0.2)
			draw_rect(Rect2(c + Vector2(-s * 0.38, -s * 0.05), Vector2(s * 0.76, s * 0.45)), orange.lightened(0.55))
			for i in 4:
				var x := -s * 0.42 + i * s * 0.21
				draw_rect(Rect2(c + Vector2(x, -s * 0.38), Vector2(s * 0.21, s * 0.3)), orange if i % 2 == 0 else Color.WHITE)
			draw_rect(Rect2(c + Vector2(-s * 0.12, s * 0.12), Vector2(s * 0.24, s * 0.28)), orange.darkened(0.2))
		"van":
			# Фургон сбоку: кузов, кабина с окном, два колеса.
			var violet := Color(0.55, 0.3, 0.85)
			_rounded_rect(Rect2(c + Vector2(-s * 0.44, -s * 0.3), Vector2(s * 0.6, s * 0.5)), s * 0.08, violet)
			_rounded_rect(Rect2(c + Vector2(s * 0.12, -s * 0.12), Vector2(s * 0.32, s * 0.32)), s * 0.08, violet.darkened(0.15))
			draw_rect(Rect2(c + Vector2(s * 0.22, -s * 0.06), Vector2(s * 0.14, s * 0.1)), Color(1, 1, 1, 0.85))
			for x in [-0.24, 0.26]:
				draw_circle(c + Vector2(s * x, s * 0.26), s * 0.12, Color(0.16, 0.18, 0.26))
				draw_circle(c + Vector2(s * x, s * 0.26), s * 0.05, Color(0.85, 0.86, 0.9))


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
