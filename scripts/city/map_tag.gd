class_name MapTag
extends PanelContainer
## Подпись над зданием, как метки на карте в референсе: белая скруглённая плашка с мягкой тенью,
## чистый текст без обводки. Рисуется поверх 3D (в слое подписей города) и следует за точкой в мире.
## Цветная точка слева: синяя — твоё, оранжевая — продаётся; выбранный район или наведение — синий текст.

const FONT := preload("res://assets/fonts/inter/Inter-SemiBold.otf")
const COLOR_TEXT := Color(0.106, 0.122, 0.165)
const COLOR_ACCENT := Color(0.184, 0.42, 1.0)

## Точка в мире, над которой висит плашка (низ плашки — на ней).
var world_pos := Vector3.ZERO

var _label := Label.new()
var _dot := Panel.new()


func _init(text: String, at: Vector3, mine: bool = false) -> void:
	world_pos = at
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(9)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.08, 0.12, 0.25, 0.16)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing_size = 0.8
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = COLOR_ACCENT
	dot_style.set_corner_radius_all(4)
	_dot.add_theme_stylebox_override("panel", dot_style)
	_dot.custom_minimum_size = Vector2(8, 8)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = mine
	row.add_child(_dot)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	add_child(row)
	set_text(text)


func set_text(text: String) -> void:
	if _label.text == tr(text):
		return
	_label.text = tr(text)
	reset_size()


## Точка слева: цвет или Color(0, 0, 0, 0) — без точки.
func set_dot(color: Color) -> void:
	_dot.visible = color.a > 0.0
	if _dot.visible:
		(_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color
		reset_size()


## Цвет текста (для всплывающих денег).
func set_text_color(color: Color) -> void:
	_label.add_theme_color_override("font_color", color)


func highlight(on: bool) -> void:
	_label.add_theme_color_override("font_color", COLOR_ACCENT if on else COLOR_TEXT)


## Поставить плашку над точкой мира; за камерой или без текста — спрятать.
func follow(camera: Camera3D) -> void:
	visible = _label.text != "" and not camera.is_position_behind(world_pos)
	if visible:
		# Размер по тексту (шрифт подхватывается только в дереве сцены).
		if size != get_combined_minimum_size():
			reset_size()
		position = (camera.unproject_position(world_pos) - Vector2(size.x / 2.0, size.y + 4.0)).round()
