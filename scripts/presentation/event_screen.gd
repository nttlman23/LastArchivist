extends Control
## Событие на острове (SPEC_SPRINT3 5.3): текст, варианты с требованиями, выбор карты, итог.

var db: DefsDB
var run: RunState
var event: EventDef
var _content: VBoxContainer
var _result: EventResolver.Result


func _ready() -> void:
	if Game.run == null or Game.run.pending() == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	event = db.event(run.pending().content)
	UiKit.add_background(self)
	_content = UiKit.centered_column(self, 18)
	_show_options()


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()


func _header() -> void:
	_content.add_child(UiKit.label(tr(event.title_key), 44, UiKit.ACCENT))
	_content.add_child(UiKit.label(UiKit.resources_text(run.resources), 0, UiKit.MUTED))


func _show_options() -> void:
	_clear()
	_header()
	_content.add_child(_text(tr(event.text_key), 22))
	for i in event.options.size():
		var option: EventOptionDef = event.options[i]
		var b := UiKit.button(tr(option.label_key), _on_option.bind(i), 760)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var reason := EventResolver.option_reason(db, run, option)
		if reason != "":
			b.text += "  — " + tr(reason)
			b.disabled = true
		_content.add_child(b)


func _on_option(index: int) -> void:
	var option: EventOptionDef = event.options[index]
	if option.needs_card:
		_pick_card(index)
		return
	_resolve(index, -1)


## Выбор карты отряда для вариантов, которые действуют на одну карту.
func _pick_card(option_index: int) -> void:
	_clear()
	_header()
	_content.add_child(UiKit.label(tr("EVENT_PICK_CARD"), 26, UiKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for i in run.codex.unit_indices(db):
		var card := run.codex.cards[i]
		var b := UiKit.card_button(db, card.memory_id, card.durability, card.level)
		b.pressed.connect(_resolve.bind(option_index, i))
		grid.add_child(b)
	_content.add_child(UiKit.button(tr("REWARD_CANCEL"), _show_options))


func _resolve(option_index: int, card_index: int) -> void:
	_result = EventResolver.apply(db, run, run.pending_node, event, option_index, card_index)
	Audio.play(&"spell" if _result.success else &"impact")
	_clear()
	_header()
	_content.add_child(_text(tr(_result.text_key), 22))
	if not _result.resources.is_empty():
		_content.add_child(UiKit.label(UiKit.resources_text(_result.resources, true), 22, UiKit.ACCENT))
	if not _result.gone.is_empty():
		var names: Array[String] = []
		for id in _result.gone:
			names.append(tr(db.memory(id).name_key))
		_content.add_child(UiKit.label(tr("REWARD_FADED") % ", ".join(names), 0, UiKit.DANGER))
	var label := tr("EVENT_TO_BATTLE") if _result.battle_tier > 0 else tr("BATTLE_CONTINUE")
	_content.add_child(UiKit.button(label, _continue, 360))


func _continue() -> void:
	if _result.battle_tier > 0:
		Game.start_event_battle(_result.battle_tier, _result.battle_reward)
	else:
		Game.complete_node()


func _text(text: String, size: int) -> Label:
	var l := UiKit.label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	return l
