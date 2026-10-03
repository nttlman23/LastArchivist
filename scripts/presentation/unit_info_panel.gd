class_name UnitInfoPanel
extends PanelContainer
## Карточка стека: портрет, характеристики и способности.
## Коротко (по умолчанию): характеристики значками и чипы способностей/статусов, описания — по наведению.
## Подробно (Settings.detailed): полные тексты строками, как раньше.

const ICON_SIZE := 30.0
## Фиксированная ширина текста: иначе автоперенос в контейнере недосчитывает высоту.
const TEXT_WIDTH := 300.0

var _header: Label
var _portrait: UnitPortrait
var _title: Label
var _hp: Label
var _stats: Label
var _abilities: VBoxContainer
var _stat_box: VBoxContainer
var _chips: HFlowContainer
## Снимок показанного стека: пересобираем карточку, только если он изменился.
var _shown: Array = []
## Компактная карточка: без базовых строк «ближний бой» и «ответ готов».
var compact := false


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_header = UiKit.label("", 17, UiKit.MUTED)
	box.add_child(_header)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	_portrait = UnitPortrait.new()
	_portrait.custom_minimum_size = Vector2(84, 84)
	_portrait.show_count = false
	top.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	_title = UiKit.label("", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_hp = UiKit.label("", 17, UiKit.MUTED)
	col.add_child(_hp)
	_stats = UiKit.label("", 17, UiKit.MUTED)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_stats)
	_stat_box = VBoxContainer.new()
	col.add_child(_stat_box)
	_chips = UiKit.flow(12)
	box.add_child(_chips)

	_abilities = VBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 6)
	box.add_child(_abilities)


func show_unit(db: DefsDB, u: UnitState, header: String, header_color: Color = UiKit.MUTED) -> void:
	visible = u != null
	if u == null:
		return
	var snapshot := [u.uid, u.def_id, u.count, u.top_hp, u.shots_left, u.retaliated, u.defending, u.waited,
			u.ability_cd, u.statuses.duplicate(), u.defense, u.attack, u.speed, header, Settings.detailed, u.illusion]
	if snapshot == _shown:
		return
	_shown = snapshot
	var side_color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	_header.text = header
	_header.add_theme_color_override("font_color", header_color)
	_portrait.set_unit(db, u)
	_title.text = "%s × %d" % [UiKit.unit_name(db, u.def_id), u.count]
	_title.add_theme_color_override("font_color", side_color)
	for box: Container in [_abilities, _stat_box, _chips]:
		for child in box.get_children():
			child.queue_free()
	var detailed := Settings.detailed
	_hp.visible = detailed
	_stats.visible = detailed
	_abilities.visible = detailed
	_stat_box.visible = not detailed
	_chips.visible = not detailed
	if detailed:
		_hp.text = tr("INFO_HP") % [u.top_hp, u.hp]
		_stats.text = "%s\n%s" % [
			tr("INFO_STATS_COMBAT") % [u.attack, u.defense, u.dmg_min, u.dmg_max],
			tr("INFO_STATS_PACE") % [u.speed, u.initiative],
		]
		for entry in abilities_of(db, u, compact):
			_abilities.add_child(_ability_row(entry[0], entry[1], entry[2]))
		return
	var stats := UiKit.unit_stat_row(u)
	# ОЗ: верхнее существо / максимум.
	(stats.get_child(0).get_child(1) as Label).text = "%d/%d" % [u.top_hp, u.hp]
	_stat_box.add_child(stats)
	for c in chips_of(db, u):
		_chips.add_child(UiKit.chip(c[0], c[1], c[2], c[3], c[4], 18))


## [значок, текст, активно ли] — общий список для карточки и тестов.
static func abilities_of(db: DefsDB, u: UnitState, skip_basic: bool = false) -> Array:
	var list: Array = []
	if u.ability_id != &"" and db.abilities.has(u.ability_id):
		var ab := db.ability(u.ability_id)
		var state_text: String = TranslationServer.translate("ABILITY_READY")
		if u.ability_cd > 0:
			state_text = TranslationServer.translate("ABILITY_COOLDOWN") % u.ability_cd
		list.append([UnitGlyphs.ICON_ABILITY, "%s (%s): %s" % [
			TranslationServer.translate(ab.name_key), state_text, TranslationServer.translate(ab.desc_key)], u.ability_cd <= 0])
	if u.is_ranged:
		list.append([UnitGlyphs.ICON_RANGED, TranslationServer.translate("ABILITY_RANGED") % u.shots_left, u.shots_left > 0])
	else:
		list.append([UnitGlyphs.ICON_MELEE, TranslationServer.translate("ABILITY_MELEE"), true])
	if u.is_flying:
		list.append([UnitGlyphs.ICON_FLYING, TranslationServer.translate("ABILITY_FLYING"), true])
	if u.retaliated:
		list.append([UnitGlyphs.ICON_RETALIATION_USED, TranslationServer.translate("STATUS_RETALIATION_USED"), false])
	else:
		list.append([UnitGlyphs.ICON_RETALIATION, TranslationServer.translate("STATUS_RETALIATION_READY"), true])
	if u.defending:
		list.append([UnitGlyphs.ICON_DEFEND, TranslationServer.translate("STATUS_DEFENDING"), true])
	if u.waited:
		list.append([UnitGlyphs.ICON_WAIT, TranslationServer.translate("STATUS_WAITED"), true])
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		list.append([UnitGlyphs.ICON_MARK, TranslationServer.translate("STATUS_RIFT_MARKED"), false])
	if u.has_status(UnitState.STATUS_MARKED):
		list.append([UnitGlyphs.ICON_MARK, TranslationServer.translate("STATUS_MARKED"), true])
	if u.has_status(UnitState.STATUS_SHIELD_WALL):
		list.append([UnitGlyphs.ICON_RETALIATION, TranslationServer.translate("STATUS_SHIELD_WALL"), true])
	if u.has_status(UnitState.STATUS_RUST_ARMOR):
		list.append([UnitGlyphs.ICON_ARMOR, TranslationServer.translate("STATUS_RUST_ARMOR"), true])
	if u.has_status(UnitState.STATUS_ADVANCE):
		list.append([UnitGlyphs.ICON_ORDER, TranslationServer.translate("STATUS_ADVANCE"), true])
	if skip_basic:
		return list.filter(func(e: Array) -> bool: return e[0] != UnitGlyphs.ICON_MELEE and e[0] != UnitGlyphs.ICON_RETALIATION)
	return list


## Короткие чипы: [значок, короткая подпись, цвет, заголовок подсказки, описание].
## Базовые «ближний бой» и «ответ готов» опускаются — это поведение по умолчанию.
static func chips_of(db: DefsDB, u: UnitState) -> Array:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var list: Array = []
	if u.ability_id != &"" and db.abilities.has(u.ability_id):
		var ab := db.ability(u.ability_id)
		var ready := u.ability_cd <= 0
		var short: String = t.call(ab.name_key) if ready else "%s %d" % [t.call(ab.name_key), u.ability_cd]
		var body: String = t.call(ab.desc_key)
		if not ready:
			body += "\n" + t.call("ABILITY_COOLDOWN") % u.ability_cd
		list.append([UnitGlyphs.ICON_ABILITY, short, UiKit.ACCENT if ready else UiKit.MUTED, t.call(ab.name_key), body])
	if u.is_ranged:
		list.append([UnitGlyphs.ICON_RANGED, str(u.shots_left), Color.WHITE if u.shots_left > 0 else UiKit.MUTED,
				t.call("CHIP_RANGED"), t.call("ABILITY_RANGED") % u.shots_left])
	if u.is_flying:
		list.append([UnitGlyphs.ICON_FLYING, "", Color.WHITE, t.call("CHIP_FLYING"), t.call("ABILITY_FLYING")])
	if u.retaliated and not u.has_status(UnitState.STATUS_SHIELD_WALL):
		list.append([UnitGlyphs.ICON_RETALIATION_USED, "", UiKit.MUTED, t.call("CHIP_RETALIATION_USED"), t.call("STATUS_RETALIATION_USED")])
	if u.defending:
		list.append([UnitGlyphs.ICON_DEFEND, "", UiKit.PLAYER_COLOR.lightened(0.3), t.call("CHIP_DEFENDING"), t.call("STATUS_DEFENDING")])
	if u.waited:
		list.append([UnitGlyphs.ICON_WAIT, "", Color.WHITE, t.call("CHIP_WAITED"), t.call("STATUS_WAITED")])
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		list.append([UnitGlyphs.ICON_MARK, t.call("CHIP_RIFT"), Color(0.8, 0.5, 1.0), t.call("CHIP_RIFT"), t.call("STATUS_RIFT_MARKED")])
	if u.has_status(UnitState.STATUS_MARKED):
		list.append([UnitGlyphs.ICON_MARK, "+50%", UiKit.DANGER, t.call("CHIP_MARKED"), t.call("STATUS_MARKED")])
	if u.has_status(UnitState.STATUS_SHIELD_WALL):
		list.append([UnitGlyphs.ICON_RETALIATION, t.call("CHIP_ALL"), UiKit.ACCENT, t.call("ABIL_SHIELD_WALL"), t.call("STATUS_SHIELD_WALL")])
	if u.has_status(UnitState.STATUS_RUST_ARMOR):
		list.append([UnitGlyphs.ICON_ARMOR, "+4", UiKit.ACCENT, t.call("SPELL_RUST_ARMOR"), t.call("STATUS_RUST_ARMOR")])
	if u.has_status(UnitState.STATUS_ADVANCE):
		list.append([UnitGlyphs.ICON_ORDER, "+2", UiKit.ACCENT, t.call("ORDER_ADVANCE"), t.call("STATUS_ADVANCE")])
	if u.fury > 0:
		list.append([UnitGlyphs.ICON_MELEE, "+%d" % u.fury, UiKit.DANGER, t.call("CHIP_ASH_FURY"), t.call("STATUS_ASH_FURY")])
	if u.illusion:
		list.append([UnitGlyphs.ICON_MARK, t.call("CHIP_ILLUSION"), Color(0.8, 0.8, 1.0), t.call("CHIP_ILLUSION"), t.call("STATUS_ILLUSION")])
	if u.speed <= 0:
		list.append([UnitGlyphs.ICON_SPEED, t.call("CHIP_IMMOBILE"), UiKit.MUTED, t.call("CHIP_IMMOBILE"), t.call("STATUS_IMMOBILE")])
	if u.construct:
		list.append([UnitGlyphs.ICON_ARMOR, "", UiKit.STAT_COLOR, t.call("CHIP_CONSTRUCT"), t.call("STATUS_CONSTRUCT")])
	return list


func _ability_row(icon: StringName, text: String, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ic := AbilityIcon.new()
	ic.kind = icon
	ic.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var l := UiKit.label(text, 16, Color.WHITE if enabled else UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	row.add_child(l)
	return row


class AbilityIcon:
	extends Control
	var kind: StringName

	func _draw() -> void:
		UnitGlyphs.draw_icon(self, kind, size * 0.5, size.x * 0.5, Color(0.22, 0.24, 0.3))
