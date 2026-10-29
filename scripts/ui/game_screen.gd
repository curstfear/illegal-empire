extends Control
## Интерфейс партии поверх 3D-города: верхняя панель, карточка района над зданием,
## окно рынка, вкладки «Деньги / Ларёк / Навыки», журнал, окно проверки полиции.
## Только показывает GameState и передаёт ему нажатия.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const COLOR_UP := Color(0.45, 0.9, 0.55)
const COLOR_DOWN := Color(0.95, 0.4, 0.42)
const COLOR_DIRTY := Color(0.85, 0.7, 0.35)
const RISK_COLORS: Array[Color] = [Color(0.45, 0.9, 0.55), Color(0.95, 0.85, 0.4), Color(0.95, 0.6, 0.3), Color(0.95, 0.35, 0.35)]
const RISK_KEYS: Array[String] = ["RISK_LEGAL", "RISK_LOW", "RISK_MID", "RISK_HIGH"]

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _clean_label: Label = %CleanLabel
@onready var _dirty_label: Label = %DirtyLabel
@onready var _debt_label: Label = %DebtLabel
@onready var _heat_label: Label = %HeatLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = { 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button }
@onready var _payment_label: Label = %PaymentLabel
@onready var _event_label: Label = %EventLabel
@onready var _card: PanelContainer = %DistrictCard
@onready var _card_title: Label = %CardTitle
@onready var _card_info: Label = %CardInfo
@onready var _card_close_button: Button = %CardCloseButton
@onready var _card_travel_button: Button = %CardTravelButton
@onready var _card_market_button: Button = %CardMarketButton
@onready var _activities_grid: GridContainer = %ActivitiesGrid
@onready var _market_window: PanelContainer = %MarketWindow
@onready var _market_title: Label = %MarketTitle
@onready var _market_close_button: Button = %MarketCloseButton
@onready var _market_grid: GridContainer = %MarketGrid
@onready var _tabs: TabContainer = %Tabs
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

## 3D-город (ставит сцена игры). Нужен, чтобы держать карточку над зданием.
var city: Node3D
## Район, чья карточка открыта ("" — закрыта).
var _card_district: String = ""
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
	_build_market()
	_build_stall()
	_build_skills()
	_tabs.set_tab_title(0, tr("TAB_MONEY"))
	_tabs.set_tab_title(1, tr("TAB_STALL"))
	_tabs.set_tab_title(2, tr("TAB_SKILLS"))
	for button: Button in [_pay_due_button, _pay_all_button, _borrow_button, _deposit_button, _withdraw_button,
			_loan_button, _repay_button, _buy_stall_button, _card_close_button, _card_travel_button,
			_card_market_button, _market_close_button]:
		_make_small(button)
	_card_close_button.pressed.connect(close_card)
	_card_travel_button.pressed.connect(func() -> void:
		GameState.travel(_card_district)
		_refresh())
	# Пока открыт рынок, карточку района прячем, чтобы окна не налезали друг на друга.
	_card_market_button.pressed.connect(func() -> void:
		_market_window.visible = true
		_card.visible = false
		_refresh())
	_market_close_button.pressed.connect(func() -> void:
		_market_window.visible = false
		open_card(GameState.session.district))
	_pause_button.pressed.connect(func() -> void: Clock.paused = not Clock.paused)
	for value: int in _speed_buttons:
		_speed_buttons[value].pressed.connect(Clock.set_speed.bind(value))
	_pay_due_button.pressed.connect(func() -> void: GameState.pay(GameState.session.payment_left()))
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
	_refresh()
	Clock.set_speed(1)


func _process(_delta: float) -> void:
	var minutes := Clock.minutes_of_day()
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	# Часы идут, и дело может перестать помещаться в остаток дня.
	for id: String in _activity_buttons:
		_activity_buttons[id].disabled = not GameState.can_do_activity(id)
	_place_card()


## Открыть карточку района над его главным зданием.
func open_card(district: String) -> void:
	_card_district = district
	_card.visible = true
	_market_window.visible = false
	if city != null:
		city.select(district)
	_refresh()


func close_card() -> void:
	_card_district = ""
	_card.visible = false
	if city != null:
		city.select("")


## Карточка висит над зданием и следует за камерой, но не уходит за край экрана.
func _place_card() -> void:
	if not _card.visible or city == null:
		return
	_card.size = _card.get_combined_minimum_size()
	var anchor: Vector2 = city.anchor_screen_position(_card_district)
	var pos := anchor - Vector2(_card.size.x / 2.0, _card.size.y + 24.0)
	var screen := get_viewport_rect().size
	pos.x = clampf(pos.x, 16.0, screen.x - _card.size.x - 470.0)
	pos.y = clampf(pos.y, 120.0, screen.y - _card.size.y - 80.0)
	_card.position = pos


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

func _build_market() -> void:
	for header: String in ["COL_GOOD", "COL_RISK", "COL_BUY", "COL_SELL", "COL_OWNED", "", "", "", ""]:
		_header_label(_market_grid, header)
	for good: Dictionary in GameState.session.market.goods:
		var id: String = good.id
		var risk := GameState.session.market.risk_level(id)
		var row := {
			"name": _add_label(_market_grid, good.name_key, 180),
			"risk": _add_label(_market_grid, RISK_KEYS[risk], 76),
			"buy": _add_label(_market_grid, "", 96),
			"sell": _add_label(_market_grid, "", 66),
			"owned": _add_label(_market_grid, "", 160),
			"buy_one": _add_button(_market_grid, "+1", GameState.buy.bind(id, 1)),
			"buy_max": _add_button(_market_grid, "", func() -> void: GameState.buy(id, GameState.session.max_affordable(id))),
			"sell_one": _add_button(_market_grid, "−1", GameState.sell.bind(id, 1)),
			"sell_all": _add_button(_market_grid, "BTN_SELL_ALL", func() -> void: GameState.sell(id, GameState.session.inventory[id])),
		}
		row.risk.add_theme_color_override("font_color", RISK_COLORS[risk])
		row.risk.add_theme_font_size_override("font_size", 14)
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
	if _card_district != s.district:
		return
	for activity: Dictionary in s.local_activities():
		var id: String = activity.id
		var name_label := _add_label(_activities_grid, activity.name_key, 210)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var result: String
		if activity.kind == "job":
			var key := "ACT_PAY_CLEAN" if activity.legal else "ACT_PAY_DIRTY"
			result = tr(key) % _format_money(s.activity_pay(activity))
		else:
			var range_ := s.activity_yield(activity)
			result = tr("ACT_YIELD") % [range_[0], range_[1]]
		var details := _add_label(_activities_grid, "%s · %s\n%s" % [tr("ACT_HOURS") % int(activity.hours),
				tr("ACT_ENERGY") % int(activity.energy), result], 120)
		details.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		details.add_theme_font_size_override("font_size", 14)
		details.modulate = Color(1, 1, 1, 0.75)
		if not activity.legal:
			name_label.add_theme_color_override("font_color", COLOR_DIRTY)
			details.add_theme_color_override("font_color", COLOR_DIRTY)
		_activity_buttons[id] = _add_button(_activities_grid, "BTN_DO", GameState.do_activity.bind(id))
		_activity_buttons[id].size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_stall() -> void:
	for id: String in GameState.session.stall.stock:
		var good := GameState.session.market.get_good(id)
		_add_label(_stall_grid, good.name_key, 150)
		var stock := _add_label(_stall_grid, "", 150)
		stock.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		stock.add_theme_font_size_override("font_size", 16)
		var button := _add_button(_stall_grid, "", GameState.stock_stall.bind(id))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_stall_rows[id] = { "stock": stock, "button": button }


func _build_skills() -> void:
	for id in Skills.IDS:
		var name_label := _add_label(_skills_grid, "", 150)
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(80, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.show_percentage = false
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.1)
		back.set_corner_radius_all(4)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.91, 0.23, 0.27, 0.9)
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", back)
		bar.add_theme_stylebox_override("fill", fill)
		_skills_grid.add_child(bar)
		var effect := _add_label(_skills_grid, "", 160)
		effect.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		effect.add_theme_font_size_override("font_size", 14)
		effect.modulate = Color(1, 1, 1, 0.7)
		_skill_rows[id] = { "name": name_label, "bar": bar, "effect": effect }


func _header_label(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.55)
	label.add_theme_font_size_override("font_size", 15)
	grid.add_child(label)


func _add_label(grid: GridContainer, text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)
	return label


func _add_button(grid: GridContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	_make_small(button)
	button.pressed.connect(action)
	grid.add_child(button)
	return button


## Компактная кнопка: те же стили темы, но меньше отступы.
func _make_small(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = get_theme_stylebox(state, "Button").duplicate()
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)
	if not button.has_theme_font_size_override("font_size"):
		button.add_theme_font_size_override("font_size", 16)


# --- Обновление ---

func _refresh() -> void:
	var s := GameState.session
	_day_label.text = tr("HUD_DAY") % s.day
	_energy_label.text = tr("HUD_ENERGY") % s.energy
	_clean_label.text = tr("HUD_CLEAN") % _format_money(s.clean)
	_dirty_label.text = tr("HUD_DIRTY") % _format_money(s.dirty)
	_debt_label.text = tr("HUD_DEBT") % _format_money(s.debt)
	var stars := s.police.stars(s.district)
	_heat_label.text = tr("HUD_HEAT") % ("★".repeat(stars) + "☆".repeat(5 - stars))
	if s.payment_left() > 0:
		_payment_label.text = tr("HUD_PAYMENT_DUE") % [_format_money(s.payment_left()), s.next_payment_day]
	else:
		_payment_label.text = tr("HUD_PAYMENT_DONE") % s.next_payment_day
	_refresh_event_label()

	# Рынок открыт только там, где он есть и где ты стоишь.
	if not s.has_market():
		_market_window.visible = false
	_market_title.text = tr("MARKET_TITLE") % tr(s.market.get_district(s.district).name_key)
	_refresh_market()
	_refresh_card()

	var can_act := s.can_act()
	_pay_due_button.disabled = not can_act or s.payment_left() == 0 or s.money < s.payment_left()
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
	_refresh_stall()
	_refresh_skills()
	_refresh_check()


func _refresh_card() -> void:
	if _card_district == "":
		return
	var s := GameState.session
	var here := _card_district == s.district
	var stars := s.police.stars(_card_district)
	_card_title.text = tr(s.market.get_district(_card_district).name_key)
	var info := tr("HUD_HEAT") % ("★".repeat(stars) + "☆".repeat(5 - stars))
	if here:
		info = tr("CARD_YOU_ARE_HERE") + "   ·   " + info
	_card_info.text = info
	_card_travel_button.visible = not here
	_card_travel_button.disabled = not s.can_act()
	_card_market_button.visible = here and s.has_market()
	_card_market_button.disabled = _market_window.visible
	_activities_grid.visible = here
	_build_activities()


func _refresh_market() -> void:
	var s := GameState.session
	var can_act := s.can_act()
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var price := s.buy_price(id)
		var before: int = s.market.previous_prices[s.district][id]
		row.buy.text = "$%s %s" % [_format_money(price), "▲" if price > before else ("▼" if price < before else "")]
		row.buy.modulate = COLOR_UP if price > before else (COLOR_DOWN if price < before else Color.WHITE)
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
