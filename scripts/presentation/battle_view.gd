class_name BattleView
extends Node2D
## Отрисовка поля и проигрывание событий боя. Состояние только читает.

const HEX_SIZE := 54.0
const UNIT_RADIUS := HEX_SIZE * 0.6
const STEP_TIME := 0.09
const LUNGE_TIME := 0.12
const SHOT_TIME := 0.22
const FADE_TIME := 0.3

const HEX_COLOR := Color(0.17, 0.19, 0.24)
const HEX_LINE := Color(0.3, 0.33, 0.4)
const OBSTACLE_COLOR := Color(0.32, 0.27, 0.22)
const REACH_COLOR := Color(0.25, 0.42, 0.32)
const PATH_COLOR := Color(0.4, 0.65, 0.45)
const HOVER_COLOR := Color(1, 1, 1, 0.12)
const ACTIVE_RING := Color(1.0, 0.85, 0.3)

var state: BattleState
var db: DefsDB

# Подсветка, задаётся экраном боя.
var reachable: Dictionary[Vector2i, int] = {}
var preview_path: Array[Vector2i] = []
var preview_target := -1
var hover_hex := Vector2i(-1, -1)
var show_active := true

# Отображаемое состояние стеков — отстаёт от BattleState на время анимаций.
var _pos: Dictionary[int, Vector2] = {}
var _count: Dictionary[int, int] = {}
var _alpha: Dictionary[int, float] = {}
var _flash: Dictionary[int, float] = {}
var _projectile_from := Vector2.ZERO
var _projectile_to := Vector2.ZERO
var _projectile_t := -1.0
var _floaters: Array[Dictionary] = []
var _font: Font


func setup(p_state: BattleState, p_db: DefsDB) -> void:
	state = p_state
	db = p_db
	_font = ThemeDB.fallback_font
	sync()


## Подгоняет отображение под текущее состояние.
func sync() -> void:
	_pos.clear()
	_count.clear()
	_alpha.clear()
	for u in state.units:
		_pos[u.uid] = hex_center(u.hex)
		_count[u.uid] = u.count
		_alpha[u.uid] = 1.0 if u.is_alive() else 0.0
	queue_redraw()


func hex_center(hex: Vector2i) -> Vector2:
	return HexGrid.to_pixel(hex, HEX_SIZE)


func board_size() -> Vector2:
	return Vector2(HexGrid.SQRT3 * HEX_SIZE * (state.grid.width + 0.5), HEX_SIZE * (1.5 * (state.grid.height - 1) + 2.0))


## Клетка под точкой в локальных координатах; (-1, -1) вне поля.
func hex_at(local: Vector2) -> Vector2i:
	var h := HexGrid.from_pixel(local, HEX_SIZE)
	return h if state.grid.in_bounds(h) else Vector2i(-1, -1)


func clear_preview() -> void:
	reachable = {}
	preview_path = []
	preview_target = -1
	queue_redraw()


func _process(delta: float) -> void:
	if _floaters.is_empty() and _flash.is_empty():
		return
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.2)
	for uid in _flash.keys():
		_flash[uid] -= delta
		if _flash[uid] <= 0.0:
			_flash.erase(uid)
	queue_redraw()


# --- Проигрывание событий ---------------------------------------------------

func play(events: Array[BattleEvent]) -> void:
	for e in events:
		match e.type:
			BattleEvent.MOVED:
				await _play_move(e.data["uid"], e.data["path"])
			BattleEvent.ATTACKED:
				await _play_attack(e.data)
			BattleEvent.DIED:
				await _tween_value(func(v: float) -> void: _alpha[int(e.data["uid"])] = v, 1.0, 0.0, FADE_TIME)
	sync()


func _play_move(uid: int, path: Array) -> void:
	for i in range(1, path.size()):
		var from := hex_center(path[i - 1])
		var to := hex_center(path[i])
		var time := STEP_TIME * (HexGrid.distance(path[i - 1], path[i]))
		await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, time)


func _play_attack(d: Dictionary) -> void:
	var attacker: int = d["attacker"]
	var target: int = d["target"]
	var from := _pos[attacker]
	var to := _pos[target]
	if d["ranged"]:
		_projectile_from = from
		_projectile_to = to
		await _tween_value(func(t: float) -> void: _projectile_t = t, 0.0, 1.0, SHOT_TIME)
		_projectile_t = -1.0
	else:
		var lunge := from.lerp(to, 0.35)
		await _tween_value(func(t: float) -> void: _pos[attacker] = from.lerp(lunge, t), 0.0, 1.0, LUNGE_TIME)
		_pos[attacker] = from
	_count[target] = maxi(0, _count[target] - int(d["killed"]))
	_flash[target] = 0.25
	var text := "-%d" % int(d["damage"])
	if int(d["killed"]) > 0:
		text += "  †%d" % int(d["killed"])
	_floaters.append({"text": text, "pos": to, "t": 0.0})
	await get_tree().create_timer(0.25).timeout


func _tween_value(setter: Callable, from: float, to: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_method(_tween_step.bind(setter), from, to, time)
	await tw.finished


func _tween_step(value: float, setter: Callable) -> void:
	setter.call(value)
	queue_redraw()


# --- Отрисовка ---------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	var path_set := {}
	for h in preview_path:
		path_set[h] = true
	for hex in state.grid.all_hexes():
		var c := hex_center(hex)
		var pts := HexGrid.corners(c, HEX_SIZE - 1.5)
		var fill := HEX_COLOR
		if state.obstacles.has(hex):
			fill = OBSTACLE_COLOR
		elif path_set.has(hex):
			fill = PATH_COLOR
		elif reachable.has(hex):
			fill = REACH_COLOR
		draw_colored_polygon(pts, fill)
		if hex == hover_hex:
			draw_colored_polygon(pts, HOVER_COLOR)
		pts.append(pts[0])
		draw_polyline(pts, HEX_LINE, 1.5, true)
		if state.obstacles.has(hex):
			_draw_rock(c)

	var active := state.active_unit()
	for u in state.units:
		if _alpha.get(u.uid, 0.0) <= 0.0:
			continue
		_draw_unit(u, active != null and show_active and u.uid == active.uid)

	if _projectile_t >= 0.0:
		var p := _projectile_from.lerp(_projectile_to, _projectile_t)
		var dir := (_projectile_to - _projectile_from).normalized()
		draw_line(p - dir * 22, p, UiKit.ACCENT, 4.0, true)

	for f in _floaters:
		var t := float(f["t"])
		var pos: Vector2 = f["pos"] + Vector2(-30, -UNIT_RADIUS - 10 - 40 * t)
		var col := Color(1, 0.4, 0.35, clampf(1.6 - t * 1.4, 0, 1))
		draw_string_outline(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color(0, 0, 0, col.a))
		draw_string(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)


func _draw_rock(c: Vector2) -> void:
	var rock := PackedVector2Array([c + Vector2(-24, 14), c + Vector2(-14, -12), c + Vector2(4, -20), c + Vector2(22, -6), c + Vector2(20, 16)])
	draw_colored_polygon(rock, OBSTACLE_COLOR.darkened(0.35))


func _draw_unit(u: UnitState, is_active: bool) -> void:
	var def := db.unit(u.def_id)
	var c: Vector2 = _pos[u.uid]
	var alpha: float = _alpha[u.uid]
	var side_color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	var body := def.color
	if _flash.has(u.uid):
		body = body.lerp(Color.WHITE, 0.7)
	body.a = alpha

	if is_active:
		draw_circle(c, UNIT_RADIUS + 7, Color(ACTIVE_RING, 0.9 * alpha), false, 4.0, true)
	if u.uid == preview_target:
		draw_circle(c, UNIT_RADIUS + 7, Color(1, 0.3, 0.25, alpha), false, 4.0, true)
	draw_circle(c, UNIT_RADIUS, body, true, -1.0, true)
	draw_circle(c, UNIT_RADIUS, Color(side_color, alpha), false, 4.0, true)

	# Метки: стрелок — треугольник сверху, летун — «крылья».
	if u.is_ranged:
		var tip := c + Vector2(0, -UNIT_RADIUS + 4)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -10), tip + Vector2(8, 4), tip + Vector2(-8, 4)]), Color(0.1, 0.1, 0.1, alpha))
	if u.is_flying:
		draw_line(c + Vector2(-UNIT_RADIUS - 2, -6), c + Vector2(-UNIT_RADIUS - 16, -18), Color(side_color, alpha), 4.0, true)
		draw_line(c + Vector2(UNIT_RADIUS + 2, -6), c + Vector2(UNIT_RADIUS + 16, -18), Color(side_color, alpha), 4.0, true)

	var initials := UiKit.unit_abbr(db, u.def_id)
	draw_string(_font, c + Vector2(-UNIT_RADIUS, 9), initials, HORIZONTAL_ALIGNMENT_CENTER, UNIT_RADIUS * 2, 26, Color(0.05, 0.05, 0.08, alpha))

	var count_text := str(_count.get(u.uid, u.count))
	var badge := Rect2(c + Vector2(-24, UNIT_RADIUS - 12), Vector2(48, 26))
	draw_rect(badge, Color(side_color.darkened(0.55), alpha))
	draw_rect(badge, Color(side_color, alpha), false, 2.0)
	draw_string(_font, badge.position + Vector2(0, 20), count_text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 20, Color(1, 1, 1, alpha))
