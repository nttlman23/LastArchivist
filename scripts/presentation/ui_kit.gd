class_name UiKit
extends RefCounted
## Общие элементы интерфейса-плейсхолдера.

const BG_COLOR := Color(0.07, 0.08, 0.11)
const PANEL_COLOR := Color(0.12, 0.13, 0.18)
const ACCENT := Color(0.95, 0.8, 0.4)
const ACTIVE_BORDER := Color(1.0, 0.85, 0.3)
const PLAYER_COLOR := Color(0.35, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const MUTED := Color(0.65, 0.67, 0.72)
const DANGER := Color(1.0, 0.45, 0.4)


static func add_background(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


static func label(text: String, size: int = 0, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_pressed: Callable, min_width: int = 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.pressed.connect(Audio.play.bind(&"ui_click"))
	b.pressed.connect(on_pressed)
	return b


static func panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


static func centered_column(parent: Control, separation: int = 16) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


## «Чернила 2 · Пергамент 3 · Эфир 1»; signed — с плюсом («+2»), нули пропускаются.
static func resources_text(res: Dictionary, signed: bool = false) -> String:
	var parts: Array[String] = []
	for id in RunState.RESOURCE_IDS:
		var v: int = res.get(id, 0)
		if signed and v == 0:
			continue
		var num := ("%+d" % v) if signed else str(v)
		parts.append("%s %s" % [TranslationServer.translate("RES_" + String(id).to_upper()), num])
	return " · ".join(parts)


static func unit_name(db: DefsDB, def_id: StringName) -> String:
	return TranslationServer.translate(db.unit(def_id).name_key)


## Короткая подпись стека: первые буквы слов названия («Пепельный Гуль» -> «ПГ»).
static func unit_abbr(db: DefsDB, def_id: StringName) -> String:
	var words := unit_name(db, def_id).replace("-", " ").split(" ", false)
	var abbr := ""
	for i in mini(2, words.size()):
		abbr += words[i].left(1).to_upper()
	return abbr


static func unit_stats(def: UnitDef) -> String:
	var text := TranslationServer.translate("CARD_STATS") % [def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative]
	var tags: Array[String] = []
	if def.is_ranged:
		tags.append(TranslationServer.translate("TAG_RANGED") % def.shots)
	if def.is_flying:
		tags.append(TranslationServer.translate("TAG_FLYING"))
	if not tags.is_empty():
		text += "\n" + ", ".join(tags)
	return text


const HERO_CARD_COLOR := Color(0.95, 0.75, 0.3)


## Карта-воспоминание в виде кнопки. durability < 0 — показывать максимальную.
static func card_button(db: DefsDB, memory_id: StringName, durability: int = -1, level: int = 1) -> Button:
	var mem := db.memory(memory_id)
	var dur := mem.max_durability if durability < 0 else durability

	var detailed := Settings.detailed
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 235 if detailed else 168)
	var normal := panel_style(PANEL_COLOR, Color(0.25, 0.27, 0.33), 2)
	var hover := panel_style(PANEL_COLOR.lightened(0.08), Color(0.45, 0.48, 0.55), 2)
	var pressed := panel_style(PANEL_COLOR.lightened(0.05), ACCENT, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	b.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var strip := ColorRect.new()
	strip.color = db.unit(mem.unit_id).color if mem.is_unit() else HERO_CARD_COLOR
	strip.custom_minimum_size = Vector2(10, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := TranslationServer.translate(mem.name_key)
	if level > 1:
		title += "  " + TranslationServer.translate("CARD_LEVEL") % level
	col.add_child(label(title, 24, ACCENT))
	var dur_color := DANGER if dur <= 1 else MUTED
	if mem.is_unit() and not detailed:
		# Коротко: численность, прочность точками, способность чипом, характеристики значками.
		var def := db.unit(mem.unit_id)
		var count := floori(mem.count * (1.0 + 0.5 * (level - 1)))
		col.add_child(label("%d × %s" % [count, TranslationServer.translate(def.name_key)], 19))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(pips(dur, mem.max_durability))
		if durability >= 0 and dur <= 1:
			line.add_child(chip(UnitGlyphs.ICON_KILL, "", DANGER, TranslationServer.translate("CARD_WORN"), TranslationServer.translate("CARD_WORN_TIP"), 16))
		if def.ability_id != &"":
			var ab := db.ability(def.ability_id)
			line.add_child(chip(UnitGlyphs.ICON_ABILITY, TranslationServer.translate(ab.name_key), ACCENT,
					TranslationServer.translate(ab.name_key), TranslationServer.translate(ab.desc_key), 16))
		if def.is_ranged:
			line.add_child(chip(UnitGlyphs.ICON_RANGED, str(def.shots), STAT_COLOR, TranslationServer.translate("CHIP_RANGED"),
					TranslationServer.translate("ABILITY_RANGED") % def.shots, 16))
		if def.is_flying:
			line.add_child(chip(UnitGlyphs.ICON_FLYING, "", STAT_COLOR, TranslationServer.translate("CHIP_FLYING"), TranslationServer.translate("ABILITY_FLYING"), 16))
		col.add_child(line)
		col.add_child(def_stat_row(def))
	elif not mem.is_unit() and not detailed:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		line.add_child(label(TranslationServer.translate("CARD_HERO"), 0, HERO_CARD_COLOR))
		line.add_child(pips(dur, mem.max_durability))
		if durability >= 0 and dur <= 1:
			line.add_child(chip(UnitGlyphs.ICON_KILL, "", DANGER, TranslationServer.translate("CARD_WORN"), TranslationServer.translate("CARD_WORN_TIP"), 16))
		col.add_child(line)
		var desc := label(TranslationServer.translate("MEM_LAST_KING_SHORT") if mem.id == &"last_king" else "", 16, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
	elif mem.is_unit():
		var def := db.unit(mem.unit_id)
		var count := floori(mem.count * (1.0 + 0.5 * (level - 1)))
		col.add_child(label("%d × %s" % [count, TranslationServer.translate(def.name_key)]))
		col.add_child(label(TranslationServer.translate("CARD_DURABILITY") % [dur, mem.max_durability], 0, dur_color))
		var stats := label(unit_stats(def), 16, MUTED)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(stats)
		if def.ability_id != &"":
			var ab := label(TranslationServer.translate("CARD_ABILITY") % TranslationServer.translate(db.ability(def.ability_id).name_key), 16, ACCENT)
			col.add_child(ab)
	else:
		col.add_child(label(TranslationServer.translate("CARD_HERO"), 0, HERO_CARD_COLOR))
		col.add_child(label(TranslationServer.translate("CARD_DURABILITY") % [dur, mem.max_durability], 0, dur_color))
		var desc := label(TranslationServer.translate(mem.desc_key), 16, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
	Tip.attach(b, TranslationServer.translate(mem.name_key), _card_tooltip(db, mem), UnitGlyphs.ICON_ABILITY if mem.is_unit() else UnitGlyphs.ICON_ORDER)
	b.pressed.connect(Audio.play.bind(&"card"))
	return b


## Подсказка карты: способность существа или описание геройской карты.
static func _card_tooltip(db: DefsDB, mem: MemoryCardDef) -> String:
	if not mem.is_unit():
		return TranslationServer.translate(mem.desc_key)
	var def := db.unit(mem.unit_id)
	if def.ability_id == &"":
		return ""
	var ab := db.ability(def.ability_id)
	return "%s: %s" % [TranslationServer.translate(ab.name_key), TranslationServer.translate(ab.desc_key)]


## Сводка Архивариуса: приказы, улучшения, заклинания с зарядами.
static func hero_summary(db: DefsDB, run: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(PANEL_COLOR))
	var col := VBoxContainer.new()
	panel.add_child(col)
	var school := db.school(run.school_id)
	col.add_child(label("%s · %s" % [TranslationServer.translate("PREP_HERO"), TranslationServer.translate(school.name_key)], 22, ACCENT))
	if not Settings.detailed:
		col.add_child(_hero_chips(db, run, school))
		return panel

	var orders: Array[String] = []
	for id in run.hero.available_orders(db, run.codex):
		orders.append(TranslationServer.translate(db.order(id).name_key))
	col.add_child(label(TranslationServer.translate("PREP_ORDERS") % ", ".join(orders), 18))

	var counts := {}
	for id in run.hero.active_upgrades(db, run.codex):
		counts[id] = counts.get(id, 0) + 1
	var ups: Array[String] = []
	for id: StringName in counts:
		var text := TranslationServer.translate(db.upgrade(id).name_key)
		ups.append(text if counts[id] == 1 else "%s ×%d" % [text, counts[id]])
	col.add_child(label(TranslationServer.translate("PREP_UPGRADES") % (", ".join(ups) if not ups.is_empty() else TranslationServer.translate("PREP_NONE")), 18, MUTED))

	var spells: Array[String] = []
	for slot in run.hero.spells:
		spells.append("%s ×%d" % [TranslationServer.translate(db.spell(slot.spell_id).name_key), slot.charges])
	col.add_child(label(TranslationServer.translate("PREP_SPELLS") % (", ".join(spells) if not spells.is_empty() else TranslationServer.translate("PREP_NONE")), 18, Color(0.75, 0.6, 1.0)))
	return panel


## Сводка героя чипами: пассивка школы, приказы, улучшения, заклинания; описания — по наведению.
static func _hero_chips(db: DefsDB, run: RunState, school: SchoolDef) -> HFlowContainer:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var f := flow(14)
	f.add_child(chip(UnitGlyphs.ICON_POINTS, t.call("PASSIVE_" + String(school.passive_id).to_upper()), school.color.lightened(0.2),
			t.call(school.name_key), t.call(school.desc_key)))
	for id in run.hero.available_orders(db, run.codex):
		var o := db.order(id)
		f.add_child(chip(UnitGlyphs.ICON_ORDER, t.call(o.name_key), STAT_COLOR, t.call(o.name_key), t.call(o.desc_key)))
	var counts := {}
	for id in run.hero.active_upgrades(db, run.codex):
		counts[id] = counts.get(id, 0) + 1
	for id: StringName in counts:
		var text: String = t.call(db.upgrade(id).name_key)
		f.add_child(chip(UnitGlyphs.ICON_ABILITY, text if counts[id] == 1 else "%s ×%d" % [text, counts[id]], ACCENT, text, ""))
	for slot in run.hero.spells:
		var sp := db.spell(slot.spell_id)
		f.add_child(chip(UnitGlyphs.ICON_SPELL, "%s ×%d" % [t.call(sp.name_key), slot.charges], Color(0.75, 0.6, 1.0), t.call(sp.name_key), t.call(sp.desc_key)))
	return f


# --- Значки и чипы (SPEC_SPRINT4 2) ------------------------------------------------

const RESOURCE_ICONS := {
	RunState.INK: UnitGlyphs.ICON_INK,
	RunState.PARCHMENT: UnitGlyphs.ICON_PARCHMENT,
	RunState.AETHER: UnitGlyphs.ICON_AETHER,
}
const RESOURCE_COLORS := {
	RunState.INK: Color(0.55, 0.7, 1.0),
	RunState.PARCHMENT: Color(0.95, 0.85, 0.6),
	RunState.AETHER: Color(0.8, 0.6, 1.0),
}
const STAT_COLOR := Color(0.85, 0.87, 0.92)


static func icon_rect(icon: StringName, size: float, color: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = IconAtlas.get_icon(icon)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## «Значок + текст»; подробности — в подсказке по наведению.
static func chip(icon: StringName, text: String, color: Color = STAT_COLOR, tip_title: String = "", tip_body: String = "", size: int = 18) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(icon_rect(icon, size + 2, color))
	if text != "":
		var l := label(text, size, color)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(l)
	if tip_title != "" or tip_body != "":
		Tip.attach(box, tip_title, tip_body, icon, color)
	return box


## Почему стоит взять карту: роль, закрытая дыра Кодекса, слияние; сравнение с похожей картой — в подсказке роли.
static func advice_row(db: DefsDB, codex: CodexState, memory_id: StringName) -> HFlowContainer:
	var row := flow(12)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var reasons := CardAdvisor.reasons(db, codex, memory_id)
	for i in reasons.size():
		var r: Array = reasons[i]
		var tip: String = t.call(r[2])
		if i == 0:
			tip += _compare_tip(db, codex, memory_id)
		row.add_child(chip(r[0], r[1], ACCENT if i > 0 else STAT_COLOR, r[1], tip, 17))
	return row


## Риск боя: сила врагов относительно лучших карт армии (три уровня, подробности в подсказке).
static func risk_chip(db: DefsDB, codex: CodexState, enc: EncounterDef, size: int = 18) -> HBoxContainer:
	var risk := CardAdvisor.risk(db, codex, enc)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var name: String = t.call(CardAdvisor.RISK_KEYS[risk])
	var body: String = t.call("RISK_TIP") % [roundi(CardAdvisor.encounter_power(db, enc)), roundi(CardAdvisor.army_power(db, codex))]
	return chip(UnitGlyphs.ICON_KILL, name, CardAdvisor.RISK_COLORS[risk], t.call("RISK_TITLE") + ": " + name, body, size)


static func _compare_tip(db: DefsDB, codex: CodexState, memory_id: StringName) -> String:
	var similar := CardAdvisor.similar_card(db, codex, memory_id)
	if similar < 0:
		return ""
	var card := codex.cards[similar]
	var mine := CardAdvisor.card_power(db, card.memory_id, card.level)
	if mine <= 0.0:
		return ""
	var ratio := CardAdvisor.card_power(db, memory_id) / mine - 1.0
	return "\n" + TranslationServer.translate("ADVICE_COMPARE") % [TranslationServer.translate(db.memory(card.memory_id).name_key), "%+d%%" % roundi(ratio * 100.0)]


static func flow(separation: int = 10) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", separation)
	f.add_theme_constant_override("v_separation", 4)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	return f


## Строка характеристик значками: ОЗ, атака, защита, урон, скорость, инициатива.
static func stat_row(hp: int, attack: int, defense: int, dmg_min: int, dmg_max: int, speed: int, initiative: int, size: int = 17) -> HFlowContainer:
	var row := flow(10)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	row.add_child(chip(UnitGlyphs.ICON_HP, str(hp), Color(1, 0.55, 0.55), t.call("STAT_HP"), t.call("STAT_HP_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_MELEE, str(attack), STAT_COLOR, t.call("STAT_ATTACK"), t.call("STAT_ATTACK_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_DEFEND, str(defense), STAT_COLOR, t.call("STAT_DEFENSE"), t.call("STAT_DEFENSE_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_RETALIATION, "%d–%d" % [dmg_min, dmg_max], STAT_COLOR, t.call("STAT_DAMAGE"), t.call("STAT_DAMAGE_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_SPEED, str(speed), STAT_COLOR, t.call("STAT_SPEED"), t.call("STAT_SPEED_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_WAIT, str(initiative), STAT_COLOR, t.call("STAT_INITIATIVE"), t.call("STAT_INITIATIVE_TIP"), size))
	return row


static func unit_stat_row(u: UnitState, size: int = 17) -> HFlowContainer:
	return stat_row(u.hp, u.attack, u.defense, u.dmg_min, u.dmg_max, u.speed, u.initiative, size)


static func def_stat_row(def: UnitDef, size: int = 16) -> HFlowContainer:
	return stat_row(def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative, size)


## Прочность точками ●●○ (заполненные — текущая).
static func pips(current: int, maximum: int, size: float = 12.0) -> Control:
	var p := Pips.new()
	p.current = current
	p.maximum = maximum
	p.radius = size * 0.42
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(maximum * (size + 4), size + 2)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	Tip.attach(p, TranslationServer.translate("CARD_DURABILITY") % [current, maximum], TranslationServer.translate("DURABILITY_TIP"))
	return p


class Pips:
	extends Control
	var current := 0
	var maximum := 0
	var radius := 5.0

	func _draw() -> void:
		var r := radius
		for i in maximum:
			var c := Vector2(r + 2 + i * (r * 2 + 4), size.y * 0.5)
			var col := (UiKit.DANGER if current <= 1 else UiKit.ACCENT) if i < current else Color(0.35, 0.37, 0.42)
			draw_circle(c, r, col)


## Ресурсы значками; signed — со знаком, нули пропускаются.
static func resource_row(res: Dictionary, signed: bool = false, size: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for id in RunState.RESOURCE_IDS:
		var v: int = res.get(id, 0)
		if signed and v == 0:
			continue
		var name := TranslationServer.translate("RES_" + String(id).to_upper())
		row.add_child(chip(RESOURCE_ICONS[id], ("%+d" % v) if signed else str(v), RESOURCE_COLORS[id], name, TranslationServer.translate("RES_" + String(id).to_upper() + "_TIP"), size))
	return row


## Кнопка со значком; описание — в подсказке.
static func icon_button(icon: StringName, text: String, on_pressed: Callable, tip_title: String = "", tip_body: String = "", min_width: int = 0) -> Button:
	var b := button(text, on_pressed, min_width)
	b.icon = IconAtlas.get_icon(icon)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 22)
	if tip_title != "" or tip_body != "":
		Tip.attach(b, tip_title, tip_body, icon)
	return b
