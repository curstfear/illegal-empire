extends Control
## Экран партии (прототип): верхняя панель, районы, рынок, журнал,
## ростовщик, банк, окно проверки полиции.
## Только показывает GameState и передаёт ему нажатия.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const COLOR_UP := Color(0.45, 0.9, 0.55)
const COLOR_DOWN := Color(0.95, 0.4, 0.42)
const RISK_COLORS: Array[Color] = [Color(0.45, 0.9, 0.55), Color(0.95, 0.85, 0.4), Color(0.95, 0.6, 0.3), Color(0.95, 0.35, 0.35)]
const RISK_KEYS: Array[String] = ["RISK_LEGAL", "RISK_LOW", "RISK_MID", "RISK_HIGH"]

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _clean_label: Label = %CleanLabel
@onready var _dirty_label: Label = %DirtyLabel
@onready var _debt_label: Label = %DebtLabel
@onready var _heat_label: Label = %HeatLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = { 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button }
@onready var _payment_label: Label = %PaymentLabel
@onready var _event_label: Label = %EventLabel
@onready var _district_bar: HBoxContainer = %DistrictBar
@onready var _travel_hint: Label = %TravelHint
@onready var _market_title: Label = %MarketTitle
@onready var _market_grid: GridContainer = %MarketGrid
@onready var _log_text: RichTextLabel = %LogText
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

## Узлы строк рынка по id товара: { "buy": Label, "sell": Label, ... }.
var _rows: Dictionary = {}
## Кнопки районов по id района.
var _district_buttons: Dictionary = {}


func _ready() -> void:
	if GameState.session == null:
		GameState.new_game()
	var s := GameState.session
	_build_districts()
	_build_market()
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
	_travel_hint.text = tr("TRAVEL_HINT") % int(s.balance.travel_hours)
	_add_log_entry(GameState.intro)
	_refresh()
	Clock.set_speed(1)


func _process(_delta: float) -> void:
	var minutes := Clock.minutes_of_day()
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]


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


func _build_districts() -> void:
	for district: Dictionary in GameState.session.market.districts:
		var button := Button.new()
		button.text = district.name_key
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void:
			GameState.travel(district.id)
			_refresh())
		_district_bar.add_child(button)
		_district_bar.move_child(button, _travel_hint.get_index())
		_district_buttons[district.id] = button


func _build_market() -> void:
	for header: String in ["COL_GOOD", "COL_RISK", "COL_BUY", "COL_SELL", "COL_OWNED", "", "", "", ""]:
		var label := Label.new()
		label.text = header
		label.modulate = Color(1, 1, 1, 0.55)
		label.add_theme_font_size_override("font_size", 16)
		_market_grid.add_child(label)
	for good: Dictionary in GameState.session.market.goods:
		var id: String = good.id
		var risk := GameState.session.market.risk_level(id)
		var row := {
			"name": _add_label(good.name_key, 190),
			"risk": _add_label(RISK_KEYS[risk], 80),
			"buy": _add_label("", 100),
			"sell": _add_label("", 70),
			"owned": _add_label("", 170),
			"buy_one": _add_button("+1", GameState.buy.bind(id, 1)),
			"buy_max": _add_button("BTN_BUY_MAX", func() -> void: GameState.buy(id, GameState.session.max_affordable(id))),
			"sell_one": _add_button("−1", GameState.sell.bind(id, 1)),
			"sell_all": _add_button("BTN_SELL_ALL", func() -> void: GameState.sell(id, GameState.session.inventory[id])),
		}
		row.risk.add_theme_color_override("font_color", RISK_COLORS[risk])
		row.risk.add_theme_font_size_override("font_size", 15)
		for key: String in ["buy", "sell", "owned"]:
			row[key].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_rows[id] = row


func _add_label(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 19)
	_market_grid.add_child(label)
	return label


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	_market_grid.add_child(button)
	return button


func _refresh() -> void:
	var s := GameState.session
	_day_label.text = tr("HUD_DAY") % s.day
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

	for id: String in _district_buttons:
		var button: Button = _district_buttons[id]
		button.set_pressed_no_signal(id == s.district)
		button.disabled = not s.can_act() and id != s.district
	_market_title.text = tr("MARKET_TITLE") % tr(s.market.get_district(s.district).name_key)
	_refresh_market()

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
	_refresh_check()


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
		row.owned.text = tr("OWNED_AVG") % [owned, _format_money(s.average_cost(id))] if owned > 0 else "—"
		var affordable := can_act and s.max_affordable(id) > 0
		row.buy_one.disabled = not affordable
		row.buy_max.disabled = not affordable
		row.sell_one.disabled = not can_act or owned < 1
		row.sell_all.disabled = not can_act or owned < 1


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
