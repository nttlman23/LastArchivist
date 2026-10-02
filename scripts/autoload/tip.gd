extends CanvasLayer
## Единая всплывающая подсказка (SPEC_SPRINT4 2.1): заголовок со значком и 1–3 строки описания.
## Tip.attach(control, title, body, icon) — показывается через DELAY наведения рядом с курсором.

const DELAY := 0.35
const WIDTH := 360.0
const OFFSET := Vector2(18, 22)

var _panel: PanelContainer
var _icon: TextureRect
var _title: Label
var _body: Label
var _timer: Timer
var _pending: Control


func _ready() -> void:
	layer = 100
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.09, 0.13, 0.97), UiKit.ACCENT.darkened(0.3), 1))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	_title = UiKit.label("", 20, UiKit.ACCENT)
	row.add_child(_title)
	_body = UiKit.label("", 17)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(WIDTH, 0)
	col.add_child(_body)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = DELAY
	_timer.timeout.connect(_show_pending)
	add_child(_timer)


## Подсказка для элемента; повторный вызов заменяет текст. Пустой body и title — подсказки нет.
func attach(control: Control, title: String, body: String = "", icon: StringName = &"", color: Color = Color.WHITE) -> void:
	control.set_meta("tip", [title, body, icon, color])
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if not control.mouse_entered.is_connected(_on_enter):
		control.mouse_entered.connect(_on_enter.bind(control))
		control.mouse_exited.connect(_on_exit.bind(control))
		control.tree_exiting.connect(_on_exit.bind(control))


func hide_tip() -> void:
	_pending = null
	_timer.stop()
	_panel.visible = false


func _on_enter(control: Control) -> void:
	_pending = control
	_timer.start()


func _on_exit(control: Control) -> void:
	if _pending == control or _panel.visible:
		hide_tip()


func _show_pending() -> void:
	if _pending == null or not is_instance_valid(_pending) or not _pending.is_visible_in_tree():
		return
	var data: Array = _pending.get_meta("tip", [])
	if data.is_empty() or (String(data[0]) == "" and String(data[1]) == ""):
		return
	_title.text = data[0]
	_body.text = data[1]
	_body.visible = String(data[1]) != ""
	_icon.visible = data[2] != &""
	_icon.texture = IconAtlas.get_icon(data[2])
	_icon.modulate = data[3]
	_panel.reset_size()
	_panel.visible = true
	_position_panel()


func _process(_delta: float) -> void:
	if _panel.visible:
		_position_panel()


func _position_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + OFFSET
	var sz := _panel.get_combined_minimum_size()
	pos.x = minf(pos.x, vp.x - sz.x - 8)
	if pos.y + sz.y > vp.y - 8:
		pos.y = get_viewport().get_mouse_position().y - sz.y - 12
	_panel.position = pos
