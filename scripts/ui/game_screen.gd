extends Control
## Экран партии (прототип этапа 1): верхняя панель, рынок, ростовщик, журнал.
## Только показывает GameState и передаёт ему нажатия.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const COLOR_UP := Color(0.45, 0.9, 0.55)
const COLOR_DOWN := Color(0.95, 0.4, 0.42)

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _debt_label: Label = %DebtLabel
@onready var _payment_label: Label = %PaymentLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = { 1: %Speed1Button, 2: %Speed2Button, 4: %Speed4Button }
@onready var _market_grid: GridContainer = %MarketGrid
@onready var _debt_hint: Label = %DebtHint
@onready var _pay_due_button: Button = %PayDueButton
@onready var _pay_all_button: Button = %PayAllButton
@onready var _log_text: RichTextLabel = %LogText
@onready var _end_day_button: Button = %EndDayButton
@onready var _save_button: Button = %SaveButton
@onready var _menu_button: Button = %MenuButton
@onready var _end_overlay: ColorRect = %EndOverlay
@onready var _end_title: Label = %EndTitle
@onready var _end_text: Label = %EndText
@onready var _end_menu_button: Button = %EndMenuButton

## Узлы строк рынка по id товара: { "buy": Label, "sell": Label, ... }.
var _rows: Dictionary = {}


func _ready() -> void:
	if GameState.session == null:
		GameState.new_game()
	_build_market()
	_pause_button.pressed.connect(func() -> void: Clock.paused = not Clock.paused)
	for value: int in _speed_buttons:
		_speed_buttons[value].pressed.connect(Clock.set_speed.bind(value))
	_pay_due_button.pressed.connect(func() -> void: GameState.pay(GameState.session.payment_left()))
	_pay_all_button.pressed.connect(func() -> void: GameState.pay(GameState.session.money))
	_end_day_button.pressed.connect(Clock.finish_day)
	_save_button.pressed.connect(_on_save_pressed)
	_menu_button.pressed.connect(_go_to_menu)
	_end_menu_button.pressed.connect(_go_to_menu)
	GameState.changed.connect(_refresh)
	GameState.day_ended.connect(_on_day_ended)
	GameState.finished.connect(_show_end)
	Clock.speed_changed.connect(_refresh_speed_buttons)

	_debt_hint.text = tr("DEBT_HINT") % roundi(GameState.session.balance.weekly_interest * 100)
	_add_log_entry(GameState.intro)
	_refresh()
	Clock.set_speed(1)


func _process(_delta: float) -> void:
	var minutes := Clock.minutes_of_day()
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]


func _unhandled_input(event: InputEvent) -> void:
	if _end_overlay.visible or not event is InputEventKey or not event.pressed or event.echo:
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


func _build_market() -> void:
	for header: String in ["COL_GOOD", "COL_BUY", "COL_SELL", "COL_OWNED", "", "", "", ""]:
		var label := Label.new()
		label.text = header
		label.modulate = Color(1, 1, 1, 0.55)
		_market_grid.add_child(label)
	for good: Dictionary in GameState.session.market.goods:
		var id: String = good.id
		var row := {
			"name": _add_label(good.name_key, 220),
			"buy": _add_label("", 110),
			"sell": _add_label("", 90),
			"owned": _add_label("", 200),
			"buy_one": _add_button("+1", GameState.buy.bind(id, 1)),
			"buy_max": _add_button("BTN_BUY_MAX", func() -> void: GameState.buy(id, GameState.session.max_affordable(id))),
			"sell_one": _add_button("−1", GameState.sell.bind(id, 1)),
			"sell_all": _add_button("BTN_SELL_ALL", func() -> void: GameState.sell(id, GameState.session.inventory[id])),
		}
		row.buy.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.sell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.owned.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_rows[id] = row


func _add_label(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 20)
	_market_grid.add_child(label)
	return label


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	_market_grid.add_child(button)
	return button


func _refresh() -> void:
	var s := GameState.session
	_day_label.text = tr("HUD_DAY") % s.day
	_money_label.text = tr("HUD_MONEY") % _format_money(s.money)
	_debt_label.text = tr("HUD_DEBT") % _format_money(s.debt)
	if s.payment_left() > 0:
		_payment_label.text = tr("HUD_PAYMENT_DUE") % [_format_money(s.payment_left()), s.next_payment_day]
	else:
		_payment_label.text = tr("HUD_PAYMENT_DONE") % s.next_payment_day
	var can_pay := s.money > 0 and s.status == GameSession.Status.PLAYING
	_pay_due_button.disabled = not can_pay or s.payment_left() == 0 or s.money < s.payment_left()
	_pay_all_button.disabled = not can_pay

	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var price := s.market.buy_price(id)
		var before: int = s.market.previous_prices[id]
		row.buy.text = "$%s %s" % [_format_money(price), "▲" if price > before else ("▼" if price < before else "")]
		row.buy.modulate = COLOR_UP if price > before else (COLOR_DOWN if price < before else Color.WHITE)
		row.sell.text = "$%s" % _format_money(s.market.sell_price(id))
		var owned: int = s.inventory[id]
		row.owned.text = tr("OWNED_AVG") % [owned, _format_money(s.average_cost(id))] if owned > 0 else "—"
		row.buy_one.disabled = s.max_affordable(id) < 1
		row.buy_max.disabled = s.max_affordable(id) < 1
		row.sell_one.disabled = owned < 1
		row.sell_all.disabled = owned < 1


func _refresh_speed_buttons() -> void:
	_pause_button.set_pressed_no_signal(Clock.paused)
	for value: int in _speed_buttons:
		_speed_buttons[value].set_pressed_no_signal(not Clock.paused and Clock.speed == value)


func _on_day_ended(report: Array) -> void:
	for entry: Array in report:
		_add_log_entry(entry)


func _on_save_pressed() -> void:
	if GameState.save():
		_add_log(tr("SAVED"))


func _show_end(status: GameSession.Status) -> void:
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


## Запись из логики: [ключ_перевода, аргументы]. Суммы от 1000 пишем с пробелами.
func _add_log_entry(entry: Array) -> void:
	var text := tr(entry[0])
	if not entry[1].is_empty():
		text = text % entry[1].map(func(arg: Variant) -> Variant:
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
