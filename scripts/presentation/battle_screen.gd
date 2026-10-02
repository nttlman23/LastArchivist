extends Control
## Экран боя: связывает BattleState, BattleView, ввод игрока и AI.

const BOARD_TOP := 150.0
const AI_DELAY := 0.35
const LOG_LINES := 8
const QUEUE_SLOT := 60.0
const QUEUE_ACTIVE_SLOT := 76.0

var db: DefsDB
var state: BattleState
var view: BattleView

var _busy := true
var _pending: BattleAction
var _hover_key := ""
var _queue_box: HBoxContainer
var _round_label: Label
var _status_label: Label
var _active_panel: UnitInfoPanel
var _hover_panel: UnitInfoPanel
var _preview_label: Label
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _wait_btn: Button
var _defend_btn: Button
var _end_panel: PanelContainer


func _ready() -> void:
	db = Game.defs
	if Game.run == null:
		# Запуск сцены напрямую из редактора — тестовый забег.
		Game.run = RunState.create(db, 1)
		Game.selected = [0, 1, 2, 3]
	var run := Game.run
	var encounter := db.encounter(run.current_encounter_id(db))
	state = BattleState.create(db, encounter, run.codex, Game.selected, run.battle_seed())

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.add_background(self)
	view = BattleView.new()
	add_child(view)
	view.setup(state, db)
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
	top.position = Vector2(24, 20)
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
	_status_label.position = Vector2(24, 104)
	add_child(_status_label)

	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -400
	side.offset_right = -20
	side.offset_top = 150
	side.offset_bottom = -20
	side.add_theme_constant_override("separation", 12)
	add_child(side)
	_active_panel = UnitInfoPanel.new()
	side.add_child(_active_panel)
	_hover_panel = UnitInfoPanel.new()
	_hover_panel.visible = false
	side.add_child(_hover_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 18)
	_log.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.PANEL_COLOR))
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_log)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -440
	bottom.offset_top = -150
	bottom.offset_bottom = -16
	add_child(bottom)
	_preview_label = UiKit.label("", 24, UiKit.ACCENT)
	bottom.add_child(_preview_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bottom.add_child(row)
	_wait_btn = UiKit.button(tr("BATTLE_WAIT"), _on_wait, 200)
	row.add_child(_wait_btn)
	_defend_btn = UiKit.button(tr("BATTLE_DEFEND"), _on_defend, 200)
	row.add_child(_defend_btn)
	row.add_child(UiKit.button(tr("BATTLE_RETREAT"), Game.abandon_battle, 200))
	for b: Button in [_wait_btn, _defend_btn]:
		b.focus_mode = Control.FOCUS_NONE


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
	if u == null or state.outcome != BattleState.Outcome.NONE:
		_status_label.text = ""
		_active_panel.visible = false
		return
	var side_color := UiKit.PLAYER_COLOR if player_turn else UiKit.ENEMY_COLOR
	_status_label.text = (tr("BATTLE_YOUR_TURN") if player_turn else tr("BATTLE_ENEMY_TURN")) % UiKit.unit_name(db, u.def_id)
	_status_label.add_theme_color_override("font_color", side_color)
	_active_panel.show_unit(db, u, tr("INFO_ACTIVE"), UiKit.ACTIVE_BORDER)


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
	_refresh_hud()
	if state.outcome != BattleState.Outcome.NONE:
		_show_end()
		return
	_busy = false
	view.reachable = Pathfinding.reachable(state, state.active_unit())
	_invalidate_hover()
	_update_hover()


func _execute(action: BattleAction) -> void:
	_pending = null
	_invalidate_hover()
	view.clear_preview()
	view.show_active = false
	_preview_label.text = ""
	var events := BattleResolver.apply(state, action)
	_log_events(events)
	await view.play(events)
	view.show_active = true


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


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover()
		_player_act(_pending)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				_on_wait()
			KEY_D:
				_on_defend()


func _update_hover() -> void:
	if state == null:
		return
	var local := view.get_local_mouse_position()
	var hex := view.hex_at(local)
	var can_act := not _busy and _is_player_turn()
	var pending := _action_at(local, hex) if can_act else null
	view.set_cursor(_CURSOR_ICONS.get(pending.type, &"") if pending else &"", local)
	# Мышь шлёт много событий за кадр: пересобираем подсветку и карточки, только если что-то изменилось.
	var key := "%s|%s|%s" % [hex, pending, can_act]
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
	_preview_label.text = ""
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


# --- Лог и конец боя ----------------------------------------------------------

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
	box.add_child(UiKit.button(tr("BATTLE_CONTINUE"), func() -> void: Game.finish_battle(state.outcome), 360))
	add_child(_end_panel)
	_end_panel.custom_minimum_size = Vector2(520, 240)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
