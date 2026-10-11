extends CanvasLayer
## Справочник (SPEC_SPRINT11 2): F1 с любого экрана или кнопка в главном меню. Пока открыт — игра
## на паузе (бой, анимации, таймеры); закрытие (F1, Esc, «Закрыть») возвращает туда же без сброса.

const SIDE_WIDTH := 330.0

var _root: Control
var _scroll: ScrollContainer
var _buttons: Array[Button] = []
var _section := 0


func _ready() -> void:
	# Ниже всплывающих подсказок (Tip, слой 100), выше экранов; работает и на паузе.
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _root != null


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Открыть на разделе section (по умолчанию — последний открытый).
func open(section: StringName = &"") -> void:
	if section != &"":
		_section = maxi(0, HelpContent.SECTIONS.find(section))
	if is_open():
		_select(_section)
		return
	get_tree().paused = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.BG_COLOR, UiKit.ACCENT, 2, true))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		panel.set("offset_" + side, 50.0 if side in ["left", "top"] else -50.0)
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	row.add_child(side)
	side.add_child(UiKit.label(TranslationServer.translate("HELP_TITLE"), 36, UiKit.ACCENT))
	_buttons.clear()
	for i in HelpContent.SECTIONS.size():
		var id := HelpContent.SECTIONS[i]
		var b := UiKit.button(HelpContent.title(id), _select.bind(i), SIDE_WIDTH)
		b.toggle_mode = true
		b.icon = IconAtlas.get_icon(HelpContent.SECTION_ICONS[id])
		b.add_theme_constant_override("icon_max_width", 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		side.add_child(b)
		_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var keys := UiKit.label(TranslationServer.translate("HELP_KEYS"), 16, UiKit.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	side.add_child(keys)
	side.add_child(UiKit.button(TranslationServer.translate("HELP_CLOSE"), close, SIDE_WIDTH))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_scroll)
	_select(_section)
	Audio.play(&"ui_click")


func close() -> void:
	if not is_open():
		return
	_root.queue_free()
	_root = null
	_scroll = null
	_buttons.clear()
	get_tree().paused = false
	Audio.play(&"ui_click")


func _select(index: int) -> void:
	_section = index
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == index)
	for child in _scroll.get_children():
		child.queue_free()
	_scroll.add_child(HelpContent.build(HelpContent.SECTIONS[index], Game.defs, Game.profile))
	_scroll.scroll_vertical = 0


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and is_open():
		close()
		get_viewport().set_input_as_handled()
