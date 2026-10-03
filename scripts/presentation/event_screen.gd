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
	Hints.show_hint(&"event")
	UiKit.add_background(self)
	_content = UiKit.centered_column(self, 18)
	_show_options()


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()


func _header() -> void:
	_content.add_child(UiKit.label(tr(event.title_key), 44, UiKit.ACCENT))
	_content.add_child(UiKit.resource_row(run.resources))


func _show_options() -> void:
	_clear()
	_header()
	_content.add_child(_text(tr(event.text_key), 22))
	for i in event.options.size():
		var option: EventOptionDef = event.options[i]
		var full := tr(option.label_key)
		# Коротко: только действие, без пояснения в скобках — его заменяют чипы эффектов.
		var short := full.get_slice(" (", 0) if not Settings.detailed else full
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var b := UiKit.button(short, _on_option.bind(i), 420)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Tip.attach(b, short, full)
		var reason := EventResolver.option_reason(db, run, option)
		if reason != "":
			b.text += "  — " + tr(reason)
			b.disabled = true
		row.add_child(b)
		if not Settings.detailed:
			for c in option_chips(option):
				row.add_child(UiKit.chip(c[0], c[1], c[2], c[3], "", 20))
		_content.add_child(row)


## Чипы эффектов варианта: [значок, текст, цвет, подсказка].
static func option_chips(option: EventOptionDef) -> Array:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var chips: Array = []
	if option.chance < 1.0:
		chips.append([UnitGlyphs.ICON_MARK, "%d%%" % roundi(option.chance * 100), UiKit.ACCENT, t.call("EVENT_CHIP_CHANCE")])
	for e: EventEffect in option.effects:
		match e.kind:
			EventEffect.Kind.RESOURCE:
				chips.append([UiKit.RESOURCE_ICONS[e.resource], "%+d" % e.amount, UiKit.RESOURCE_COLORS[e.resource], t.call("RES_" + String(e.resource).to_upper())])
			EventEffect.Kind.DURABILITY_CHOSEN, EventEffect.Kind.DURABILITY_RANDOM, EventEffect.Kind.DURABILITY_STRONGEST:
				var text := "%+d" % e.amount
				if e.kind == EventEffect.Kind.DURABILITY_RANDOM:
					text += " ×%d" % e.count
				chips.append([UnitGlyphs.ICON_HEAL, text, UiKit.ACCENT if e.amount > 0 else UiKit.DANGER, t.call("EVENT_CHIP_DURABILITY")])
			EventEffect.Kind.ADD_CARD:
				chips.append([UnitGlyphs.ICON_ABILITY, "+%d" % e.count, UiKit.ACCENT, t.call("EVENT_CHIP_ADD_CARD")])
			EventEffect.Kind.REMOVE_CHOSEN:
				chips.append([UnitGlyphs.ICON_ABILITY, "−1", UiKit.DANGER, t.call("EVENT_CHIP_REMOVE_CARD")])
			EventEffect.Kind.SPELL_CHARGES_ALL:
				chips.append([UnitGlyphs.ICON_SPELL, "%+d" % e.amount, UiKit.ACCENT, t.call("EVENT_CHIP_CHARGES")])
			EventEffect.Kind.UPGRADE_RANDOM:
				chips.append([UnitGlyphs.ICON_ABILITY, "", UiKit.ACCENT, t.call("EVENT_CHIP_UPGRADE")])
			EventEffect.Kind.RELIC:
				chips.append([UnitGlyphs.ICON_CHALICE, "", Color(0.85, 0.7, 0.4), TranslationServer.translate("EFFECT_RELIC")])
			EventEffect.Kind.SCOUT_NEXT:
				chips.append([UnitGlyphs.ICON_MOVE, "+%d" % e.count, UiKit.ACCENT, t.call("EVENT_CHIP_SCOUT")])
			EventEffect.Kind.BATTLE:
				chips.append([UnitGlyphs.ICON_MELEE, t.call("EVENT_CHIP_BATTLE") % e.tier, UiKit.DANGER, t.call("EVENT_CHIP_BATTLE") % e.tier])
	return chips


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
		_content.add_child(UiKit.resource_row(_result.resources, true, 22))
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
