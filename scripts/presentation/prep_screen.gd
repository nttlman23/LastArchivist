extends Control
## Подготовка: выбор до 5 карт отрядов на бой; сводка Архивариуса и геройские карты.

var _selected: Array[int] = []
## Кнопки карт отрядов: индекс в Кодексе -> кнопка.
var _buttons: Dictionary[int, Button] = {}
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
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	box.add_child(UiKit.label(tr("PREP_TITLE") % [run.battle_index + 1, db.encounter_chain.size(), tr(encounter.name_key)], 40, UiKit.ACCENT))
	var enemies: Array[String] = []
	for i in encounter.unit_ids.size():
		enemies.append("%d × %s" % [encounter.counts[i], UiKit.unit_name(db, encounter.unit_ids[i])])
	box.add_child(UiKit.label("%s %s" % [tr("PREP_ENEMIES"), ", ".join(enemies)], 0, UiKit.ENEMY_COLOR))
	box.add_child(_hero_summary(db, run))
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
		var b := UiKit.card_button(db, card.memory_id, card.durability, card.level)
		if db.memory(card.memory_id).is_unit():
			b.toggle_mode = true
			b.toggled.connect(_on_card_toggled.bind(i))
			_buttons[i] = b
		else:
			# Геройская карта действует из Кодекса и в бой не выставляется.
			b.disabled = true
		grid.add_child(b)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_start = UiKit.button(tr("PREP_START"), _on_start)
	buttons.add_child(_start)
	buttons.add_child(UiKit.button(tr("PREP_TO_MENU"), Game.to_main_menu))

	# По умолчанию — первые карты отрядов.
	var units := run.codex.unit_indices(db)
	for i in units.slice(0, BattleState.MAX_STACKS):
		_buttons[i].button_pressed = true
	_refresh()


## Сводка Архивариуса: приказы, улучшения, заклинания с зарядами.
func _hero_summary(db: DefsDB, run: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(UiKit.label(tr("PREP_HERO"), 22, UiKit.ACCENT))

	var orders: Array[String] = []
	for id in run.hero.available_orders(db, run.codex):
		orders.append(tr(db.order(id).name_key))
	col.add_child(UiKit.label(tr("PREP_ORDERS") % ", ".join(orders), 18))

	var counts := {}
	for id in run.hero.active_upgrades(db, run.codex):
		counts[id] = counts.get(id, 0) + 1
	var ups: Array[String] = []
	for id: StringName in counts:
		var text := tr(db.upgrade(id).name_key)
		ups.append(text if counts[id] == 1 else "%s ×%d" % [text, counts[id]])
	col.add_child(UiKit.label(tr("PREP_UPGRADES") % (", ".join(ups) if not ups.is_empty() else tr("PREP_NONE")), 18, UiKit.MUTED))

	var spells: Array[String] = []
	for slot in run.hero.spells:
		spells.append("%s ×%d" % [tr(db.spell(slot.spell_id).name_key), slot.charges])
	col.add_child(UiKit.label(tr("PREP_SPELLS") % (", ".join(spells) if not spells.is_empty() else tr("PREP_NONE")), 18, Color(0.75, 0.6, 1.0)))
	return panel


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
	for i in _buttons:
		_buttons[i].modulate = Color.WHITE if _buttons[i].button_pressed else Color(0.6, 0.6, 0.65)


func _on_start() -> void:
	Game.start_battle(_selected)
