class_name HelpContent
extends RefCounted
## Разделы справочника (SPEC_SPRINT11 2). Тексты — в переводах (HELP_*), числа — из констант кода,
## чтобы справочник не устаревал при балансе; значки — те же, что рисует игра.

const SECTIONS: Array[StringName] = [&"run", &"resources", &"codex", &"rework", &"hero", &"icons", &"damage", &"objectives", &"schools"]
const SECTION_ICONS := {
	&"run": UnitGlyphs.ICON_MOVE, &"resources": UnitGlyphs.ICON_POINTS, &"codex": UnitGlyphs.ICON_KILL,
	&"rework": UnitGlyphs.ICON_SPELL, &"hero": UnitGlyphs.ICON_ORDER, &"icons": UnitGlyphs.ICON_MARK,
	&"damage": UnitGlyphs.ICON_MELEE, &"objectives": UnitGlyphs.ICON_THREAT, &"schools": UnitGlyphs.ICON_ABILITY,
}
const TEXT := Color(0.9, 0.9, 0.92)
const NOTE := Color(0.72, 0.74, 0.8)
const TEXT_WIDTH := 1100.0
const MapScreen := preload("res://scripts/presentation/map_screen.gd")


static func title(section: StringName) -> String:
	return TranslationServer.translate("HELP_%s" % String(section).to_upper())


## Значки поля боя в справочнике: [значок, цвет, название, описание]. Тест сверяет их со значками,
## которые рисует BattleView, чтобы справочник не отставал.
static func icon_entries() -> Array:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	return [
		[UnitGlyphs.ICON_RANGED, Color.WHITE, t.call("CHIP_RANGED"), t.call("HELP_ICON_RANGED")],
		[UnitGlyphs.ICON_FLYING, Color.WHITE, t.call("CHIP_FLYING"), t.call("HELP_ICON_FLYING")],
		[UnitGlyphs.ICON_ABILITY, UiKit.ACCENT, t.call("HELP_ICON_ABILITY_NAME"), t.call("HELP_ICON_ABILITY")],
		[UnitGlyphs.ICON_MARK, BattleView.DAMAGE_COLOR, t.call("CHIP_MARKED"), t.call("STATUS_MARKED")],
		[UnitGlyphs.ICON_MARK, BattleView.RIFT_COLOR, t.call("CHIP_RIFT"), t.call("STATUS_RIFT_MARKED")],
		[UnitGlyphs.ICON_DEFEND, UiKit.PLAYER_COLOR.lightened(0.3), t.call("CHIP_DEFENDING"), t.call("STATUS_DEFENDING")],
		[UnitGlyphs.ICON_RETALIATION, UiKit.ACCENT, t.call("HELP_ICON_SHIELD_WALL_NAME"), t.call("STATUS_SHIELD_WALL")],
		[UnitGlyphs.ICON_RETALIATION_USED, UiKit.MUTED, t.call("CHIP_RETALIATION_USED"), t.call("STATUS_RETALIATION_USED")],
		[UnitGlyphs.ICON_ARMOR, UiKit.ACCENT, t.call("HELP_ICON_ARMOR_NAME"), t.call("STATUS_RUST_ARMOR")],
		[UnitGlyphs.ICON_ORDER, UiKit.ACCENT, t.call("HELP_ICON_ADVANCE_NAME"), t.call("STATUS_ADVANCE")],
		[UnitGlyphs.ICON_MELEE, UiKit.DANGER, t.call("CHIP_ASH_FURY"), t.call("STATUS_ASH_FURY")],
		[UnitGlyphs.ICON_THREAT, UiKit.DANGER, t.call("HELP_ICON_THREAT_NAME"), t.call("HELP_ICON_THREAT")],
		[UnitGlyphs.ICON_MASK, Color(0.85, 0.85, 1.0), t.call("CHIP_ILLUSION"), t.call("STATUS_ILLUSION")],
		[UnitGlyphs.ICON_KILL, UiKit.DANGER, t.call("CARD_WORN"), t.call("CARD_WORN_TIP")],
	]


## Содержимое раздела (колонка с текстом, значками и таблицами).
static func build(section: StringName, db: DefsDB, profile: ProfileState) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(UiKit.label(title(section), 34, UiKit.ACCENT))
	match section:
		&"run":
			_run(col)
		&"resources":
			_resources(col, db)
		&"codex":
			_codex(col)
		&"rework":
			_rework(col)
		&"hero":
			_hero(col)
		&"icons":
			_icons(col)
		&"damage":
			_damage(col, db)
		&"objectives":
			_objectives(col)
		&"schools":
			_schools(col, db, profile)
	return col


# --- Разделы -----------------------------------------------------------------------

static func _run(col: VBoxContainer) -> void:
	_para(col, _tr("HELP_RUN_1") % MapState.LAYERS)
	_para(col, _tr("HELP_RUN_2"))
	for type in MapScreen.TYPE_KEYS:
		var key: String = MapScreen.TYPE_KEYS[type]
		col.add_child(_swatch_row(MapView.TYPE_COLORS[type], _tr(key), _tr(key + "_DESC")))
	_para(col, _tr("HELP_RUN_3"))


static func _resources(col: VBoxContainer, db: DefsDB) -> void:
	_para(col, _tr("HELP_RES_INTRO"))
	var t1 := MapActions.battle_rewards(_encounter(db, 1, false))
	var t2 := MapActions.battle_rewards(_encounter(db, 2, false))
	var t3 := MapActions.battle_rewards(_encounter(db, 3, false))
	var el := MapActions.battle_rewards(_encounter(db, 3, true))
	var uses := {
		RunState.INK: _tr("HELP_RES_INK_USE") % ShopOps.REPAIR_COST,
		RunState.PARCHMENT: _tr("HELP_RES_PARCHMENT_USE") % [ShopOps.CARD_PRICE, ShopOps.HERO_CARD_PRICE, ShopOps.REWORK_COST],
		RunState.AETHER: _tr("HELP_RES_AETHER_USE") % [ShopOps.RECHARGE_COST, MapActions.SCOUT_COST, MapActions.FLIGHT_COST],
	}
	for id in RunState.RESOURCE_IDS:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(_icon(UiKit.RESOURCE_ICONS[id], UiKit.RESOURCE_COLORS[id], 30))
		head.add_child(UiKit.label(_tr("RES_" + String(id).to_upper()), 26, UiKit.RESOURCE_COLORS[id]))
		col.add_child(head)
		_para(col, _tr("HELP_RES_FROM") % [t1[id], t2[id], t3[id], el[id]], NOTE)
		_para(col, uses[id], NOTE)
		_para(col, _tr("HELP_RES_%s_WHY" % String(id).to_upper()), NOTE)


static func _codex(col: VBoxContainer) -> void:
	_para(col, _tr("HELP_CODEX_1") % CodexState.MAX_CARDS)
	_para(col, _tr("HELP_CODEX_2"))
	_para(col, _tr("HELP_CODEX_3"))
	_para(col, _tr("HELP_CODEX_4"))
	col.add_child(_icon_row(UnitGlyphs.ICON_KILL, UiKit.DANGER, _tr("CARD_WORN"), _tr("CARD_WORN_TIP")))
	col.add_child(_icon_row(UnitGlyphs.ICON_MARK, BattleView.RIFT_COLOR, _tr("CHIP_RIFT"), _tr("HELP_CODEX_RIFT")))


static func _rework(col: VBoxContainer) -> void:
	_para(col, _tr("HELP_REWORK_1"))
	for form in CodexOps.ALL_FORMS:
		var name := String(CodexOps.Form.keys()[form])
		col.add_child(_icon_row(ReworkPanel.FORM_ICONS[form], UiKit.ACCENT, _tr(ReworkPanel.FORM_KEYS[form]), _tr("HELP_REWORK_" + name)))
	_para(col, _tr("HELP_REWORK_2"))


static func _hero(col: VBoxContainer) -> void:
	for key in ["HELP_HERO_1", "HELP_HERO_2"]:
		_para(col, _tr(key))
	col.add_child(_icon_row(UnitGlyphs.ICON_ORDER, UiKit.ACCENT, _tr("CARD_HERO"), _tr("CARD_HERO_TIP")))
	_para(col, _tr("HELP_HERO_3"))


static func _icons(col: VBoxContainer) -> void:
	_para(col, _tr("HELP_ICONS_INTRO"))
	for e: Array in icon_entries():
		col.add_child(_icon_row(e[0], e[1], e[2], e[3]))
	var intents := HBoxContainer.new()
	intents.add_theme_constant_override("separation", 6)
	for icon in BattleView.INTENT_ICONS.values():
		intents.add_child(_icon(icon, BattleView.THREAT_COLOR.lightened(0.2), 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(intents)
	row.add_child(_text_block(_tr("HELP_ICON_INTENT_NAME"), _tr("HELP_ICON_INTENT")))
	col.add_child(row)
	_para(col, _tr("HELP_ICON_COUNT"))


static func _damage(col: VBoxContainer, db: DefsDB) -> void:
	_para(col, _tr("HELP_DAMAGE_1"))
	_para(col, _tr("HELP_DAMAGE_2") % [roundi(DamageCalc.ATTACK_BONUS_PER_POINT * 100), roundi(DamageCalc.ATTACK_BONUS_PER_POINT * DamageCalc.ATTACK_BONUS_CAP * 100),
			_num(DamageCalc.DEFENSE_BONUS_PER_POINT * 100), roundi(DamageCalc.DEFENSE_BONUS_PER_POINT * DamageCalc.DEFENSE_BONUS_CAP * 100)])
	_para(col, _tr("HELP_DAMAGE_3") % [_num(DamageCalc.DEFEND_MULTIPLIER), DamageCalc.LONG_RANGE, _num(DamageCalc.HALF), _num(DamageCalc.MARK_BONUS), _num(DamageCalc.ILLUSION_DAMAGE)])
	# Пример на настоящих существах: Легион Соляных Стражей бьёт Стаю Пепельных Гулей.
	var a := UnitState.from_def(db.unit(db.memory(&"salt_legion").unit_id), 0, UnitState.Side.PLAYER, db.memory(&"salt_legion").count, Vector2i.ZERO)
	var d := UnitState.from_def(db.unit(db.memory(&"ghoul_pack").unit_id), 1, UnitState.Side.ENEMY, db.memory(&"ghoul_pack").count, Vector2i(1, 0))
	var r := DamageCalc.damage_range(a, d, false)
	_para(col, _tr("HELP_DAMAGE_EXAMPLE") % [_tr(db.memory(&"salt_legion").name_key), a.count, a.dmg_min, a.dmg_max, a.attack,
			_tr(db.memory(&"ghoul_pack").name_key), d.defense, a.count * a.dmg_min, a.count * a.dmg_max,
			_pct(DamageCalc.attack_modifier(a.attack, d.defense)), r.x, r.y, d.hp, DamageCalc.kills(d, r.x), DamageCalc.kills(d, r.y)], NOTE)
	_para(col, _tr("HELP_DAMAGE_4"))
	_para(col, _tr("HELP_DAMAGE_5"))


static func _objectives(col: VBoxContainer) -> void:
	_para(col, _tr("HELP_OBJECTIVES_1"))
	for obj in ObjectiveRule.ALL:
		var key := "OBJ_" + String(obj).to_upper()
		var body := _tr(key + "_DESC")
		if body.contains("%d"):
			body = body.replace("%d", "N")
		col.add_child(_icon_row(UiKit.OBJECTIVE_ICONS.get(obj, UnitGlyphs.ICON_KILL), UiKit.OBJECTIVE_COLOR, _tr(key), body))
	_para(col, _tr("OBJ_BONUS_TIP"), NOTE)
	col.add_child(_icon_row(UnitGlyphs.ICON_ORDER, UiKit.DANGER, _tr("COMMANDER_TITLE"), _tr("HELP_COMMANDER")))


static func _schools(col: VBoxContainer, db: DefsDB, profile: ProfileState) -> void:
	_para(col, _tr("HELP_SCHOOLS_1"))
	for s in db.schools_sorted():
		if not s.implemented:
			continue
		var open := profile == null or MetaRewards.is_school_open(profile, s)
		var body := _tr(s.desc_key) + ("" if open else "\n" + _tr("HELP_SCHOOL_LOCKED") % s.unlock_cost)
		col.add_child(_swatch_row(s.color, _tr(s.name_key), body))


# --- Кирпичики -------------------------------------------------------------------

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## Встреча нужного уровня (для наград за бой в разделе ресурсов).
static func _encounter(db: DefsDB, tier: int, elite: bool) -> EncounterDef:
	for id in db.encounters:
		var e: EncounterDef = db.encounters[id]
		if e.tier == tier and e.elite == elite and not e.boss:
			return e
	return EncounterDef.new()


static func _num(v: float) -> String:
	var s := ("%.2f" % v).rstrip("0").rstrip(".")
	return s.replace(".", ",")


static func _pct(f: float) -> String:
	var v := roundi((f - 1.0) * 100.0)
	return ("+%d%%" % v) if v >= 0 else ("−%d%%" % -v)


static func _para(col: VBoxContainer, text: String, color: Color = TEXT) -> void:
	var l := UiKit.label(text, 20, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	col.add_child(l)


static func _icon(icon: StringName, color: Color, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = IconAtlas.get_icon(icon)
	r.modulate = color
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return r


static func _text_block(name: String, body: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UiKit.label(name, 21, UiKit.ACCENT))
	var l := UiKit.label(body, 18, NOTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_WIDTH - 60, 0)
	v.add_child(l)
	return v


static func _icon_row(icon: StringName, color: Color, name: String, body: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_icon(icon, color, 30))
	row.add_child(_text_block(name, body))
	return row


static func _swatch_row(color: Color, name: String, body: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var sw := ColorRect.new()
	sw.color = color
	sw.custom_minimum_size = Vector2(26, 26)
	sw.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(sw)
	row.add_child(_text_block(name, body))
	return row
