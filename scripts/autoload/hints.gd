extends CanvasLayer
## Пошаговые подсказки (SPEC_SPRINT4 3): короткая плашка при первой встрече с механикой.
## Каждая показывается один раз за профиль; отключаются и сбрасываются в настройках.

const WIDTH := 460.0
## Все подсказки (текст — ключ HINT_<ID>).
const IDS: Array[StringName] = [&"school", &"map", &"battle", &"ability", &"hero", &"targeting", &"rift",
		&"memory", &"faded", &"shop", &"haven", &"event"]

var _panel: PanelContainer
var _text: Label
var _queue: Array[StringName] = []
var _current := &""


func _ready() -> void:
	layer = 90
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.1, 0.12, 0.18, 0.97), UiKit.ACCENT, 2))
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(UiKit.icon_rect(UnitGlyphs.ICON_POINTS, 26, UiKit.ACCENT))
	_text = UiKit.label("", 19)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	row.add_child(_text)
	var ok := UiKit.button(tr("HINT_OK"), _dismiss, 160)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(ok)


func should_show(id: StringName) -> bool:
	return Settings.hints and Game.profile != null and not Game.profile.seen_hints.has(id)


## Показать подсказку id (текст — ключ HINT_<ID>), если она ещё не показывалась.
func show_hint(id: StringName) -> void:
	if not should_show(id) or id == _current or _queue.has(id):
		return
	_queue.append(id)
	if _current == &"":
		_next()


func reset() -> void:
	Game.profile.seen_hints.clear()
	Game.save_profile()


func hide_all() -> void:
	_queue.clear()
	_current = &""
	_panel.visible = false


func _next() -> void:
	if _queue.is_empty():
		_current = &""
		_panel.visible = false
		return
	_current = _queue.pop_front()
	Game.profile.seen_hints.append(_current)
	Game.save_profile()
	_text.text = tr("HINT_" + String(_current).to_upper())
	_panel.reset_size()
	_panel.visible = true
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2((vp.x - _panel.get_combined_minimum_size().x) * 0.5, 120)


func _dismiss() -> void:
	_next()
