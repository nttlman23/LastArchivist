extends GutTest
## Спринт 11: справочник (F1) — открытие и закрытие с паузой, все разделы собираются, числа — из
## констант, значки поля боя и ресурсы — все в справочнике.

var db: DefsDB


func before_all() -> void:
	db = DefsDB.load_default()


func after_each() -> void:
	Help.close()


## Весь текст раздела (для проверок содержимого).
func _text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _text(child)
	return out


func test_open_close_pauses_game() -> void:
	assert_false(Help.is_open())
	Help.open()
	assert_true(Help.is_open())
	assert_true(get_tree().paused, "пока открыт — пауза")
	Help.close()
	assert_false(Help.is_open())
	assert_false(get_tree().paused)


func test_f1_toggles_and_esc_closes() -> void:
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	Help._input(f1)
	assert_true(Help.is_open())
	Help._input(f1)
	assert_false(Help.is_open())
	Help._input(f1)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Help._input(esc)
	assert_false(Help.is_open())


func test_open_on_section() -> void:
	Help.open(&"damage")
	assert_eq(Help._section, HelpContent.SECTIONS.find(&"damage"))


func test_all_sections_build() -> void:
	for id in HelpContent.SECTIONS:
		var col := HelpContent.build(id, db, ProfileState.new())
		var text := _text(col)
		assert_gt(col.get_child_count(), 2, String(id))
		assert_false(text.contains("HELP_"), "все строки переведены: %s" % id)
		assert_false(text.contains("%d") or text.contains("%s"), "все числа подставлены: %s" % id)
		col.free()


func test_resource_prices_come_from_constants() -> void:
	var col := HelpContent.build(&"resources", db, null)
	var text := _text(col)
	for id in RunState.RESOURCE_IDS:
		assert_true(text.contains(tr("RES_" + String(id).to_upper())), String(id))
	assert_true(text.contains(tr("HELP_RES_PARCHMENT_USE") % [ShopOps.CARD_PRICE, ShopOps.HERO_CARD_PRICE, ShopOps.REWORK_COST]))
	assert_true(text.contains(tr("HELP_RES_AETHER_USE") % [ShopOps.RECHARGE_COST, MapActions.SCOUT_COST, MapActions.FLIGHT_COST]))
	col.free()


## Каждый значок, который BattleView рисует у фишки, объяснён в справочнике.
func test_every_battle_icon_is_explained() -> void:
	var s := TestHelpers.empty_battle()
	var u := TestHelpers.add(s, 0, Vector2i(0, 0), 10)
	for st in [UnitState.STATUS_MARKED, UnitState.STATUS_RIFT_MARKED, UnitState.STATUS_RUST_ARMOR, UnitState.STATUS_ADVANCE]:
		u.statuses[st] = 1
	u.defending = true
	u.retaliated = true
	u.fury = 1
	var shown: Array = BattleView.status_icons(u).map(func(e: Array) -> StringName: return e[0])
	u.statuses[UnitState.STATUS_SHIELD_WALL] = 1
	shown.append_array(BattleView.status_icons(u).map(func(e: Array) -> StringName: return e[0]))
	shown.append_array([UnitGlyphs.ICON_RANGED, UnitGlyphs.ICON_FLYING, UnitGlyphs.ICON_ABILITY, UnitGlyphs.ICON_THREAT, UnitGlyphs.ICON_MASK])
	var explained: Array = HelpContent.icon_entries().map(func(e: Array) -> StringName: return e[0])
	for icon in shown:
		assert_true(explained.has(icon), "значок %s есть в справочнике" % icon)
