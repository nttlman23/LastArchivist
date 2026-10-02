class_name ReworkPanel
extends HBoxContainer
## Переработка карты: список карт Кодекса → формы превращения с результатом → подтверждение.
## Используется после боя, в лавке и в гавани. Само превращение делает владелец по сигналу.

signal confirmed(card_index: int, form: CodexOps.Form)

const FORM_ICONS := {
	CodexOps.Form.SPELL: UnitGlyphs.ICON_SPELL,
	CodexOps.Form.UPGRADE: UnitGlyphs.ICON_ABILITY,
	CodexOps.Form.SACRIFICE: UnitGlyphs.ICON_HEAL,
	CodexOps.Form.FUSE: UnitGlyphs.ICON_RETALIATION,
}
const FORM_KEYS := {
	CodexOps.Form.SPELL: "FORM_NAME_SPELL",
	CodexOps.Form.UPGRADE: "FORM_NAME_UPGRADE",
	CodexOps.Form.SACRIFICE: "FORM_NAME_SACRIFICE",
	CodexOps.Form.FUSE: "FORM_NAME_FUSE",
}

var db: DefsDB
var run: RunState
## Доп. проверка владельца (цена, «уже использовано»): (card_index, form) -> ключ причины или "".
var extra_reason: Callable = func(_i: int, _f: CodexOps.Form) -> String: return ""
var selected_card := -1
var forms_box: VBoxContainer
var _confirm_box: HBoxContainer
var _card_buttons: Array[Button] = []


func setup(p_db: DefsDB, p_run: RunState) -> void:
	db = p_db
	run = p_run
	add_theme_constant_override("separation", 24)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for i in run.codex.cards.size():
		var b := Button.new()
		b.text = card_line(db, run, i)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(420, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(select_card.bind(i))
		grid.add_child(b)
		_card_buttons.append(b)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	forms_box = VBoxContainer.new()
	forms_box.add_theme_constant_override("separation", 8)
	right.add_child(forms_box)
	_confirm_box = HBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 12)
	right.add_child(_confirm_box)


static func card_line(p_db: DefsDB, p_run: RunState, i: int) -> String:
	var card := p_run.codex.cards[i]
	var mem := p_db.memory(card.memory_id)
	var text := TranslationServer.translate(mem.name_key)
	if card.level > 1:
		text += " " + TranslationServer.translate("CARD_LEVEL") % card.level
	if not mem.is_unit():
		text += " · " + TranslationServer.translate("CARD_HERO")
	return "%s · %s" % [text, TranslationServer.translate("CARD_DURABILITY") % [card.durability, mem.max_durability]]


func select_card(index: int) -> void:
	selected_card = index
	for i in _card_buttons.size():
		_card_buttons[i].set_pressed_no_signal(i == index)
	_clear(_confirm_box)
	_clear(forms_box)
	for form in CodexOps.ALL_FORMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.icon = IconAtlas.get_icon(FORM_ICONS[form])
		b.add_theme_constant_override("icon_max_width", 22)
		var reason: String = extra_reason.call(index, form)
		if reason == "":
			reason = CodexOps.unavailable_reason(db, run, index, form)
		if reason == "":
			var full := form_preview(db, run, index, form)
			b.text = full if Settings.detailed else "%s: %s" % [tr(FORM_KEYS[form]), form_short(db, run, index, form)]
			var tip_body := full
			if form == CodexOps.Form.SPELL:
				tip_body += "\n" + tr(db.spell(db.memory(run.codex.cards[index].memory_id).spell_id).desc_key)
			Tip.attach(b, tr(FORM_KEYS[form]), tip_body, FORM_ICONS[form])
			b.pressed.connect(_ask_confirm.bind(form))
		else:
			b.text = "%s — %s" % [tr(FORM_KEYS[form]), tr(reason)]
			b.disabled = true
		forms_box.add_child(b)


## Короткий результат для кнопки: «Цепная молния ×2», «+1 к атаке», «+1 → 3 карты», «ур. 2 · 18».
static func form_short(p_db: DefsDB, p_run: RunState, index: int, form: CodexOps.Form) -> String:
	var card := p_run.codex.cards[index]
	var mem := p_db.memory(card.memory_id)
	match form:
		CodexOps.Form.SPELL:
			return "%s ×%d" % [TranslationServer.translate(p_db.spell(mem.spell_id).name_key), CodexOps.spell_charges(card)]
		CodexOps.Form.UPGRADE:
			return TranslationServer.translate(p_db.upgrade(mem.upgrade_id).name_key)
		CodexOps.Form.SACRIFICE:
			return TranslationServer.translate("FORM_SACRIFICE_SHORT") % CodexOps.sacrifice_repairs(p_db, p_run.codex, index)
		CodexOps.Form.FUSE:
			var result := CodexOps.fuse_result(p_run.codex, index)
			return TranslationServer.translate("FORM_FUSE_SHORT") % [result[0], floori(mem.count * (1.0 + 0.5 * (result[0] - 1)))]
	return ""


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


func _ask_confirm(form: CodexOps.Form) -> void:
	_clear(_confirm_box)
	var question := UiKit.label(tr("FORM_CONFIRM") % [tr(db.memory(run.codex.cards[selected_card].memory_id).name_key),
			form_preview(db, run, selected_card, form)], 20, UiKit.ACCENT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(520, 0)
	_confirm_box.add_child(question)
	_confirm_box.add_child(UiKit.button(tr("FORM_APPLY"), _confirm.bind(form), 200))
	_confirm_box.add_child(UiKit.button(tr("REWARD_CANCEL"), _clear.bind(_confirm_box), 160))


func _confirm(form: CodexOps.Form) -> void:
	Audio.play(&"transform")
	confirmed.emit(selected_card, form)


func _clear(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()
