extends "res://scripts/presentation/battle_screen.gd"
## Учебный бой-пролог (SPEC_SPRINT10 8): малое поле, три отряда игрока против часового, который только защищается.
## Задания по шагам — плашкой сверху; на шаге разрешены только нужные действия, неверное — подсказка
## повторяется. После «Метки» враг слабеет — его остаётся добить. Пропуск — кнопкой.

const FIELD := Vector2i(7, 5)
const ENEMY_HEX := Vector2i(5, 2)
## Шаги: задание (ключ TUT_STEP_*), чей ход ожидается, какие действия разрешены. Последний — свободный.
const STEPS := [
	{"key": "TUT_STEP_MOVE", "unit": &"salt_guard", "types": [BattleAction.Type.MOVE]},
	{"key": "TUT_STEP_SHOOT", "unit": &"chronicler", "types": [BattleAction.Type.SHOOT]},
	{"key": "TUT_STEP_WAIT", "unit": &"ash_ghoul", "types": [BattleAction.Type.WAIT]},
	{"key": "TUT_STEP_DEFEND", "unit": &"ash_ghoul", "types": [BattleAction.Type.DEFEND]},
	{"key": "TUT_STEP_HERO", "unit": &"salt_guard", "types": [BattleAction.Type.HERO]},
	{"key": "TUT_STEP_MELEE", "unit": &"salt_guard", "types": [BattleAction.Type.MELEE]},
	{"key": "TUT_STEP_ABILITY", "unit": &"chronicler", "types": [BattleAction.Type.ABILITY]},
	{"key": "TUT_STEP_FINISH", "unit": &"", "types": []},
]
## Учебный враг: прочный и почти безобидный (ответный удар ощутим, но не губителен).
const ENEMY_HP := 60
const ENEMY_COUNT := 10

var step := 0
var _step_panel: PanelContainer
var _step_label: Label
var _warn_label: Label


func _ready() -> void:
	Hints.suppressed = true
	super._ready()
	_build_step_panel()
	_update_step()


func _exit_tree() -> void:
	Hints.suppressed = false
	super._exit_tree()


## Поле 7 × 5: Страж (ближний бой), Летописцы (стрелки, способность «Метка»), Гули; враг — часовой.
func _make_state() -> BattleState:
	var s := BattleState.new()
	s.grid.width = FIELD.x
	s.grid.height = FIELD.y
	s.rng.seed = 7
	for id in db.abilities:
		s.ability_cooldowns[id] = db.abilities[id].cooldown
	s.hero_orders = db.base_orders.duplicate()
	var units := [[&"salt_guard", 12, Vector2i(0, 2), 9], [&"chronicler", 10, Vector2i(0, 0), 8], [&"ash_ghoul", 10, Vector2i(0, 4), 7]]
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
	def.ability_id = &""
	s.add_unit(def, UnitState.Side.ENEMY, ENEMY_COUNT, ENEMY_HEX)
	return s


## Учебный враг только защищается.
func _enemy_action() -> BattleAction:
	return BattleAction.defend()


## Действие игрока проходит, только если это действие текущего шага (или шаг не про этот отряд).
func _player_act(action: BattleAction) -> void:
	if action != null and not allowed(action):
		_warn_label.text = tr("TUT_WRONG")
		Audio.play(&"ui_click")
		return
	super._player_act(action)


func allowed(action: BattleAction) -> bool:
	if step >= STEPS.size() - 1:
		return true
	var s: Dictionary = STEPS[step]
	var u := state.active_unit()
	if u == null or u.def_id != s["unit"]:
		return true
	return (s["types"] as Array).has(action.type)


## После действия игрока — следующий шаг; перед последним враг слабеет.
func _execute(action: BattleAction) -> void:
	var u := state.active_unit()
	var players := u != null and u.side == UnitState.Side.PLAYER
	await super._execute(action)
	if players and step < STEPS.size() - 1 and (STEPS[step]["types"] as Array).has(action.type):
		step += 1
		if step == STEPS.size() - 1:
			_weaken_enemy()
		_update_step()


func _weaken_enemy() -> void:
	for e in state.alive(UnitState.Side.ENEMY):
		e.count = 1
		e.top_hp = mini(e.top_hp, 10)
	view.sync()


## Подсказки боя заменены заданиями.
func _show_turn_hints() -> void:
	_update_step()


func _build_step_panel() -> void:
	_step_panel = PanelContainer.new()
	_step_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.09, 0.13, 0.95), UiKit.ACCENT, 2, true))
	_step_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_step_panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_step_label = UiKit.label("", 22, UiKit.ACCENT)
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_label.custom_minimum_size = Vector2(620, 0)
	col.add_child(_step_label)
	_warn_label = UiKit.label("", 16, UiKit.DANGER)
	col.add_child(_warn_label)
	var skip := UiKit.button(tr("TUT_SKIP"), Game.finish_tutorial, 260)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(skip)
	add_child(_step_panel)
	# Между полем и кнопками действий: малое поле занимает верх экрана, кнопки не перекрываются.
	_step_panel.anchor_left = 0.35
	_step_panel.anchor_right = 0.35
	_step_panel.anchor_top = 1.0
	_step_panel.anchor_bottom = 1.0
	_step_panel.offset_top = -450
	_step_panel.offset_bottom = -340
	_step_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _update_step() -> void:
	if _step_label == null:
		return
	_step_label.text = "%s %d/%d. %s" % [tr("TUT_STEP"), mini(step + 1, STEPS.size()), STEPS.size(), tr(STEPS[step]["key"])]
	_warn_label.text = ""


## Конец учебного боя: что дальше и кнопка к выбору школы (или в меню, если обучение запущено оттуда).
func _show_end() -> void:
	view.clear_preview()
	Audio.play(&"victory")
	if _step_panel:
		_step_panel.visible = false
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.ACCENT, 3, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_panel.add_child(box)
	var title := UiKit.label(tr("TUT_DONE_TITLE"), 48, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := UiKit.label(tr("TUT_DONE_TEXT"), 20, Color(0.9, 0.88, 0.82))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(620, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var go := UiKit.button(tr("TUT_DONE_MENU") if Game.tutorial_from_menu else tr("TUT_DONE_NEXT"), Game.finish_tutorial, 360)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(go)
	add_child(_end_panel)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
