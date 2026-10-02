extends Control
## Награда после победы: угасшие карты, выбор 1 из 3, сброс при полном Кодексе.

var _offer: Array[StringName] = []
var _content: VBoxContainer
var _chosen: StringName


func _ready() -> void:
	if Game.run == null:
		Game.to_main_menu()
		return
	_offer = Game.run.roll_rewards(Game.defs)
	UiKit.add_background(self)
	_content = UiKit.centered_column(self, 24)
	_show_offer()


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()


func _show_offer() -> void:
	_clear()
	var db := Game.defs
	_content.add_child(_centered(UiKit.label(tr("REWARD_TITLE"), 44, UiKit.ACCENT)))
	if Game.last_faded.is_empty():
		_content.add_child(_centered(UiKit.label(tr("REWARD_NONE_FADED"), 0, UiKit.MUTED)))
	else:
		var names: Array[String] = []
		for id in Game.last_faded:
			names.append(tr(db.memory(id).name_key))
		_content.add_child(_centered(UiKit.label(tr("REWARD_FADED") % ", ".join(names), 0, UiKit.DANGER)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	for id in _offer:
		var b := UiKit.card_button(db, id)
		b.pressed.connect(_on_pick.bind(id))
		row.add_child(b)

	var skip := UiKit.button(tr("REWARD_SKIP"), Game.complete_reward)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(skip)


func _on_pick(id: StringName) -> void:
	var codex := Game.run.codex
	if not codex.is_full():
		codex.add(Game.defs, id)
		Game.complete_reward()
		return
	_chosen = id
	_show_discard()


func _show_discard() -> void:
	_clear()
	var codex := Game.run.codex
	_content.add_child(_centered(UiKit.label(tr("REWARD_DISCARD") % CodexState.MAX_CARDS, 32, UiKit.ACCENT)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for i in codex.cards.size():
		var card := codex.cards[i]
		var b := UiKit.card_button(Game.defs, card.memory_id, card.durability)
		b.pressed.connect(_on_discard.bind(i))
		grid.add_child(b)
	var cancel := UiKit.button(tr("REWARD_CANCEL"), _show_offer)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(cancel)


func _on_discard(index: int) -> void:
	var codex := Game.run.codex
	codex.remove_at(index)
	codex.add(Game.defs, _chosen)
	Game.complete_reward()


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
