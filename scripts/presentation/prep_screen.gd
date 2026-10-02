extends Control
## Подготовка: выбор до 5 карт Кодекса на бой.

var _selected: Array[int] = []
var _buttons: Array[Button] = []
var _start: Button


func _ready() -> void:
	if Game.run == null:
		Game.to_main_menu()
		return
	var db := Game.defs
	var run := Game.run
	var encounter := db.encounter(run.current_encounter_id(db))

	UiKit.add_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	box.add_child(UiKit.label(tr("PREP_TITLE") % [run.battle_index + 1, db.encounter_chain.size(), tr(encounter.name_key)], 40, UiKit.ACCENT))
	var enemies: Array[String] = []
	for i in encounter.unit_ids.size():
		enemies.append("%d × %s" % [encounter.counts[i], UiKit.unit_name(db, encounter.unit_ids[i])])
	box.add_child(UiKit.label("%s %s" % [tr("PREP_ENEMIES"), ", ".join(enemies)], 0, UiKit.ENEMY_COLOR))
	box.add_child(UiKit.label(tr("PREP_HINT") % BattleState.MAX_STACKS, 0, UiKit.MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for i in run.codex.cards.size():
		var card := run.codex.cards[i]
		var b := UiKit.card_button(db, card.memory_id, card.durability)
		b.toggle_mode = true
		b.toggled.connect(_on_card_toggled.bind(i))
		grid.add_child(b)
		_buttons.append(b)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_start = UiKit.button(tr("PREP_START"), _on_start)
	buttons.add_child(_start)
	buttons.add_child(UiKit.button(tr("PREP_TO_MENU"), Game.to_main_menu))

	# По умолчанию — первые карты, как было на прошлом бою.
	for i in mini(BattleState.MAX_STACKS, _buttons.size()):
		_buttons[i].button_pressed = true
	_refresh()


func _on_card_toggled(pressed: bool, index: int) -> void:
	if pressed:
		if _selected.size() >= BattleState.MAX_STACKS:
			_buttons[index].set_pressed_no_signal(false)
			return
		_selected.append(index)
	else:
		_selected.erase(index)
	_refresh()


func _refresh() -> void:
	_start.disabled = _selected.is_empty()
	for i in _buttons.size():
		_buttons[i].modulate = Color.WHITE if _buttons[i].button_pressed else Color(0.6, 0.6, 0.65)


func _on_start() -> void:
	Game.start_battle(_selected)
