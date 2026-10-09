extends Control
## Достижения (SPEC_SPRINT9 6): сетка значков. Полученные — цветные, дата в подсказке;
## остальные — тусклые, условие в подсказке. Скрытых нет.

const BADGE_SIZE := Vector2(210, 176)
const COLUMNS := 7

var db: DefsDB


func _ready() -> void:
	db = Game.defs
	UiKit.add_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	box.add_child(head)
	head.add_child(UiKit.label(tr("ACH_TITLE"), 44, UiKit.ACCENT))
	var all := db.achievements_sorted()
	var count := UiKit.label(tr("ACH_COUNT") % [Game.profile.achievements.size(), all.size()], 24, UiKit.MUTED)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for a in all:
		grid.add_child(_badge(a))

	var back := UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(back)


## Значок достижения: медальон (или круг со значком), название, дата или «не получено».
func _badge(a: AchievementDef) -> PanelContainer:
	var earned := Game.profile.has_achievement(a.id)
	var color := a.color if earned else UiKit.MUTED.darkened(0.35)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = BADGE_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR if earned else UiKit.PANEL_COLOR.darkened(0.25),
			color.darkened(0.2), 2 if earned else 1, earned))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var medal := ArtDB.achievement(a.id)
	if medal:
		# Рисованный медальон (SPEC_SPRINT9 18): неполученный — тёмный, с замком.
		var art := UiKit.art_rect(medal, Vector2(84, 84), false, Color.WHITE if earned else Color(0.32, 0.32, 0.36))
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not earned:
			var lock := UiKit.icon_rect(UnitGlyphs.ICON_LOCK, 26, UiKit.MUTED)
			lock.position = Vector2(58, 58)
			art.add_child(lock)
		col.add_child(art)
	else:
		col.add_child(_disc(a, earned, color))
	var name := UiKit.label(tr(a.name_key), 19, color.lightened(0.25) if earned else UiKit.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Место под две строки — карточки одной высоты.
	name.custom_minimum_size = Vector2(0, 50)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(name)
	var sub := UiKit.label(Game.profile.achievements[a.id] if earned else tr("ACH_LOCKED"), 14, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var body := tr(a.desc_key) + "\n\n" + Achievements.reward_text(db, a)
	if earned:
		body += "\n" + tr("ACH_EARNED_ON") % Game.profile.achievements[a.id]
	Tip.attach(panel, tr(a.name_key), body, a.icon, a.color)
	return panel


## Процедурный круг со значком — когда рисованного медальона нет.
func _disc(a: AchievementDef, earned: bool, color: Color) -> Control:
	var disc := Disc.new()
	disc.color = color
	disc.earned = earned
	disc.custom_minimum_size = Vector2(76, 76)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiKit.icon_rect(a.icon if earned else UnitGlyphs.ICON_LOCK, 42, color.lightened(0.15) if earned else color)
	# Значок по центру круга: якоря на весь круг с полями (размер круга на момент сборки ещё 0).
	icon.custom_minimum_size = Vector2.ZERO
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top"]:
		icon.set("offset_" + side, 17)
	for side in ["right", "bottom"]:
		icon.set("offset_" + side, -17)
	disc.add_child(icon)
	return disc


## Круглая подложка значка: полученное — заливка и кольцо цвета достижения, остальное — тусклое кольцо.
class Disc:
	extends Control
	var color := Color.WHITE
	var earned := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(color, 0.18 if earned else 0.06))
		draw_arc(c, r, 0, TAU, 48, Color(color, 0.9 if earned else 0.4), 2.5 if earned else 1.5, true)
