extends Control
## «Память после боя» (SPEC_SPRINT2 6.4, SPEC_SPRINT3 4): полученные ресурсы и одно действие —
## взять новую карту, превратить карту Кодекса или пропустить.

const FORM_KEYS := ReworkPanel.FORM_KEYS

var db: DefsDB
var run: RunState
var _offer: Array[StringName] = []
var _content: VBoxContainer
var _chosen: StringName
var _rework: ReworkPanel


func _ready() -> void:
	if Game.run == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	_offer = run.roll_rewards(db, Game.reward_guarantees_hero())
	Hints.show_hint(&"memory")
	if not Game.last_faded.is_empty():
		Hints.show_hint(&"faded")
	UiKit.add_background(self)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	margin.add_child(_content)
	_show_main()


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()
	_rework = null


func _show_main() -> void:
	_clear()
	_content.add_child(UiKit.label(tr("MEMORY_TITLE"), 40, UiKit.ACCENT))
	if not Game.last_rewards.is_empty():
		var got := HBoxContainer.new()
		got.add_theme_constant_override("separation", 12)
		got.add_child(UiKit.label(tr("MEMORY_RESOURCES_SHORT"), 0, UiKit.MUTED))
		got.add_child(UiKit.resource_row(Game.last_rewards, true))
		_content.add_child(got)
	if Game.last_faded.is_empty():
		_content.add_child(UiKit.label(tr("REWARD_NONE_FADED"), 0, UiKit.MUTED))
	else:
		var names: Array[String] = []
		for id in Game.last_faded:
			names.append(tr(db.memory(id).name_key))
		_content.add_child(UiKit.label(tr("REWARD_FADED") % ", ".join(names), 0, UiKit.DANGER))
	if Settings.detailed:
		_content.add_child(UiKit.label(tr("MEMORY_ONE_ACTION"), 0, UiKit.MUTED))

	# Секция 1: новое воспоминание.
	_content.add_child(UiKit.label(tr("MEMORY_NEW"), 28, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	for id in _offer:
		# Карта и под ней — почему её стоит взять (роль, какую дыру Кодекса закрывает).
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var b := UiKit.card_button(db, id)
		b.pressed.connect(_on_pick.bind(id))
		col.add_child(b)
		col.add_child(UiKit.advice_row(db, run.codex, id))
		row.add_child(col)

	# Секция 2: переработка карты Кодекса.
	_content.add_child(UiKit.label(tr("MEMORY_REWORK"), 28, UiKit.ACCENT))
	if Settings.detailed:
		_content.add_child(UiKit.label(tr("MEMORY_REWORK_HINT"), 0, UiKit.MUTED))
	_rework = ReworkPanel.new()
	_rework.setup(db, run)
	_rework.confirmed.connect(_apply)
	_content.add_child(_rework)

	var skip := UiKit.button(tr("REWARD_SKIP"), Game.complete_node)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(skip)


## Для тестов и автопрогона.
var _forms_box: HFlowContainer:
	get:
		return _rework.forms_box


func _on_select_card(index: int) -> void:
	_rework.select_card(index)


func _apply_form(form: CodexOps.Form) -> void:
	_apply(_rework.selected_card, form)


func _apply(card_index: int, form: CodexOps.Form) -> void:
	CodexOps.apply(db, run, card_index, form)
	Game.complete_node()


# --- Новая карта ---------------------------------------------------------------

func _on_pick(id: StringName) -> void:
	if not run.codex.is_full():
		run.codex.add(db, id)
		Game.complete_node()
		return
	_chosen = id
	_show_discard()


func _show_discard() -> void:
	_clear()
	_content.add_child(UiKit.label(tr("REWARD_DISCARD") % CodexState.MAX_CARDS, 32, UiKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for i in run.codex.cards.size():
		var card := run.codex.cards[i]
		var b := UiKit.card_button(db, card.memory_id, card.durability, card.level)
		b.pressed.connect(_on_discard.bind(i))
		grid.add_child(b)
	var cancel := UiKit.button(tr("REWARD_CANCEL"), _show_main)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(cancel)


func _on_discard(index: int) -> void:
	run.codex.remove_at(index)
	run.codex.add(db, _chosen)
	Game.complete_node()
