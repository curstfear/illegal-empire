extends Control
## Интерфейс партии поверх 3D-города, в стиле «белых карточек»: показатели слева сверху,
## часы и скорость справа сверху, карточка района или здания справа, трекер платежа снизу слева,
## панель «Здания / Люди / Деньги / Ларёк / Навыки / Журнал» снизу справа, окно рынка, окно проверки полиции.
## Только показывает GameState и передаёт ему нажатия.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const FONT_BOLD := preload("res://assets/fonts/inter/Inter-SemiBold.otf")
## Вкладки нижней правой панели.
const TABS: Array[String] = ["TAB_BUILDINGS", "TAB_CREW", "TAB_MONEY", "TAB_STALL", "TAB_SKILLS", "TAB_LOG"]
const TAB_INDEX := { "buildings": 0, "crew": 1, "money": 2, "stall": 3, "skills": 4, "log": 5 }
## Цвета ролей в таблетках.
const ROLE_COLORS := { "cook": Color(0.09, 0.6, 0.35), "dealer": Color(0.72, 0.46, 0.04), "guard": Color(0.184, 0.42, 1.0) }
## Всплывающие сообщения: сколько держится и сколько сразу на экране.
const TOAST_SECONDS := 6.0
const TOASTS_MAX := 4
## Сдвиг города вбок (доля высоты кадра): с открытой карточкой справа и без неё.
const SCREEN_SHIFT_CARD := 0.12
const SCREEN_SHIFT_CLOSED := 0.03
const COLOR_ACCENT := Color(0.184, 0.42, 1.0)
const COLOR_UP := Color(0.09, 0.6, 0.35)
const COLOR_DOWN := Color(0.86, 0.2, 0.22)
const COLOR_WARN := Color(0.93, 0.55, 0.1)
const COLOR_DIRTY := Color(0.72, 0.46, 0.04)
const COLOR_TEXT := Color(0.106, 0.122, 0.165)
const COLOR_MUTED := Color(0.42, 0.45, 0.52)
const COLOR_TILE := Color(0.965, 0.972, 0.985)
const RISK_COLORS: Array[Color] = [Color(0.09, 0.6, 0.35), Color(0.7, 0.55, 0.0), Color(0.93, 0.5, 0.08), Color(0.86, 0.2, 0.22)]
const RISK_KEYS: Array[String] = ["RISK_LEGAL", "RISK_LOW", "RISK_MID", "RISK_HIGH"]
const KIND_ICONS := { "warehouse": "warehouse", "lab": "lab", "front": "front" }

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _clean_label: Label = %CleanLabel
@onready var _dirty_label: Label = %DirtyLabel
@onready var _debt_label: Label = %DebtLabel
@onready var _heat_label: Label = %HeatLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = { 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button }
@onready var _event_label: Label = %EventLabel
@onready var _card: PanelContainer = %DistrictCard
@onready var _card_scroll: ScrollContainer = %Scroll
@onready var _card_header: HBoxContainer = %Header
@onready var _card_kicker: Label = %CardKicker
@onready var _card_title: Label = %CardTitle
@onready var _card_info: Label = %CardInfo
@onready var _card_status: HBoxContainer = %CardStatus
@onready var _card_tiles: GridContainer = %CardTiles
@onready var _card_close_button: Button = %CardCloseButton
@onready var _card_travel_button: Button = %CardTravelButton
@onready var _card_market_button: Button = %CardMarketButton
@onready var _activities_grid: GridContainer = %ActivitiesGrid
@onready var _market_window: PanelContainer = %MarketWindow
@onready var _market_title: Label = %MarketTitle
@onready var _market_close_button: Button = %MarketCloseButton
@onready var _market_grid: GridContainer = %MarketGrid
@onready var _tabs: TabContainer = %Tabs
@onready var _tab_buttons: HBoxContainer = %TabButtons
@onready var _right: VBoxContainer = %Right
@onready var _toasts: VBoxContainer = %Toasts
@onready var _payment_card: PanelContainer = %PaymentCard
@onready var _buildings_list: VBoxContainer = %BuildingsList
@onready var _crew_list: VBoxContainer = %CrewList
@onready var _debt_hint: Label = %DebtHint
@onready var _pay_due_button: Button = %PayDueButton
@onready var _pay_all_button: Button = %PayAllButton
@onready var _borrow_button: Button = %BorrowButton
@onready var _bank_info: Label = %BankInfo
@onready var _bank_hint: Label = %BankHint
@onready var _deposit_button: Button = %DepositButton
@onready var _withdraw_button: Button = %WithdrawButton
@onready var _loan_button: Button = %LoanButton
@onready var _repay_button: Button = %RepayButton
@onready var _stall_info: Label = %StallInfo
@onready var _buy_stall_button: Button = %BuyStallButton
@onready var _stall_grid: GridContainer = %StallGrid
@onready var _skills_grid: GridContainer = %SkillsGrid
@onready var _log_text: RichTextLabel = %LogText
@onready var _end_day_button: Button = %EndDayButton
@onready var _lay_low_button: Button = %LayLowButton
@onready var _save_button: Button = %SaveButton
@onready var _menu_button: Button = %MenuButton
@onready var _check_overlay: ColorRect = %CheckOverlay
@onready var _check_text: Label = %CheckText
@onready var _bribe_button: Button = %BribeButton
@onready var _surrender_button: Button = %SurrenderButton
@onready var _flee_button: Button = %FleeButton
@onready var _end_overlay: ColorRect = %EndOverlay
@onready var _end_title: Label = %EndTitle
@onready var _end_text: Label = %EndText
@onready var _end_menu_button: Button = %EndMenuButton

## 3D-город (ставит сцена игры). Нужен, чтобы подсвечивать выбранное.
var city: Node3D
## Мини-графики в карточках-показателях: все деньги и розыск за последние дни.
var _money_chart := Sparkline.new(Vector2(34, 16))
var _heat_chart := Sparkline.new(Vector2(34, 16))
## Подписи под числами в карточках-показателях: { "clean": [разница, подпись], ... }.
var _kpi_subs: Dictionary = {}
## Трекер платежа: заголовок, сумма, дни, кнопка «Внести».
var _pay_track := DayTrack.new()
var _pay_title_right := Label.new()
var _pay_bar := ProgressBar.new()
var _pay_amount := Label.new()
var _pay_quick_button := Button.new()
## Иконка в заголовке карточки (меняется: район, склад, лаборатория, фасад).
var _card_icon_box := PanelContainer.new()
## Район, чья карточка открыта ("" — закрыта).
var _card_district: String = ""
## Если открыта карточка здания — его id (иначе "").
var _card_property: String = ""
## Содержимое карточки здания: строится заново при каждом обновлении.
var _prop_box := VBoxContainer.new()
## Узлы строк рынка по id товара: { "buy": Label, "sell": Label, ... }.
var _rows: Dictionary = {}
## Кнопки дел текущего района по id дела.
var _activity_buttons: Dictionary = {}
## Строки ларька по id товара: { "stock": Label, "button": Button }.
var _stall_rows: Dictionary = {}
## Строки навыков по id: { "name": Label, "bar": ProgressBar, "effect": Label }.
var _skill_rows: Dictionary = {}


func _ready() -> void:
	if GameState.session == null:
		GameState.new_game()
	var s := GameState.session
	_prop_box.add_theme_constant_override("separation", 6)
	_activities_grid.get_parent().add_child(_prop_box)
	_card_header.add_child(_card_icon_box)
	_card_header.move_child(_card_icon_box, 0)
	_card_icon_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_bold(_card_title)
	_build_top_bar()
	_wrap_event_label()
	_build_payment_card()
	_build_tab_buttons()
	_build_market()
	_build_stall()
	_build_skills()
	for button: Button in [_pause_button, _card_close_button, _market_close_button] + _speed_buttons.values():
		_make_small(button, 8)
	_end_day_button.add_theme_stylebox_override("normal", get_theme_stylebox("pressed", "Button"))
	_end_day_button.add_theme_color_override("font_color", Color.WHITE)
	_card_close_button.pressed.connect(close_card)
	_card_travel_button.pressed.connect(func() -> void:
		GameState.travel(_card_district)
		_refresh())
	# Пока открыт рынок, карточку района прячем, чтобы окна не налезали друг на друга.
	_card_market_button.pressed.connect(func() -> void:
		_market_window.visible = true
		_card.visible = false
		_update_screen_shift()
		_refresh())
	_market_close_button.pressed.connect(func() -> void:
		_market_window.visible = false
		open_card(GameState.session.district))
	_pause_button.pressed.connect(func() -> void: Clock.paused = not Clock.paused)
	for value: int in _speed_buttons:
		_speed_buttons[value].pressed.connect(Clock.set_speed.bind(value))
	_pay_due_button.pressed.connect(func() -> void: GameState.pay(GameState.session.payment_left()))
	_pay_quick_button.pressed.connect(func() -> void: GameState.pay(GameState.session.payment_left()))
	_pay_all_button.pressed.connect(func() -> void: GameState.pay(GameState.session.money))
	_borrow_button.pressed.connect(GameState.borrow_from_shark)
	_deposit_button.pressed.connect(GameState.deposit_clean)
	_withdraw_button.pressed.connect(GameState.withdraw_deposit)
	_loan_button.pressed.connect(GameState.take_bank_loan)
	_repay_button.pressed.connect(GameState.repay_bank_loan)
	_buy_stall_button.pressed.connect(GameState.buy_stall)
	_end_day_button.pressed.connect(Clock.finish_day)
	_lay_low_button.pressed.connect(GameState.lay_low)
	_save_button.pressed.connect(_on_save_pressed)
	_menu_button.pressed.connect(_go_to_menu)
	_bribe_button.pressed.connect(GameState.resolve_check.bind("bribe"))
	_surrender_button.pressed.connect(GameState.resolve_check.bind("surrender"))
	_flee_button.pressed.connect(GameState.resolve_check.bind("flee"))
	_end_menu_button.pressed.connect(_go_to_menu)
	GameState.changed.connect(_refresh)
	GameState.reported.connect(_on_reported)
	GameState.finished.connect(_show_end)
	Clock.speed_changed.connect(_refresh_speed_buttons)

	_debt_hint.text = tr("DEBT_HINT") % roundi(s.balance.weekly_interest * 100)
	_borrow_button.text = tr("BTN_BORROW") % [_format_money(s.balance.shark_loan_step),
			_format_money(roundi(s.balance.shark_loan_step * (1.0 + s.balance.shark_loan_fee)))]
	_buy_stall_button.text = tr("BTN_BUY_STALL") % _format_money(s.balance.stall_price)
	_card_travel_button.text = tr("BTN_TRAVEL_HERE") % int(s.balance.travel_hours)
	_add_log_entry(GameState.intro)
	open_drawer(0)
	_refresh()
	Clock.set_speed(1)


func _process(_delta: float) -> void:
	var minutes := Clock.minutes_of_day()
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	# Часы идут, и дело может перестать помещаться в остаток дня.
	for id: String in _activity_buttons:
		_activity_buttons[id].disabled = not GameState.can_do_activity(id)
	_fit_card()


## Открыть карточку района (справа).
func open_card(district: String) -> void:
	if district != _card_district or not _card.visible or _card_property != "":
		Audio.ui("open")
	_card_property = ""
	_card_district = district
	_card.visible = true
	_market_window.visible = false
	if city != null:
		city.select(district)
	_update_screen_shift()
	_refresh()


## Открыть карточку здания (склад, лаборатория, фасад).
func open_property_card(id: String) -> void:
	if id != _card_property or not _card.visible:
		Audio.ui("open")
	_card_property = id
	_card_district = GameState.session.properties.get_def(id).district
	_card.visible = true
	_market_window.visible = false
	if city != null:
		city.select_property(id)
	_update_screen_shift()
	_refresh()


func close_card() -> void:
	_card_property = ""
	_card_district = ""
	_card.visible = false
	if city != null:
		city.select("")
	_update_screen_shift()


## Карточка справа по высоте содержимого, но не выше колонки — дальше прокрутка.
func _fit_card() -> void:
	if not _card.visible:
		return
	var content := (_card_scroll.get_child(0) as Control).get_combined_minimum_size().y
	_card_scroll.custom_minimum_size.y = minf(content, maxf(120.0, _right.size.y - 26.0))


func _update_screen_shift() -> void:
	if city != null:
		city.camera_rig.screen_shift = SCREEN_SHIFT_CARD if _card.visible else SCREEN_SHIFT_CLOSED


func _unhandled_input(event: InputEvent) -> void:
	if _end_overlay.visible or _check_overlay.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			Clock.paused = not Clock.paused
		KEY_1:
			Clock.set_speed(1)
		KEY_2:
			Clock.set_speed(2)
		KEY_3:
			Clock.set_speed(4)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Построение ---

## Карточки-показатели как в референсе: иконка в цветном квадрате, подпись, крупное число,
## маленькая разница за день и строка-пояснение.
func _build_top_bar() -> void:
	_kpi_card(_clean_label, "clean", "KPI_CLEAN", Color(0.09, 0.6, 0.35), _money_chart)
	_kpi_card(_dirty_label, "dirty", "KPI_DIRTY", Color(0.85, 0.6, 0.1))
	_kpi_card(_debt_label, "debt", "KPI_DEBT", COLOR_DOWN)
	_kpi_card(_heat_label, "heat", "KPI_HEAT", COLOR_ACCENT, _heat_chart)
	_kpi_card(_energy_label, "energy", "KPI_ENERGY", Color(0.1, 0.65, 0.8))
	_money_chart.color = COLOR_UP
	_money_chart.tooltip_text = "KPI_MONEY_CHART"
	_heat_chart.color = COLOR_ACCENT
	_day_label.add_theme_color_override("font_color", COLOR_MUTED)
	_day_label.add_theme_font_size_override("font_size", 11)
	_time_label.add_theme_font_size_override("font_size", 15)
	_bold(_time_label)
	_clock_icon()
	# «Сохранить» и «В меню» — иконками, как колокольчик и аватар в референсе.
	for pair: Array in [[_save_button, "save", "BTN_SAVE"], [_menu_button, "menu", "BTN_TO_MENU"]]:
		var button: Button = pair[0]
		button.text = ""
		button.tooltip_text = pair[2]
		button.custom_minimum_size = Vector2(30, 30)
		_make_small(button, 4)
		var icon := GameIcon.new(pair[1], 16.0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
		button.add_child(icon)


## Событие дня и слух — на белой плашке справа, чтобы текст не терялся на фоне домов.
func _wrap_event_label() -> void:
	var row := _event_label.get_parent()
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _card_style(12, 4))
	pill.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.remove_child(_event_label)
	_event_label.size_flags_horizontal = Control.SIZE_FILL
	pill.add_child(_event_label)
	row.add_child(pill)
	# Пустую строку (нет события и слуха) прячем вместе с плашкой.
	_event_label.draw.connect(func() -> void: pill.visible = _event_label.text != "")


func _clock_icon() -> void:
	var row := _day_label.get_parent()
	var icon := _icon_square("day", COLOR_ACCENT, 26)
	row.add_child(icon)
	row.move_child(icon, 0)


## Заменить подпись-значение на карточку [иконка | подпись, число + разница, пояснение | график].
func _kpi_card(value: Label, icon: String, caption_key: String, tint: Color, chart: Sparkline = null) -> void:
	var row := value.get_parent()
	var index := value.get_index()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(10, 8))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_icon_square(icon, tint, 30))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.add_child(_small_label(tr(caption_key), 11, COLOR_MUTED))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	row.remove_child(value)
	value.add_theme_font_size_override("font_size", 17)
	_bold(value)
	line.add_child(value)
	var delta := _small_label("", 11, COLOR_UP)
	delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(delta)
	texts.add_child(line)
	var sub := _small_label("", 10, COLOR_MUTED)
	texts.add_child(sub)
	box.add_child(texts)
	if chart != null:
		chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(chart)
	card.add_child(box)
	row.add_child(card)
	row.move_child(card, index)
	_kpi_subs[icon] = [delta, sub]


## Нижняя левая карточка: срок платежа ростовщику как трекер доставки.
func _build_payment_card() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_icon_square("debt", COLOR_DOWN, 24))
	var title := _small_label(tr("PAY_TITLE"), 13, COLOR_TEXT)
	_bold(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_pay_title_right.add_theme_font_size_override("font_size", 11)
	_pay_title_right.add_theme_color_override("font_color", COLOR_MUTED)
	head.add_child(_pay_title_right)
	box.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.add_child(_pay_track)
	# Справа — сколько внесено и кнопка, как карточка заказа в референсе.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", _tile_style())
	side.custom_minimum_size.x = 150
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 4)
	_pay_amount.add_theme_font_size_override("font_size", 11)
	_pay_amount.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	side_box.add_child(_pay_amount)
	_pay_bar.custom_minimum_size = Vector2(0, 6)
	_pay_bar.show_percentage = false
	_pay_bar.max_value = 1.0
	side_box.add_child(_pay_bar)
	_pay_quick_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(_pay_quick_button, 10)
	side_box.add_child(_pay_quick_button)
	side.add_child(side_box)
	body.add_child(side)
	box.add_child(body)
	_payment_card.add_child(box)


## Кнопки-вкладки нижней правой панели (сегменты, как «Docks / Forklifts / Trucks»).
func _build_tab_buttons() -> void:
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i]
		button.toggle_mode = true
		_make_small(button, 10)
		button.pressed.connect(open_drawer.bind(i))
		_tab_buttons.add_child(button)


func _build_market() -> void:
	_market_grid.columns = 10
	for header: String in ["COL_GOOD", "COL_RISK", "COL_BUY", "COL_CHART", "COL_SELL", "COL_OWNED", "", "", "", ""]:
		_header_label(_market_grid, header)
	for good: Dictionary in GameState.session.market.goods:
		var id: String = good.id
		var risk := GameState.session.market.risk_level(id)
		# Название с иконкой товара.
		var name_cell := HBoxContainer.new()
		name_cell.add_theme_constant_override("separation", 6)
		name_cell.add_child(GameIcon.new(id, 16.0))
		var name_label := Label.new()
		name_label.text = good.name_key
		name_label.add_theme_font_size_override("font_size", 13)
		name_cell.add_child(name_label)
		name_cell.custom_minimum_size.x = 150
		_market_grid.add_child(name_cell)
		var row := {
			"name": name_label,
			"risk": _add_label(_market_grid, RISK_KEYS[risk], 54),
			"buy": _add_label(_market_grid, "", 64),
			"chart": _add_chart(_market_grid),
			"sell": _add_label(_market_grid, "", 44),
			"owned": _add_label(_market_grid, "", 70),
			"buy_one": _add_button(_market_grid, "+1", GameState.buy.bind(id, 1)),
			"buy_max": _add_button(_market_grid, "", func() -> void: GameState.buy(id, GameState.session.max_affordable(id))),
			"sell_one": _add_button(_market_grid, "−1", GameState.sell.bind(id, 1)),
			"sell_all": _add_button(_market_grid, "BTN_SELL_ALL", func() -> void: GameState.sell(id, GameState.session.inventory[id])),
		}
		row.risk.add_theme_color_override("font_color", RISK_COLORS[risk])
		row.risk.add_theme_font_size_override("font_size", 11)
		for key: String in ["buy", "sell", "owned", "buy_max"]:
			row[key].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_rows[id] = row


## Дела района строятся заново при каждом обновлении: район, оплата и сбор зависят от состояния.
func _build_activities() -> void:
	var s := GameState.session
	_activity_buttons.clear()
	for child in _activities_grid.get_children():
		_activities_grid.remove_child(child)
		child.queue_free()
	if _card_district != s.district or _card_property != "":
		return
	for activity: Dictionary in s.local_activities():
		var id: String = activity.id
		var name_label := _add_label(_activities_grid, activity.name_key, 120)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var result: String
		if activity.kind == "job":
			var key := "ACT_PAY_CLEAN" if activity.legal else "ACT_PAY_DIRTY"
			result = tr(key) % _format_money(s.activity_pay(activity))
		else:
			var range_ := s.activity_yield(activity)
			result = tr("ACT_YIELD") % [range_[0], range_[1]]
		var details := _add_label(_activities_grid, "%s · %s\n%s" % [tr("ACT_HOURS") % int(activity.hours),
				tr("ACT_ENERGY") % int(activity.energy), result], 92)
		details.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		details.add_theme_font_size_override("font_size", 10)
		details.add_theme_color_override("font_color", COLOR_MUTED)
		if not activity.legal:
			name_label.add_theme_color_override("font_color", COLOR_DIRTY)
			details.add_theme_color_override("font_color", COLOR_DIRTY)
		_activity_buttons[id] = _add_button(_activities_grid, "BTN_DO", GameState.do_activity.bind(id))
		_activity_buttons[id].size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_stall() -> void:
	for id: String in GameState.session.stall.stock:
		var good := GameState.session.market.get_good(id)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(GameIcon.new(id, 16.0))
		var stall_name := Label.new()
		stall_name.text = good.name_key
		cell.add_child(stall_name)
		cell.custom_minimum_size.x = 130
		_stall_grid.add_child(cell)
		var stock := _add_label(_stall_grid, "", 120)
		stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		stock.add_theme_font_size_override("font_size", 11)
		stock.add_theme_color_override("font_color", COLOR_MUTED)
		var button := _add_button(_stall_grid, "", GameState.stock_stall.bind(id))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_stall_rows[id] = { "stock": stock, "button": button }


func _build_skills() -> void:
	for id in Skills.IDS:
		var name_label := _add_label(_skills_grid, "", 120)
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(80, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.show_percentage = false
		_skills_grid.add_child(bar)
		var effect := _add_label(_skills_grid, "", 150)
		effect.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		effect.add_theme_font_size_override("font_size", 11)
		effect.add_theme_color_override("font_color", COLOR_MUTED)
		_skill_rows[id] = { "name": name_label, "bar": bar, "effect": effect }


func _add_chart(grid: GridContainer) -> Sparkline:
	var chart := Sparkline.new(Vector2(56, 18))
	chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(chart)
	return chart


func _header_label(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 10)
	grid.add_child(label)


func _add_label(grid: GridContainer, text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 12)
	grid.add_child(label)
	return label


func _add_button(grid: GridContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_make_small(button, 8)
	button.pressed.connect(action)
	grid.add_child(button)
	return button


# --- Мелкие детали оформления ---

## Компактная кнопка: стили темы с меньшими отступами.
func _make_small(button: Button, padding: int = 10) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var style: StyleBox = get_theme_stylebox(state, "Button").duplicate()
		style.content_margin_left = padding
		style.content_margin_right = padding
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_size_override("font_size", 12)


## Белая карточка с тонкой рамкой и мягкой тенью.
func _card_style(margin_x: int, margin_y: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("panel", "PanelContainer").duplicate()
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.set_corner_radius_all(12)
	return style


## Серая плитка внутри карточки (без тени).
func _tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TILE
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


## Иконка в скруглённом квадрате с лёгкой заливкой цвета.
func _icon_square(kind: String, tint: Color, side: int) -> PanelContainer:
	var square := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint, 0.12)
	style.set_corner_radius_all(side / 4)
	style.set_content_margin_all(side * 0.2)
	square.add_theme_stylebox_override("panel", style)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(GameIcon.new(kind, side * 0.6))
	return square


## Таблетка-статус: «В наличии», «Мало», «Варится»…
func _pill(text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.12)
	style.set_corner_radius_all(6)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(_small_label(text, 11, color.darkened(0.15)))
	return pill


## Плитка-показатель: подпись, значение, полоска (если progress ≥ 0).
func _tile(caption: String, value: String, progress: float = -1.0, color: Color = COLOR_ACCENT) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _tile_style())
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_small_label(caption, 10, COLOR_MUTED))
	var value_label := _small_label(value, 14, COLOR_TEXT)
	_bold(value_label)
	box.add_child(value_label)
	if progress >= 0.0:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 4)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = clampf(progress, 0.0, 1.0)
		var fill: StyleBoxFlat = get_theme_stylebox("fill", "ProgressBar").duplicate()
		fill.bg_color = color
		bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
	tile.add_child(box)
	return tile


func _small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bold(label: Label) -> void:
	label.add_theme_font_override("font", FONT_BOLD)


## Подпись раздела карточки: мелко, заглавными, серым.
func _section(text: String) -> void:
	var label := _small_label(text.to_upper(), 10, COLOR_MUTED)
	_prop_box.add_child(label)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Обновление ---

func _refresh() -> void:
	var s := GameState.session
	_day_label.text = tr("HUD_DAY") % s.day
	_energy_label.text = "%d / %d" % [s.energy, int(s.balance.energy_max)]
	_clean_label.text = "$" + _format_money(s.clean)
	_dirty_label.text = "$" + _format_money(s.dirty)
	_debt_label.text = "$" + _format_money(s.debt)
	var stars := s.police.stars(s.district)
	_heat_label.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	_money_chart.set_values(s.money_series())
	_heat_chart.set_values(s.heat_series())
	_refresh_kpi_subs()
	_refresh_payment()
	_refresh_event_label()

	# Рынок открыт только там, где он есть и где ты стоишь.
	if not s.has_market():
		_market_window.visible = false
	_market_title.text = tr("MARKET_TITLE") % tr(s.market.get_district(s.district).name_key) \
			+ "   ·   " + tr("POCKET") % [s.pocket_used(), int(s.balance.pocket_size)]
	_refresh_market()
	_refresh_card()

	var can_act := s.can_act()
	_pay_due_button.disabled = not can_act or s.payment_left() == 0 or s.money < s.payment_left()
	_pay_quick_button.disabled = _pay_due_button.disabled
	_pay_all_button.disabled = not can_act or s.money == 0
	_borrow_button.disabled = not can_act
	_bank_info.text = tr("BANK_INFO") % [_format_money(s.bank.deposit), _format_money(s.bank.loan)]
	if not s.bank.trusts(s.police.max_heat()):
		_bank_hint.text = tr("BANK_HINT_HEAT")
	else:
		_bank_hint.text = tr("BANK_HINT") % _format_money(s.bank.loan_limit(s.clean_earned))
	_deposit_button.disabled = not can_act or s.clean == 0
	_withdraw_button.disabled = not can_act or s.bank.deposit == 0
	_loan_button.text = tr("BTN_TAKE_LOAN") % _format_money(s.bank.loan_limit(s.clean_earned))
	_loan_button.disabled = not s.can_take_loan()
	_repay_button.disabled = not can_act or s.bank.loan == 0 or s.clean == 0
	_end_day_button.disabled = not can_act
	_lay_low_button.disabled = not can_act
	_save_button.disabled = not can_act
	_refresh_buildings()
	_refresh_crew()
	_refresh_stall()
	_refresh_skills()
	_refresh_check()


## Строки под числами: разница денег за день, отмыв, проценты, район, силы.
func _refresh_kpi_subs() -> void:
	var s := GameState.session
	var history := s.money_history
	var delta := s.net_money() - (int(history[-1]) if not history.is_empty() else s.net_money())
	var clean_delta: Label = _kpi_subs.clean[0]
	clean_delta.text = ("+$" if delta >= 0 else "−$") + _format_money(absi(delta)) if delta != 0 else ""
	clean_delta.add_theme_color_override("font_color", COLOR_UP if delta >= 0 else COLOR_DOWN)
	_kpi_subs.clean[1].text = tr("KPI_SUB_TOTAL") % _format_money(s.net_money())
	var queued := 0
	for prop: Dictionary in s.properties.mine():
		queued += int(s.properties.state[prop.id].dirty_queue)
	_kpi_subs.dirty[1].text = tr("KPI_SUB_LAUNDER") % _format_money(queued)
	var days_to_interest := 7 - (s.day - 1) % 7
	_kpi_subs.debt[1].text = tr("KPI_SUB_INTEREST") % [roundi(s.balance.weekly_interest * 100), days_to_interest]
	_kpi_subs.heat[1].text = tr(s.market.get_district(s.district).name_key)
	_kpi_subs.energy[1].visible = false


## Трекер платежа: дни срока, проценты, сколько внесено.
func _refresh_payment() -> void:
	var s := GameState.session
	var period := int(s.balance.payment_interval_days)
	var last := s.next_payment_day
	var first := last - period + 1
	var marks := { first: [tr("TRACK_START"), tr("TRACK_DAY") % first], last: [tr("TRACK_PAYMENT"), tr("TRACK_DAY") % last] }
	for day in range(first, last):
		if day % 7 == 0:
			marks[day] = [tr("TRACK_INTEREST"), tr("TRACK_DAY") % day]
	if not marks.has(s.day):
		marks[s.day] = [tr("TRACK_TODAY"), tr("TRACK_DAY") % s.day]
	_pay_track.set_state(first, last, s.day, marks)
	var need := int(s.balance.payment_min)
	var paid := need - s.payment_left()
	_pay_amount.text = tr("PAY_PROGRESS") % [_format_money(paid), _format_money(need)]
	_pay_bar.value = float(paid) / need
	var left_days := last - s.day
	if s.payment_left() == 0:
		_pay_title_right.text = tr("PAY_DONE")
		_pay_title_right.add_theme_color_override("font_color", COLOR_UP)
	else:
		_pay_title_right.text = tr("PAY_TODAY") if left_days == 0 else tr("PAY_DAYS_LEFT") % left_days
		_pay_title_right.add_theme_color_override("font_color", COLOR_DOWN if left_days <= 2 else COLOR_MUTED)
	_pay_quick_button.text = tr("BTN_PAY_SHORT") % _format_money(s.payment_left())


func _refresh_card() -> void:
	if _card_district == "":
		return
	var s := GameState.session
	if _card_property != "":
		_refresh_property_card()
		return
	var here := _card_district == s.district
	var district := s.market.get_district(_card_district)
	var stars := s.police.stars(_card_district)
	_set_card_icon("district", COLOR_ACCENT)
	_card_kicker.text = tr("KICKER_DISTRICT").to_upper()
	_card_title.text = tr(district.name_key)
	_card_info.text = tr("CARD_DISTRICT_INFO") % [s.local_activities().size() if here else _district_activity_count(_card_district)]
	_clear(_card_status)
	_card_status.add_child(_pill(tr("PILL_HERE"), COLOR_UP) if here else _pill(tr("PILL_AWAY") % int(s.balance.travel_hours), COLOR_MUTED))
	_card_status.add_child(_pill(tr("PILL_HEAT") % ("★".repeat(stars) + "☆".repeat(5 - stars)),
			RISK_COLORS[mini(3, stars)] if stars > 0 else COLOR_UP))
	_clear(_card_tiles)
	var heat: float = s.police.heat[_card_district]
	_card_tiles.add_child(_tile(tr("TILE_HEAT"), "%d / 100" % roundi(heat), heat / 100.0, COLOR_DOWN if heat >= 50 else COLOR_ACCENT))
	_card_tiles.add_child(_tile(tr("TILE_POLICE"), "×%.1f" % float(district.police)))
	var owned := s.properties.mine().filter(func(p: Dictionary) -> bool: return p.district == _card_district).size()
	_card_tiles.add_child(_tile(tr("TILE_BUILDINGS"), str(owned)))
	_card_tiles.add_child(_tile(tr("TILE_MARKET"), tr("TILE_YES") if district.has_market else tr("TILE_NO")))
	_card_travel_button.visible = not here
	_card_travel_button.disabled = not s.can_act()
	_card_market_button.visible = here and s.has_market()
	_card_market_button.disabled = _market_window.visible
	_activities_grid.visible = here
	_clear(_prop_box)
	if here and not s.local_activities().is_empty():
		_section(tr("SECTION_JOBS"))
		_activities_grid.get_parent().move_child(_prop_box, _activities_grid.get_index())
	_build_activities()


func _district_activity_count(district: String) -> int:
	return GameState.session.activities.filter(func(a: Dictionary) -> bool: return a.district == district).size()


func _set_card_icon(kind: String, tint: Color) -> void:
	_clear(_card_icon_box)
	var square := _icon_square(kind, tint, 36)
	_card_icon_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_card_icon_box.add_child(square)


## Карточка здания, как «Riverside Hub» в референсе: статусы, плитки, товар, варка, отмыв, улучшения.
func _refresh_property_card() -> void:
	var s := GameState.session
	var props := s.properties
	var id := _card_property
	var prop := props.get_def(id)
	var st: Dictionary = props.state[id]
	var here := s.at_property(id)
	var mine := props.is_mine(id)
	var kind: String = prop.kind
	_activities_grid.get_parent().move_child(_prop_box, -1)
	_set_card_icon(KIND_ICONS[kind], COLOR_ACCENT if kind != "lab" else COLOR_UP)
	_card_kicker.text = (tr("PROP_KIND_" + kind.to_upper()) + " · " + tr(s.market.get_district(prop.district).name_key)).to_upper()
	_card_title.text = tr(prop.name_key)
	_card_info.text = ""
	_clear(_card_status)
	if st.owned:
		_card_status.add_child(_pill(tr("PILL_OWNED"), COLOR_UP))
	elif st.rented:
		_card_status.add_child(_pill(tr("PILL_RENTED") % _format_money(int(prop.rent)), COLOR_ACCENT))
	else:
		_card_status.add_child(_pill(tr("PILL_FOR_SALE"), COLOR_WARN))
	if mine and not st.batches.is_empty():
		_card_status.add_child(_pill(tr("PILL_BREWING"), COLOR_ACCENT))
	if st.frozen_days > 0:
		_card_status.add_child(_pill(tr("PILL_FROZEN") % int(st.frozen_days), COLOR_DOWN))
	if not here:
		_card_status.add_child(_pill(tr("PILL_AWAY") % int(s.balance.travel_hours), COLOR_MUTED))
	_clear(_card_tiles)
	_card_travel_button.visible = not here
	_card_travel_button.disabled = not s.can_act()
	_card_market_button.visible = false
	_activities_grid.visible = false
	_build_activities()
	_clear(_prop_box)
	if not mine:
		_card_tiles.add_child(_tile(tr("TILE_PRICE"), "$" + _format_money(int(prop.buy_price))))
		_card_tiles.add_child(_tile(tr("TILE_RENT"), "$%s / %s" % [_format_money(int(prop.rent)), tr("TILE_NIGHT")]))
		_card_tiles.add_child(_tile(tr("TILE_CAPACITY"), str(int(prop.capacity))))
		_card_tiles.add_child(_tile(tr("TILE_NEIGHBORS"), _neighbors_text(float(prop.get("neighbors", 1.0)))))
		# Кнопки видны всегда; купить можно, только стоя в районе здания.
		_prop_row([_prop_button(tr("BTN_BUY_PROPERTY") % _format_money(int(prop.buy_price)),
				GameState.buy_property.bind(id), not s.can_buy_property(id), true),
			_prop_button(tr("BTN_RENT_PROPERTY") % _format_money(int(prop.rent)),
				GameState.rent_property.bind(id), not s.can_rent_property(id))])
		if not here:
			_prop_note(tr("PROP_GO_THERE_FIRST") % tr(s.market.get_district(prop.district).name_key))
		elif s.clean < int(prop.buy_price):
			_prop_note(tr("PROP_NEED_CLEAN") % _format_money(int(prop.buy_price) - s.clean))
		_prop_note(tr("PROP_BUY_HINT"))
		return
	# Плитки: склад и риски (у фасада — отмыв и налоговая).
	var used := props.stock_used(id)
	var capacity := int(prop.capacity)
	_card_tiles.add_child(_tile(tr("TILE_STOCK"), "%d / %d" % [used, capacity], float(used) / capacity,
			COLOR_WARN if used > capacity * 0.85 else COLOR_ACCENT))
	if kind == "front":
		_card_tiles.add_child(_tile(tr("TILE_LAUNDER"), "$" + _format_money(int(st.dirty_queue)),
				float(st.dirty_queue) / maxf(1.0, float(prop.launder_limit)), COLOR_DIRTY))
		_card_tiles.add_child(_tile(tr("TILE_TAX"), "%d / 100" % roundi(props.tax_attention), props.tax_attention / 100.0,
				COLOR_DOWN if props.tax_attention >= float(s.balance.tax_audit_threshold) else COLOR_ACCENT))
		_card_tiles.add_child(_tile(tr("TILE_REGISTER"), "$%s / %s" % [_format_money(int(prop.revenue)), tr("TILE_NIGHT")]))
	else:
		_card_tiles.add_child(_tile(tr("TILE_EVIDENCE"), "%d / 100" % roundi(st.evidence), st.evidence / 100.0,
				COLOR_DOWN if st.evidence >= 50 else COLOR_WARN))
		var raid := s.raid_chance(id)
		_card_tiles.add_child(_tile(tr("TILE_RAID"), "%d%%" % roundi(raid * 100), raid, COLOR_DOWN))
		_card_tiles.add_child(_tile(tr("TILE_SMELL"), "+%d · %d%%" % [roundi(s.smell_tonight(id)), roundi(s.snitch_chance(id) * 100)]))
	# Товар: что внутри и что в кармане.
	_section(tr("SECTION_INVENTORY") + "   " + tr("POCKET") % [s.pocket_used(), int(s.balance.pocket_size)])
	var spoil := props.spoilage(id)
	var any := false
	for good: Dictionary in s.market.goods:
		var gid: String = good.id
		var inside := props.stock_of(id, gid)
		var carried: int = s.inventory[gid]
		if inside == 0 and carried == 0:
			continue
		any = true
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(GameIcon.new(gid, 16.0))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label(tr(good.name_key), 12, COLOR_TEXT))
		texts.add_child(_small_label(tr("PROP_GOOD_COUNTS") % [inside, carried], 10, COLOR_MUTED))
		cell.add_child(texts)
		if spoil.has(gid):
			cell.add_child(_pill(tr("PILL_SPOILS"), COLOR_WARN))
		elif not good.legal and inside > 0:
			cell.add_child(_pill(tr("PILL_ILLEGAL"), COLOR_DOWN))
		_prop_row([cell,
			_prop_button(tr("BTN_STORE"), GameState.store_goods.bind(id, gid), carried == 0 or not s.can_use_property(id)),
			_prop_button(tr("BTN_TAKE"), GameState.take_goods.bind(id, gid), inside == 0 or not s.can_use_property(id))])
	if not any:
		_prop_note(tr("PROP_EMPTY"))
	# Варка: рецепты, идущие партии, оборудование.
	var recipes := props.recipes_for(id)
	if not recipes.is_empty():
		_section(tr("PROP_PRODUCTION"))
		for recipe: Dictionary in recipes:
			var inputs: Array[String] = []
			for gid: String in recipe.inputs:
				inputs.append("%d %s" % [int(recipe.inputs[gid]), tr(s.market.get_good(gid).name_key)])
			var text := tr("RECIPE_LINE") % [" + ".join(inputs), int(recipe.amount),
					tr(s.market.get_good(recipe.output).name_key), int(recipe.nights)]
			var batches := props.max_batches(id, recipe.id)
			_prop_row([_prop_label(text), _prop_button(tr("BTN_BREW") % batches,
					GameState.start_production.bind(id, recipe.id), batches == 0 or not s.can_use_property(id))])
		for batch: Dictionary in st.batches:
			var recipe := props.get_recipe(batch.recipe)
			_prop_note(tr("PROP_BATCH") % [int(batch.count), tr(recipe.name_key), int(batch.nights_left)])
		if kind == "lab":
			var cost := s.lab_upgrade_cost(id)
			var level_text := tr("PROP_LAB_LEVEL") % [int(st.level), roundi(s.defect_chance(id) * 100),
					roundi(s.great_chance(id) * 100)]
			if cost > 0:
				_prop_row([_prop_label(level_text), _prop_button(tr("BTN_UPGRADE") % _format_money(cost),
						GameState.upgrade_lab.bind(id), not s.can_upgrade_lab(id))])
			else:
				_prop_note(level_text)
	# Фасад: касса и отмыв.
	if kind == "front":
		_section(tr("SECTION_LAUNDER"))
		_prop_note(tr("PROP_LAUNDER_INFO") % [_format_money(int(st.dirty_queue)), _format_money(int(prop.launder_limit)),
				roundi(float(prop.launder_fee) * 100), _format_money(int(prop.revenue))])
		_prop_row([_prop_button(tr("BTN_LAUNDER") % _format_money(s.dirty), GameState.launder.bind(id), not s.can_launder(id), true)])
	else:
		_prop_row([_prop_label(tr("PROP_CLEANUP_HINT")), _prop_button(tr("BTN_CLEANUP") % int(s.balance.cleanup_energy),
				GameState.cleanup.bind(id), not GameState.can_cleanup(id))])
	# Люди в здании.
	var workers := s.crew.working_at(id)
	_section(tr("SECTION_CREW"))
	if workers.is_empty():
		_prop_note(tr("CREW_NOBODY_HERE"))
	for person: Dictionary in workers:
		_prop_row([_person_cell(person), _pill(tr(s.crew.roles[person.role].name_key), ROLE_COLORS[person.role])])
	# Улучшения здания.
	var upgrades := props.upgrades_for(id, s.balance.upgrades)
	if not upgrades.is_empty():
		_section(tr("PROP_UPGRADES"))
		for upgrade: String in upgrades:
			var info: Dictionary = s.balance.upgrades[upgrade]
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -2)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(_small_label(tr(info.name_key), 12, COLOR_TEXT))
			cell.add_child(_small_label(tr(info.name_key + "_DESC"), 10, COLOR_MUTED))
			if props.has_upgrade(id, upgrade):
				_prop_row([cell, _pill(tr("PILL_INSTALLED"), COLOR_UP)])
			else:
				_prop_row([cell, _prop_button(tr("BTN_INSTALL") % _format_money(int(info.cost)),
						GameState.buy_upgrade.bind(id, upgrade), not s.can_buy_upgrade(id, upgrade))])
	# Продать купленное или съехать из арендованного (только пустое).
	var sell_text := tr("BTN_SELL_PROPERTY") % _format_money(s.property_sell_price(id)) if st.owned else tr("BTN_LEAVE_PROPERTY")
	_prop_row([_prop_label(tr("PROP_SELL_HINT")), _prop_button(sell_text, GameState.sell_property.bind(id),
			not s.can_sell_property(id))])


func _neighbors_text(neighbors: float) -> String:
	if neighbors <= 0.4:
		return tr("NEIGHBORS_FEW")
	return tr("NEIGHBORS_MANY") if neighbors >= 1.1 else tr("NEIGHBORS_SOME")


func _prop_row(items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for item: Control in items:
		row.add_child(item)
	_prop_box.add_child(row)


func _prop_label(text: String) -> Label:
	var label := _small_label(text, 11, COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 150
	return label


func _prop_note(text: String) -> void:
	var label := _prop_label(text)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 10)
	_prop_box.add_child(label)


func _prop_button(text: String, action: Callable, disabled: bool, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(button, 8)
	if primary:
		button.add_theme_stylebox_override("normal", get_theme_stylebox("pressed", "Button"))
		button.add_theme_color_override("font_color", Color.WHITE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


## Вкладка «Здания»: всё твоё — тип, район, статус, заполненность склада; ниже — что продаётся.
## Клик по «›» открывает карточку здания.
func _refresh_buildings() -> void:
	var s := GameState.session
	var props := s.properties
	_clear(_buildings_list)
	var mine := props.mine()
	_tab_buttons.get_child(0).text = tr("TAB_BUILDINGS") + (" %d" % mine.size() if not mine.is_empty() else "")
	_buildings_list.add_child(_small_label(tr("BUILDINGS_MINE").to_upper(), 10, COLOR_MUTED))
	if mine.is_empty():
		var empty := _small_label(tr("BUILDINGS_EMPTY"), 11, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buildings_list.add_child(empty)
	for prop: Dictionary in mine:
		var id: String = prop.id
		var st: Dictionary = props.state[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon_square(KIND_ICONS[prop.kind], COLOR_ACCENT, 26))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label(tr(prop.name_key), 12, COLOR_TEXT))
		texts.add_child(_small_label(tr(s.market.get_district(prop.district).name_key) + " · " + tr("PROP_KIND_" + String(prop.kind).to_upper()), 10, COLOR_MUTED))
		row.add_child(texts)
		var status: PanelContainer
		if st.frozen_days > 0:
			status = _pill(tr("PILL_FROZEN") % int(st.frozen_days), COLOR_DOWN)
		elif not st.batches.is_empty():
			status = _pill(tr("PILL_BREWING"), COLOR_ACCENT)
		elif int(st.dirty_queue) > 0:
			status = _pill(tr("PILL_LAUNDERING"), COLOR_DIRTY)
		elif st.stock.is_empty():
			status = _pill(tr("PILL_EMPTY"), COLOR_MUTED)
		else:
			status = _pill(tr("PILL_STORED"), COLOR_UP)
		row.add_child(status)
		var fill := VBoxContainer.new()
		fill.custom_minimum_size.x = 56
		fill.add_theme_constant_override("separation", 1)
		fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fill.add_child(_small_label("%d/%d" % [props.stock_used(id), int(prop.capacity)], 10, COLOR_MUTED))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(56, 4)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = float(props.stock_used(id)) / int(prop.capacity)
		fill.add_child(bar)
		row.add_child(fill)
		var open := Button.new()
		open.text = "›"
		open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(open, 8)
		open.pressed.connect(open_property_card.bind(id))
		row.add_child(open)
		_buildings_list.add_child(row)
		_buildings_list.add_child(HSeparator.new())
	var for_sale := props.defs.filter(func(p: Dictionary) -> bool: return not props.is_mine(p.id))
	if for_sale.is_empty():
		return
	_buildings_list.add_child(_small_label(tr("BUILDINGS_FOR_SALE").to_upper(), 10, COLOR_MUTED))
	for prop: Dictionary in for_sale:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon_square(KIND_ICONS[prop.kind], COLOR_WARN, 26))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label(tr(prop.name_key), 12, COLOR_TEXT))
		texts.add_child(_small_label(tr(s.market.get_district(prop.district).name_key) + " · " + tr("PROP_KIND_" + String(prop.kind).to_upper()), 10, COLOR_MUTED))
		row.add_child(texts)
		row.add_child(_small_label("$%s · $%s/%s" % [_format_money(int(prop.buy_price)), _format_money(int(prop.rent)), tr("TILE_NIGHT")], 11, COLOR_TEXT))
		var open := Button.new()
		open.text = "›"
		open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(open, 8)
		open.pressed.connect(open_property_card.bind(String(prop.id)))
		row.add_child(open)
		_buildings_list.add_child(row)


## Вкладка «Люди»: бригада (место работы, уволить) и биржа (нанять).
func _refresh_crew() -> void:
	var s := GameState.session
	var crew := s.crew
	_clear(_crew_list)
	_tab_buttons.get_child(TAB_INDEX.crew).text = tr("TAB_CREW") + (" %d" % crew.people.size() if not crew.people.is_empty() else "")
	_crew_list.add_child(_small_label((tr("CREW_MINE") % [crew.people.size(), int(s.balance.crew_max),
			_format_money(crew.total_wages())]).to_upper(), 10, COLOR_MUTED))
	if crew.people.is_empty():
		var empty := _small_label(tr("CREW_EMPTY"), 11, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_crew_list.add_child(empty)
	for person: Dictionary in crew.people:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_person_cell(person))
		row.add_child(_job_picker(person))
		var fire := Button.new()
		fire.text = "✕"
		fire.tooltip_text = tr("BTN_FIRE")
		fire.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(fire, 7)
		fire.disabled = not s.can_act()
		fire.pressed.connect(GameState.fire.bind(int(person.id)))
		row.add_child(fire)
		_crew_list.add_child(row)
	_crew_list.add_child(HSeparator.new())
	_crew_list.add_child(_small_label(tr("CREW_CANDIDATES").to_upper(), 10, COLOR_MUTED))
	for person: Dictionary in crew.candidates:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_person_cell(person))
		var hire := Button.new()
		hire.text = tr("BTN_HIRE") % _format_money(int(person.wage))
		hire.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(hire, 8)
		hire.disabled = not s.can_hire(int(person.id))
		hire.pressed.connect(GameState.hire.bind(int(person.id)))
		row.add_child(hire)
		_crew_list.add_child(row)


## Человек: иконка роли, кличка, навык звёздами, черта, зарплата; подсказка — что делает роль и черта.
func _person_cell(person: Dictionary) -> HBoxContainer:
	var crew := GameState.session.crew
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = tr("ROLE_DESC_" + String(person.role).to_upper()) + "\n" + tr(crew.traits[person.trait].name_key) \
			+ ": " + tr(crew.traits[person.trait].name_key + "_DESC")
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _small_label(tr(person.nick), 12, COLOR_TEXT)
	_bold(name_label)
	top.add_child(name_label)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(_small_label("★".repeat(int(person.skill)), 10, COLOR_WARN))
	stars.add_child(_small_label("★".repeat(int(GameState.session.balance.crew_skill_max) - int(person.skill)), 10,
			Color(COLOR_MUTED, 0.3)))
	top.add_child(stars)
	texts.add_child(top)
	texts.add_child(_small_label("%s · %s · $%s %s" % [tr(crew.roles[person.role].name_key), tr(crew.traits[person.trait].name_key),
			_format_money(int(person.wage)), tr("CREW_PER_DAY")], 10, COLOR_MUTED))
	cell.add_child(_role_badge(person.role))
	cell.add_child(texts)
	return cell


func _role_badge(role: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ROLE_COLORS[role], 0.14)
	style.set_corner_radius_all(13)
	badge.add_theme_stylebox_override("panel", style)
	badge.custom_minimum_size = Vector2(26, 26)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := _small_label(tr("ROLE_LETTER_" + role.to_upper()), 12, ROLE_COLORS[role])
	_bold(letter)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(letter)
	return badge


## Где работает: «без работы» или одно из твоих зданий, куда эта роль подходит.
func _job_picker(person: Dictionary) -> OptionButton:
	var s := GameState.session
	var picker := OptionButton.new()
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	picker.add_theme_font_size_override("font_size", 11)
	picker.custom_minimum_size.x = 132
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.add_item(tr("CREW_NO_JOB"))
	picker.set_item_metadata(0, "")
	for prop: Dictionary in s.properties.mine():
		if not s.crew.can_work_in(person, prop.kind):
			continue
		picker.add_item(tr(prop.name_key))
		picker.set_item_metadata(picker.item_count - 1, prop.id)
		if prop.id == person.job:
			picker.select(picker.item_count - 1)
	picker.disabled = not s.can_act()
	picker.item_selected.connect(func(index: int) -> void:
		GameState.assign(int(person.id), String(picker.get_item_metadata(index))))
	return picker


func _refresh_market() -> void:
	var s := GameState.session
	var can_act := s.can_act()
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var price := s.buy_price(id)
		var before: int = s.market.previous_prices[s.district][id]
		row.buy.text = "$%s %s" % [_format_money(price), "▲" if price > before else ("▼" if price < before else "")]
		row.buy.add_theme_color_override("font_color", COLOR_UP if price > before else (COLOR_DOWN if price < before else COLOR_TEXT))
		# График за 14 дней: зелёный — сейчас дешевле среднего (выгодно брать), оранжевый — дороже.
		var series := s.market.price_series(s.district, id)
		var average := 0.0
		for value: int in series:
			average += value
		average /= series.size()
		row.chart.color = COLOR_UP if price <= average else COLOR_WARN
		row.chart.set_values(series)
		row.sell.text = "$%s" % _format_money(s.sell_price(id))
		var owned: int = s.inventory[id]
		if owned == 0:
			row.owned.text = "—"
		elif s.average_cost(id) == 0:
			row.owned.text = tr("OWNED_FREE") % owned
		else:
			row.owned.text = tr("OWNED_AVG") % [owned, _format_money(s.average_cost(id))]
		# «На все»: сколько штук выйдет и почём в среднем — крупная закупка сама поднимает цену.
		var count := s.max_affordable(id)
		row.buy_max.text = tr("BTN_BUY_MAX_N") % count
		if count > 0:
			var total := s.market.quote_buy(s.district, id, count)
			row.buy_max.tooltip_text = tr("BUY_MAX_HINT") % [count, _format_money(total / count), _format_money(total)]
		else:
			row.buy_max.tooltip_text = ""
		var affordable := can_act and count > 0
		row.buy_one.disabled = not affordable
		row.buy_max.disabled = not affordable
		row.sell_one.disabled = not can_act or owned < 1
		row.sell_all.disabled = not can_act or owned < 1


func _refresh_stall() -> void:
	var s := GameState.session
	_buy_stall_button.visible = not s.stall.owned
	_buy_stall_button.disabled = not s.can_buy_stall()
	_stall_info.text = tr("STALL_OWNED" if s.stall.owned else "STALL_INFO") % _format_money(s.balance.stall_daily_fee)
	_stall_grid.visible = s.stall.owned
	for id: String in _stall_rows:
		var row: Dictionary = _stall_rows[id]
		row.stock.text = tr("STALL_STOCK") % [s.stall.stock[id], int(s.market.get_good(id).stall_daily)]
		row.button.text = tr("BTN_STOCK") % s.inventory[id]
		row.button.disabled = not s.can_stock_stall(id)


func _refresh_skills() -> void:
	var skills := GameState.session.skills
	var b := GameState.session.balance
	for id: String in _skill_rows:
		var row: Dictionary = _skill_rows[id]
		var lvl := skills.level(id)
		row.name.text = tr("SKILL_LEVEL") % [tr("SKILL_" + id.to_upper()), lvl]
		row.bar.value = skills.progress(id)
		match id:
			"trade":
				row.effect.text = tr("SKILL_TRADE_EFFECT") % roundi(lvl * b.trade_bonus_per_level * 100)
			"charisma":
				row.effect.text = tr("SKILL_CHARISMA_EFFECT") % [roundi(lvl * b.charisma_pay_per_level * 100),
						roundi(lvl * b.charisma_bribe_per_level * 100)]
			"stealth":
				row.effect.text = tr("SKILL_STEALTH_EFFECT") % roundi(lvl * b.stealth_heat_per_level * 100)
			"craft":
				row.effect.text = tr("SKILL_CRAFT_EFFECT") % roundi(lvl * b.craft_yield_per_level * 100)


func _refresh_event_label() -> void:
	var events := GameState.session.events
	var parts: Array[String] = []
	if not events.today.is_empty():
		parts.append(tr("EVENT_TODAY") % tr(events.today.text_key))
	if events.rumor_known:
		parts.append(tr("RUMOR") % tr(events.tomorrow.rumor_key))
	_event_label.text = "   ·   ".join(parts)


func _refresh_check() -> void:
	var s := GameState.session
	_check_overlay.visible = not s.pending_check.is_empty() and s.status == GameSession.Status.PLAYING
	if not _check_overlay.visible:
		return
	_check_text.text = tr("CHECK_TEXT") % [tr(s.market.get_district(s.district).name_key), _format_money(s.illegal_goods_value())]
	_bribe_button.text = tr("CHECK_BRIBE") % _format_money(s.pending_check.bribe)
	_bribe_button.disabled = not s.can_bribe()
	_flee_button.text = tr("CHECK_FLEE") % roundi(s.flee_chance() * 100)


func _refresh_speed_buttons() -> void:
	_pause_button.set_pressed_no_signal(Clock.paused)
	for value: int in _speed_buttons:
		_speed_buttons[value].set_pressed_no_signal(not Clock.paused and Clock.speed == value)


# --- События экрана ---

func _on_reported(report: Array) -> void:
	for entry: Array in report:
		_add_log_entry(entry)


func _on_save_pressed() -> void:
	if GameState.save():
		_add_log(tr("SAVED"))


func _show_end(status: GameSession.Status) -> void:
	_check_overlay.visible = false
	_end_overlay.visible = true
	if status == GameSession.Status.WON:
		_end_title.text = "END_WON_TITLE"
		_end_text.text = tr("END_WON_TEXT") % GameState.session.day
	else:
		_end_title.text = "END_LOST_TITLE"
		_end_text.text = "END_LOST_TEXT"
	_end_menu_button.grab_focus()


func _go_to_menu() -> void:
	Clock.paused = true
	get_tree().change_scene_to_file(MENU_SCENE)


func _add_log(text: String) -> void:
	_log_text.append_text("• %s\n" % text)
	_show_toast(text)


## Короткое сообщение внизу слева: всплывает и через несколько секунд тает.
## Полная история — во вкладке «Журнал».
func _show_toast(text: String) -> void:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _card_style(12, 6))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var label := _small_label(text, 12, COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pill.add_child(label)
	pill.custom_minimum_size.x = minf(380.0, label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 28.0)
	_toasts.add_child(pill)
	while _toasts.get_child_count() > TOASTS_MAX:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tween := pill.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(pill, "modulate:a", 0.0, 0.6)
	tween.tween_callback(pill.queue_free)


## Открыть вкладку нижней правой панели (0 здания, 1 деньги, 2 ларёк, 3 навыки, 4 журнал).
func open_drawer(tab: int) -> void:
	_tabs.current_tab = tab
	for i in _tab_buttons.get_child_count():
		_tab_buttons.get_child(i).set_pressed_no_signal(i == tab)


func open_tab(name: String) -> void:
	open_drawer(TAB_INDEX[name])


## Запись из логики: [ключ_перевода, аргументы].
## Строки-аргументы — это ключи перевода, суммы от 1000 пишем с пробелами.
func _add_log_entry(entry: Array) -> void:
	var text := tr(entry[0])
	if not entry[1].is_empty():
		text = text % entry[1].map(func(arg: Variant) -> Variant:
			if arg is String:
				return tr(arg)
			return _format_money(arg) if arg is int and arg >= 1000 else arg)
	_add_log(text)


## 48000 → «48 000».
static func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = " " + digits.right(3) + result
		digits = digits.left(-3)
	return ("-" if value < 0 else "") + digits + result
