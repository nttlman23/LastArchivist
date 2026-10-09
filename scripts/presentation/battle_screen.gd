extends Control
## Экран боя: связывает BattleState, BattleView, ввод игрока, панель Архивариуса и AI.

const BOARD_TOP := 140.0
const AI_DELAY := 0.35
const LOG_LINES := 8
const QUEUE_SLOT := 60.0
const QUEUE_ACTIVE_SLOT := 76.0
const BUTTON_HEIGHT := 46.0
const NO_HEX := Vector2i(-1, -1)

var db: DefsDB
var state: BattleState
var view: BattleView

var _busy := true
var _pending: BattleAction
var _hover_key := ""
## Режим прицеливания: {"label": String, "options": Array[BattleAction]} или пусто.
var _targeting: Dictionary = {}
var _queue: QueueStrip
var _round_label: Label
var _status_label: Label
var _active_panel: UnitInfoPanel
var _hover_panel: UnitInfoPanel
## Цель боя и командир врага (SPEC_SPRINT5 10–11).
var _battle_info: PanelContainer
var _objective_box: HBoxContainer
var _commander_box: HBoxContainer
var _intent_box: HBoxContainer
var _preview_label: Label
## Короткое превью значками (в режиме «подробно» вместо него — текст в _preview_label).
var _preview_box: HBoxContainer
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _ability_btn: Button
var _wait_btn: Button
var _defend_btn: Button
var _hero_label: Label
var _hero_box: HBoxContainer
## Зоны угрозы врагов на текущий ход игрока (SPEC_SPRINT5 2): uid -> ThreatMap.Zone.
var _enemy_zones: Dictionary[int, ThreatMap.Zone] = {}
## Действия героя в порядке кнопок (горячие клавиши 1–9): [id, slot].
var _hero_entries: Array = []
## Подписи состояния панелей — пересборка только при изменениях.
var _hero_key := ""
var _info_key := ""
var _end_panel: PanelContainer


func _ready() -> void:
	db = Game.defs
	if Game.run == null:
		# Запуск сцены напрямую из редактора — тестовый забег, первый бой карты.
		Game.run = RunState.create(db, 1)
		Game.selected = [0, 1, 2, 3]
		MapActions.travel(Game.run, Game.run.map.next_of(MapState.START)[0])
	var run := Game.run
	state = BattleSetup.for_run(db, run, Game.selected)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Audio.play_music(Game.battle_music(state))
	# Фон боя — цвет очистки кадра (Game), отдельный прямоугольник на весь экран не нужен.
	if Settings.effects_full:
		add_child(UiKit.ambient_ash(self))
	# Рисованный пол: первый акт (SPEC_SPRINT9 4), Затопленные хранилища (этап B, раздел 18).
	var floor_tex := ArtDB.background(&"battle_act2" if state.biome == &"flooded" else &"battle_act1")
	if floor_tex:
		add_child(UiKit.art_background(floor_tex, 0.6))
		move_child(get_child(get_child_count() - 1), 0)
	view = BattleView.new()
	view.art_floor = floor_tex != null
	add_child(view)
	view.setup(state, db)
	view.event_label = _event_label
	_build_hud()
	resized.connect(_layout)
	_layout()

	var events := BattleResolver.begin(state)
	# Начало боя может добавить стеки (иллюзия «Масок») — показать их сразу.
	view.sync()
	_log_events(events)
	_show_objective_banner()
	_run_turns()


## Плашка цели боя при входе; затем цель видна в панели справа.
func _show_objective_banner() -> void:
	if state.objective == ObjectiveRule.ELIMINATE and state.commander_id == &"":
		return
	if state.objective != ObjectiveRule.ELIMINATE:
		Hints.show_hint(&"objective")
	if state.commander_id != &"":
		Hints.show_hint(&"commander")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.OBJECTIVE_COLOR, 2, true))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	col.add_child(UiKit.label(tr("OBJ_BANNER"), 18, UiKit.MUTED))
	col.add_child(UiKit.objective_chip(state.objective, state.objective_rounds, "", 30))
	if state.commander_id != &"":
		col.add_child(UiKit.commander_chip(db, state.commander_id, 22))
	add_child(panel)
	panel.reset_size()
	panel.position = Vector2((size.x - 420.0 - panel.size.x) * 0.5, BOARD_TOP + 220.0)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


## Полоса ОЗ босса второго акта с отметкой половины — порога второй фазы (SPEC_SPRINT7 6).
func _boss_bar(hp: int, full: int) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(320, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var share := clampf(float(hp) / float(maxi(1, full)), 0.0, 1.0)
	var mark := state.boss_phase_share
	var phase2 := state.boss_phase >= 2
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r, Color(0, 0, 0, 0.45))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * share, r.size.y)), BattleView.RIFT_COLOR.darkened(0.25 if phase2 else 0.0))
		var x := r.size.x * mark
		bar.draw_line(Vector2(x, -3), Vector2(x, r.size.y + 3), UiKit.ACCENT if not phase2 else UiKit.MUTED, 2.0)
		bar.draw_rect(r, Color(1, 1, 1, 0.35), false, 1.0))
	Tip.attach(bar, tr("BOSS_BAR"), tr("BOSS_PHASE_TIP"))
	return bar


## Плашка второй фазы босса: что изменилось на поле.
func _show_phase_banner(uid: int) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, BattleView.RIFT_COLOR, 2, true))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	col.add_child(UiKit.label(tr("BOSS_PHASE_BANNER") % _name(uid), 28, BattleView.RIFT_COLOR))
	col.add_child(UiKit.label(tr("BOSS_PHASE_BANNER_TEXT"), 18, UiKit.MUTED))
	add_child(panel)
	panel.reset_size()
	panel.position = Vector2((size.x - 420.0 - panel.size.x) * 0.5, BOARD_TOP + 220.0)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func _layout() -> void:
	var board := view.board_size()
	var free_width := size.x - 420.0
	view.position = Vector2(maxf(20.0, (free_width - board.x) * 0.5) + HexGrid.SQRT3 * BattleView.HEX_SIZE * 0.5, BOARD_TOP + BattleView.HEX_SIZE)


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(24, 16)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	_round_label = UiKit.label("", 28, UiKit.ACCENT)
	_round_label.custom_minimum_size = Vector2(150, 0)
	_round_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_round_label)
	_queue = QueueStrip.new()
	_queue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue.mouse_filter = Control.MOUSE_FILTER_STOP
	_queue.hovered.connect(_on_queue_hover)
	_queue.tooltip_text = "queue"
	top.add_child(_queue)

	_status_label = UiKit.label("", 26)
	_status_label.position = Vector2(24, 98)
	add_child(_status_label)

	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -400
	side.offset_right = -20
	side.offset_top = 16
	side.offset_bottom = -16
	side.add_theme_constant_override("separation", 10)
	add_child(side)
	_battle_info = PanelContainer.new()
	_battle_info.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR))
	var info_col := VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 6)
	_battle_info.add_child(info_col)
	_objective_box = HBoxContainer.new()
	info_col.add_child(_objective_box)
	_commander_box = HBoxContainer.new()
	_commander_box.add_theme_constant_override("separation", 10)
	info_col.add_child(_commander_box)
	_intent_box = HBoxContainer.new()
	info_col.add_child(_intent_box)
	side.add_child(_battle_info)
	_active_panel = UnitInfoPanel.new()
	side.add_child(_active_panel)
	_hover_panel = UnitInfoPanel.new()
	_hover_panel.compact = true
	_hover_panel.visible = false
	side.add_child(_hover_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 120)
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.PANEL_COLOR))
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_log)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -440
	bottom.offset_top = -178
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 16)
	bottom.add_child(preview_row)
	_preview_label = UiKit.label("", 22, UiKit.ACCENT)
	preview_row.add_child(_preview_label)
	_preview_box = HBoxContainer.new()
	_preview_box.add_theme_constant_override("separation", 16)
	preview_row.add_child(_preview_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)
	_ability_btn = _small_button("", _on_ability, 330)
	row.add_child(_ability_btn)
	_wait_btn = _small_button(tr("BATTLE_WAIT"), _on_wait, 170)
	_wait_btn.icon = IconAtlas.get_icon(UnitGlyphs.ICON_WAIT)
	Tip.attach(_wait_btn, tr("CHIP_WAITED"), tr("STATUS_WAITED"), UnitGlyphs.ICON_WAIT)
	row.add_child(_wait_btn)
	_defend_btn = _small_button(tr("BATTLE_DEFEND"), _on_defend, 170)
	_defend_btn.icon = IconAtlas.get_icon(UnitGlyphs.ICON_DEFEND)
	Tip.attach(_defend_btn, tr("CHIP_DEFENDING"), tr("STATUS_DEFENDING"), UnitGlyphs.ICON_DEFEND)
	row.add_child(_defend_btn)
	row.add_child(_small_button(tr("BATTLE_RETREAT"), Game.abandon_node, 170))

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 10)
	bottom.add_child(hero_row)
	_hero_label = UiKit.label("", 18, UiKit.MUTED)
	_hero_label.custom_minimum_size = Vector2(250, 0)
	_hero_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_row.add_child(_hero_label)
	_hero_box = HBoxContainer.new()
	_hero_box.add_theme_constant_override("separation", 8)
	hero_row.add_child(_hero_box)


func _small_button(text: String, on_pressed: Callable, width: float) -> Button:
	var b := UiKit.button(text, on_pressed, int(width))
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.focus_mode = Control.FOCUS_NONE
	return b


func _refresh_hud() -> void:
	_round_label.text = tr("BATTLE_ROUND") % state.round_number
	_refresh_battle_info()
	var upcoming: Array[int] = []
	if state.active_uid >= 0:
		upcoming.append(state.active_uid)
	upcoming.append_array(TurnManager.upcoming(state))
	var slots: Array[Dictionary] = []
	for uid in upcoming:
		slots.append(_queue_slot(uid, uid == state.active_uid, false))
	for uid in TurnManager.next_round_order(state):
		slots.append(_queue_slot(uid, false, true))
	_queue.set_slots(slots, tr("QUEUE_NEXT_ROUND") % (state.round_number + 1))

	var u := state.active_unit()
	var player_turn := _is_player_turn()
	_wait_btn.disabled = not player_turn or u.waited
	_defend_btn.disabled = not player_turn
	_refresh_ability_button(u, player_turn)
	_refresh_hero_panel()
	if u == null or state.outcome != BattleState.Outcome.NONE:
		_status_label.text = ""
		_active_panel.visible = false
		return
	var side_color := UiKit.PLAYER_COLOR if player_turn else UiKit.ENEMY_COLOR
	_status_label.text = (tr("BATTLE_YOUR_TURN") if player_turn else tr("BATTLE_ENEMY_TURN")) % UiKit.unit_name(db, u.def_id)
	_status_label.add_theme_color_override("font_color", side_color)
	_active_panel.show_unit(db, u, tr("INFO_ACTIVE"), UiKit.ACTIVE_BORDER)


## Цель с прогрессом и намерение командира (значок, действие, цель).
func _refresh_battle_info() -> void:
	_battle_info.visible = state.objective != ObjectiveRule.ELIMINATE or state.commander_id != &"" 			or (state.biome == &"flooded" and state.boss_uid >= 0)
	var boss := state.get_unit(state.boss_uid)
	var boss_hp := boss.total_hp() if boss else 0
	var key := "%s|%s|%s|%s|%s|%s" % [state.round_number, state.hold_count, state.intent, state.get_unit(int(state.intent.get("target", -1))) != null, boss_hp, state.boss_phase]
	if key == _info_key or not _battle_info.visible:
		return
	_info_key = key
	for child in _objective_box.get_children():
		child.queue_free()
	for child in _commander_box.get_children():
		child.queue_free()
	for child in _intent_box.get_children():
		child.queue_free()
	var progress := ""
	match state.objective:
		ObjectiveRule.SURVIVE, ObjectiveRule.PROTECT:
			progress = tr("OBJ_PROGRESS_ROUNDS") % [mini(state.round_number, state.objective_rounds), state.objective_rounds]
		ObjectiveRule.HOLD:
			progress = tr("OBJ_PROGRESS_HOLD") % [state.hold_count, state.objective_rounds]
	# У босса второго акта цель — он сам: вместо «Уничтожить всех» — его ОЗ и фаза.
	if not (state.objective == ObjectiveRule.ELIMINATE and boss and state.biome == &"flooded"):
		_objective_box.add_child(UiKit.objective_chip(state.objective, state.objective_rounds, progress, 19))
	# Босс второго акта: ОЗ и фаза (вторая — с половины ОЗ).
	if boss and state.biome == &"flooded":
		var full := boss.start_count * boss.hp
		_objective_box.add_child(UiKit.chip(UnitGlyphs.ICON_HP, "%d/%d · %s" % [boss_hp, full, tr("BOSS_PHASE") % state.boss_phase],
				BattleView.RIFT_COLOR, UiKit.unit_name(db, boss.def_id), tr("BOSS_PHASE_TIP"), 17))
		_objective_box.add_child(_boss_bar(boss_hp, full))
	if state.commander_id == &"":
		return
	_commander_box.add_child(UiKit.commander_chip(db, state.commander_id, 17))
	var def := db.commander(state.commander_id)
	if state.intent.is_empty():
		_intent_box.add_child(UiKit.label(tr("COMMANDER_IDLE"), 16, UiKit.MUTED))
		return
	var id := StringName(state.intent["action"])
	var what := tr("CMDACT_" + String(id).to_upper())
	var target := state.get_unit(int(state.intent.get("target", -1)))
	if target:
		what += " → " + UiKit.unit_name(db, target.def_id)
	_intent_box.add_child(UiKit.chip(CommanderActions.ICONS.get(id, UnitGlyphs.ICON_SPELL), what, def.color,
			tr("COMMANDER_INTENT") % tr("CMDACT_" + String(id).to_upper()),
			tr("CMDACT_" + String(id).to_upper() + "_DESC") + "\n" + tr("COMMANDER_INTENT_TIP"), 16))


func _queue_slot(uid: int, is_active: bool, next: bool) -> Dictionary:
	var u := state.get_unit(uid)
	return {
		"uid": uid, "def": u.def_id, "color": db.unit(u.def_id).color, "side": u.side, "count": u.count,
		"size": QUEUE_ACTIVE_SLOT if is_active else QUEUE_SLOT, "active": is_active, "next": next,
		"name": UiKit.unit_name(db, u.def_id),
	}


## Наведение на портрет очереди подсвечивает стек на поле.
func _on_queue_hover(uid: int) -> void:
	view.highlight_uid = uid
	_queue.set_highlight(uid)
	view.refresh_highlights()


## Подсветка портретов стека в очереди (наведение на поле).
func _highlight_queue(uid: int) -> void:
	_queue.set_highlight(uid)


func _refresh_ability_button(u: UnitState, player_turn: bool) -> void:
	if u == null or u.ability_id == &"" or not player_turn:
		_ability_btn.text = tr("HUD_NO_ABILITY")
		_ability_btn.disabled = true
		Tip.attach(_ability_btn, "", "")
		return
	var ab := db.ability(u.ability_id)
	var title := tr(ab.name_key)
	if u.ability_id == Abilities.ECHO:
		var copied := Abilities.effective(state, u)
		title = tr("HUD_ECHO_OF") % (tr(db.ability(copied).name_key) if copied != &"" else tr("HUD_ECHO_NOTHING"))
	if u.ability_cd > 0:
		_ability_btn.text = tr("HUD_ABILITY_CD") % [title, u.ability_cd]
	else:
		_ability_btn.text = tr("HUD_ABILITY") % title
	_ability_btn.disabled = Abilities.options(state, u).is_empty()
	_ability_btn.icon = IconAtlas.get_icon(UnitGlyphs.ICON_ABILITY)
	_ability_btn.add_theme_constant_override("icon_max_width", 22)
	Tip.attach(_ability_btn, title, tr(ab.desc_key), UnitGlyphs.ICON_ABILITY, UiKit.ACCENT)


func _refresh_hero_panel() -> void:
	var can_act := not _busy and state.can_hero_act()
	# Пересборка кнопок — только при изменениях: новые кнопки и надписи стоят заметного времени
	# раскладки при программной отрисовке (SPEC_SPRINT6 11).
	var key := "%s|%s|%s|%s" % [can_act, state.hero_actions_left, state.hero_orders, state.spell_charges()]
	if key == _hero_key:
		return
	_hero_key = key
	for child in _hero_box.get_children():
		child.queue_free()
	_hero_entries.clear()
	if state.hero_actions_left > 0:
		_hero_label.text = tr("HUD_HERO_READY")
		_hero_label.add_theme_color_override("font_color", UiKit.ACCENT)
	else:
		_hero_label.text = tr("HUD_HERO_USED")
		_hero_label.add_theme_color_override("font_color", UiKit.MUTED)
	for id in state.hero_orders:
		_hero_entries.append([id, -1])
	for slot in state.hero_spells.size():
		if int(state.hero_spells[slot]["charges"]) > 0:
			_hero_entries.append([StringName(state.hero_spells[slot]["spell_id"]), slot])
	for i in _hero_entries.size():
		var id: StringName = _hero_entries[i][0]
		var slot: int = _hero_entries[i][1]
		var text: String
		var tooltip: String
		if slot < 0:
			text = tr("HUD_ORDER") % [tr(db.order(id).name_key), i + 1]
			tooltip = tr(db.order(id).desc_key)
		else:
			text = tr("HUD_SPELL") % [tr(db.spell(id).name_key), int(state.hero_spells[slot]["charges"]), i + 1]
			tooltip = tr(db.spell(id).desc_key)
		var b := _small_button(text, _on_hero.bind(i), 0)
		b.custom_minimum_size.x = 0
		b.icon = IconAtlas.get_icon(UnitGlyphs.ICON_ORDER if slot < 0 else UnitGlyphs.ICON_SPELL)
		b.add_theme_constant_override("icon_max_width", 20)
		Tip.attach(b, tr(db.order(id).name_key) if slot < 0 else tr(db.spell(id).name_key), tooltip,
				UnitGlyphs.ICON_ORDER if slot < 0 else UnitGlyphs.ICON_SPELL)
		b.disabled = not can_act or HeroActions.options(state, id, slot).is_empty()
		if slot >= 0:
			b.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
		_hero_box.add_child(b)


# --- Ход боя -----------------------------------------------------------------

func _is_player_turn() -> bool:
	var u := state.active_unit()
	return u != null and u.side == UnitState.Side.PLAYER and state.outcome == BattleState.Outcome.NONE


func _run_turns() -> void:
	_busy = true
	_enemy_zones = {}
	view.threatened = {}
	view.enemy_intents = {}
	view._redraw_units()
	while state.outcome == BattleState.Outcome.NONE and not _is_player_turn():
		_refresh_hud()
		await get_tree().create_timer(AI_DELAY).timeout
		await _execute(AiController.choose_action(state, state.active_uid))
	if state.outcome != BattleState.Outcome.NONE:
		_refresh_hud()
		_show_end()
		return
	_busy = false
	_refresh_hud()
	Audio.play(&"turn")
	_show_turn_hints()
	view.reachable = Pathfinding.reachable(state, state.active_unit())
	view.dim_unreachable = true
	_compute_threats()
	_invalidate_hover()
	_update_hover()


## Зоны угрозы всех врагов и свои стеки под ударом — один раз на ход игрока.
func _compute_threats() -> void:
	_enemy_zones = ThreatMap.zones(state, UnitState.Side.ENEMY)
	var threatened: Dictionary[int, bool] = {}
	for u in state.alive(UnitState.Side.PLAYER):
		if not ThreatMap.attackers_of(state, _enemy_zones, u, true).is_empty():
			threatened[u.uid] = true
	view.threatened = threatened
	_predict_intents.call_deferred()
	if not threatened.is_empty():
		Hints.show_hint(&"threat")


## Намерения врагов — на следующем кадре, чтобы расчёт не складывался с началом хода в один кадр.
func _predict_intents() -> void:
	if not _is_player_turn() or _busy:
		return
	view.enemy_intents = EnemyIntents.predict(state)
	view._redraw_units()
	_invalidate_hover()
	_update_hover()


func _show_turn_hints() -> void:
	Hints.show_hint(&"battle")
	var u := state.active_unit()
	if u.ability_ready() and not Abilities.options(state, u).is_empty():
		Hints.show_hint(&"ability")
	if state.can_hero_act() and not _hero_entries.is_empty():
		Hints.show_hint(&"hero")


func _execute(action: BattleAction) -> void:
	_pending = null
	_targeting = {}
	_invalidate_hover()
	view.clear_preview()
	view.show_active = false
	_set_preview("", [])
	var events := BattleResolver.apply(state, action)
	_log_events(events)
	# Вторая фаза босса — плотнее музыка (play_music не перезапускает тот же трек).
	Audio.play_music(Game.battle_music(state))
	await view.play(events)
	view.show_active = true


## Действие игрока: отряда (передаёт ход) или героя (ход остаётся у отряда).
func _player_act(action: BattleAction) -> void:
	if _busy or not _is_player_turn() or action == null or not BattleResolver.validate(state, action):
		return
	_busy = true
	await _execute(action)
	_run_turns()


func _on_wait() -> void:
	_player_act(BattleAction.wait())


func _on_defend() -> void:
	_player_act(BattleAction.defend())


func _on_ability() -> void:
	if _busy or not _is_player_turn():
		return
	var u := state.active_unit()
	var label := tr(db.ability(u.ability_id).name_key)
	_begin_targeting(label, Abilities.options(state, u))


func _on_hero(index: int) -> void:
	if _busy or index >= _hero_entries.size() or not state.can_hero_act():
		return
	var id: StringName = _hero_entries[index][0]
	var slot: int = _hero_entries[index][1]
	var label := tr(db.order(id).name_key) if slot < 0 else tr(db.spell(id).name_key)
	_begin_targeting(label, HeroActions.options(state, id, slot))


## Без цели — выполняется сразу; иначе включается выбор цели на поле.
func _begin_targeting(label: String, options: Array[BattleAction]) -> void:
	if options.is_empty():
		return
	if options.size() == 1 and options[0].target_uid < 0 and options[0].dest == NO_HEX:
		_player_act(options[0])
		return
	_targeting = {"label": label, "options": options}
	Hints.show_hint(&"targeting")
	var hexes: Dictionary[Vector2i, bool] = {}
	for a in options:
		var u := state.get_unit(a.target_uid)
		hexes[u.hex if u else a.dest] = true
	view.targets = hexes
	view.reachable = {}
	view.dim_unreachable = false
	_invalidate_hover()
	_update_hover()


func _cancel_targeting() -> void:
	if _targeting.is_empty():
		return
	_targeting = {}
	view.targets = {}
	view.affected = {}
	if _is_player_turn():
		view.reachable = Pathfinding.reachable(state, state.active_unit())
		view.dim_unreachable = true
	_invalidate_hover()
	_update_hover()


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_update_hover()
			_player_act(_pending)
	elif event is InputEventKey and event.keycode == KEY_ALT and not event.echo:
		_update_hover()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				_on_wait()
			KEY_D:
				_on_defend()
			KEY_Q:
				_on_ability()
			KEY_ESCAPE:
				_cancel_targeting()
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_9:
					_on_hero(event.keycode - KEY_1)


func _update_hover() -> void:
	if state == null:
		return
	var local := view.get_local_mouse_position()
	var hex := view.hex_at(local)
	var can_act := not _busy and _is_player_turn()
	var pending: BattleAction = null
	if can_act:
		pending = _target_at(local, hex) if not _targeting.is_empty() else _action_at(local, hex)
	var icon: StringName = &""
	if pending:
		icon = _CURSOR_ICONS.get(pending.type, &"") if _targeting.is_empty() else UnitGlyphs.ICON_SPELL
	view.set_cursor(icon, local)
	# Мышь шлёт много событий за кадр: пересобираем подсветку и карточки, только если что-то изменилось.
	var alt := Input.is_key_pressed(KEY_ALT)
	var key := "%s|%s|%s|%s|%s" % [hex, pending, can_act, not _targeting.is_empty(), alt]
	if key == _hover_key:
		return
	_hover_key = key
	_pending = pending

	view.hover_hex = hex
	var hovered: UnitState = state.unit_at(hex) if hex.x >= 0 else null
	var active := state.active_unit()
	if hovered and hovered != active:
		_hover_panel.show_unit(db, hovered, tr("INFO_HOVER"))
	else:
		_hover_panel.visible = false
	_highlight_queue(hovered.uid if hovered else -1)

	view.preview_path = []
	view.preview_target = -1
	view.threat = {}
	view.threat_attack = {}
	view.shot_targets = {}
	view.heat = {}
	view.affected = {}
	view.intent_hover = -1
	view.intent_arrows_all = alt
	_set_preview("", [])
	if not _targeting.is_empty():
		_set_preview(tr("TARGET_PROMPT") % _targeting["label"], [], tr("TARGET_PROMPT_SHORT") % _targeting["label"])
		if _pending:
			_show_target_preview(_pending)
	else:
		if alt and not _enemy_zones.is_empty():
			view.heat = ThreatMap.heat(_enemy_zones)
		elif hovered and hovered.side == UnitState.Side.ENEMY and _enemy_zones.has(hovered.uid):
			_show_enemy_threat(hovered)
		if _pending:
			_show_preview(_pending)
		elif hovered and hovered.side == UnitState.Side.PLAYER and not _enemy_zones.is_empty():
			_show_threat_to(hovered)
	view.refresh_highlights()


## Наведение на врага: куда дойдёт, кого ударит, в кого может выстрелить.
func _show_enemy_threat(enemy: UnitState) -> void:
	var z := _enemy_zones[enemy.uid]
	view.threat = z.move
	view.threat_attack = z.melee
	view.shot_targets = ThreatMap.shot_targets(state, enemy)
	view.intent_hover = enemy.uid
	# Предполагаемое действие врага — чипом в строке превью.
	var it: Dictionary = view.enemy_intents.get(enemy.uid, {})
	if it.is_empty() or _pending:
		return
	var what := tr("INTENT_" + BattleAction.Type.keys()[int(it["type"])])
	var target := state.get_unit(int(it["target"]))
	if target:
		what += " → " + UiKit.unit_name(db, target.def_id)
	_set_preview(tr("INTENT_LONG") % what, [[BattleView.INTENT_ICONS.get(int(it["type"]), UnitGlyphs.ICON_MOVE), what, BattleView.THREAT_COLOR.lightened(0.2), tr("INTENT_TIP")]])


## Наведение на свой стек: кто из врагов его достаёт и сколько урона в худшем случае.
func _show_threat_to(u: UnitState) -> void:
	var attackers := ThreatMap.attackers_of(state, _enemy_zones, u)
	if attackers.is_empty():
		return
	var affected: Dictionary[int, bool] = {}
	for uid in attackers:
		affected[uid] = false
	view.affected = affected
	var d := ThreatMap.damage_to(state, _enemy_zones, u)
	_set_preview(tr("PREVIEW_THREAT") % [attackers.size(), d.x, d.y, d.z], [
		[UnitGlyphs.ICON_THREAT, str(attackers.size()), UiKit.DANGER, tr("PREVIEW_TIP_THREAT")],
		[UnitGlyphs.ICON_MELEE, "%d–%d" % [d.x, d.y], UiKit.ACCENT, tr("PREVIEW_TIP_THREAT_DAMAGE")],
		[UnitGlyphs.ICON_KILL, "≤%d" % d.z, UiKit.DANGER, tr("PREVIEW_TIP_THREAT_KILLS")],
	])


## Сбрасывает кэш наведения после изменения состояния боя.
func _invalidate_hover() -> void:
	_hover_key = ""


const _CURSOR_ICONS := {
	BattleAction.Type.MOVE: UnitGlyphs.ICON_MOVE,
	BattleAction.Type.MELEE: UnitGlyphs.ICON_MELEE,
	BattleAction.Type.SHOOT: UnitGlyphs.ICON_RANGED,
}


func _action_at(local: Vector2, hex: Vector2i) -> BattleAction:
	if hex.x < 0:
		return null
	var u := state.active_unit()
	var target := state.unit_at(hex)
	if target and target.side != u.side:
		if u.can_shoot() and not state.is_blocked(u):
			return BattleAction.shoot(target.uid)
		return _melee_from_cursor(u, target, local)
	if view.reachable.has(hex):
		return BattleAction.move(hex)
	return null


## Вариант прицеливания под курсором: по стеку на клетке или по самой клетке.
func _target_at(local: Vector2, hex: Vector2i) -> BattleAction:
	if hex.x < 0:
		return null
	var unit := state.unit_at(hex)
	for a: BattleAction in _targeting["options"]:
		if a.target_uid >= 0:
			if unit and a.target_uid == unit.uid:
				return a
		elif a.dest == hex:
			if a.ref_id == HeroActions.SALT_WALL or a.ref_id == HeroActions.BARRIER:
				# Вторая клетка стены — в сторону курсора.
				var copy := BattleAction.spell(a.slot, a.ref_id, -1, hex,
						HeroActions.salt_wall_second(state, hex, local - view.hex_center(hex)))
				return copy
			return a
	return null


## Сторона атаки определяется положением курсора внутри гекса цели.
func _melee_from_cursor(u: UnitState, target: UnitState, local: Vector2) -> BattleAction:
	var center := view.hex_center(target.hex)
	var dir := (local - center).normalized()
	var best: BattleAction = null
	var best_dot := -INF
	for n in state.grid.neighbors(target.hex):
		if n != u.hex and not view.reachable.has(n):
			continue
		var dot := dir.dot((view.hex_center(n) - center).normalized())
		if dot > best_dot:
			best_dot = dot
			best = BattleAction.melee(n, target.uid)
	return best


## Превью: в режиме «подробно» — полный текст, иначе короткая подпись и чипы [значок, текст, цвет, подсказка].
func _set_preview(text: String, chips: Array, short: String = "") -> void:
	for child in _preview_box.get_children():
		child.queue_free()
	if Settings.detailed:
		_preview_label.text = text
		return
	_preview_label.text = short
	for c in chips:
		_preview_box.add_child(UiKit.chip(c[0], c[1], c[2], c[3], "", 22))


func _damage_chips(icon: StringName, r: Vector2i, target: UnitState) -> Array:
	return [
		[icon, "%d–%d" % [r.x, r.y], UiKit.ACCENT, tr("PREVIEW_TIP_DAMAGE")],
		[UnitGlyphs.ICON_KILL, "%d–%d" % [DamageCalc.kills(target, r.x), DamageCalc.kills(target, r.y)], UiKit.DANGER, tr("PREVIEW_TIP_KILLS")],
	]


func _show_preview(action: BattleAction) -> void:
	if action == null:
		return
	var u := state.active_unit()
	match action.type:
		BattleAction.Type.MOVE:
			view.preview_path = Pathfinding.path(state, u, action.dest)
			_set_preview(tr("BATTLE_PREVIEW_MOVE"), [[UnitGlyphs.ICON_MOVE, str(view.preview_path.size() - 1), UiKit.ACCENT, tr("PREVIEW_TIP_STEPS")]])
		BattleAction.Type.MELEE, BattleAction.Type.SHOOT:
			var target := state.get_unit(action.target_uid)
			var ranged := action.type == BattleAction.Type.SHOOT
			view.preview_target = target.uid
			if not ranged and action.dest != u.hex:
				view.preview_path = Pathfinding.path(state, u, action.dest)
			elif not ranged:
				view.preview_path = [u.hex]
			var r := DamageCalc.damage_range(u, target, ranged)
			var key := "BATTLE_PREVIEW_SHOOT" if ranged else "BATTLE_PREVIEW_MELEE"
			_set_preview(tr(key) % [r.x, r.y, DamageCalc.kills(target, r.x), DamageCalc.kills(target, r.y)],
					_damage_chips(UnitGlyphs.ICON_RANGED if ranged else UnitGlyphs.ICON_MELEE, r, target))


## Превью способности/приказа/заклинания: эффект на цель и кого ещё заденет.
func _show_target_preview(action: BattleAction) -> void:
	var u := state.active_unit()
	var target := state.get_unit(action.target_uid)
	if target:
		view.preview_target = target.uid
	view.affected = _harmed_by(action)
	var label: String = _targeting["label"]
	var text := label
	var chips: Array = []
	if action.is_hero() and action.slot >= 0:
		var power := int(state.hero_spells[action.slot]["power"])
		match action.ref_id:
			HeroActions.ASH_RECORD, HeroActions.CHAIN_SPELL:
				text = tr("PREVIEW_FIXED") % [label, power, DamageCalc.kills(target, power)]
				chips = [[UnitGlyphs.ICON_SPELL, str(power), UiKit.ACCENT, tr("PREVIEW_TIP_DAMAGE")],
						[UnitGlyphs.ICON_KILL, str(DamageCalc.kills(target, power)), UiKit.DANGER, tr("PREVIEW_TIP_KILLS")]]
			HeroActions.HUNGER:
				var heal := mini(power, target.start_count * target.hp - target.total_hp())
				text = tr("PREVIEW_HEAL") % [label, heal]
				chips = [[UnitGlyphs.ICON_HEAL, "+%d" % heal, Color(0.45, 0.95, 0.5), tr("PREVIEW_TIP_HEAL")]]
			HeroActions.SHARD_RAIN:
				text = tr("PREVIEW_AREA") % [label, power]
				chips = [[UnitGlyphs.ICON_SPELL, str(power), UiKit.ACCENT, tr("PREVIEW_TIP_AREA")]]
			_:
				text = tr(db.spell(action.ref_id).desc_key)
	elif action.is_hero():
		text = "%s: %s" % [label, tr(db.order(action.ref_id).desc_key)]
	else:
		var id := Abilities.effective(state, u)
		match id:
			Abilities.DEVOUR, Abilities.SHARD_VOLLEY, Abilities.CHAIN_LIGHTNING, Abilities.RAM:
				var ranged := id != Abilities.DEVOUR and id != Abilities.RAM
				var bonus := 1.0
				if id == Abilities.RAM:
					var dir := HexGrid.line_direction(u.hex, target.hex)
					bonus = Abilities.RAM_BONUS if state.is_free(HexGrid.step(target.hex, dir)) else Abilities.RAM_BLOCKED_BONUS
					view.preview_path = Abilities.ram_path(state, u, target)
				var r := DamageCalc.damage_range(u, target, ranged, bonus)
				text = tr("PREVIEW_DAMAGE") % [label, r.x, r.y, DamageCalc.kills(target, r.x), DamageCalc.kills(target, r.y)]
				chips = _damage_chips(UnitGlyphs.ICON_ABILITY, r, target)
			Abilities.RESTORE:
				var heal := mini(Abilities.RESTORE_AMOUNT, target.start_count * target.hp - target.total_hp())
				text = tr("PREVIEW_HEAL") % [label, heal]
				chips = [[UnitGlyphs.ICON_HEAL, "+%d" % heal, Color(0.45, 0.95, 0.5), tr("PREVIEW_TIP_HEAL")]]
			_:
				text = "%s: %s" % [label, tr(db.ability(id).desc_key)]
	var allies_hit := view.affected.values().count(true)
	if allies_hit > 0:
		text += tr("PREVIEW_ALLIES_HIT") % allies_hit
		chips.append([UnitGlyphs.ICON_RETALIATION_USED, str(allies_hit), UiKit.DANGER, tr("PREVIEW_TIP_ALLIES")])
	_set_preview(text, chips, label)


## Кто потеряет ОЗ от действия (uid -> свой ли), кроме самого действующего стека.
## Считается на копии боя; суммы не показываются, чтобы не раскрывать бросок.
func _harmed_by(action: BattleAction) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	var clone := BattleState.from_dict(state.to_dict())
	var before := {}
	for u in clone.units:
		before[u.uid] = u.total_hp()
	BattleResolver.apply(clone, action)
	for u in clone.units:
		if u.total_hp() < int(before[u.uid]) and (action.is_hero() or u.uid != state.active_uid):
			result[u.uid] = u.side == UnitState.Side.PLAYER
	return result


# --- Лог и конец боя ----------------------------------------------------------

func _event_label(e: BattleEvent) -> String:
	match e.type:
		BattleEvent.RIFT_MARKED:
			return tr("RIFT_MARK_FLOAT")
		BattleEvent.PHASE_CHANGED:
			return tr("BOSS_PHASE_FLOAT")
		BattleEvent.ERASED:
			return tr("RIFT_ERASE_FLOAT")
		BattleEvent.COMMANDER_ACTED:
			return tr("CMDACT_" + String(e.data["action"]).to_upper())
		BattleEvent.ABILITY_USED:
			return tr(db.ability(e.data["ability"]).name_key)
		BattleEvent.HERO_ACTED:
			return _hero_action_name(e.data["action"])
	return ""


func _hero_action_name(id: StringName) -> String:
	if db.orders.has(id):
		return tr(db.order(id).name_key)
	return tr(db.spell(id).name_key)


func _log_events(events: Array[BattleEvent]) -> void:
	for e in events:
		var line := ""
		match e.type:
			BattleEvent.ROUND_STARTED:
				line = "[color=#%s]%s[/color]" % [UiKit.ACCENT.to_html(false), tr("LOG_ROUND") % int(e.data["round"])]
			BattleEvent.ATTACKED:
				var key := "LOG_ATTACK"
				if e.data["ranged"]:
					key = "LOG_SHOOT"
				elif e.data["retaliation"]:
					key = "LOG_RETALIATE"
				line = tr(key) % [_name(e.data["attacker"]), _name(e.data["target"]), int(e.data["damage"]), int(e.data["killed"])]
			BattleEvent.DAMAGED:
				line = tr("LOG_DAMAGED") % [_name(e.data["uid"]), int(e.data["damage"]), int(e.data["killed"])]
			BattleEvent.HEALED:
				line = tr("LOG_HEALED") % [_name(e.data["uid"]), int(e.data["amount"]), int(e.data["revived"])]
			BattleEvent.PUSHED:
				line = tr("LOG_CURRENT" if e.data.get("current", false) else "LOG_PUSHED") % _name(e.data["uid"])
			BattleEvent.PHASE_CHANGED:
				line = "[color=#%s]%s[/color]" % [BattleView.RIFT_COLOR.to_html(false), tr("LOG_BOSS_PHASE") % _name(e.data["uid"])]
				Hints.show_hint(&"flooded")
				_show_phase_banner(int(e.data["uid"]))
			BattleEvent.SUMMONED:
				line = tr("LOG_SUMMONED") % _name(e.data["uid"])
			BattleEvent.COMMANDER_INTENT:
				line = "[color=#%s]%s[/color]" % [_commander_html(), tr("LOG_COMMANDER_INTENT") % tr("CMDACT_" + String(e.data["action"]).to_upper())]
			BattleEvent.COMMANDER_ACTED:
				var act := tr("CMDACT_" + String(e.data["action"]).to_upper())
				if int(e.data["target"]) >= 0:
					act += " → " + _name(e.data["target"])
				line = "[color=#%s]%s[/color]" % [_commander_html(), tr("LOG_COMMANDER_ACTED") % act]
			BattleEvent.OBJECTIVE_PROGRESS:
				line = "[color=#%s]%s[/color]" % [UiKit.OBJECTIVE_COLOR.to_html(false), tr("LOG_OBJECTIVE_PROGRESS") % [int(e.data["count"]), int(e.data["need"])]]
			BattleEvent.ABILITY_USED:
				line = tr("LOG_ABILITY") % [_name(e.data["uid"]), tr(db.ability(e.data["ability"]).name_key)]
			BattleEvent.HERO_ACTED:
				var action_name := _hero_action_name(e.data["action"])
				if int(e.data["target"]) >= 0:
					line = tr("LOG_HERO_TARGET") % [action_name, _name(e.data["target"])]
				else:
					line = tr("LOG_HERO") % action_name
				line = "[color=#c0a0ff]%s[/color]" % line
			BattleEvent.OBSTACLE_ADDED:
				line = tr("LOG_WALL") % int(e.data["rounds"])
			BattleEvent.RIFT_MARKED:
				line = "[color=#c080ff]%s[/color]" % (tr("LOG_RIFT_MARK") % _name(e.data["uid"]))
				Hints.show_hint(&"rift")
			BattleEvent.ERASED:
				line = "[color=#c080ff]%s[/color]" % (tr("LOG_RIFT_ERASE") % _name(e.data["uid"]))
			BattleEvent.DIED:
				line = tr("LOG_DIED") % _name(e.data["uid"])
			BattleEvent.WAITED:
				if Settings.detailed:
					line = tr("LOG_WAIT") % _name(e.data["uid"])
			BattleEvent.DEFENDED:
				if Settings.detailed:
					line = tr("LOG_DEFEND") % _name(e.data["uid"])
			BattleEvent.BATTLE_ENDED:
				if e.data.get("reason", "") == "rounds":
					line = tr("LOG_TIMEOUT")
				elif e.data.get("reason", "") == "erased":
					line = tr("LOG_ALL_ERASED")
				elif e.data.get("reason", "") == "objective":
					line = tr("LOG_OBJECTIVE_WIN")
		if line != "":
			_log_lines.append(line)
	while _log_lines.size() > LOG_LINES:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func _commander_html() -> String:
	return db.commander(state.commander_id).color.to_html(false) if state.commander_id != &"" else "c0a0ff"


func _name(uid: int) -> String:
	var u := state.get_unit(uid)
	var color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	return "[color=#%s]%s[/color]" % [color.to_html(false), UiKit.unit_name(db, u.def_id)]


func _show_end() -> void:
	view.clear_preview()
	var won := state.outcome == BattleState.Outcome.PLAYER_WON
	Audio.play(&"victory" if won else &"defeat")
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.ACCENT, 3, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_panel.add_child(box)
	var title := UiKit.label(tr("BATTLE_WON") if won else tr("BATTLE_LOST"), 56, UiKit.ACCENT if won else UiKit.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.button(tr("BATTLE_CONTINUE"), func() -> void: Game.finish_battle(state.outcome, state.spell_charges(), state.erased_cards, state), 360))
	add_child(_end_panel)
	_end_panel.custom_minimum_size = Vector2(520, 240)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
