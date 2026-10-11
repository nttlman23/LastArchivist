extends "res://scripts/presentation/tutorial_screen.gd"
## Второй урок «Герой и Кодекс» (SPEC_SPRINT11 5), часть 1: заклинание героя с зарядами, разбор урона
## при ударе вплотную, дальний выстрел вполсилы. После победы — износ карт, сводка ресурсов и
## превращение изношенной карты в заклинание на настоящей панели переработки (учебный Кодекс).
## Дальше — учебная карта (tutorial_map_screen). В забег, достижения и историю ничего не пишется.

const FIELD2 := Vector2i(9, 5)
const ENEMY2_HEX := Vector2i(7, 2)
const SPELL := &"ash_record"
const SPELL_CHARGES := 2
const STEPS2 := [
	{"key": "TUT2_STEP_SPELL", "unit": &"salt_guard", "types": [BattleAction.Type.HERO], "ref": SPELL},
	{"key": "TUT2_STEP_MELEE", "unit": &"salt_guard", "types": [BattleAction.Type.MELEE]},
	{"key": "TUT2_STEP_SHOOT", "unit": &"chronicler", "types": [BattleAction.Type.SHOOT]},
	{"key": "TUT2_STEP_FINISH", "unit": &"", "types": []},
]

## Учебный Кодекс после боя: изношенная карта (прочность 1) превращается в заклинание.
var _codex_run: RunState
var _rework: ReworkPanel
var _rework_text: Label


func _steps() -> Array:
	return STEPS2


## Поле 9 × 5: Страж рядом с врагом, Летописцы далеко (выстрел дальше 5 клеток — вполсилы). У героя —
## «Пепельная запись» с двумя зарядами.
func _make_state() -> BattleState:
	var s := BattleState.new()
	s.grid.width = FIELD2.x
	s.grid.height = FIELD2.y
	s.rng.seed = 11
	for id in db.abilities:
		s.ability_cooldowns[id] = db.abilities[id].cooldown
	s.hero_orders = db.base_orders.duplicate()
	s.hero_spells.append({"spell_id": SPELL, "charges": SPELL_CHARGES, "power": db.spell(SPELL).power})
	var units := [[&"salt_guard", 12, Vector2i(5, 2), 9], [&"chronicler", 10, Vector2i(0, 0), 8]]
	for i in units.size():
		var u := s.add_unit(db.unit(units[i][0]), UnitState.Side.PLAYER, units[i][1], units[i][2])
		u.initiative = units[i][3]
		u.card_index = i
	var def := (db.unit(&"rust_sentinel") as UnitDef).duplicate() as UnitDef
	def.hp = ENEMY_HP
	def.attack = 1
	def.dmg_min = 1
	def.dmg_max = 1
	def.initiative = 1
	def.speed = 0
	def.ability_id = &""
	s.add_unit(def, UnitState.Side.ENEMY, ENEMY_COUNT, ENEMY2_HEX)
	return s


func _skip() -> void:
	Game.finish_tutorial2()


## Победа: вместо итога боя — износ, ресурсы и превращение карты.
func _show_end() -> void:
	view.clear_preview()
	Audio.play(&"victory")
	if _step_panel:
		_step_panel.visible = false
	_codex_run = RunState.create(db, 3)
	# Летописцы ходили в бой и износились: прочность 1 — угаснут после следующего боя.
	_codex_run.codex.cards[2].durability = 1
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.ACCENT, 3, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_end_panel.add_child(box)
	box.add_child(UiKit.label(tr("TUT2_AFTER_TITLE"), 40, UiKit.ACCENT))
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 14)
	res.add_child(UiKit.label(tr("TUT2_AFTER_REWARD"), 20, UiKit.MUTED))
	res.add_child(UiKit.resource_row(MapActions.battle_rewards(db.encounter(&"crypt_1")), true, 20))
	box.add_child(res)
	_rework_text = UiKit.label(tr("TUT2_AFTER_TEXT"), 20, Color(0.9, 0.88, 0.82))
	_rework_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rework_text.custom_minimum_size = Vector2(1100, 0)
	box.add_child(_rework_text)
	_rework = ReworkPanel.new()
	_rework.setup(db, _codex_run)
	_rework.confirmed.connect(_on_rework)
	box.add_child(_rework)
	var skip := UiKit.button(tr("TUT_SKIP"), _skip, 300)
	box.add_child(skip)
	add_child(_end_panel)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Учим именно заклинанию: другие формы — подсказка; заклинание — дальше, на карту.
func _on_rework(card_index: int, form: CodexOps.Form) -> void:
	if form != CodexOps.Form.SPELL:
		_rework_text.text = tr("TUT2_AFTER_WRONG")
		return
	var charges := CodexOps.spell_charges(_codex_run.codex.cards[card_index])
	CodexOps.apply(db, _codex_run, card_index, form)
	_rework.queue_free()
	_rework_text.text = tr("TUT2_AFTER_DONE") % charges
	var go := UiKit.button(tr("TUT2_TO_MAP"), Game.goto.bind(Game.SCENE_TUTORIAL_MAP), 360)
	_rework_text.get_parent().add_child(go)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
