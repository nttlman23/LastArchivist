extends Control
## Подготовка: выбор до 5 карт отрядов на бой; сводка Архивариуса и геройские карты.

var _selected: Array[int] = []
## Кнопки карт отрядов: индекс в Кодексе -> кнопка.
var _buttons: Dictionary[int, Button] = {}
var _start: Button
var _hero_cards: Array[Control] = []


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

	var title: String
	if encounter.boss:
		title = tr("PREP_TITLE_RIFT") % tr(encounter.name_key)
	elif encounter.elite:
		title = tr("PREP_TITLE_ELITE") % tr(encounter.name_key)
	else:
		title = tr("PREP_TITLE_BATTLE") % [encounter.tier, tr(encounter.name_key)]
	box.add_child(UiKit.label(title, 40, UiKit.DANGER if encounter.boss else UiKit.ACCENT))
	if encounter.boss:
		box.add_child(UiKit.label(tr("PREP_RIFT_WARNING" if encounter.act == 1 else "PREP_ABYSS_WARNING"), 0, UiKit.DANGER))
	var enemies: Array[String] = []
	for i in encounter.unit_ids.size():
		enemies.append("%d × %s" % [Difficulty.enemy_count(run.difficulty, encounter.counts[i]), UiKit.unit_name(db, encounter.unit_ids[i])])
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 20)
	enemy_row.add_child(UiKit.label("%s %s" % [tr("PREP_ENEMIES"), ", ".join(enemies)], 0, UiKit.ENEMY_COLOR))
	enemy_row.add_child(UiKit.risk_chip(db, run.codex, encounter, run.difficulty))
	box.add_child(enemy_row)
	# Цель боя и командир врага (SPEC_SPRINT5 10–11).
	var objective := BattleSetup.objective_of(run, encounter)
	var commander := Difficulty.commander_for(db, run, encounter)
	if objective != ObjectiveRule.ELIMINATE or commander != &"":
		var goal_row := HBoxContainer.new()
		goal_row.add_theme_constant_override("separation", 20)
		goal_row.add_child(UiKit.label(tr("PREP_OBJECTIVE"), 0, UiKit.MUTED))
		goal_row.add_child(UiKit.objective_chip(objective, encounter.objective_rounds + Difficulty.objective_extra(run.difficulty), "", 20))
		if commander != &"":
			goal_row.add_child(UiKit.commander_chip(db, commander, 20))
		box.add_child(goal_row)
	box.add_child(UiKit.hero_summary(db, run))
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 24)
	hint_row.add_child(UiKit.label(tr("PREP_HINT") % BattleState.MAX_STACKS, 0, UiKit.MUTED))
	var only_units := CheckButton.new()
	only_units.text = tr("PREP_ONLY_UNITS")
	only_units.focus_mode = Control.FOCUS_NONE
	only_units.toggled.connect(_on_only_units)
	Tip.attach(only_units, tr("PREP_ONLY_UNITS"), tr("PREP_ONLY_UNITS_TIP"))
	hint_row.add_child(only_units)
	box.add_child(hint_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	# Карты по ролям (ближний бой, стрелки, поддержка, летуны, Архивариус), внутри — по силе.
	var order: Array[int] = []
	for i in run.codex.cards.size():
		order.append(i)
	var key := func(i: int) -> float:
		var card := run.codex.cards[i]
		return CardAdvisor.role(db, card.memory_id) * 100000.0 - CardAdvisor.card_power(db, card.memory_id, card.level)
	order.sort_custom(func(a: int, b: int) -> bool: return key.call(a) < key.call(b))
	for i in order:
		var card := run.codex.cards[i]
		var b := UiKit.card_button(db, card.memory_id, card.durability, card.level)
		if db.memory(card.memory_id).is_unit():
			b.toggle_mode = true
			b.toggled.connect(_on_card_toggled.bind(i))
			_buttons[i] = b
		else:
			# Геройская карта действует из Кодекса и в бой не выставляется.
			b.disabled = true
			_hero_cards.append(b)
		grid.add_child(b)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_start = UiKit.button(tr("PREP_START"), _on_start)
	buttons.add_child(_start)
	buttons.add_child(UiKit.button(tr("PREP_TO_MAP"), Game.abandon_node))

	# По умолчанию — сильнейшие карты отрядов (в порядке Кодекса).
	var units := run.codex.unit_indices(db)
	units.sort_custom(func(a: int, b: int) -> bool:
		return CardAdvisor.card_power(db, run.codex.cards[a].memory_id, run.codex.cards[a].level) \
				> CardAdvisor.card_power(db, run.codex.cards[b].memory_id, run.codex.cards[b].level))
	var best := units.slice(0, BattleState.MAX_STACKS)
	best.sort()
	for i in best:
		_buttons[i].button_pressed = true
	_refresh()


func _on_only_units(on: bool) -> void:
	for b in _hero_cards:
		b.visible = not on


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
