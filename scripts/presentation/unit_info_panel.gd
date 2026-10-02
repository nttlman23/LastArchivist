class_name UnitInfoPanel
extends PanelContainer
## Карточка стека: портрет, характеристики и способности простым языком.

const ICON_SIZE := 30.0
## Фиксированная ширина текста: иначе автоперенос в контейнере недосчитывает высоту.
const TEXT_WIDTH := 300.0

var _header: Label
var _portrait: UnitPortrait
var _title: Label
var _hp: Label
var _stats: Label
var _abilities: VBoxContainer
## Снимок показанного стека: пересобираем карточку, только если он изменился.
var _shown: Array = []


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

	_abilities = VBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 6)
	box.add_child(_abilities)


func show_unit(db: DefsDB, u: UnitState, header: String, header_color: Color = UiKit.MUTED) -> void:
	visible = u != null
	if u == null:
		return
	var snapshot := [u.uid, u.def_id, u.count, u.top_hp, u.shots_left, u.retaliated, u.defending, u.waited, header]
	if snapshot == _shown:
		return
	_shown = snapshot
	var side_color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	_header.text = header
	_header.add_theme_color_override("font_color", header_color)
	_portrait.set_unit(db, u)
	_title.text = "%s × %d" % [UiKit.unit_name(db, u.def_id), u.count]
	_title.add_theme_color_override("font_color", side_color)
	_hp.text = tr("INFO_HP") % [u.top_hp, u.hp]
	_stats.text = "%s\n%s" % [
		tr("INFO_STATS_COMBAT") % [u.attack, u.defense, u.dmg_min, u.dmg_max],
		tr("INFO_STATS_PACE") % [u.speed, u.initiative],
	]

	for child in _abilities.get_children():
		child.queue_free()
	for entry in abilities_of(u):
		_abilities.add_child(_ability_row(entry[0], entry[1], entry[2]))


## [значок, текст, активно ли] — общий список для карточки и тестов.
static func abilities_of(u: UnitState) -> Array:
	var list: Array = []
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
