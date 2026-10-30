extends Control
## Главное меню: новая игра (выбор режима, родного города и прошлого героя), загрузка, выход и смена языка.
## «Настройки» пока показывают подсказку «в разработке».

const SETTINGS_PATH := "user://settings.cfg"
const GAME_SCENE := "res://scenes/game.tscn"
const LANGUAGES: Array[String] = ["ru", "en"]

@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _language_button: Button = %LanguageButton
@onready var _hint_label: Label = %HintLabel
@onready var _version_label: Label = %VersionLabel
@onready var _menu: VBoxContainer = $Center/Menu

## Выбор для новой партии: { "mode", "home", "past" } и описания под рядами кнопок.
var _choice := { "mode": "career", "home": "berlin", "past": "driver" }
var _setup_panel: VBoxContainer
var _setup_notes: Dictionary = {}


func _ready() -> void:
	_load_language()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_new_game_button.pressed.connect(_open_setup)
	_load_game_button.pressed.connect(_continue_game)
	_load_game_button.disabled = not SaveSystem.has_save()
	_settings_button.pressed.connect(_show_coming_soon)
	_quit_button.pressed.connect(get_tree().quit)
	_language_button.pressed.connect(_switch_language)
	_new_game_button.grab_focus()


func _start_new_game() -> void:
	GameState.new_game(_choice.mode, _choice.home, _choice.past)
	get_tree().change_scene_to_file(GAME_SCENE)


## Экран новой игры: три ряда кнопок (режим, родной город, прошлое) с описанием выбранного.
func _open_setup() -> void:
	if _setup_panel == null:
		_build_setup()
	_menu.visible = false
	_setup_panel.visible = true


func _close_setup() -> void:
	_setup_panel.visible = false
	_menu.visible = true
	_new_game_button.grab_focus()


func _build_setup() -> void:
	var balance := GameData.load_balance()
	_setup_panel = VBoxContainer.new()
	_setup_panel.add_theme_constant_override("separation", 10)
	_setup_panel.custom_minimum_size.x = 620
	var title := Label.new()
	title.text = "MENU_NEW_GAME"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.97, 0.97, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_panel.add_child(title)
	var modes := {}
	for id: String in balance.modes:
		modes[id] = [balance.modes[id].name_key, balance.modes[id].desc_key]
	_add_choice_row("mode", "SETUP_MODE", modes)
	var homes := {}
	for id: String in balance.home_cities:
		var info: Dictionary = balance.home_cities[id]
		homes[id] = ["CITY_" + id.to_upper(), tr(info.desc_key) % [_money(int(info.money)), _money(int(info.debt))]]
	_add_choice_row("home", "SETUP_HOME", homes)
	var pasts := {}
	for id: String in balance.backgrounds:
		pasts[id] = [balance.backgrounds[id].name_key, balance.backgrounds[id].desc_key]
	_add_choice_row("past", "SETUP_PAST", pasts)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	var back := Button.new()
	back.text = "SETUP_BACK"
	back.custom_minimum_size = Vector2(180, 52)
	back.pressed.connect(_close_setup)
	buttons.add_child(back)
	var start := Button.new()
	start.text = "SETUP_START"
	start.custom_minimum_size = Vector2(260, 52)
	start.pressed.connect(_start_new_game)
	buttons.add_child(start)
	_setup_panel.add_child(_spacer(8))
	_setup_panel.add_child(buttons)
	$Center.add_child(_setup_panel)


## Ряд выбора: подпись, кнопки-переключатели и описание выбранного. options: { id: [ключ названия, описание] }.
func _add_choice_row(key: String, caption: String, options: Dictionary) -> void:
	_setup_panel.add_child(_spacer(6))
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	label.add_theme_font_size_override("font_size", 14)
	_setup_panel.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 44)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	note.add_theme_font_size_override("font_size", 14)
	_setup_notes[key] = note
	for id: String in options:
		var button := Button.new()
		button.text = options[id][0]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = _choice[key] == id
		button.pressed.connect(func() -> void:
			_choice[key] = id
			note.text = options[id][1])
		row.add_child(button)
	note.text = options[_choice[key]][1]
	_setup_panel.add_child(row)
	_setup_panel.add_child(note)


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _money(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = " " + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result


func _continue_game() -> void:
	if GameState.continue_game():
		get_tree().change_scene_to_file(GAME_SCENE)


func _show_coming_soon() -> void:
	_hint_label.text = "MENU_COMING_SOON"


func _switch_language() -> void:
	var current := TranslationServer.get_locale().substr(0, 2)
	var next := LANGUAGES[(LANGUAGES.find(current) + 1) % LANGUAGES.size()]
	TranslationServer.set_locale(next)
	_save_language(next)


func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		TranslationServer.set_locale(config.get_value("general", "language", "ru"))
	elif not TranslationServer.get_locale().begins_with("en"):
		TranslationServer.set_locale("ru")


func _save_language(language: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("general", "language", language)
	config.save(SETTINGS_PATH)
