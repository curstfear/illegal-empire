class_name WorldMap
extends Control
## Мировая карта (как тёмный глобус в референсе №3): 3D-глобус (GlobeView) — крутить и приближать, города —
## светящиеся точки, раскрашенные по выбранному слою (розыск, твоё влияние или цена товара). Наведение — дуга
## перелёта от текущего города; клик — карточка города справа с перелётом; снизу — где дешевле купить и дороже продать.
## Только показывает GameState и передаёт ему нажатия.

signal closed

const FONT_BOLD := preload("res://assets/fonts/inter/Inter-SemiBold.otf")
const BG := Color(0.055, 0.07, 0.115, 0.97)
const PANEL := Color(0.1, 0.125, 0.19, 0.92)
const TEXT := Color(0.92, 0.94, 0.98)
const MUTED := Color(0.58, 0.63, 0.74)
const ACCENT := Color(0.38, 0.6, 1.0)
const GOOD := Color(0.25, 0.85, 0.55)
const BAD := Color(1.0, 0.36, 0.38)
const WARN := Color(1.0, 0.7, 0.25)
const LEVEL_COLORS := { "friend": GOOD, "neutral": MUTED, "rival": WARN, "enemy": BAD }
## Материки упрощёнными многоугольниками (долгота, широта) — глобус рисует их точками.
const LAND := [
	[-168, 66, -140, 70, -95, 72, -80, 68, -62, 60, -55, 52, -66, 45, -75, 38, -81, 31, -80, 25, -90, 29, -97, 26,
		-97, 20, -87, 21, -83, 10, -78, 8, -80, 9, -92, 15, -105, 20, -112, 30, -118, 34, -124, 40, -124, 48,
		-135, 58, -150, 60, -165, 60],
	[-55, 60, -45, 60, -20, 70, -20, 80, -60, 82, -70, 77, -55, 70],
	[-78, 8, -60, 10, -50, 0, -35, -5, -38, -15, -48, -26, -58, -38, -65, -42, -68, -55, -75, -50, -72, -30,
		-71, -18, -80, -5, -78, 2],
	[-10, 36, -9, 43, -2, 44, -5, 48, 2, 51, 5, 53, 8, 57, 5, 62, 15, 69, 28, 71, 40, 67, 30, 60, 40, 55, 45, 45,
		40, 42, 28, 41, 26, 38, 22, 36, 15, 38, 12, 44, 8, 44, 3, 42, 0, 38, -5, 36],
	[-6, 50, 2, 51, 0, 53, -2, 56, -3, 58, -6, 57, -5, 54],
	[-17, 21, -10, 30, -5, 36, 10, 37, 20, 32, 33, 31, 35, 28, 43, 12, 51, 11, 40, -3, 40, -15, 35, -25, 28, -33,
		19, -35, 15, -27, 12, -15, 9, -1, 8, 4, -8, 5, -15, 10],
	[28, 41, 40, 42, 45, 45, 40, 55, 30, 60, 40, 67, 60, 70, 80, 73, 110, 77, 140, 72, 170, 70, 180, 66, 160, 60,
		140, 55, 130, 43, 122, 40, 122, 30, 110, 20, 108, 10, 100, 13, 104, 1, 98, 8, 95, 16, 90, 22, 80, 15,
		77, 8, 72, 20, 66, 25, 57, 25, 50, 30, 48, 29, 56, 24, 59, 22, 55, 17, 43, 12, 35, 28, 36, 36],
	[130, 31, 136, 34, 141, 36, 142, 43, 140, 41, 135, 35],
	[95, 5, 105, -6, 115, -8, 120, -5, 110, 0, 100, 2],
	[114, -22, 122, -18, 130, -12, 137, -12, 142, -11, 146, -19, 153, -27, 150, -37, 141, -38, 131, -31,
		116, -35, 114, -27],
]

## Слой раскраски городов: "heat", "influence", "price".
var mode := "price"
var good := "blue_dust"
var _selected := ""
var _hovered := ""
var _globe := GlobeView.new()

var _side := PanelContainer.new()
var _side_scroll := ScrollContainer.new()
var _side_box := VBoxContainer.new()
var _bottom := PanelContainer.new()
var _bottom_box := VBoxContainer.new()
var _modes := HBoxContainer.new()
var _good_picker := OptionButton.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_globe)
	_globe.city_clicked.connect(func(id: String) -> void:
		_selected = id
		refresh())
	_globe.city_hovered.connect(func(id: String) -> void:
		_hovered = id
		_refresh_globe())
	_build_ui()
	resized.connect(_layout)
	GameState.changed.connect(refresh)


## Открыть карту: выбран текущий город.
func open() -> void:
	_selected = GameState.session.city
	visible = true
	refresh()
	_globe.focus(_selected)
	_layout.call_deferred()


func _build_ui() -> void:
	_modes.add_theme_constant_override("separation", 6)
	_modes.position = Vector2(24, 18)
	_modes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_modes)
	var title := _label(tr("WORLD_TITLE"), 22, TEXT)
	title.add_theme_font_override("font", FONT_BOLD)
	_modes.add_child(title)
	_modes.add_child(_spacer(16))
	for item: Array in [["heat", "MAP_MODE_HEAT"], ["influence", "MAP_MODE_INFLUENCE"], ["price", "MAP_MODE_PRICE"]]:
		var button := Button.new()
		button.text = tr(item[1])
		button.toggle_mode = true
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(func() -> void:
			mode = item[0]
			refresh())
		button.set_meta("mode", item[0])
		_modes.add_child(button)
	for g: Dictionary in GameState.session.market.goods:
		_good_picker.add_item(tr(g.name_key))
		_good_picker.set_item_metadata(_good_picker.item_count - 1, g.id)
		if g.id == good:
			_good_picker.select(_good_picker.item_count - 1)
	_good_picker.add_theme_font_size_override("font_size", 12)
	_good_picker.item_selected.connect(func(index: int) -> void:
		good = _good_picker.get_item_metadata(index)
		mode = "price"
		refresh())
	_modes.add_child(_good_picker)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	close.add_theme_font_size_override("font_size", 12)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	_modes.add_child(_spacer(16))
	_modes.add_child(close)
	for pair: Array in [[_side, _side_box], [_bottom, _bottom_box]]:
		var style := StyleBoxFlat.new()
		style.bg_color = PANEL
		style.set_corner_radius_all(18)
		style.set_content_margin_all(16)
		style.border_color = Color(1, 1, 1, 0.06)
		style.set_border_width_all(1)
		(pair[0] as PanelContainer).add_theme_stylebox_override("panel", style)
		(pair[1] as VBoxContainer).add_theme_constant_override("separation", 6)
		add_child(pair[0])
	# Карточка города длинная (цены, документы) — с прокруткой.
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_scroll.add_child(_side_box)
	_side.add_child(_side_scroll)
	_bottom.add_child(_bottom_box)


## Карта слева, карточка города справа, таблица цен снизу.
func _layout() -> void:
	var side_w := 300.0
	var bottom_h := 120.0
	_side.position = Vector2(size.x - side_w - 20, 70)
	_side.size = Vector2(side_w, size.y - 90)
	_bottom.position = Vector2(20, size.y - bottom_h - 20)
	_bottom.size = Vector2(size.x - side_w - 60, bottom_h)
	_globe.position = Vector2(20, 70)
	_globe.size = Vector2(size.x - side_w - 60, size.y - bottom_h - 110)
	queue_redraw()


## Значение слоя для города (0…1) и его цвет.
func _city_value(city_id: String) -> float:
	var s := GameState.session
	match mode:
		"heat":
			return s.city_heat(city_id) / 100.0
		"influence":
			return s.city_influence(city_id) / 100.0
	var prices: Array = s.world.cities.map(func(c: Dictionary) -> int: return s.city_price(c.id, good, true))
	var low: int = prices.min()
	var high: int = prices.max()
	return 0.5 if high == low else float(s.city_price(city_id, good, true) - low) / (high - low)


func _city_color(city_id: String) -> Color:
	var v := _city_value(city_id)
	match mode:
		"heat":
			return GOOD.lerp(BAD, v)
		"influence":
			return MUTED.lerp(ACCENT, v)
	return GOOD.lerp(BAD, v)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)


## Города на глобус: цвет по слою, подпись — имя и значение слоя; дуга — к выбранному или наведённому.
func _refresh_globe() -> void:
	var s := GameState.session
	var list := {}
	for city: Dictionary in s.world.cities:
		list[city.id] = { "lat": city.lat, "lon": city.lon, "name": tr(city.name_key), "sub": _value_text(city.id),
				"color": _city_color(city.id), "here": city.id == s.city, "selected": city.id == _selected,
				"left": city.get("label", "") == "left" }
	_globe.set_cities(list)
	_globe.set_arc(s.city, _hovered if _hovered != "" else _selected)


func _value_text(city_id: String) -> String:
	var s := GameState.session
	match mode:
		"heat":
			var stars := mini(5, floori(s.city_heat(city_id) / 20.0))
			return "★".repeat(stars) + "☆".repeat(5 - stars)
		"influence":
			return tr("MAP_INFLUENCE") % roundi(s.city_influence(city_id))
	return "$" + str(s.city_price(city_id, good, true))


func refresh() -> void:
	if not visible or GameState.session == null:
		return
	for child in _modes.get_children():
		if child is Button and child.has_meta("mode"):
			(child as Button).set_pressed_no_signal(child.get_meta("mode") == mode)
	_refresh_side()
	_refresh_bottom()
	_refresh_globe()


## Карточка выбранного города: страна, розыск, влияние, банды, цены, перелёт.
func _refresh_side() -> void:
	var s := GameState.session
	_clear(_side_box)
	var city := s.world.get_city(_selected)
	if city.is_empty():
		return
	var name := _label(tr(city.name_key), 20, TEXT)
	name.add_theme_font_override("font", FONT_BOLD)
	_side_box.add_child(name)
	_side_box.add_child(_label(tr(s.world.get_country(city.country).name_key), 12, MUTED))
	if city.id == s.city:
		_side_box.add_child(_label(tr("PILL_HERE"), 12, GOOD))
	else:
		_side_box.add_child(_label(tr("WORLD_FLIGHT") % [str(s.world.flight_cost(s.city, city.id)),
				str(s.world.flight_hours(s.city, city.id))], 12, TEXT))
		if s.crosses_border(city.id):
			if s.docs_ok(city.id):
				_side_box.add_child(_label(tr("MAP_DOCS_OK"), 12, GOOD))
			else:
				var needs: Array = []
				if not s.documents.has_passport():
					needs.append(tr("MAP_NEED_PASSPORT"))
				var zone := s.zone_of(city.id)
				if Documents.needs_visa(zone, s.balance) and s.documents.visa(zone, s.day).is_empty():
					needs.append(tr(s.balance.visas[zone].name_key))
				_side_box.add_child(_label(tr("MAP_NEEDS") % ", ".join(needs), 12, BAD))
			var customs := s.customs_chance(city.id)
			if customs > 0.0:
				_side_box.add_child(_label(tr("MAP_CUSTOMS") % roundi(customs * 100.0), 12, WARN))
		var fly := Button.new()
		fly.text = tr("BTN_FLY")
		fly.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fly.disabled = not s.can_fly(city.id)
		var id: String = city.id
		fly.pressed.connect(func() -> void:
			visible = false
			closed.emit()
			GameState.fly(id))
		_side_box.add_child(fly)
	var stars := mini(5, floori(s.city_heat(city.id) / 20.0))
	_side_box.add_child(_label(tr("MAP_HEAT") % ("★".repeat(stars) + "☆".repeat(5 - stars)), 12, BAD if stars >= 3 else TEXT))
	_side_box.add_child(_label(tr("MAP_YOUR_INFLUENCE") % roundi(s.city_influence(city.id)), 12, TEXT))
	_side_box.add_child(_label(tr("MAP_GANGS").to_upper(), 10, MUTED))
	for gang: Dictionary in s.gangs.defs:
		if s.world.city_of(gang.home) != city.id:
			continue
		var level := s.gangs.level(gang.id)
		_side_box.add_child(_label("%s — %s" % [tr(gang.name_key), tr("GANG_LEVEL_" + level.to_upper())], 12, LEVEL_COLORS[level]))
	_side_box.add_child(_label(tr("MAP_PRICES").to_upper(), 10, MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	for header: String in ["COL_GOOD", "COL_BUY", "COL_SELL"]:
		grid.add_child(_label(tr(header), 10, MUTED))
	for g: Dictionary in s.market.goods:
		grid.add_child(_label(tr(g.name_key), 11, TEXT))
		grid.add_child(_label("$" + str(s.city_price(city.id, g.id, true)), 11, TEXT))
		grid.add_child(_label("$" + str(s.city_price(city.id, g.id, false)), 11, TEXT))
	_side_box.add_child(grid)
	_refresh_documents()


## Документы: паспорт, визы, подделки (у подделывателя), чемодан с двойным дном.
func _refresh_documents() -> void:
	var s := GameState.session
	var docs := s.documents
	_side_box.add_child(_label(tr("DOCS_TITLE").to_upper(), 10, MUTED))
	var passport_text := tr("DOCS_PASSPORT_NONE")
	if docs.passport == "real":
		passport_text = tr("DOCS_PASSPORT_REAL")
	elif docs.passport == "fake":
		passport_text = tr("DOCS_PASSPORT_FAKE")
	elif docs.passport_ready > 0:
		passport_text = tr("DOCS_PASSPORT_WAIT") % docs.passport_ready
	_side_box.add_child(_label(passport_text, 12, TEXT if docs.has_passport() else WARN))
	if docs.passport != "real" and docs.passport_ready == 0:
		_doc_button(tr("BTN_PASSPORT") % [str(int(s.balance.passport_cost)), int(s.balance.passport_days)],
				s.can_apply_passport(), GameState.apply_passport)
	if s.at_forger() and not docs.has_passport():
		_doc_button(tr("BTN_FAKE_PASSPORT") % str(int(s.balance.fake_passport_cost)), s.can_buy_fake_passport(),
				GameState.buy_fake.bind("passport"))
	for zone: String in s.balance.visas:
		var info: Dictionary = s.balance.visas[zone]
		var v := docs.visa(zone, s.day)
		var text := tr("DOCS_VISA_NONE") % tr(info.name_key)
		if not v.is_empty():
			text = (tr("DOCS_VISA_FAKE") if v.kind == "fake" else tr("DOCS_VISA")) % [tr(info.name_key), int(v.until)]
		elif docs.visa_ready.has(zone):
			text = tr("DOCS_VISA_WAIT") % [tr(info.name_key), int(docs.visa_ready[zone])]
		_side_box.add_child(_label(text, 12, TEXT if not v.is_empty() else MUTED))
		if v.get("kind", "") != "real" and not docs.visa_ready.has(zone):
			if s.visa_refused(zone):
				_side_box.add_child(_label(tr("DOCS_REFUSED"), 11, BAD))
			else:
				_doc_button(tr("BTN_VISA") % str(int(info.cost)), s.can_apply_visa(zone), GameState.apply_visa.bind(zone))
		if s.at_forger() and v.is_empty():
			_doc_button(tr("BTN_FAKE_VISA") % str(int(s.balance.fake_visa_cost[zone])), s.can_buy_fake_visa(zone),
					GameState.buy_fake.bind("visa", zone))
	if s.at_forger():
		var note := _label(tr("DOCS_FORGER"), 11, WARN)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_side_box.add_child(note)
	if s.smuggle_case:
		_side_box.add_child(_label(tr("DOCS_CASE"), 11, GOOD))
	else:
		_doc_button(tr("BTN_CASE") % str(int(s.balance.smuggle_case_cost)), s.can_buy_smuggle_case(), GameState.buy_smuggle_case)


func _doc_button(text: String, enabled: bool, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = not enabled
	button.pressed.connect(action)
	_side_box.add_child(button)


## Снизу: выбранный товар по городам — где дешевле купить, где дороже продать.
func _refresh_bottom() -> void:
	var s := GameState.session
	_clear(_bottom_box)
	_bottom_box.add_child(_label(tr("MAP_RANKING") % tr(s.market.get_good(good).name_key), 12, TEXT))
	var cities: Array = s.world.cities.duplicate()
	cities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return s.city_price(a.id, good, true) < s.city_price(b.id, good, true))
	var best_sell := 0
	for city: Dictionary in cities:
		best_sell = maxi(best_sell, s.city_price(city.id, good, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in cities.size():
		var city: Dictionary = cities[i]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		var title := _label("%d. %s" % [i + 1, tr(city.name_key)], 12, TEXT)
		title.add_theme_font_override("font", FONT_BOLD)
		cell.add_child(title)
		cell.add_child(_label(tr("MAP_BUY_AT") % s.city_price(city.id, good, true), 11, GOOD if i == 0 else MUTED))
		var sell := s.city_price(city.id, good, false)
		cell.add_child(_label(tr("MAP_SELL_AT") % sell, 11, WARN if sell == best_sell else MUTED))
		row.add_child(cell)
	_bottom_box.add_child(row)
	var hint := _label(tr("MAP_HINT"), 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bottom_box.add_child(hint)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(width: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	return spacer


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
