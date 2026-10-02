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
var _queue_box: HBoxContainer
var _round_label: Label
var _status_label: Label
var _active_panel: UnitInfoPanel
var _hover_panel: UnitInfoPanel
var _preview_label: Label
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _ability_btn: Button
var _wait_btn: Button
var _defend_btn: Button
var _hero_label: Label
var _hero_box: HBoxContainer
## Действия героя в порядке кнопок (горячие клавиши 1–9): [id, slot].
var _hero_entries: Array = []
var _end_panel: PanelContainer


func _ready() -> void:
	db = Game.defs
	if Game.run == null:
		# Запуск сцены напрямую из редактора — тестовый забег.
		Game.run = RunState.create(db, 1)
		Game.selected = [0, 1, 2, 3]
	var run := Game.run
	var encounter := db.encounter(run.current_encounter_id(db))
	state = BattleState.create(db, encounter, run.codex, Game.selected, run.battle_seed(), run.hero)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.add_background(self)
	view = BattleView.new()
	add_child(view)
	view.setup(state, db)
	view.event_label = _event_label
	_build_hud()
	resized.connect(_layout)
	_layout()

	var events := BattleResolver.begin(state)
	_log_events(events)
	_run_turns()


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
	_queue_box = HBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 6)
	_queue_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_queue_box)

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
	_preview_label = UiKit.label("", 22, UiKit.ACCENT)
	bottom.add_child(_preview_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)
	_ability_btn = _small_button("", _on_ability, 330)
	row.add_child(_ability_btn)
	_wait_btn = _small_button(tr("BATTLE_WAIT"), _on_wait, 170)
	row.add_child(_wait_btn)
	_defend_btn = _small_button(tr("BATTLE_DEFEND"), _on_defend, 170)
	row.add_child(_defend_btn)
	row.add_child(_small_button(tr("BATTLE_RETREAT"), Game.abandon_battle, 170))

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
	for child in _queue_box.get_children():
		child.queue_free()
	var upcoming: Array[int] = []
	if state.active_uid >= 0:
		upcoming.append(state.active_uid)
	upcoming.append_array(TurnManager.upcoming(state))
	for uid in upcoming:
		var is_active := uid == state.active_uid
		var slot := UnitPortrait.create(db, state.get_unit(uid), QUEUE_ACTIVE_SLOT if is_active else QUEUE_SLOT, is_active)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_queue_box.add_child(slot)
	var sep := UiKit.label("│", 40, UiKit.MUTED)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue_box.add_child(sep)
	for uid in TurnManager.next_round_order(state):
		var slot := UnitPortrait.create(db, state.get_unit(uid), QUEUE_SLOT)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.modulate = Color(1, 1, 1, 0.5)
		_queue_box.add_child(slot)

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


func _refresh_ability_button(u: UnitState, player_turn: bool) -> void:
	if u == null or u.ability_id == &"" or not player_turn:
		_ability_btn.text = tr("HUD_NO_ABILITY")
		_ability_btn.disabled = true
		_ability_btn.tooltip_text = ""
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
	_ability_btn.tooltip_text = tr(ab.desc_key)


func _refresh_hero_panel() -> void:
	for child in _hero_box.get_children():
		child.queue_free()
	_hero_entries.clear()
	var can_act := not _busy and state.can_hero_act()
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
		b.tooltip_text = tooltip
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
	view.reachable = Pathfinding.reachable(state, state.active_unit())
	_invalidate_hover()
	_update_hover()


func _execute(action: BattleAction) -> void:
	_pending = null
	_targeting = {}
	_invalidate_hover()
	view.clear_preview()
	view.show_active = false
	_preview_label.text = ""
	var events := BattleResolver.apply(state, action)
	_log_events(events)
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
	var hexes: Dictionary[Vector2i, bool] = {}
	for a in options:
		var u := state.get_unit(a.target_uid)
		hexes[u.hex if u else a.dest] = true
	view.targets = hexes
	view.reachable = {}
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
	var key := "%s|%s|%s|%s" % [hex, pending, can_act, not _targeting.is_empty()]
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

	view.preview_path = []
	view.preview_target = -1
	view.threat = {}
	view.affected = {}
	_preview_label.text = ""
	if not _targeting.is_empty():
		_preview_label.text = tr("TARGET_PROMPT") % _targeting["label"]
		if _pending:
			_show_target_preview(_pending)
	else:
		# Зона угрозы: куда может дойти враг под курсором.
		if hovered and active and hovered.side != active.side and not hovered.is_ranged:
			view.threat = Pathfinding.reachable(state, hovered)
		_show_preview(_pending)
	view.refresh_highlights()


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
			if a.ref_id == HeroActions.SALT_WALL:
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


func _show_preview(action: BattleAction) -> void:
	if action == null:
		return
	var u := state.active_unit()
	match action.type:
		BattleAction.Type.MOVE:
			view.preview_path = Pathfinding.path(state, u, action.dest)
			_preview_label.text = tr("BATTLE_PREVIEW_MOVE")
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
			_preview_label.text = tr(key) % [r.x, r.y, DamageCalc.kills(target, r.x), DamageCalc.kills(target, r.y)]


## Превью способности/приказа/заклинания: эффект на цель и кого ещё заденет.
func _show_target_preview(action: BattleAction) -> void:
	var u := state.active_unit()
	var target := state.get_unit(action.target_uid)
	if target:
		view.preview_target = target.uid
	view.affected = _harmed_by(action)
	var text: String = _targeting["label"]
	if action.is_hero() and action.slot >= 0:
		var power := int(state.hero_spells[action.slot]["power"])
		match action.ref_id:
			HeroActions.ASH_RECORD, HeroActions.CHAIN_SPELL:
				text = tr("PREVIEW_FIXED") % [text, power, DamageCalc.kills(target, power)]
			HeroActions.HUNGER:
				text = tr("PREVIEW_HEAL") % [text, mini(power, target.start_count * target.hp - target.total_hp())]
			HeroActions.SHARD_RAIN:
				text = tr("PREVIEW_AREA") % [text, power]
			_:
				text = tr(db.spell(action.ref_id).desc_key)
	elif action.is_hero():
		text = "%s: %s" % [text, tr(db.order(action.ref_id).desc_key)]
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
				text = tr("PREVIEW_DAMAGE") % [text, r.x, r.y, DamageCalc.kills(target, r.x), DamageCalc.kills(target, r.y)]
			Abilities.RESTORE:
				text = tr("PREVIEW_HEAL") % [text, mini(Abilities.RESTORE_AMOUNT, target.start_count * target.hp - target.total_hp())]
			_:
				text = "%s: %s" % [text, tr(db.ability(id).desc_key)]
	var allies_hit := view.affected.values().count(true)
	if allies_hit > 0:
		text += tr("PREVIEW_ALLIES_HIT") % allies_hit
	_preview_label.text = text


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
				line = tr("LOG_PUSHED") % _name(e.data["uid"])
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
			BattleEvent.DIED:
				line = tr("LOG_DIED") % _name(e.data["uid"])
			BattleEvent.WAITED:
				line = tr("LOG_WAIT") % _name(e.data["uid"])
			BattleEvent.DEFENDED:
				line = tr("LOG_DEFEND") % _name(e.data["uid"])
			BattleEvent.BATTLE_ENDED:
				if e.data.get("reason", "") == "rounds":
					line = tr("LOG_TIMEOUT")
		if line != "":
			_log_lines.append(line)
	while _log_lines.size() > LOG_LINES:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func _name(uid: int) -> String:
	var u := state.get_unit(uid)
	var color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	return "[color=#%s]%s[/color]" % [color.to_html(false), UiKit.unit_name(db, u.def_id)]


func _show_end() -> void:
	view.clear_preview()
	var won := state.outcome == BattleState.Outcome.PLAYER_WON
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_COLOR, UiKit.ACCENT, 3))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_panel.add_child(box)
	var title := UiKit.label(tr("BATTLE_WON") if won else tr("BATTLE_LOST"), 56, UiKit.ACCENT if won else UiKit.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.button(tr("BATTLE_CONTINUE"), func() -> void: Game.finish_battle(state.outcome, state.spell_charges()), 360))
	add_child(_end_panel)
	_end_panel.custom_minimum_size = Vector2(520, 240)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
