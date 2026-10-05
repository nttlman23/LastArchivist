extends Control
## Архив-лавка (SPEC_SPRINT3 5.1): покупка воспоминаний, ремонт, перезаряд, одна переработка.

var db: DefsDB
var run: RunState
var visit: ShopOps.Visit
var _content: VBoxContainer
var _resources: Label


func _ready() -> void:
	if Game.run == null or Game.run.pending() == null:
		Game.to_main_menu()
		return
	db = Game.defs
	run = Game.run
	visit = ShopOps.open(db, run, run.pending_node)
	Hints.show_hint(&"shop")
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
	_content.add_theme_constant_override("separation", 14)
	margin.add_child(_content)
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	_content.add_child(UiKit.label(tr("SHOP_TITLE"), 40, UiKit.ACCENT))
	_content.add_child(UiKit.resource_row(run.resources, false, 24))

	_content.add_child(UiKit.label(tr("SHOP_CARDS"), 26, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	for i in visit.offer.size():
		var col := VBoxContainer.new()
		row.add_child(col)
		var card := UiKit.card_button(db, visit.offer[i])
		card.pressed.connect(_buy.bind(i))
		var reason := ShopOps.buy_reason(db, run, visit, i)
		card.disabled = reason != ""
		col.add_child(card)
		var price_row := HBoxContainer.new()
		price_row.add_theme_constant_override("separation", 8)
		price_row.add_child(UiKit.chip(UnitGlyphs.ICON_PARCHMENT, str(ShopOps.price(db, visit.offer[i], run)),
				UiKit.RESOURCE_COLORS[RunState.PARCHMENT] if reason == "" else UiKit.MUTED, tr("RES_PARCHMENT"), tr("SHOP_PRICE_TIP"), 20))
		if reason != "":
			price_row.add_child(UiKit.label(tr(reason), 18, UiKit.MUTED))
		col.add_child(price_row)
		if visit.offer[i] != &"":
			col.add_child(UiKit.advice_row(db, run.codex, visit.offer[i]))

	_content.add_child(_section(tr("SHOP_REPAIR_SHORT"), UnitGlyphs.ICON_INK, ShopOps.repair_cost(run), RunState.INK, tr("SHOP_REPAIR") % ShopOps.repair_cost(run)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for i in run.codex.cards.size():
		var b := _row_button(ReworkPanel.card_line(db, run, i), _repair.bind(i))
		var reason := ShopOps.repair_reason(db, run, i)
		if reason != "":
			b.disabled = true
			b.tooltip_text = tr(reason)
		grid.add_child(b)

	if not run.hero.spells.is_empty():
		_content.add_child(_section(tr("SHOP_RECHARGE_SHORT"), UnitGlyphs.ICON_AETHER, ShopOps.RECHARGE_COST, RunState.AETHER, tr("SHOP_RECHARGE") % ShopOps.RECHARGE_COST))
		var spells := HBoxContainer.new()
		spells.add_theme_constant_override("separation", 8)
		_content.add_child(spells)
		for s in run.hero.spells.size():
			var slot := run.hero.spells[s]
			var b := _row_button("%s ×%d" % [tr(db.spell(slot.spell_id).name_key), slot.charges], _recharge.bind(s))
			b.disabled = ShopOps.recharge_reason(run, s) != ""
			spells.add_child(b)

	_content.add_child(_section(tr("SHOP_REWORK_SHORT"), UnitGlyphs.ICON_PARCHMENT, ShopOps.rework_cost(run), RunState.PARCHMENT, tr("SHOP_REWORK") % ShopOps.rework_cost(run)))
	var rework := ReworkPanel.new()
	rework.extra_reason = func(i: int, f: CodexOps.Form) -> String:
		var r := ShopOps.rework_reason(db, run, visit, i, f)
		return r if r != CodexOps.unavailable_reason(db, run, i, f) else ""
	rework.setup(db, run)
	rework.confirmed.connect(_rework)
	_content.add_child(rework)

	var leave := UiKit.button(tr("SHOP_LEAVE"), Game.complete_node)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(leave)


## Заголовок раздела: «Ремонт  [капля] 1» с подсказкой полного правила.
func _section(title: String, icon: StringName, cost: int, res: StringName, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiKit.label(title, 26, UiKit.ACCENT))
	row.add_child(UiKit.chip(icon, str(cost), UiKit.RESOURCE_COLORS[res], title, tip, 22))
	return row


func _row_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _buy(index: int) -> void:
	if ShopOps.buy(db, run, visit, index):
		Game.achievement_event(Achievements.Event.PURCHASE)
		_rebuild()


func _repair(index: int) -> void:
	if ShopOps.repair(db, run, index):
		Audio.play(&"heal")
		_rebuild()


func _recharge(slot: int) -> void:
	if ShopOps.recharge(run, slot):
		Audio.play(&"spell")
		_rebuild()


func _rework(card_index: int, form: CodexOps.Form) -> void:
	if ShopOps.rework(db, run, visit, card_index, form):
		Game.achievement_event(Achievements.Event.REWORK)
		_rebuild()
