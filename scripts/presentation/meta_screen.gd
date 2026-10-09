extends Control
## «Зал Архива» (SPEC_SPRINT8 2): дерево улучшений в три ветви и полоса открытий (SPEC_SPRINT4 5.3).
## Узел — значок с ценой; название и эффект — в подсказке.

const NODE_SIZE := Vector2(80, 80)
const LINK_SIZE := Vector2(4, 16)
const BOUGHT := Color(0.95, 0.8, 0.4)
const READY := Color(0.55, 0.8, 1.0)
const LOCKED := Color(0.4, 0.42, 0.48)
const BRANCH_KEYS := {
	MetaUpgrades.SUPPLIES: "HALL_BRANCH_SUPPLIES",
	MetaUpgrades.KNOWLEDGE: "HALL_BRANCH_KNOWLEDGE",
	MetaUpgrades.EXPEDITION: "HALL_BRANCH_EXPEDITION",
}

var db: DefsDB
var _content: VBoxContainer


func _ready() -> void:
	db = Game.defs
	UiKit.add_background(self, false, &"hall")
	_content = UiKit.centered_column(self, 14)
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var p := Game.profile
	var title := UiKit.label(tr("META_TITLE"), 44, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 24)
	top.add_child(UiKit.chip(UnitGlyphs.ICON_POINTS, str(p.points), UiKit.ACCENT, tr("META_POINTS"), tr("META_POINTS_TIP"), 26))
	top.add_child(UiKit.label(tr("META_STATS") % [p.runs, p.wins, p.best_layer], 18, UiKit.MUTED))
	_content.add_child(top)

	# Слева — дерево, справа — открытия и кнопки.
	var main := HBoxContainer.new()
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 110)
	_content.add_child(main)
	var tree := HBoxContainer.new()
	tree.add_theme_constant_override("separation", 70)
	for branch in MetaUpgrades.BRANCHES:
		tree.add_child(_branch(branch))
	main.add_child(tree)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(side)
	side.add_child(UiKit.label(tr("HALL_UNLOCKS"), 24, UiKit.MUTED))
	for unlock in MetaRewards.all_unlocks(db):
		side.add_child(_unlock_button(unlock))
	side.add_child(Control.new())
	var reset := UiKit.icon_button(UnitGlyphs.ICON_POINTS, tr("HALL_RESET") + " (%d)" % MetaUpgrades.spent(db, p), _reset,
			tr("HALL_RESET"), tr("HALL_RESET_TIP"), 420)
	reset.disabled = p.upgrades.is_empty()
	side.add_child(reset)
	side.add_child(UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 420))


## Ветвь: заголовок и узлы сверху вниз, между ними — связи (яркие, если оба узла куплены).
func _branch(branch: StringName) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var head := UiKit.label(tr(BRANCH_KEYS[branch]), 24, UiKit.MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var nodes := db.hall_branch(branch)
	for i in nodes.size():
		if i > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = LINK_SIZE
			link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var both := Game.profile.upgrades.has(nodes[i - 1].id) and Game.profile.upgrades.has(nodes[i].id)
			link.color = BOUGHT if both else LOCKED.darkened(0.3)
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(link)
		col.add_child(_node(nodes[i]))
	return col


func _node(node: UpgradeNodeDef) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var reason := MetaUpgrades.buy_reason(db, Game.profile, node.id)
	var bought := reason == "REASON_UNLOCKED"
	var color := BOUGHT if bought else (READY if reason == "" else LOCKED)
	var b := Button.new()
	b.name = String(node.id)
	b.custom_minimum_size = NODE_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var style := UiKit.panel_style(UiKit.PANEL_COLOR.lightened(0.06) if bought else UiKit.PANEL_COLOR, color, 3 if reason != "REASON_NEEDS_PREVIOUS" else 1)
	(style as StyleBoxFlat).set_corner_radius_all(int(NODE_SIZE.x / 2))
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, style)
	b.icon = IconAtlas.get_icon(node.icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 44)
	b.add_theme_color_override("icon_normal_color", color)
	b.add_theme_color_override("icon_hover_color", color.lightened(0.2))
	b.add_theme_color_override("icon_disabled_color", color)
	b.disabled = reason != ""
	b.pressed.connect(_buy.bind(node.id))
	var body := tr(node.desc_key)
	if not bought:
		body += "\n" + tr("HALL_COST_TIP") % node.cost
		if reason != "" and reason != "REASON_NO_POINTS":
			body += " · " + tr(reason)
	if Game.run != null:
		body += "\n" + tr("HALL_FROZEN_TIP")
	Tip.attach(b, tr(node.name_key), body, node.icon, color)
	if not bought:
		UiKit.add_hover_lift(b)
	box.add_child(b)
	var cost := UiKit.chip(UnitGlyphs.ICON_POINTS, tr("META_OPEN") if bought else str(node.cost), color, "", "", 16)
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cost)
	return box


## Открытие (школа, карта, событие) компактной кнопкой: имя и цена, описание — в подсказке.
func _unlock_button(unlock: Dictionary) -> Button:
	var reason := MetaRewards.buy_reason(db, Game.profile, unlock)
	var open := reason == "REASON_UNLOCKED"
	var text := _unlock_name(unlock) + ("" if open else "  · %d" % unlock["cost"])
	var b := UiKit.icon_button(UnitGlyphs.ICON_POINTS if not open else UnitGlyphs.ICON_CHALICE, text, _buy_unlock.bind(unlock),
			_unlock_name(unlock), _unlock_desc(unlock) + ("" if reason in ["", "REASON_UNLOCKED", "REASON_NO_POINTS"] else "\n" + tr(reason)))
	b.disabled = reason != ""
	b.custom_minimum_size.x = 420
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if open:
		b.add_theme_color_override("font_disabled_color", BOUGHT)
	return b


func _unlock_name(u: Dictionary) -> String:
	match u["kind"]:
		MetaRewards.Kind.SCHOOL:
			return tr("META_KIND_SCHOOL") % tr(db.school(u["target"]).name_key)
		MetaRewards.Kind.CARD:
			return tr("META_KIND_CARD") % tr(db.memory(u["target"]).name_key)
		MetaRewards.Kind.EVENT:
			return tr("META_KIND_EVENT") % tr(db.event(u["target"]).title_key)
	return ""


func _unlock_desc(u: Dictionary) -> String:
	match u["kind"]:
		MetaRewards.Kind.SCHOOL:
			return tr(db.school(u["target"]).desc_key)
		MetaRewards.Kind.CARD:
			return tr("META_CARD_TIP")
		MetaRewards.Kind.EVENT:
			return tr(db.event(u["target"]).text_key)
	return ""


func _buy(id: StringName) -> void:
	if MetaUpgrades.buy(db, Game.profile, id):
		Game.save_profile()
		Audio.play(&"transform")
		_rebuild()


func _buy_unlock(unlock: Dictionary) -> void:
	if MetaRewards.buy(db, Game.profile, unlock):
		Game.save_profile()
		Audio.play(&"transform")
		_rebuild()


func _reset() -> void:
	MetaUpgrades.reset(db, Game.profile)
	Game.save_profile()
	Audio.play(&"ui_click")
	_rebuild()
