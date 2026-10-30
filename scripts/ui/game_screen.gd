extends Control
## Интерфейс партии поверх 3D-города, в стиле «белых карточек»: показатели слева сверху,
## часы и скорость справа сверху, карточка района или здания справа, трекер платежа снизу слева,
## панель «Здания / Люди / Перевозки / Банды / Деньги / Ларёк / Навыки / Журнал» снизу справа, окно рынка, окно проверки полиции,
## окно разборки (выбор тактики, потом отчёт о бое и последствия).
## Только показывает GameState и передаёт ему нажатия.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const FONT_BOLD := preload("res://assets/fonts/inter/Inter-SemiBold.otf")
## Вкладки нижней правой панели.
const TABS: Array[String] = ["TAB_BUILDINGS", "TAB_CREW", "TAB_ROUTES", "TAB_GANGS", "TAB_MONEY", "TAB_STALL", "TAB_SKILLS", "TAB_LOG"]
const TAB_INDEX := { "buildings": 0, "crew": 1, "routes": 2, "gangs": 3, "money": 4, "stall": 5, "skills": 6, "log": 7 }
## Цвета уровней отношения банды к тебе.
const LEVEL_COLORS := { "friend": Color(0.09, 0.6, 0.35), "neutral": Color(0.42, 0.45, 0.52),
		"rival": Color(0.93, 0.55, 0.1), "enemy": Color(0.86, 0.2, 0.22) }
## Цвета ролей в таблетках.
const ROLE_COLORS := { "cook": Color(0.09, 0.6, 0.35), "dealer": Color(0.72, 0.46, 0.04), "guard": Color(0.184, 0.42, 1.0),
		"courier": Color(0.55, 0.3, 0.85), "manager": Color(0.1, 0.55, 0.65), "accountant": Color(0.4, 0.5, 0.15),
		"lawyer": Color(0.35, 0.38, 0.5), "scout": Color(0.85, 0.35, 0.55), "fighter": Color(0.75, 0.22, 0.2),
		"hacker": Color(0.2, 0.6, 0.85) }
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
## Блок «Полиция» в карточке района — всегда после дел района.
var _police_box := VBoxContainer.new()
## Узлы строк рынка по id товара: { "buy": Label, "sell": Label, ... }.
var _rows: Dictionary = {}
## Кнопки дел текущего района по id дела.
var _activity_buttons: Dictionary = {}
## Строки ларька по id товара: { "stock": Label, "button": Button }.
var _stall_rows: Dictionary = {}
## Строки навыков по id: { "name": Label, "bar": ProgressBar, "effect": Label }.
var _skill_rows: Dictionary = {}
## Панель «Дела» слева: ситуации с выбором и заказы (строится кодом); открыта ли доска заказов.
var _jobs_box := VBoxContainer.new()
var _offers_open := false
var _ladder_open := false
## Вкладка «Перевозки» (строится кодом) и выбор в форме нового маршрута.
var _routes_list := VBoxContainer.new()
var _route_form := { "from": "", "to": "", "good": "", "vehicle": 0, "courier": 0, "scout": 0,
		"ship_from": "", "ship_to": "", "ship_good": "", "ship_amount": 0, "ship_disguise": false,
		"sup": "", "sup_good": "", "sup_amount": 10, "sup_to": "", "sup_mode": "daily",
		"line_from": "", "line_transport": "", "line_to": "", "line_good": "", "line_amount": 20 }
## Вкладка «Банды» (строится кодом).
var _gangs_list := VBoxContainer.new()
## Окно разборки (строится кодом): затемнение, содержимое и банда, на которую собираемся наехать ("" — не собираемся).
var _fight_overlay := ColorRect.new()
var _fight_box := VBoxContainer.new()
var _fight_gang: String = ""
## Кнопка «Мир» и мировая карта.
var _world_button := Button.new()
var _world_overlay := WorldMap.new()


func _ready() -> void:
	if GameState.session == null:
		GameState.new_game()
	var s := GameState.session
	_prop_box.add_theme_constant_override("separation", 6)
	_activities_grid.get_parent().add_child(_prop_box)
	_police_box.add_theme_constant_override("separation", 6)
	_activities_grid.get_parent().add_child(_police_box)
	_card_header.add_child(_card_icon_box)
	_card_header.move_child(_card_icon_box, 0)
	_card_icon_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_bold(_card_title)
	_build_top_bar()
	_wrap_event_label()
	_build_payment_card()
	_build_jobs_panel()
	_build_routes_tab()
	_build_gangs_tab()
	_build_fight_overlay()
	_build_world()
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
	if city != null and GameState.session.world.city_of(_card_district) == GameState.session.city:
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


## Слева над городом — колонка карточек «Дела» (как «Robot Reports» в референсе, раздел 16.2):
## сначала ситуации, где надо выбрать, потом заказы. Над всплывающими сообщениями, с прокруткой.
func _build_jobs_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.anchor_bottom = 1.0
	scroll.offset_right = 330.0
	scroll.offset_bottom = -190.0
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_jobs_box.add_theme_constant_override("separation", 8)
	_jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jobs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_jobs_box)
	_toasts.get_parent().add_child(scroll)


func _refresh_jobs() -> void:
	var s := GameState.session
	_clear(_jobs_box)
	_jobs_box.add_child(_rank_card())
	for sit: Dictionary in s.jobs.situations:
		_jobs_box.add_child(_situation_card(sit))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(12, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_icon_square("day", COLOR_ACCENT, 22))
	var title := _small_label(tr("ORDERS_TITLE") % [s.jobs.orders.size(), s.limit("order_active_max")], 13, COLOR_TEXT)
	_bold(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var offers := s.jobs.offers_in(s.city)
	var toggle := Button.new()
	toggle.text = tr("ORDERS_BOARD") % offers.size()
	toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	toggle.toggle_mode = true
	toggle.button_pressed = _offers_open
	_make_small(toggle, 8)
	toggle.toggled.connect(func(on: bool) -> void:
		_offers_open = on
		_refresh_jobs())
	head.add_child(toggle)
	box.add_child(head)
	if s.jobs.orders.is_empty() and not _offers_open:
		box.add_child(_wrapped(tr("ORDERS_EMPTY"), 11, COLOR_MUTED))
	for order: Dictionary in s.jobs.orders:
		box.add_child(_order_row(order))
	if _offers_open:
		box.add_child(HSeparator.new())
		for offer: Dictionary in offers:
			box.add_child(_order_offer_row(offer))
	card.add_child(box)
	_jobs_box.add_child(card)


## Карточка ступени: где ты, что нужно до следующей (полоски) и что она откроет; по кнопке — вся лестница.
func _rank_card() -> PanelContainer:
	var s := GameState.session
	var ranks: Array = s.balance.ranks
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(12, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_icon_square("district", COLOR_UP, 22))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_small_label((tr("RANK_TITLE") % [s.rank + 1, ranks.size()]).to_upper(), 9, COLOR_MUTED))
	var rank_label := _small_label(tr(s.rank_name_key()), 14, COLOR_TEXT)
	_bold(rank_label)
	titles.add_child(rank_label)
	head.add_child(titles)
	var toggle := Button.new()
	toggle.text = tr("BTN_LADDER")
	toggle.toggle_mode = true
	toggle.button_pressed = _ladder_open
	_make_small(toggle, 8)
	toggle.toggled.connect(func(on: bool) -> void:
		_ladder_open = on
		_refresh_jobs())
	head.add_child(toggle)
	box.add_child(head)
	if _ladder_open:
		for i in ranks.size():
			var mark := "✓ " if i <= s.rank else "· "
			box.add_child(_small_label(mark + tr(s.rank_name_key(i)) + _perks_text(i, " — "), 11,
					COLOR_TEXT if i == s.rank else (COLOR_UP if i < s.rank else COLOR_MUTED)))
	elif s.is_top_rank():
		box.add_child(_wrapped(tr("RANK_TOP"), 11, COLOR_MUTED))
	else:
		box.add_child(_small_label(tr("RANK_NEXT") % tr(s.rank_name_key(s.rank + 1)), 11, COLOR_TEXT))
		var needs: Dictionary = s.rank_def(s.rank + 1).needs
		for key: String in needs:
			var have := s.rank_stat(key)
			var need := int(needs[key])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var label := _small_label(tr("NEED_" + key.to_upper()), 10, COLOR_MUTED)
			label.custom_minimum_size.x = 130
			row.add_child(label)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 6)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.value = minf(1.0, float(have) / maxf(1.0, need))
			row.add_child(bar)
			var money := key == "earned"
			row.add_child(_small_label(("$%s / $%s" % [_format_money(have), _format_money(need)]) if money
					else ("%d / %d" % [mini(have, need), need]), 10, COLOR_UP if have >= need else COLOR_TEXT))
			box.add_child(row)
		box.add_child(_wrapped(tr("RANK_OPENS") % _perks_text(s.rank + 1, ""), 10, COLOR_ACCENT))
	card.add_child(box)
	return card


## Бонусы ступени словами: «+1 заказ в работе, +2 поставщика».
func _perks_text(index: int, prefix: String) -> String:
	var perks: Dictionary = GameState.session.rank_def(index).perks
	if perks.is_empty():
		return ""
	var parts: Array[String] = []
	for key: String in perks:
		var value := float(perks[key])
		var text := tr("PERK_" + key.to_upper())
		if text.contains("%d"):
			text = text % (roundi(value * 100) if value < 1.0 else roundi(value))
		parts.append(text)
	return prefix + ", ".join(parts)


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := _small_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _job_what(job: Dictionary) -> String:
	var s := GameState.session
	return tr("ORDER_WHAT") % [int(job.amount), tr(s.market.get_good(job.good).name_key), tr(s.market.get_district(job.district).name_key)]


func _job_reward(job: Dictionary) -> String:
	var legal: bool = GameState.session.market.get_good(job.good).legal
	return tr("ORDER_REWARD_CLEAN" if legal else "ORDER_REWARD_DIRTY") % _format_money(int(job.reward))


## Взятый заказ: кто, что и куда, сколько есть под рукой, сколько дней осталось, награда и кнопки.
func _order_row(order: Dictionary) -> VBoxContainer:
	var s := GameState.session
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(GameIcon.new(order.good, 16.0))
	var what := _wrapped(_job_what(order), 12, COLOR_TEXT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(what)
	var days_left := int(order.deadline) - s.day
	top.add_child(_pill(tr("ORDER_TODAY") if days_left <= 0 else tr("ORDER_DAYS_LEFT") % (days_left + 1),
			COLOR_DOWN if days_left <= 0 else (COLOR_WARN if days_left == 1 else COLOR_MUTED)))
	row.add_child(top)
	var have := s.order_have(order)
	row.add_child(_small_label(tr("ORDER_PROGRESS") % [tr(s.client_name_key(order.client)), mini(have, int(order.amount)),
			int(order.amount), _job_reward(order)], 10, COLOR_UP if have >= int(order.amount) else COLOR_MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	var deliver := _prop_button(tr("BTN_DELIVER_ORDER"), GameState.deliver_order.bind(int(order.id)),
			not s.can_deliver_order(int(order.id)), true)
	if s.district != order.district:
		deliver.tooltip_text = tr("ORDER_GO_THERE") % tr(s.market.get_district(order.district).name_key)
	buttons.add_child(deliver)
	if s.can_snitch_order(int(order.id)):
		var snitch := _prop_button(tr("BTN_SNITCH_ORDER"), GameState.snitch_order.bind(int(order.id)), false)
		snitch.tooltip_text = tr("ORDER_SNITCH_TIP")
		buttons.add_child(snitch)
	var drop := _prop_button("✕", GameState.drop_order.bind(int(order.id)), not s.can_act())
	drop.tooltip_text = tr("BTN_DROP_ORDER")
	buttons.add_child(drop)
	row.add_child(buttons)
	return row


func _order_offer_row(offer: Dictionary) -> HBoxContainer:
	var s := GameState.session
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(GameIcon.new(offer.good, 16.0))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_wrapped(_job_what(offer), 12, COLOR_TEXT))
	texts.add_child(_small_label(tr("OFFER_INFO") % [tr(s.client_name_key(offer.client)), _job_reward(offer), int(offer.days)],
			10, COLOR_MUTED))
	row.add_child(texts)
	row.add_child(_prop_button(tr("BTN_ACCEPT_ORDER"), GameState.accept_order.bind(int(offer.id)), not s.can_accept_order(int(offer.id))))
	return row


## Карточка ситуации: что случилось, где, сколько часов на решение и кнопки выбора.
func _situation_card(sit: Dictionary) -> PanelContainer:
	var s := GameState.session
	var card := PanelContainer.new()
	var style := _card_style(12, 10)
	style.border_color = COLOR_WARN
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := _small_label(tr(s.situation_title_key(sit.kind)), 13, COLOR_TEXT)
	_bold(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hours := maxi(0, int(sit.expires) - (s.day * 24 + int(Clock.hours_passed())))
	head.add_child(_pill(tr("SIT_HOURS_LEFT") % hours, COLOR_WARN))
	box.add_child(head)
	box.add_child(_wrapped(_situation_text(sit), 11, COLOR_TEXT))
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
	var first := true
	for choice: String in GameSession.SITUATION_CHOICES[sit.kind]:
		var button := _prop_button(_choice_text(sit, choice), GameState.choose_situation.bind(int(sit.id), choice),
				not s.can_choose_situation(int(sit.id), choice), first)
		button.size_flags_horizontal = Control.SIZE_FILL
		buttons.add_child(button)
		first = false
	box.add_child(buttons)
	card.add_child(box)
	return card


func _place_name(place: String) -> String:
	var s := GameState.session
	if place.begins_with("@"):
		return tr(s.market.get_district(place.substr(1)).name_key)
	return tr(s.properties.get_def(place).name_key)


func _situation_text(sit: Dictionary) -> String:
	var s := GameState.session
	var key := s.situation_title_key(sit.kind) + "_TEXT"
	match sit.kind:
		"advance":
			return tr(key) % [tr(s.crew.get_person(int(sit.target)).get("nick", "")), _format_money(int(sit.cost))]
		"bulk_buyer":
			return tr(key) % [_place_name(sit.place), int(sit.amount), tr(s.market.get_good(sit.target).name_key), _format_money(int(sit.cost))]
		"tip_off":
			var gang := String(sit.target).get_slice("|", 0)
			var good := String(sit.target).get_slice("|", 1)
			return tr(key) % [tr(s.gangs.get_def(gang).name_key), _place_name(sit.place), int(sit.amount), tr(s.market.get_good(good).name_key)]
	return tr(key) % _place_name(sit.place)


func _choice_text(sit: Dictionary, choice: String) -> String:
	var s := GameState.session
	var key := "SIT_CHOICE_%s_%s" % [String(sit.kind).to_upper(), choice.to_upper()]
	match [sit.kind, choice]:
		["cop_visit", "bribe"], ["advance", "pay"], ["neighbors", "pay"], ["bulk_buyer", "sell"], ["high_roller", "play"]:
			return tr(key) % _format_money(int(sit.cost))
		["cop_visit", "hide"]:
			return tr(key) % roundi((float(s.balance.sit_hide_chance) + s.skills.level("stealth") * float(s.balance.sit_hide_per_stealth)) * 100)
		["neighbors", "vent"]:
			return tr(key) % _format_money(int(s.balance.upgrades.vent.cost))
		["tip_off", "rob"]:
			return tr(key) % roundi(s.tip_rob_chance() * 100)
		["tip_off", "police"]:
			return tr(key) % _format_money(int(s.balance.sit_tip_police_pay))
	return tr(key)


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
		var first_cell := _market_grid.get_child_count() - 1
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
		row.cells = range(first_cell, _market_grid.get_child_count()).map(func(i: int) -> Control: return _market_grid.get_child(i))
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
		elif activity.kind == "steal_car":
			result = tr("ACT_STEAL_RESULT") % roundi(s.steal_car_chance() * 100)
		elif activity.kind == "ring_fight":
			result = tr("ACT_RING_RESULT") % [roundi(s.ring_chance() * 100), _format_money(int(s.balance.ring_prize))] \
					if not s.ring_fighter().is_empty() else tr("ACT_RING_NEED")
		elif activity.kind == "street_race":
			result = tr("ACT_RACE_RESULT") % [roundi(s.race_chance() * 100), _format_money(int(s.balance.race_entry)),
					_format_money(int(s.balance.race_prize))] if not s.race_vehicle().is_empty() else tr("ACT_RACE_NEED")
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
	_refresh_jobs()

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
	_refresh_routes()
	_refresh_gangs()
	_refresh_stall()
	_refresh_skills()
	_refresh_check()
	_refresh_fight()


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
	_kpi_subs.heat[1].text = tr(s.world.get_city(s.city).name_key) + " · " + tr(s.market.get_district(s.district).name_key)
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
	var host := s.gangs.gang_owner(_card_district)
	if host != "":
		var level := s.gangs.level(host)
		_card_status.add_child(_pill(tr("PILL_GANG") % [tr(s.gangs.get_def(host).name_key), tr("GANG_LEVEL_" + level.to_upper())],
				LEVEL_COLORS[level]))
	_clear(_card_tiles)
	var heat: float = s.police.heat[_card_district]
	_card_tiles.add_child(_tile(tr("TILE_HEAT"), "%d / 100" % roundi(heat), heat / 100.0, COLOR_DOWN if heat >= 50 else COLOR_ACCENT))
	_card_tiles.add_child(_tile(tr("TILE_POLICE"), "×%.1f" % float(district.police)))
	var owned := s.properties.mine().filter(func(p: Dictionary) -> bool: return p.district == _card_district).size()
	_card_tiles.add_child(_tile(tr("TILE_BUILDINGS"), str(owned)))
	_card_tiles.add_child(_tile(tr("TILE_MARKET"), tr("TILE_YES") if district.has_market else tr("TILE_NO")))
	_card_tiles.add_child(_tile(tr("TILE_OWNER"), _owner_title(_card_district)))
	var mine_share := s.gangs.share(_card_district, Gangs.PLAYER)
	_card_tiles.add_child(_tile(tr("TILE_YOUR_INFLUENCE"), "%d / 100" % roundi(mine_share), mine_share / 100.0))
	var dossier: float = s.police.dossier[_card_district]
	_card_tiles.add_child(_tile(tr("TILE_DOSSIER"), "%d / 100" % roundi(dossier) if dossier > 0.0 else tr("TILE_DOSSIER_NONE"),
			dossier / 100.0 if dossier > 0.0 else -1.0, COLOR_DOWN))
	_card_tiles.add_child(_tile(tr("TILE_KRYSHA"), tr("TILE_KRYSHA_UNTIL") % int(s.police.krysha[_card_district])
			if s.police.has_krysha(_card_district) else tr("TILE_NO")))
	_card_travel_button.visible = not here and s.world.city_of(_card_district) == s.city
	_card_travel_button.disabled = not s.can_act()
	_card_market_button.visible = here and s.has_market()
	_card_market_button.disabled = _market_window.visible
	_activities_grid.visible = here
	_clear(_prop_box)
	_police_box.visible = true
	_police_section(_card_district)
	_activities_grid.get_parent().move_child(_police_box, -1)
	if here and not s.local_activities().is_empty():
		_section(tr("SECTION_JOBS"))
		_activities_grid.get_parent().move_child(_prop_box, _activities_grid.get_index())
	_build_activities()


## В карточке района: детективы (если ведут дело) и «крыша» — нанять или отказаться.
## Крупные дела района: что нужно (ступень, люди), шанс, подготовка и кнопка «На дело».
func _operations_section(where: String) -> void:
	var s := GameState.session
	var ops := s.operations_in(where)
	if ops.is_empty():
		return
	_police_box.add_child(_small_label(tr("SECTION_OPERATIONS").to_upper(), 10, COLOR_MUTED))
	for op: Dictionary in ops:
		var id: String = op.id
		var kind := s.op_kind(id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var title := _small_label(tr(kind.name_key), 12, COLOR_TEXT)
		_bold(title)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(_pill(tr("OP_CHANCE") % roundi(s.op_chance(id) * 100), COLOR_ACCENT))
		box.add_child(head)
		var loot: Array[String] = []
		if int(kind.get("money", 0)) > 0:
			loot.append("$" + _format_money(int(kind.money)))
		for good: String in kind.get("goods", {}):
			loot.append("%d × %s" % [int(kind.goods[good]), tr(s.market.get_good(good).name_key)])
		var team: Array[String] = []
		for role: String in kind.roles:
			team.append("%s ×%d" % [tr(s.crew.roles[role].name_key), int(kind.roles[role])])
		box.add_child(_wrapped(tr("OP_INFO") % [", ".join(loot), ", ".join(team), int(kind.heat)], 10, COLOR_MUTED))
		var blocker := ""
		if s.rank < int(kind.min_rank):
			blocker = tr("OP_NEED_RANK") % tr(s.rank_name_key(int(kind.min_rank)))
		elif not s.op_missing(id).is_empty():
			var missing: Array[String] = []
			for item: Array in s.op_missing(id):
				missing.append("%s %d/%d" % [tr(s.crew.roles[item[0]].name_key), int(item[2]), int(item[1])])
			blocker = tr("OP_NEED_CREW") % ", ".join(missing)
		elif s.op_cooling(id) > 0:
			blocker = tr("OP_COOLING") % s.op_cooling(id)
		elif s.district != where:
			blocker = tr("OP_GO_THERE")
		if blocker != "":
			box.add_child(_wrapped(blocker, 10, COLOR_WARN))
		var buttons := HFlowContainer.new()
		buttons.add_theme_constant_override("h_separation", 4)
		buttons.add_theme_constant_override("v_separation", 4)
		for prep: String in s.balance.op_preps:
			var info: Dictionary = s.balance.op_preps[prep]
			var done: bool = s.op_state(id).preps.has(prep)
			var label := tr(info.name_key) + (" ✓" if done else (" $" + _format_money(s.prep_cost(id, prep)) if s.prep_cost(id, prep) > 0
					else " · %d ч" % int(info.hours)))
			var button := _prop_button(label, GameState.do_prep.bind(id, prep), done or not GameState.can_prep(id, prep))
			button.tooltip_text = tr("PREP_TIP") % roundi(float(info.bonus) * 100)
			buttons.add_child(button)
		buttons.add_child(_prop_button(tr("BTN_LAUNCH_OP") % int(s.balance.op_hours), GameState.launch_operation.bind(id),
				not GameState.can_launch(id), true))
		box.add_child(buttons)
		_police_box.add_child(box)


func _police_section(where: String) -> void:
	var s := GameState.session
	_clear(_police_box)
	_operations_section(where)
	_police_box.add_child(_small_label(tr("SECTION_POLICE").to_upper(), 10, COLOR_MUTED))
	if s.police.detectives_on(where):
		var note := _small_label(tr("POLICE_DETECTIVES"), 10, COLOR_DOWN)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_police_box.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var info := _small_label(tr("POLICE_KRYSHA_ON") % int(s.police.krysha[where]) if s.police.has_krysha(where)
			else tr("POLICE_KRYSHA_OFF"), 11, COLOR_TEXT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var button := Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(button, 8)
	button.add_theme_font_size_override("font_size", 10)
	button.tooltip_text = tr("BTN_KRYSHA_TIP")
	if s.police.has_krysha(where):
		button.text = tr("BTN_KRYSHA_DROP")
		button.disabled = not s.can_act()
		button.pressed.connect(GameState.drop_krysha.bind(where))
	else:
		button.text = tr("BTN_KRYSHA_HIRE") % _format_money(s.krysha_fee(where))
		button.disabled = not s.can_hire_krysha(where)
		button.pressed.connect(GameState.hire_krysha.bind(where))
	row.add_child(button)
	_police_box.add_child(row)
	if s.police.has_krysha(where) and float(s.police.dossier[where]) > 0.0:
		var hush := Button.new()
		hush.text = tr("BTN_HUSH") % _format_money(s.hush_cost(where))
		hush.tooltip_text = tr("BTN_HUSH_TIP")
		hush.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(hush, 8)
		hush.add_theme_font_size_override("font_size", 10)
		hush.disabled = not s.can_hush(where)
		hush.pressed.connect(GameState.hush_case.bind(where))
		_police_box.add_child(hush)


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
	_police_box.visible = false
	_set_card_icon(KIND_ICONS[kind], COLOR_ACCENT if kind != "lab" else COLOR_UP)
	_card_kicker.text = (_kind_name(prop) + " · " + tr(s.market.get_district(prop.district).name_key)).to_upper()
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
	_card_travel_button.visible = not here and s.world.city_of(_card_district) == s.city
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
		_card_tiles.add_child(_tile(tr("TILE_REGISTER"), "$%s / %s" % [_format_money(int(prop.revenue)), tr("TILE_DAY")]))
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
	# Поставки сюда и приказы менеджеру.
	var contracts := s.suppliers.contracts.filter(func(c: Dictionary) -> bool: return c.to == id)
	if not contracts.is_empty():
		_section(tr("SECTION_SUPPLIES"))
		for contract: Dictionary in contracts:
			_prop_note(tr("SUP_KEEP_LINE" if contract.mode == "keep" else "SUP_DAILY_LINE") % [int(contract.amount),
					tr(s.market.get_good(contract.good).name_key), tr(s.suppliers.get_def(contract.supplier).name_key)])
	_section(tr("SECTION_ORDERS"))
	if not s.has_manager(id):
		_prop_note(tr("ORDERS_NEED_MANAGER"))
	else:
		var orders := s.manager_order(id)
		if not recipes.is_empty():
			var brew: Array = [["auto", tr("ORDER_BREW_AUTO")], ["none", tr("ORDER_BREW_NONE")]]
			for recipe: Dictionary in recipes:
				brew.append([recipe.id, tr(recipe.name_key)])
			_prop_row([_prop_label(tr("ORDER_BREW")), _order_picker(id, "brew", brew, orders.brew)])
		if kind == "front":
			var keep: Array = s.balance.manager_launder_keep.map(func(v: float) -> Array:
				return [int(v), tr("ORDER_LAUNDER_OFF") if v < 0 else (tr("ORDER_LAUNDER_ALL") if v == 0
						else tr("ORDER_LAUNDER_KEEP") % _format_money(int(v)))])
			_prop_row([_prop_label(tr("ORDER_LAUNDER")), _order_picker(id, "launder_keep", keep, orders.launder_keep)])
		_prop_note(tr("ORDERS_HINT"))
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


func _order_picker(id: String, key: String, items: Array, current: Variant) -> OptionButton:
	var picker := OptionButton.new()
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(picker, 7)
	for item: Array in items:
		picker.add_item(item[1])
		if item[0] == current:
			picker.select(picker.item_count - 1)
	picker.disabled = not GameState.session.can_act()
	picker.item_selected.connect(func(index: int) -> void: GameState.set_order(id, key, items[index][0]))
	return picker


## Тип здания словами; казино — отдельно от прочих прикрытий.
func _kind_name(prop: Dictionary) -> String:
	if prop.get("casino", false):
		return tr("PROP_KIND_CASINO")
	if not prop.get("port", []).is_empty():
		return tr("PROP_KIND_HANGAR") if prop.port.has("plane") else tr("PROP_KIND_PIER")
	return tr("PROP_KIND_" + String(prop.kind).to_upper())


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
		texts.add_child(_small_label(_place_line(prop), 10, COLOR_MUTED))
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
	# Продаются — только в городе, где ты сейчас.
	var for_sale := props.defs.filter(func(p: Dictionary) -> bool:
		return not props.is_mine(p.id) and s.world.city_of(p.district) == s.city)
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
		texts.add_child(_small_label(tr(s.market.get_district(prop.district).name_key) + " · " + _kind_name(prop), 10, COLOR_MUTED))
		row.add_child(texts)
		row.add_child(_small_label("$%s · $%s/%s" % [_format_money(int(prop.buy_price)), _format_money(int(prop.rent)), tr("TILE_NIGHT")], 11, COLOR_TEXT))
		var open := Button.new()
		open.text = "›"
		open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(open, 8)
		open.pressed.connect(open_property_card.bind(String(prop.id)))
		row.add_child(open)
		_buildings_list.add_child(row)


## «Район · тип», а для зданий в другом городе — «Город · район · тип».
func _place_line(prop: Dictionary) -> String:
	var s := GameState.session
	var where := tr(s.market.get_district(prop.district).name_key)
	var prop_city := s.world.city_of(prop.district)
	if prop_city != s.city:
		where = tr(s.world.get_city(prop_city).name_key) + " · " + where
	return where + " · " + _kind_name(prop)


## Вкладка «Люди»: бригада (место работы, уволить) и биржа (нанять).
func _refresh_crew() -> void:
	var s := GameState.session
	var crew := s.crew
	_clear(_crew_list)
	_tab_buttons.get_child(TAB_INDEX.crew).text = tr("TAB_CREW") + (" %d" % crew.people.size() if not crew.people.is_empty() else "")
	_crew_list.add_child(_small_label((tr("CREW_MINE") % [crew.people.size(), s.limit("crew_max"),
			_format_money(crew.total_wages())]).to_upper(), 10, COLOR_MUTED))
	if crew.people.is_empty():
		var empty := _small_label(tr("CREW_EMPTY"), 11, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_crew_list.add_child(empty)
	_crew_list.add_child(_arsenal_row())
	for person: Dictionary in crew.people:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_person_cell(person))
		if person.role in ["courier", "scout"]:
			var route := s.logistics.route_of(int(person.id))
			var where := _small_label(tr("CREW_ON_ROUTE") if not route.is_empty() else tr("CREW_NO_ROUTE"), 11,
					COLOR_TEXT if not route.is_empty() else COLOR_MUTED)
			where.custom_minimum_size.x = 132
			row.add_child(where)
		elif person.role == "lawyer":
			var on_call := _small_label(tr("CREW_ON_CALL"), 11, COLOR_TEXT)
			on_call.custom_minimum_size.x = 132
			row.add_child(on_call)
		else:
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
		_crew_list.add_child(_loyalty_row(person))
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


## Под человеком: лояльность, страх и усталость полосками, сколько знает;
## ниже — кнопки «Премия», «Надавить», «Выходной» и (кому можно) «В менеджеры».
## Арсенал: оружие и броня на складах в этом городе и сколько бойцов вооружено.
func _arsenal_row() -> HBoxContainer:
	var s := GameState.session
	var stock := s.arsenal()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(GameIcon.new("pistol", 16.0))
	var parts: Array[String] = []
	for id: String in ["rifle", "shotgun", "pistol", "armor", "ammo"]:
		if int(stock[id]) > 0:
			parts.append("%s %d" % [tr(s.market.get_good(id).name_key), int(stock[id])])
	var arms := s.armament()
	var armed := arms.values().filter(func(a: Dictionary) -> bool: return a.weapon != "").size()
	var text := tr("ARSENAL_EMPTY") if parts.is_empty() else tr("ARSENAL_LINE") % [", ".join(parts), armed, arms.size()]
	var label := _small_label(text, 11, COLOR_TEXT if not parts.is_empty() else COLOR_MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _loyalty_row(person: Dictionary) -> VBoxContainer:
	var s := GameState.session
	var id := int(person.id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 8)
	meters.tooltip_text = tr("CREW_STATS_TIP")
	meters.mouse_filter = Control.MOUSE_FILTER_PASS
	meters.add_child(_indent())
	var loyalty := float(person.loyalty)
	var loyalty_color := COLOR_UP if loyalty >= 50.0 else (COLOR_WARN if loyalty >= float(s.balance.betray_loyalty) else COLOR_DOWN)
	meters.add_child(_meter(tr("CREW_LOYALTY"), loyalty / 100.0, loyalty_color))
	meters.add_child(_meter(tr("CREW_FEAR"), float(person.fear) / 100.0, COLOR_MUTED))
	var fatigue := float(person.fatigue)
	meters.add_child(_meter(tr("CREW_FATIGUE"), fatigue / 100.0,
			COLOR_DOWN if fatigue >= float(s.balance.fatigue_tired) else COLOR_WARN))
	meters.add_child(_small_label(tr("CREW_KNOWS") % roundi(s.knows_share(person) * 100.0), 10, COLOR_MUTED))
	if int(person.wounded) > 0:
		meters.add_child(_small_label(tr("CREW_WOUNDED") % int(person.wounded), 10, COLOR_DOWN))
	box.add_child(meters)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(_indent())
	buttons.add_child(_crew_button(tr("BTN_BONUS") % _format_money(s.bonus_cost(id)), "", not s.can_give_bonus(id),
			GameState.give_bonus.bind(id)))
	buttons.add_child(_crew_button(tr("BTN_PRESSURE"), tr("BTN_PRESSURE_TIP"), not s.can_pressure(id), GameState.pressure.bind(id)))
	buttons.add_child(_crew_button(tr("BTN_DAY_OFF"), tr("BTN_DAY_OFF_TIP"), not s.can_give_day_off(id),
			GameState.give_day_off.bind(id)))
	if not ["manager", "accountant", "lawyer"].has(person.role):
		buttons.add_child(_crew_button(tr("BTN_PROMOTE"), tr("BTN_PROMOTE_TIP"), not s.can_promote(id), GameState.promote.bind(id)))
	box.add_child(buttons)
	return box


## Отступ под иконкой роли, чтобы строки человека шли ровно под его именем.
func _indent() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 26
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _crew_button(text: String, tip: String, disabled: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(button, 6)
	button.add_theme_font_size_override("font_size", 10)
	button.disabled = disabled
	button.pressed.connect(action)
	return button


## Подпись и узкая цветная полоска (0–1).
func _meter(caption: String, value: float, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_small_label("%s %d" % [caption, roundi(value * 100.0)], 10, COLOR_MUTED))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 4)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = get_theme_stylebox("fill", "ProgressBar").duplicate()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box


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


# --- Перевозки ---

## Вкладка «Перевозки» строится кодом и встаёт третьей, после «Людей».
func _build_routes_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "RoutesTab"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_routes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_routes_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_routes_list)
	_tabs.add_child(scroll)
	_tabs.move_child(scroll, TAB_INDEX.routes)


## Вкладка «Перевозки»: свой транспорт (тайник), магазин машин, маршруты и форма нового маршрута.
func _refresh_routes() -> void:
	var s := GameState.session
	var logistics := s.logistics
	var vehicle_types: Dictionary = s.balance.vehicles
	_clear(_routes_list)
	_tab_buttons.get_child(TAB_INDEX.routes).text = tr("TAB_ROUTES") \
			+ (" %d" % logistics.routes.size() if not logistics.routes.is_empty() else "")
	_routes_list.add_child(_small_label((tr("ROUTES_VEHICLES") % [logistics.vehicles.size(), s.limit("vehicles_max")]).to_upper(),
			10, COLOR_MUTED))
	if logistics.vehicles.is_empty():
		_routes_list.add_child(_small_label(tr("ROUTES_NO_VEHICLES"), 11, COLOR_MUTED))
	for vehicle: Dictionary in logistics.vehicles:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_icon_square("van", COLOR_ACCENT, 22))
		var name_label := _small_label("%s #%d" % [tr(vehicle_types[vehicle.type].name_key), int(vehicle.id)], 12, COLOR_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if vehicle.get("stolen", false):
			row.add_child(_pill(tr("PILL_STOLEN"), COLOR_DOWN))
		if int(vehicle.broken) > 0:
			row.add_child(_pill(tr("PILL_REPAIR"), COLOR_DOWN))
		elif logistics.vehicle_busy(int(vehicle.id)):
			row.add_child(_pill(tr("PILL_BUSY"), COLOR_ACCENT))
		else:
			row.add_child(_pill(tr("PILL_FREE"), COLOR_MUTED))
		if vehicle.disguise:
			row.add_child(_pill(tr("PILL_DISGUISE"), COLOR_UP))
		else:
			var disguise := Button.new()
			disguise.text = tr("BTN_DISGUISE") % _format_money(int(s.balance.disguise_cost))
			disguise.tooltip_text = tr("BTN_DISGUISE_TIP")
			disguise.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_make_small(disguise, 6)
			disguise.add_theme_font_size_override("font_size", 10)
			disguise.disabled = not s.can_add_disguise(int(vehicle.id))
			disguise.pressed.connect(GameState.add_disguise.bind(int(vehicle.id)))
			row.add_child(disguise)
		if vehicle.hidden:
			row.add_child(_pill(tr("PILL_HIDDEN"), COLOR_UP))
		else:
			var hidden := Button.new()
			hidden.text = tr("BTN_HIDDEN") % _format_money(int(s.balance.hidden_compartment_cost))
			hidden.tooltip_text = tr("BTN_HIDDEN_TIP")
			hidden.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_make_small(hidden, 6)
			hidden.add_theme_font_size_override("font_size", 10)
			hidden.disabled = not s.can_add_hidden(int(vehicle.id))
			hidden.pressed.connect(GameState.add_hidden.bind(int(vehicle.id)))
			row.add_child(hidden)
		_routes_list.add_child(row)
		if vehicle.get("stolen", false):
			_routes_list.add_child(_stolen_actions(vehicle))
	_routes_list.add_child(_small_label(tr("ROUTES_SHOP").to_upper(), 10, COLOR_MUTED))
	for type: String in vehicle_types:
		var info: Dictionary = vehicle_types[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_icon_square("van", COLOR_WARN, 22))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label(tr(info.name_key), 12, COLOR_TEXT))
		texts.add_child(_small_label(tr("VEHICLE_INFO") % [int(info.capacity), str(info.notice)], 10, COLOR_MUTED))
		row.add_child(texts)
		var buy := Button.new()
		buy.text = tr("BTN_BUY_VEHICLE") % _format_money(int(info.price))
		buy.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(buy, 8)
		buy.disabled = not s.can_buy_vehicle(type)
		buy.pressed.connect(GameState.buy_vehicle.bind(type))
		row.add_child(buy)
		_routes_list.add_child(row)
	_routes_list.add_child(HSeparator.new())
	_routes_list.add_child(_small_label(tr("ROUTES_LIST").to_upper(), 10, COLOR_MUTED))
	if logistics.routes.is_empty():
		var empty := _small_label(tr("ROUTES_EMPTY"), 11, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_routes_list.add_child(empty)
	for route: Dictionary in logistics.routes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label("%s → %s" % [_place_title(route.from), _place_title(route.to)], 12, COLOR_TEXT))
		var amount := s.route_amount(route)
		# Риск — по самой опасной из смен маршрута: днём патрули, ночью засады.
		var police := 0.0
		var ambush := 0.0
		for shift: String in s.route_shifts(route):
			police = maxf(police, s.route_police_chance(route, shift))
			ambush = maxf(ambush, s.route_ambush_chance(route, maxi(amount, 1), shift))
		var info := tr("ROUTE_INFO") % [tr(s.market.get_good(route.good).name_key),
				logistics.capacity(logistics.get_vehicle(route.vehicle)) / s.good_size(route.good),
				roundi(police * 100.0), roundi(ambush * 100.0)]
		if s.is_market_place(route.to) and amount > 0:
			info += " · " + tr("ROUTE_SALE") % _format_money(s.route_sale_quote(route, amount))
		texts.add_child(_small_label(info, 10, COLOR_MUTED))
		var people := "%s · %s #%d" % [tr(s.crew.get_person(route.courier).nick),
				tr(vehicle_types[logistics.get_vehicle(route.vehicle).type].name_key), int(route.vehicle)]
		if int(route.scout) != 0:
			people += " · %s: %s" % [tr("ROLE_SCOUT"), tr(s.crew.get_person(route.scout).nick)]
		texts.add_child(_small_label(people, 10, COLOR_MUTED))
		row.add_child(texts)
		row.add_child(_shift_picker(route))
		var stop := Button.new()
		stop.text = "✕"
		stop.tooltip_text = tr("BTN_REMOVE_ROUTE")
		stop.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(stop, 7)
		stop.disabled = not s.can_act()
		stop.pressed.connect(GameState.remove_route.bind(int(route.id)))
		row.add_child(stop)
		_routes_list.add_child(row)
	_build_route_form()
	_build_supplies()
	_build_lines()
	_build_insiders()
	_build_shipments()


func _build_gangs_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GangsTab"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gangs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gangs_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_gangs_list)
	_tabs.add_child(scroll)
	_tabs.move_child(scroll, TAB_INDEX.gangs)


## Хозяин района словами: банда, «ты» или «ничей».
func _owner_title(district: String) -> String:
	var who := GameState.session.gangs.owner(district)
	if who == Gangs.PLAYER:
		return tr("OWNER_YOU")
	return tr(GameState.session.gangs.get_def(who).name_key) if who != "" else tr("OWNER_NOBODY")


## Вкладка «Банды»: каждая банда (босс, характер, люди, сила, отношение, земли) и влияние по районам полосками.
func _refresh_gangs() -> void:
	var s := GameState.session
	var gangs := s.gangs
	_clear(_gangs_list)
	var hint := _small_label(tr("GANGS_HINT"), 10, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gangs_list.add_child(hint)
	var power := HBoxContainer.new()
	power.add_theme_constant_override("separation", 6)
	var power_label := _small_label(tr("GANGS_POWER") % [roundi(s.crew_power()),
			s.fighters_ready().filter(func(p: Dictionary) -> bool: return p.role == "fighter").size(),
			tr(s.balance.gear_levels[s.gear].name_key)], 11, COLOR_TEXT)
	power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power.add_child(power_label)
	var gear := Button.new()
	if s.gear + 1 < s.balance.gear_levels.size():
		var next: Dictionary = s.balance.gear_levels[s.gear + 1]
		gear.text = tr("BTN_GEAR") % [tr(next.name_key), _format_money(int(next.cost))]
	else:
		gear.text = tr("BTN_GEAR_MAX")
	gear.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(gear, 8)
	gear.add_theme_font_size_override("font_size", 10)
	gear.disabled = not s.can_buy_gear()
	gear.pressed.connect(GameState.buy_gear)
	power.add_child(gear)
	_gangs_list.add_child(power)
	_tab_buttons.get_child(TAB_INDEX.gangs).text = tr("TAB_GANGS") + (" %d" % gangs.offers.size() if not gangs.offers.is_empty() else "")
	if not gangs.offers.is_empty():
		_gangs_list.add_child(_small_label(tr("GANGS_OFFERS").to_upper(), 10, COLOR_MUTED))
	for offer: Dictionary in gangs.offers:
		_gangs_list.add_child(_offer_row(offer))
	for gang: Dictionary in gangs.defs.filter(func(g: Dictionary) -> bool: return s.world.city_of(g.home) == s.city):
		var st: Dictionary = gangs.state[gang.id]
		var level := gangs.level(gang.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := _icon_square("district", gangs.color(gang.id), 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 6)
		var name_label := _small_label(tr(gang.name_key), 13, COLOR_TEXT)
		_bold(name_label)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(name_label)
		title.add_child(_pill(tr("GANG_LEVEL_" + level.to_upper()), LEVEL_COLORS[level]))
		if s.fight_district(gang.id) != "":
			var fight := Button.new()
			fight.text = tr("BTN_FIGHT")
			fight.tooltip_text = tr("BTN_FIGHT_TIP") + ("\n" + tr("BTN_FIGHT_BETRAY_TIP") if gangs.has_treaty(gang.id) else "")
			fight.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_make_small(fight, 8)
			fight.add_theme_font_size_override("font_size", 10)
			fight.disabled = not GameState.can_fight(gang.id)
			fight.pressed.connect(open_fight.bind(String(gang.id)))
			title.add_child(fight)
		texts.add_child(title)
		texts.add_child(_small_label(tr("GANG_BOSS") % [tr(gang.boss_key), tr(gangs.temper(gang.id).name_key)], 10, COLOR_MUTED))
		texts.add_child(_small_label(tr("GANG_INFO") % [int(st.people), _format_money(int(st.cash)), gangs.strength(gang.id)],
				10, COLOR_MUTED))
		var turf: Array = gangs.territories(gang.id).map(func(d: String) -> String: return tr(s.market.get_district(d).name_key))
		texts.add_child(_small_label((tr("GANG_RELATION") % roundi(gangs.relation(gang.id))) + " · "
				+ (tr("GANG_TURF") % ", ".join(turf) if not turf.is_empty() else tr("GANG_NO_TURF")), 10, LEVEL_COLORS[level]))
		if st.revenge:
			texts.add_child(_small_label(tr("GANG_REVENGE"), 10, COLOR_DOWN))
		if gangs.has_treaty(gang.id):
			texts.add_child(_small_label(_treaty_text(gang.id), 10, COLOR_ACCENT))
		row.add_child(texts)
		_gangs_list.add_child(row)
		_gangs_list.add_child(_diplomacy_row(gang.id))
	_gangs_list.add_child(HSeparator.new())
	_gangs_list.add_child(_small_label(tr("GANGS_INFLUENCE").to_upper(), 10, COLOR_MUTED))
	for district: Dictionary in s.world.districts_of(s.city):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var name_label := _small_label(tr(district.name_key), 11, COLOR_TEXT)
		name_label.custom_minimum_size.x = 70
		line.add_child(name_label)
		line.add_child(_influence_bar(district.id))
		var owner := _small_label(_owner_title(district.id), 10, COLOR_MUTED)
		owner.custom_minimum_size.x = 64
		owner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(owner)
		_gangs_list.add_child(line)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	for item: Array in [[tr("GANGS_YOU"), COLOR_ACCENT], [tr("GANGS_FREE"), Color(0.88, 0.9, 0.93)]]:
		var swatch := ColorRect.new()
		swatch.color = item[1]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(_small_label(item[0], 10, COLOR_MUTED))
	_gangs_list.add_child(legend)


## Кнопка «Мир» рядом с «Сохранить» и мировая карта на весь экран.
func _build_world() -> void:
	_world_button.tooltip_text = tr("BTN_WORLD")
	_world_button.custom_minimum_size = Vector2(30, 30)
	_make_small(_world_button, 4)
	var icon := GameIcon.new("globe", 16.0)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	_world_button.add_child(icon)
	_world_button.pressed.connect(func() -> void:
		if _world_overlay.visible:
			_world_overlay.visible = false
		else:
			_world_overlay.open())
	_save_button.get_parent().add_child(_world_button)
	_save_button.get_parent().move_child(_world_button, _save_button.get_index())
	_world_overlay.visible = false
	add_child(_world_overlay)
	move_child(_world_overlay, _check_overlay.get_index())


func _build_fight_overlay() -> void:
	_fight_overlay.color = _check_overlay.color
	_fight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fight_overlay.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _check_overlay.get_node("Center/Panel").get_theme_stylebox("panel"))
	_fight_box.add_theme_constant_override("separation", 10)
	panel.add_child(_fight_box)
	center.add_child(panel)
	_fight_overlay.add_child(center)
	add_child(_fight_overlay)
	move_child(_fight_overlay, _check_overlay.get_index())


## Собраться на разборку: окно с силами сторон и выбором тактики.
func open_fight(gang_id: String) -> void:
	_fight_gang = gang_id
	_refresh_fight()


## Окно разборки: перед боем — силы и тактики, после — отчёт о бое и что делать дальше.
func _refresh_fight() -> void:
	var s := GameState.session
	var result := s.fight_result
	_fight_overlay.visible = s.status == GameSession.Status.PLAYING and (not result.is_empty() or _fight_gang != "")
	if not _fight_overlay.visible:
		return
	_clear(_fight_box)
	if result.is_empty():
		_fight_prep()
	else:
		_fight_gang = ""
		_fight_report(result)


func _fight_prep() -> void:
	var s := GameState.session
	var gang := s.gangs.get_def(_fight_gang)
	_fight_title(tr("FIGHT_TITLE") % tr(gang.name_key), s.gangs.color(_fight_gang))
	_fight_text(tr("FIGHT_PREP") % [tr(s.market.get_district(s.fight_district(_fight_gang)).name_key),
			roundi(s.crew_power()), roundi(s.fight_defense(_fight_gang))])
	for tactic: String in s.balance.fight_tactics:
		var button := _fight_button(tr("FIGHT_TACTIC") % [tr(s.balance.fight_tactics[tactic].name_key),
				roundi(s.fight_chance(_fight_gang, tactic) * 100.0)], _fight_with.bind(tactic))
		button.tooltip_text = tr(String(s.balance.fight_tactics[tactic].name_key) + "_TIP")
		button.disabled = not GameState.can_fight(_fight_gang)
	_fight_button(tr("BTN_CANCEL"), open_fight.bind(""))


func _fight_with(tactic: String) -> void:
	var gang := _fight_gang
	_fight_gang = ""
	GameState.fight(gang, tactic)


## Отчёт о бое: итог, силы сторон, твои раненые и погибшие, потери банды; после победы — три последствия.
func _fight_report(result: Dictionary) -> void:
	var s := GameState.session
	var gang := s.gangs.get_def(result.gang)
	_fight_title(tr("FIGHT_WON") if result.win else tr("FIGHT_LOST"), COLOR_UP if result.win else COLOR_DOWN)
	_fight_text(tr("FIGHT_SIDES") % [tr(gang.name_key), int(result.power), int(result.defense)])
	var losses: Array = []
	if not result.wounded.is_empty():
		losses.append(tr("FIGHT_WOUNDED_LIST") % ", ".join(result.wounded.map(func(n: String) -> String: return tr(n))))
	if not result.dead.is_empty():
		losses.append(tr("FIGHT_DEAD_LIST") % ", ".join(result.dead.map(func(n: String) -> String: return tr(n))))
	_fight_text(tr("FIGHT_YOUR_LOSSES") % ("; ".join(losses) if not losses.is_empty() else tr("FIGHT_NO_LOSSES")),
			COLOR_DOWN if not result.dead.is_empty() else COLOR_TEXT)
	_fight_text(tr("FIGHT_GANG_LOSSES") % [int(result.gang_losses), int(result.heat)], COLOR_MUTED)
	if not result.win:
		_fight_button(tr("BTN_OK"), GameState.choose_fight_outcome.bind("ok"))
		return
	_fight_text(tr("FIGHT_CHOOSE"))
	var tribute := roundi(int(s.gangs.state[result.gang].cash) * float(s.balance.fight_tribute_share))
	_fight_button(tr("BTN_FIGHT_TAKE") % int(s.balance.fight_take_influence), GameState.choose_fight_outcome.bind("take"))
	_fight_button(tr("BTN_FIGHT_TRIBUTE") % _format_money(tribute), GameState.choose_fight_outcome.bind("tribute"))
	_fight_button(tr("BTN_FIGHT_MERCY"), GameState.choose_fight_outcome.bind("mercy"))


func _fight_title(text: String, color: Color) -> void:
	var title := _small_label(text, 22, color)
	_bold(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fight_box.add_child(title)


func _fight_text(text: String, color: Color = COLOR_TEXT) -> void:
	var label := _small_label(text, 13, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fight_box.add_child(label)


func _fight_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(action)
	_fight_box.add_child(button)
	return button


func _treaty_text(gang_id: String) -> String:
	var s := GameState.session
	var t := s.gangs.treaty(gang_id)
	var name := tr(s.balance.treaties[t.kind].name_key)
	if t.kind == "peace_tax":
		return tr("GANG_TREATY_TAX") % [name, _format_money(s.treaty_cost(gang_id, "peace_tax")), int(t.paid_day)]
	if int(t.until) > 0:
		return tr("GANG_TREATY_UNTIL") % [name, int(t.until)]
	return tr("GANG_TREATY") % name


## Кнопки дипломатии под бандой: встреча, договоры (что сейчас можно) или «Разорвать договор».
func _diplomacy_row(gang_id: String) -> HFlowContainer:
	var s := GameState.session
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	row.add_child(_indent())
	_diplomacy_button(row, tr("BTN_MEET") % _format_money(int(s.balance.meet_gift)), tr("BTN_MEET_TIP"),
			not GameState.can_meet(gang_id), GameState.meet.bind(gang_id))
	if s.gangs.has_treaty(gang_id):
		_diplomacy_button(row, tr("BTN_TREATY_CANCEL"), tr("BTN_TREATY_CANCEL_TIP"), not s.can_act(),
				GameState.cancel_treaty.bind(gang_id))
		return row
	for kind: String in s.balance.treaties:
		if not s.treaty_allowed(gang_id, kind):
			continue
		var name := tr(s.balance.treaties[kind].name_key)
		var cost := s.treaty_cost(gang_id, kind)
		var text := tr("BTN_TREATY_COST") % [name, _format_money(cost)] if cost > 0 else tr("BTN_TREATY") % name
		_diplomacy_button(row, text, tr(String(s.balance.treaties[kind].name_key) + "_TIP"), not s.can_sign(gang_id, kind),
				GameState.sign_treaty.bind(gang_id, kind))
	return row


func _diplomacy_button(row: Control, text: String, tip: String, disabled: bool, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(button, 6)
	button.add_theme_font_size_override("font_size", 10)
	button.disabled = disabled
	button.pressed.connect(action)
	row.add_child(button)


## Строка требования или предложения банды: что хотят, до какого дня, кнопки «да» и «нет».
func _offer_row(offer: Dictionary) -> HBoxContainer:
	var s := GameState.session
	var gang := s.gangs.get_def(offer.gang)
	var demand: bool = offer.kind == "demand"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon_square("dirty" if demand else offer.good, s.gangs.color(offer.gang), 22))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var what := tr("OFFER_DEMAND") % [tr(gang.name_key), int(offer.amount)] if demand \
			else tr("OFFER_DEAL") % [tr(gang.name_key), int(offer.units), tr(s.market.get_good(offer.good).name_key), int(offer.amount)]
	texts.add_child(_small_label(what, 12, COLOR_DOWN if demand else COLOR_TEXT))
	texts.add_child(_small_label(tr("OFFER_DAYS") % int(offer.expires), 10, COLOR_MUTED))
	row.add_child(texts)
	for answer: Array in [[true, "BTN_PAY_CUT" if demand else "BTN_BUY_DEAL"], [false, "BTN_REFUSE" if demand else "BTN_DECLINE"]]:
		var button := Button.new()
		button.text = tr(answer[1])
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(button, 8)
		button.disabled = not s.can_accept_offer(int(offer.id)) if answer[0] else not s.can_act()
		button.pressed.connect(GameState.answer_offer.bind(int(offer.id), answer[0]))
		row.add_child(button)
	return row


## Полоска влияния в районе: доли банд их цветами, твоя — синим, ничья — серым.
func _influence_bar(district: String) -> HBoxContainer:
	var gangs := GameState.session.gangs
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 10
	var parts: Array = []
	for gang: Dictionary in gangs.defs:
		if gangs.share(district, gang.id) > 0.0:
			parts.append([gangs.share(district, gang.id), gangs.color(gang.id)])
	parts.append([gangs.share(district, Gangs.PLAYER), COLOR_ACCENT])
	parts.append([gangs.free_share(district), Color(0.88, 0.9, 0.93)])
	for part: Array in parts:
		if float(part[0]) <= 0.0:
			continue
		var piece := ColorRect.new()
		piece.color = part[1]
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		piece.size_flags_stretch_ratio = float(part[0])
		piece.tooltip_text = "%d" % roundi(float(part[0]))
		bar.add_child(piece)
	return bar


## Форма «Новый маршрут»: откуда, куда, что, на чём, кто везёт.
## Угнанная машина: разобрать на запчасти, перебить номера или скинуть перекупщику.
func _stolen_actions(vehicle: Dictionary) -> HFlowContainer:
	var s := GameState.session
	var id := int(vehicle.id)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_child(_small_label(tr("STOLEN_HINT"), 10, COLOR_MUTED))
	var strip := _prop_button(tr("BTN_STRIP") % int(s.balance.strip_parts[vehicle.type]), GameState.strip_vehicle.bind(id),
			not s.can_strip_vehicle(id))
	strip.tooltip_text = tr("BTN_STRIP_TIP")
	row.add_child(strip)
	row.add_child(_prop_button(tr("BTN_RELABEL") % _format_money(int(s.balance.relabel_cost)), GameState.relabel_vehicle.bind(id),
			not s.can_relabel_vehicle(id)))
	row.add_child(_prop_button(tr("BTN_FENCE") % _format_money(s.fence_price(id)), GameState.fence_vehicle.bind(id),
			not s.can_fence_vehicle(id)))
	return row


## Когда ездит маршрут: днём (14:00), ночью (02:00) или оба рейса.
func _shift_picker(route: Dictionary) -> OptionButton:
	var picker := OptionButton.new()
	picker.tooltip_text = tr("ROUTE_SHIFT_TIP")
	_make_small(picker, 7)
	var shifts := ["day", "night", "both"]
	for shift: String in shifts:
		picker.add_item(tr("ROUTE_SHIFT_" + shift.to_upper()))
	picker.selected = shifts.find(String(route.get("shift", "night")))
	picker.disabled = not GameState.session.can_act()
	picker.item_selected.connect(func(index: int) -> void: GameState.set_route_shift(int(route.id), shifts[index]))
	return picker


func _build_route_form() -> void:
	var s := GameState.session
	var mine := s.properties.mine()
	var vehicles := s.logistics.vehicles.filter(func(v: Dictionary) -> bool: return not s.logistics.vehicle_busy(int(v.id)))
	var couriers := s.crew.people.filter(func(p: Dictionary) -> bool:
		return p.role == "courier" and not s.logistics.courier_busy(int(p.id)))
	var scouts := s.crew.people.filter(func(p: Dictionary) -> bool:
		return p.role == "scout" and not s.logistics.scout_busy(int(p.id)))
	_routes_list.add_child(_small_label(tr("ROUTES_NEW").to_upper(), 10, COLOR_MUTED))
	if mine.is_empty() or vehicles.is_empty() or couriers.is_empty():
		var need := _small_label(tr("ROUTES_NEED"), 11, COLOR_MUTED)
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_routes_list.add_child(need)
		return
	var places: Array = mine.map(func(p: Dictionary) -> Array: return [p.id, tr(p.name_key)])
	# Куда: свои здания и рынки районов.
	var targets: Array = places.duplicate()
	for d: Dictionary in s.world.districts_of(s.city):
		if d.has_market:
			targets.append([s.market_place(d.id), _place_title(s.market_place(d.id))])
	var goods: Array = s.market.goods.map(func(g: Dictionary) -> Array: return [g.id, tr(g.name_key)])
	var vehicle_items: Array = vehicles.map(func(v: Dictionary) -> Array:
		return [int(v.id), "%s #%d" % [tr(s.balance.vehicles[v.type].name_key), int(v.id)]])
	var courier_items: Array = couriers.map(func(p: Dictionary) -> Array: return [int(p.id), tr(p.nick)])
	var scout_items: Array = [[0, tr("ROUTE_NO_SCOUT")]]
	scout_items.append_array(scouts.map(func(p: Dictionary) -> Array: return [int(p.id), tr(p.nick)]))
	# Если выбранное пропало (продали здание, курьер ушёл) — берём первое подходящее.
	_fix_choice("from", places, 0)
	_fix_choice("to", targets, 1)
	_fix_choice("good", goods, 0)
	_fix_choice("vehicle", vehicle_items, 0)
	_fix_choice("courier", courier_items, 0)
	_fix_choice("scout", scout_items, 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(_form_picker("from", places))
	top.add_child(_small_label("→", 12, COLOR_MUTED))
	top.add_child(_form_picker("to", targets))
	_routes_list.add_child(top)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	middle.add_child(_form_picker("good", goods))
	middle.add_child(_form_picker("vehicle", vehicle_items))
	_routes_list.add_child(middle)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.add_child(_form_picker("courier", courier_items))
	bottom.add_child(_form_picker("scout", scout_items))
	var start := Button.new()
	start.text = tr("BTN_ADD_ROUTE")
	start.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(start, 8)
	var f := _route_form
	start.disabled = not s.can_add_route(f.from, f.to, f.good, f.vehicle, f.courier, f.scout)
	start.pressed.connect(func() -> void: GameState.add_route(f.from, f.to, f.good, f.vehicle, f.courier, f.scout))
	bottom.add_child(start)
	_routes_list.add_child(bottom)


## «Поставщики»: договоры (кто, что, сколько, куда, режим) и форма нового договора по телефону.
## Привозят каждое утро в 08:00 в твоё здание этого города, оплата при доставке.
func _build_supplies() -> void:
	var s := GameState.session
	_routes_list.add_child(HSeparator.new())
	_routes_list.add_child(_small_label((tr("SUP_TITLE") % [s.suppliers.contracts.size(), s.limit("supply_max")]).to_upper(),
			10, COLOR_MUTED))
	for contract: Dictionary in s.suppliers.contracts:
		var supplier := s.suppliers.get_def(contract.supplier)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(GameIcon.new(contract.good, 16.0))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var what := tr("SUP_KEEP_LINE" if contract.mode == "keep" else "SUP_DAILY_LINE") % [int(contract.amount),
				tr(s.market.get_good(contract.good).name_key), _ship_title(contract.to)]
		texts.add_child(_small_label(what, 12, COLOR_TEXT))
		var next := s.supply_amount(contract)
		texts.add_child(_small_label(tr("SUP_INFO") % [tr(supplier.name_key), _format_money(s.supply_price(contract.supplier, contract.good)),
				next, _format_money(next * s.supply_price(contract.supplier, contract.good))], 10, COLOR_MUTED))
		row.add_child(texts)
		var stop := Button.new()
		stop.text = "✕"
		stop.tooltip_text = tr("BTN_REMOVE_SUPPLY")
		stop.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(stop, 7)
		stop.disabled = not s.can_act()
		stop.pressed.connect(GameState.remove_supply.bind(int(contract.id)))
		row.add_child(stop)
		_routes_list.add_child(row)
	var targets: Array = s.properties.mine().filter(func(p: Dictionary) -> bool: return s.world.city_of(p.district) == s.city) \
			.map(func(p: Dictionary) -> Array: return [p.id, tr(p.name_key)])
	if targets.is_empty():
		var hint := _small_label(tr("SUP_NEED"), 11, COLOR_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_routes_list.add_child(hint)
		return
	var contacts: Array = s.suppliers.in_city(s.city).map(func(sup: Dictionary) -> Array: return [sup.id, tr(sup.name_key)])
	_fix_choice("sup", contacts, 0)
	_fix_choice("sup_to", targets, 0)
	var f := _route_form
	var supplier := s.suppliers.get_def(f.sup)
	var goods: Array = supplier.goods.map(func(g: String) -> Array:
		return [g, "%s · $%s" % [tr(s.market.get_good(g).name_key), _format_money(s.supply_price(f.sup, g))]])
	_fix_choice("sup_good", goods, 0)
	var amounts: Array = s.balance.supply_amounts.map(func(n: float) -> Array: return [int(n), tr("SUP_AMOUNT") % int(n)])
	_fix_choice("sup_amount", amounts, 1)
	var modes: Array = [["daily", tr("SUP_MODE_DAILY")], ["keep", tr("SUP_MODE_KEEP")]]
	_fix_choice("sup_mode", modes, 0)
	var desc := _small_label(tr(supplier.name_key + "_DESC") + " · " + (tr("SUP_RISK") % roundi(float(supplier.risk) * 100)
			if float(supplier.risk) > 0.05 else tr("SUP_RELIABLE")), 10, COLOR_DOWN if float(supplier.risk) > 0.05 else COLOR_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(_form_picker("sup", contacts))
	top.add_child(_form_picker("sup_good", goods))
	_routes_list.add_child(top)
	_routes_list.add_child(desc)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	middle.add_child(_form_picker("sup_amount", amounts))
	middle.add_child(_form_picker("sup_mode", modes))
	middle.add_child(_small_label("→", 12, COLOR_MUTED))
	middle.add_child(_form_picker("sup_to", targets))
	_routes_list.add_child(middle)
	if f.sup_mode == "keep" and not s.has_manager(f.sup_to):
		_routes_list.add_child(_small_label(tr("SUP_KEEP_NEEDS_MANAGER"), 10, COLOR_WARN))
	var sign := Button.new()
	sign.text = tr("BTN_ADD_SUPPLY") % _format_money(int(f.sup_amount) * s.supply_price(f.sup, f.sup_good))
	sign.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(sign, 8)
	sign.disabled = not s.can_add_supply(f.sup, f.sup_good, int(f.sup_amount), f.sup_to, f.sup_mode)
	sign.pressed.connect(func() -> void: GameState.add_supply(f.sup, f.sup_good, int(f.sup_amount), f.sup_to, f.sup_mode))
	_routes_list.add_child(sign)


## «Линии контрабанды»: регулярные рейсы катером из причала или самолётом из ангара в другой город.
func _build_lines() -> void:
	var s := GameState.session
	_routes_list.add_child(HSeparator.new())
	_routes_list.add_child(_small_label((tr("LINES_TITLE") % [s.logistics.lines.size(), s.limit("lines_max")]).to_upper(), 10, COLOR_MUTED))
	for line: Dictionary in s.logistics.lines:
		var info: Dictionary = s.balance.transports[line.transport]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(GameIcon.new(line.good, 16.0))
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_small_label("%s → %s" % [_ship_title(line.from), _ship_title(line.to)], 12, COLOR_TEXT))
		texts.add_child(_small_label(tr("LINE_INFO") % [tr(info.name_key), int(line.amount), tr(s.market.get_good(line.good).name_key),
				int(info.every), maxi(0, int(line.next) - s.day)], 10, COLOR_MUTED))
		row.add_child(texts)
		var stop := Button.new()
		stop.text = "✕"
		stop.tooltip_text = tr("BTN_REMOVE_LINE")
		stop.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_make_small(stop, 7)
		stop.disabled = not s.can_act()
		stop.pressed.connect(GameState.remove_line.bind(int(line.id)))
		row.add_child(stop)
		_routes_list.add_child(row)
	var ports: Array = s.properties.mine().filter(func(p: Dictionary) -> bool: return not p.get("port", []).is_empty()) \
			.map(func(p: Dictionary) -> Array: return [p.id, _ship_title(p.id)])
	if ports.is_empty():
		_routes_list.add_child(_wrapped(tr("LINES_NEED"), 11, COLOR_MUTED))
		return
	_fix_choice("line_from", ports, 0)
	var f := _route_form
	var transports: Array = s.port_transports(f.line_from).map(func(t: String) -> Array:
		return [t, tr(s.balance.transports[t].name_key)])
	_fix_choice("line_transport", transports, 0)
	var targets: Array = s.line_targets(f.line_from, f.line_transport).map(func(id: String) -> Array: return [id, _ship_title(id)])
	if targets.is_empty():
		_routes_list.add_child(_wrapped(tr("LINES_NO_TARGET_BOAT" if f.line_transport == "boat" else "LINES_NO_TARGET"), 11, COLOR_MUTED))
		return
	_fix_choice("line_to", targets, 0)
	var goods: Array = s.market.goods.map(func(g: Dictionary) -> Array: return [g.id, tr(g.name_key)])
	_fix_choice("line_good", goods, 0)
	var amounts: Array = s.balance.line_amounts.map(func(n: float) -> Array: return [int(n), tr("SUP_AMOUNT") % int(n)])
	_fix_choice("line_amount", amounts, 1)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(_form_picker("line_from", ports))
	top.add_child(_form_picker("line_transport", transports))
	top.add_child(_small_label("→", 12, COLOR_MUTED))
	top.add_child(_form_picker("line_to", targets))
	_routes_list.add_child(top)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	middle.add_child(_form_picker("line_good", goods))
	middle.add_child(_form_picker("line_amount", amounts))
	var open := Button.new()
	open.text = tr("BTN_ADD_LINE")
	open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(open, 8)
	open.disabled = not s.can_add_line(f.line_from, f.line_to, f.line_good, int(f.line_amount), f.line_transport)
	open.pressed.connect(func() -> void: GameState.add_line(f.line_from, f.line_to, f.line_good, int(f.line_amount), f.line_transport))
	middle.add_child(open)
	_routes_list.add_child(middle)
	var quote := s.shipment_quote(f.line_from, f.line_to, f.line_good, int(f.line_amount),
			not s.market.get_good(f.line_good).legal, f.line_transport)
	_routes_list.add_child(_small_label(tr("LINE_QUOTE") % [_format_money(int(quote.cost)), int(quote.days), roundi(float(quote.risk) * 100)],
			10, COLOR_MUTED))


## «Таможня»: свой человек в каждой зоне — платишь раз в неделю, грузы и багаж досматривают реже.
func _build_insiders() -> void:
	var s := GameState.session
	_routes_list.add_child(HSeparator.new())
	_routes_list.add_child(_small_label(tr("INSIDERS_TITLE").to_upper(), 10, COLOR_MUTED))
	for zone: String in s.balance.insider_fee:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := _small_label(tr("ZONE_" + zone.to_upper()) + " · " + tr("INSIDER_FEE") % _format_money(s.insider_fee(zone)), 12,
				COLOR_TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if s.has_insider(zone):
			row.add_child(_pill(tr("PILL_INSIDER"), COLOR_UP))
			row.add_child(_prop_button("✕", GameState.fire_insider.bind(zone), not s.can_act()))
		else:
			var hire := _prop_button(tr("BTN_HIRE_INSIDER"), GameState.hire_insider.bind(zone), not s.can_hire_insider(zone))
			if s.zone_of(s.city) != zone:
				hire.tooltip_text = tr("INSIDER_GO_THERE")
			row.add_child(hire)
		_routes_list.add_child(row)
	_routes_list.add_child(_wrapped(tr("INSIDERS_HINT"), 10, COLOR_MUTED))


## «Между городами»: грузы в пути и форма отправки (откуда, что, сколько, куда, маскировка) с расчётом.
func _build_shipments() -> void:
	var s := GameState.session
	_routes_list.add_child(HSeparator.new())
	_routes_list.add_child(_small_label((tr("SHIP_TITLE") % [s.logistics.single_shipments(), s.limit("shipments_max")]).to_upper(),
			10, COLOR_MUTED))
	for shipment: Dictionary in s.logistics.shipments:
		var line := tr("SHIP_IN_TRANSIT") % [int(shipment.amount), tr(s.market.get_good(shipment.good).name_key),
				_ship_title(shipment.to), int(shipment.arrive)]
		_routes_list.add_child(_small_label(line, 11, COLOR_TEXT))
	var sources: Array = s.properties.mine().filter(func(p: Dictionary) -> bool: return not s.properties.state[p.id].stock.is_empty()) \
			.map(func(p: Dictionary) -> Array: return [p.id, _ship_title(p.id)])
	if sources.is_empty():
		var hint := _small_label(tr("SHIP_NEED"), 11, COLOR_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_routes_list.add_child(hint)
		return
	_fix_choice("ship_from", sources, 0)
	var f := _route_form
	var stock: Dictionary = s.properties.state[f.ship_from].stock
	var goods: Array = stock.keys().filter(func(g: String) -> bool: return int(stock[g]) > 0) \
			.map(func(g: String) -> Array: return [g, "%s (%d)" % [tr(s.market.get_good(g).name_key), int(stock[g])]])
	var targets: Array = s.shipment_targets(f.ship_from).map(func(t: String) -> Array: return [t, _ship_title(t)])
	if goods.is_empty() or targets.is_empty():
		return
	_fix_choice("ship_good", goods, 0)
	_fix_choice("ship_to", targets, 0)
	var have := int(stock.get(f.ship_good, 0))
	if int(f.ship_amount) <= 0 or int(f.ship_amount) > have:
		f.ship_amount = have
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(_form_picker("ship_from", sources))
	top.add_child(_small_label("→", 12, COLOR_MUTED))
	top.add_child(_form_picker("ship_to", targets))
	_routes_list.add_child(top)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	middle.add_child(_form_picker("ship_good", goods))
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = have
	amount.value = int(f.ship_amount)
	amount.suffix = tr("SHIP_PCS")
	amount.custom_minimum_size.x = 90
	amount.value_changed.connect(func(v: float) -> void:
		f.ship_amount = int(v)
		_refresh_routes())
	middle.add_child(amount)
	var legal: bool = s.market.get_good(f.ship_good).legal
	var mask := CheckBox.new()
	mask.text = tr("SHIP_DISGUISE")
	mask.tooltip_text = tr("SHIP_DISGUISE_TIP")
	mask.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mask.add_theme_font_size_override("font_size", 11)
	mask.disabled = legal
	mask.button_pressed = f.ship_disguise and not legal
	mask.toggled.connect(func(on: bool) -> void:
		f.ship_disguise = on
		_refresh_routes())
	middle.add_child(mask)
	_routes_list.add_child(middle)
	var disguise: bool = f.ship_disguise and not legal
	var quote := s.shipment_quote(f.ship_from, f.ship_to, f.ship_good, int(f.ship_amount), disguise)
	var info := tr("SHIP_QUOTE") % [_format_money(int(quote.cost)), int(quote.days)]
	if int(quote.duty) > 0:
		info += " · " + tr("SHIP_DUTY") % _format_money(int(quote.duty))
	if float(quote.risk) > 0.0:
		info += " · " + tr("SHIP_RISK") % roundi(float(quote.risk) * 100.0)
	if int(quote.sale) > 0:
		info += " · " + tr("SHIP_SALE") % _format_money(int(quote.sale))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	var quote_label := _small_label(info, 10, COLOR_MUTED)
	quote_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(quote_label)
	var send := Button.new()
	send.text = tr("BTN_SHIP")
	send.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_make_small(send, 8)
	send.disabled = not s.can_ship(f.ship_from, f.ship_to, f.ship_good, int(f.ship_amount), disguise)
	send.pressed.connect(func() -> void: GameState.ship(f.ship_from, f.ship_to, f.ship_good, int(f.ship_amount), disguise))
	bottom.add_child(send)
	_routes_list.add_child(bottom)


## «Город: здание» или «Город: рынок района».
func _ship_title(place: String) -> String:
	var s := GameState.session
	return tr(s.world.get_city(s.world.city_of(s.place_district(place))).name_key) + ": " + _place_title(place)


## Название места маршрута: здание или «Рынок: район».
func _place_title(place: String) -> String:
	var s := GameState.session
	if s.is_market_place(place):
		return tr("ROUTE_MARKET") % tr(s.place_name_key(place))
	return tr(s.place_name_key(place))


## Оставить выбор, если он есть в списке; иначе — пункт fallback (или первый).
func _fix_choice(key: String, items: Array, fallback: int) -> void:
	if items.any(func(item: Array) -> bool: return item[0] == _route_form[key]):
		return
	_route_form[key] = items[mini(fallback, items.size() - 1)][0]


## Выпадающий список формы маршрута: items — [значение, подпись].
func _form_picker(key: String, items: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	picker.add_theme_font_size_override("font_size", 11)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.clip_text = true
	for item: Array in items:
		picker.add_item(item[1])
		picker.set_item_metadata(picker.item_count - 1, item[0])
		if item[0] == _route_form[key]:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void:
		_route_form[key] = picker.get_item_metadata(index)
		_refresh_routes())
	return picker


func _refresh_market() -> void:
	var s := GameState.session
	var can_act := s.can_act()
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		# Чем в районе не торгуют (редкости — не на каждом рынке), того в списке нет.
		var traded := s.market.trades(s.district, id)
		for cell: Control in row.cells:
			cell.visible = traded
		if not traded:
			continue
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
			"driving":
				row.effect.text = tr("SKILL_DRIVING_EFFECT") % [roundi((1.0 - skills.travel_multiplier()) * 100),
						roundi((1.0 - skills.route_police_multiplier()) * 100)]
			"leadership":
				row.effect.text = tr("SKILL_LEADERSHIP_EFFECT") % [str(snappedf(skills.loyalty_bonus(), 0.1)),
						roundi((1.0 - skills.betray_multiplier()) * 100)]
			"hacking":
				row.effect.text = tr("SKILL_HACKING_EFFECT") % [roundi(lvl * b.hacking_pay_per_level * 100),
						roundi(lvl * b.steal_car_per_hacking * 100)]


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
	# Досмотр на таможне: другой заголовок, бежать нельзя.
	var customs: bool = s.pending_check.get("customs", false)
	(_check_overlay.get_node("Center/Panel/Box/CheckTitle") as Label).text = tr("CHECK_CUSTOMS_TITLE" if customs else "CHECK_TITLE")
	if customs:
		_check_text.text = tr("CHECK_CUSTOMS_TEXT") % [tr(s.world.get_city(s.city).name_key), _format_money(s.illegal_goods_value())]
	else:
		_check_text.text = tr("CHECK_TEXT") % [tr(s.market.get_district(s.district).name_key), _format_money(s.illegal_goods_value())]
	_bribe_button.text = tr("CHECK_BRIBE") % _format_money(s.pending_check.bribe)
	_bribe_button.disabled = not s.can_bribe()
	_flee_button.visible = not customs
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


## Открыть вкладку нижней правой панели (номера — в TAB_INDEX).
func open_drawer(tab: int) -> void:
	_tabs.current_tab = tab
	# Линии маршрутов на карте — пока открыта вкладка «Перевозки».
	if city != null:
		city.get_node("Life").show_route_lines = tab == TAB_INDEX.routes
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
