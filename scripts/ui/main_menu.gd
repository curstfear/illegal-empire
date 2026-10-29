extends Control
## Главное меню: новая игра, загрузка, выход и смена языка.
## «Настройки» пока показывают подсказку «в разработке».

const SETTINGS_PATH := "user://settings.cfg"
const GAME_SCENE := "res://scenes/ui/game_screen.tscn"
const LANGUAGES: Array[String] = ["ru", "en"]

@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _language_button: Button = %LanguageButton
@onready var _hint_label: Label = %HintLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_load_language()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_new_game_button.pressed.connect(_start_new_game)
	_load_game_button.pressed.connect(_continue_game)
	_load_game_button.disabled = not SaveSystem.has_save()
	_settings_button.pressed.connect(_show_coming_soon)
	_quit_button.pressed.connect(get_tree().quit)
	_language_button.pressed.connect(_switch_language)
	_new_game_button.grab_focus()


func _start_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


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
