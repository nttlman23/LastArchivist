extends Control
## «Память после боя» (SPEC_SPRINT2 6.4): одно действие — взять новую карту,
## превратить карту Кодекса (заклинание / улучшение / жертва / слияние) или пропустить.

const FORM_KEYS := {
	CodexOps.Form.SPELL: "FORM_NAME_SPELL",
	CodexOps.Form.UPGRADE: "FORM_NAME_UPGRADE",
	CodexOps.Form.SACRIFICE: "FORM_NAME_SACRIFICE",
	CodexOps.Form.FUSE: "FORM_NAME_FUSE",
}

var db: DefsDB
var run: RunState
var _offer: Array[StringName] = []
var _content: VBoxContainer
var _chosen: StringName
var _selected_card := -1
var _forms_box: VBoxContainer
var _confirm_box: HBoxContainer
var _card_buttons: Array[Button] = []


func _ready() -> void:
	if Game.run == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	_offer = run.roll_rewards(db)
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
	_card_buttons.clear()
	_selected_card = -1


func _show_main() -> void:
	_clear()
	_content.add_child(UiKit.label(tr("MEMORY_TITLE"), 40, UiKit.ACCENT))
	if Game.last_faded.is_empty():
		_content.add_child(UiKit.label(tr("REWARD_NONE_FADED"), 0, UiKit.MUTED))
	else:
		var names: Array[String] = []
		for id in Game.last_faded:
			names.append(tr(db.memory(id).name_key))
		_content.add_child(UiKit.label(tr("REWARD_FADED") % ", ".join(names), 0, UiKit.DANGER))
	_content.add_child(UiKit.label(tr("MEMORY_ONE_ACTION"), 0, UiKit.MUTED))

	# Секция 1: новое воспоминание.
	_content.add_child(UiKit.label(tr("MEMORY_NEW"), 28, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	for id in _offer:
		var b := UiKit.card_button(db, id)
		b.pressed.connect(_on_pick.bind(id))
		row.add_child(b)

	# Секция 2: переработка карты Кодекса.
	_content.add_child(UiKit.label(tr("MEMORY_REWORK"), 28, UiKit.ACCENT))
	_content.add_child(UiKit.label(tr("MEMORY_REWORK_HINT"), 0, UiKit.MUTED))
	var rework := HBoxContainer.new()
	rework.add_theme_constant_override("separation", 24)
	_content.add_child(rework)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	rework.add_child(grid)
	for i in run.codex.cards.size():
		var b := Button.new()
		b.text = _card_line(i)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(420, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_select_card.bind(i))
		grid.add_child(b)
		_card_buttons.append(b)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rework.add_child(right)
	_forms_box = VBoxContainer.new()
	_forms_box.add_theme_constant_override("separation", 8)
	right.add_child(_forms_box)
	_confirm_box = HBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 12)
	right.add_child(_confirm_box)

	var skip := UiKit.button(tr("REWARD_SKIP"), Game.complete_reward)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(skip)


func _card_line(i: int) -> String:
	var card := run.codex.cards[i]
	var mem := db.memory(card.memory_id)
	var text := tr(mem.name_key)
	if card.level > 1:
		text += " " + tr("CARD_LEVEL") % card.level
	if not mem.is_unit():
		text += " · " + tr("CARD_HERO")
	return "%s · %s" % [text, tr("CARD_DURABILITY") % [card.durability, mem.max_durability]]


# --- Переработка ----------------------------------------------------------------

func _on_select_card(index: int) -> void:
	_selected_card = index
	for i in _card_buttons.size():
		_card_buttons[i].set_pressed_no_signal(i == index)
	_clear_box(_confirm_box)
	_clear_box(_forms_box)
	for form in CodexOps.ALL_FORMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var reason := CodexOps.unavailable_reason(db, run, index, form)
		if reason == "":
			b.text = form_preview(db, run, index, form)
			b.tooltip_text = _form_tooltip(index, form)
			b.pressed.connect(_on_form.bind(form))
		else:
			b.text = "%s — %s" % [tr(FORM_KEYS[form]), tr(reason)]
			b.disabled = true
		_forms_box.add_child(b)


## Текст результата превращения — то, что игрок увидит до подтверждения.
static func form_preview(p_db: DefsDB, p_run: RunState, index: int, form: CodexOps.Form) -> String:
	var card := p_run.codex.cards[index]
	var mem := p_db.memory(card.memory_id)
	match form:
		CodexOps.Form.SPELL:
			return TranslationServer.translate("FORM_SPELL") % [TranslationServer.translate(p_db.spell(mem.spell_id).name_key), CodexOps.spell_charges(card)]
		CodexOps.Form.UPGRADE:
			return TranslationServer.translate("FORM_UPGRADE") % TranslationServer.translate(p_db.upgrade(mem.upgrade_id).name_key)
		CodexOps.Form.SACRIFICE:
			return TranslationServer.translate("FORM_SACRIFICE") % CodexOps.sacrifice_repairs(p_db, p_run.codex, index)
		CodexOps.Form.FUSE:
			var result := CodexOps.fuse_result(p_run.codex, index)
			var count := floori(mem.count * (1.0 + 0.5 * (result[0] - 1)))
			return TranslationServer.translate("FORM_FUSE") % [result[0], count, result[1]]
	return ""


func _form_tooltip(index: int, form: CodexOps.Form) -> String:
	var mem := db.memory(run.codex.cards[index].memory_id)
	if form == CodexOps.Form.SPELL:
		return tr(db.spell(mem.spell_id).desc_key)
	return ""


func _on_form(form: CodexOps.Form) -> void:
	_clear_box(_confirm_box)
	var question := UiKit.label(tr("FORM_CONFIRM") % [tr(db.memory(run.codex.cards[_selected_card].memory_id).name_key),
			form_preview(db, run, _selected_card, form)], 20, UiKit.ACCENT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(520, 0)
	_confirm_box.add_child(question)
	_confirm_box.add_child(UiKit.button(tr("FORM_APPLY"), _apply_form.bind(form), 200))
	_confirm_box.add_child(UiKit.button(tr("REWARD_CANCEL"), _clear_box.bind(_confirm_box), 160))


func _apply_form(form: CodexOps.Form) -> void:
	Audio.play(&"transform")
	CodexOps.apply(db, run, _selected_card, form)
	Game.complete_reward()


func _clear_box(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()


# --- Новая карта ---------------------------------------------------------------

func _on_pick(id: StringName) -> void:
	if not run.codex.is_full():
		run.codex.add(db, id)
		Game.complete_reward()
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
	Game.complete_reward()
