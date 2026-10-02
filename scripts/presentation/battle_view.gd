class_name BattleView
extends Node2D
## Отрисовка поля и проигрывание событий боя. Состояние только читает.
##
## Поле разбито на слои, каждый перерисовывается только при своих изменениях:
## перестроение canvas-команд (триангуляция, сглаженные линии) дорогое,
## а повторный показ уже записанных команд почти бесплатен.
##   board   — сетка и препятствия, рисуется один раз;
##   overlay — подсветки (достижимость, путь, угроза, наведение), при смене подсветки;
##   units   — фишки, при синхронизации и во время анимаций;
##   fx      — снаряд и всплывающий урон, только пока они есть;
##   marker  — маркер ходящего стека, пульсирует через modulate/position без перерисовки;
##   cursor  — иконка действия у курсора, двигается через position.

const HEX_SIZE := 54.0
const UNIT_RADIUS := HEX_SIZE * 0.6
const STEP_TIME := 0.09
const LUNGE_TIME := 0.12
const SHOT_TIME := 0.22
const FADE_TIME := 0.3
const FLOATER_TIME := 1.2

const HEX_COLOR := Color(0.17, 0.19, 0.24)
const HEX_LINE := Color(0.3, 0.33, 0.4)
const OBSTACLE_COLOR := Color(0.32, 0.27, 0.22)
const REACH_COLOR := Color(0.25, 0.42, 0.32)
const PATH_COLOR := Color(0.4, 0.65, 0.45)
const HOVER_COLOR := Color(1, 1, 1, 0.12)
const ACTIVE_RING := Color(1.0, 0.85, 0.3)
const THREAT_COLOR := Color(1.0, 0.35, 0.3, 0.8)
const TARGET_COLOR := Color(1, 0.3, 0.25)
const BADGE_BG := Color(0.1, 0.11, 0.15)

var state: BattleState
var db: DefsDB

# Подсветка, задаётся экраном боя; после изменения вызвать refresh_highlights().
var reachable: Dictionary[Vector2i, int] = {}
var preview_path: Array[Vector2i] = []
var preview_target := -1
var hover_hex := Vector2i(-1, -1)
## Клетки, куда может дойти враг под курсором (зона угрозы).
var threat: Dictionary[Vector2i, int] = {}
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
var _time := 0.0
var _hex_fill: Dictionary[Vector2i, PackedVector2Array] = {}
var _hex_inner: Dictionary[Vector2i, PackedVector2Array] = {}

var _board: Layer
var _overlay: Layer
var _units: Layer
var _fx: Layer
var _marker: Layer
var _marker_arrow: Layer
var _cursor: CursorIcon


## Слой, делегирующий отрисовку функции BattleView.
class Layer:
	extends Node2D
	var painter: Callable

	func _init(p: Callable) -> void:
		painter = p

	func _draw() -> void:
		painter.call(self)


## Иконка действия у курсора: перерисовывается только при смене вида.
class CursorIcon:
	extends Node2D
	var kind := &"":
		set(value):
			if kind != value:
				kind = value
				visible = kind != &""
				queue_redraw()

	func _draw() -> void:
		if kind != &"":
			UnitGlyphs.draw_icon(self, kind, Vector2(26, 26), 16, Color(0.1, 0.1, 0.12, 0.9), UiKit.ACCENT)


func setup(p_state: BattleState, p_db: DefsDB) -> void:
	state = p_state
	db = p_db
	_font = ThemeDB.fallback_font
	_hex_fill.clear()
	_hex_inner.clear()
	for hex in state.grid.all_hexes():
		var c := hex_center(hex)
		_hex_fill[hex] = HexGrid.corners(c, HEX_SIZE - 1.5)
		var inner := HexGrid.corners(c, HEX_SIZE - 7.0)
		inner.append(inner[0])
		_hex_inner[hex] = inner
	if _board == null:
		_board = _add_layer(self, _draw_board)
		_overlay = _add_layer(self, _draw_overlay)
		_marker = _add_layer(self, _draw_marker_ring)
		_marker_arrow = _add_layer(_marker, _draw_marker_arrow)
		_units = _add_layer(self, _draw_units)
		_fx = _add_layer(self, _draw_fx)
		_cursor = CursorIcon.new()
		_cursor.visible = false
		add_child(_cursor)
	_board.queue_redraw()
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
	_units.queue_redraw()
	_overlay.queue_redraw()
	_update_marker()


func refresh_highlights() -> void:
	_overlay.queue_redraw()


func set_cursor(kind: StringName, local_pos: Vector2) -> void:
	_cursor.kind = kind
	_cursor.position = local_pos


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
	threat = {}
	_cursor.kind = &""
	_overlay.queue_redraw()


func _add_layer(parent: Node, painter: Callable) -> Layer:
	var layer := Layer.new(painter)
	parent.add_child(layer)
	return layer


func _process(delta: float) -> void:
	_time += delta
	_update_marker()
	if not _floaters.is_empty():
		for f in _floaters:
			f["t"] = float(f["t"]) + delta
		_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < FLOATER_TIME)
		_fx.queue_redraw()
	if not _flash.is_empty():
		for uid in _flash.keys():
			_flash[uid] -= delta
			if _flash[uid] <= 0.0:
				_flash.erase(uid)
		_units.queue_redraw()


## Маркер следует за ходящим стеком и пульсирует без перерисовки.
func _update_marker() -> void:
	var active := state.active_unit()
	_marker.visible = show_active and active != null and _pos.has(active.uid)
	if not _marker.visible:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_marker.position = _pos[active.uid]
	_marker.modulate.a = 0.55 + 0.45 * pulse
	_marker.scale = Vector2.ONE * (1.0 + 0.05 * pulse)
	_marker_arrow.position.y = -6.0 * pulse


# --- Проигрывание событий ---------------------------------------------------

func play(events: Array[BattleEvent]) -> void:
	for e in events:
		match e.type:
			BattleEvent.MOVED:
				await _play_move(e.data["uid"], e.data["path"])
			BattleEvent.ATTACKED:
				await _play_attack(e.data)
			BattleEvent.DIED:
				await _tween_value(func(v: float) -> void: _alpha[int(e.data["uid"])] = v, 1.0, 0.0, FADE_TIME, _units)
	sync()


func _play_move(uid: int, path: Array) -> void:
	for i in range(1, path.size()):
		var from := hex_center(path[i - 1])
		var to := hex_center(path[i])
		var time := STEP_TIME * (HexGrid.distance(path[i - 1], path[i]))
		await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, time, _units)


func _play_attack(d: Dictionary) -> void:
	var attacker: int = d["attacker"]
	var target: int = d["target"]
	var from := _pos[attacker]
	var to := _pos[target]
	if d["ranged"]:
		_projectile_from = from
		_projectile_to = to
		await _tween_value(func(t: float) -> void: _projectile_t = t, 0.0, 1.0, SHOT_TIME, _fx)
		_projectile_t = -1.0
		_fx.queue_redraw()
	else:
		var lunge := from.lerp(to, 0.35)
		await _tween_value(func(t: float) -> void: _pos[attacker] = from.lerp(lunge, t), 0.0, 1.0, LUNGE_TIME, _units)
		_pos[attacker] = from
	_count[target] = maxi(0, _count[target] - int(d["killed"]))
	_flash[target] = 0.25
	var text := "-%d" % int(d["damage"])
	if int(d["killed"]) > 0:
		text += "  †%d" % int(d["killed"])
	_floaters.append({"text": text, "pos": to, "t": 0.0})
	_units.queue_redraw()
	await get_tree().create_timer(0.25).timeout


func _tween_value(setter: Callable, from: float, to: float, time: float, layer: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_method(_tween_step.bind(setter, layer), from, to, time)
	await tw.finished


func _tween_step(value: float, setter: Callable, layer: CanvasItem) -> void:
	setter.call(value)
	layer.queue_redraw()


# --- Слои --------------------------------------------------------------------

func _draw_board(ci: CanvasItem) -> void:
	var outlines := PackedVector2Array()
	for hex in _hex_fill:
		var pts := _hex_fill[hex]
		ci.draw_colored_polygon(pts, OBSTACLE_COLOR if state.obstacles.has(hex) else HEX_COLOR)
		for i in 6:
			outlines.append(pts[i])
			outlines.append(pts[(i + 1) % 6])
		if state.obstacles.has(hex):
			_draw_rock(ci, hex_center(hex))
	# Все контуры одним вызовом.
	ci.draw_multiline(outlines, HEX_LINE, 1.5)


func _draw_overlay(ci: CanvasItem) -> void:
	for hex in reachable:
		ci.draw_colored_polygon(_hex_fill[hex], REACH_COLOR)
	for hex in preview_path:
		ci.draw_colored_polygon(_hex_fill[hex], PATH_COLOR)
	if _hex_fill.has(hover_hex):
		ci.draw_colored_polygon(_hex_fill[hover_hex], HOVER_COLOR)
	if not threat.is_empty():
		var lines := PackedVector2Array()
		for hex in threat:
			var pts := _hex_inner[hex]
			for i in 6:
				lines.append(pts[i])
				lines.append(pts[i + 1])
		ci.draw_multiline(lines, THREAT_COLOR, 2.5)
	if preview_target >= 0 and _pos.has(preview_target):
		ci.draw_arc(_pos[preview_target], UNIT_RADIUS + 7, 0, TAU, 32, TARGET_COLOR, 4.0)


func _draw_marker_ring(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(HexGrid.corners(Vector2.ZERO, HEX_SIZE - 1.5), Color(ACTIVE_RING, 0.3))
	ci.draw_arc(Vector2.ZERO, UNIT_RADIUS + 7, 0, TAU, 40, ACTIVE_RING, 5.0)


func _draw_marker_arrow(ci: CanvasItem) -> void:
	var tip := Vector2(0, -UNIT_RADIUS - 12)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16)]), ACTIVE_RING)


func _draw_units(ci: CanvasItem) -> void:
	for u in state.units:
		if _alpha.get(u.uid, 0.0) > 0.0:
			_draw_unit(ci, u)


func _draw_fx(ci: CanvasItem) -> void:
	if _projectile_t >= 0.0:
		var p := _projectile_from.lerp(_projectile_to, _projectile_t)
		var dir := (_projectile_to - _projectile_from).normalized()
		ci.draw_line(p - dir * 22, p, UiKit.ACCENT, 4.0)
	for f in _floaters:
		var t := float(f["t"])
		var pos: Vector2 = f["pos"] + Vector2(-30, -UNIT_RADIUS - 10 - 40 * t)
		var col := Color(1, 0.4, 0.35, clampf(1.6 - t * 1.4, 0, 1))
		ci.draw_string_outline(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color(0, 0, 0, col.a))
		ci.draw_string(_font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)


func _draw_rock(ci: CanvasItem, c: Vector2) -> void:
	var rock := PackedVector2Array([c + Vector2(-24, 14), c + Vector2(-14, -12), c + Vector2(4, -20), c + Vector2(22, -6), c + Vector2(20, 16)])
	ci.draw_colored_polygon(rock, OBSTACLE_COLOR.darkened(0.35))


func _draw_unit(ci: CanvasItem, u: UnitState) -> void:
	var c: Vector2 = _pos[u.uid]
	var alpha: float = _alpha[u.uid]
	var side_color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	var body := db.unit(u.def_id).color
	if _flash.has(u.uid):
		body = body.lerp(Color.WHITE, 0.7)
	body.a = alpha
	var ink := Color(UnitGlyphs.INK, alpha)
	var ring := Color(side_color, alpha)
	var fg := Color(1, 1, 1, alpha)
	var bg := Color(BADGE_BG, alpha)

	ci.draw_circle(c, UNIT_RADIUS, body)
	ci.draw_arc(c, UNIT_RADIUS, 0, TAU, 32, ring, 4.0)
	UnitGlyphs.draw_unit(ci, u.def_id, c, UNIT_RADIUS * 0.82, body, ink)

	# Значки способностей и состояний вокруг фишки.
	var badge_r := 11.0
	if u.is_ranged:
		var pos := c + Vector2(-UNIT_RADIUS + 2, -UNIT_RADIUS + 4)
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_RANGED, pos, badge_r, bg, fg if u.shots_left > 0 else Color(UiKit.MUTED, alpha))
		ci.draw_string_outline(_font, pos + Vector2(-26, 6), str(u.shots_left), HORIZONTAL_ALIGNMENT_RIGHT, 16, 15, 4, Color(0, 0, 0, alpha))
		ci.draw_string(_font, pos + Vector2(-26, 6), str(u.shots_left), HORIZONTAL_ALIGNMENT_RIGHT, 16, 15, fg)
	if u.is_flying:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_FLYING, c + Vector2(UNIT_RADIUS - 2, -UNIT_RADIUS + 4), badge_r, bg, fg)
	if u.defending:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_DEFEND, c + Vector2(-UNIT_RADIUS - 4, 8), badge_r, bg, Color(UiKit.PLAYER_COLOR.lightened(0.3), alpha))
	if u.retaliated:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_RETALIATION_USED, c + Vector2(UNIT_RADIUS + 4, 8), badge_r, bg, Color(UiKit.MUTED, alpha))

	# Численность и полоска здоровья верхнего существа.
	var badge := Rect2(c + Vector2(-24, UNIT_RADIUS - 12), Vector2(48, 24))
	ci.draw_rect(badge, Color(side_color.darkened(0.55), alpha))
	ci.draw_rect(badge, ring, false, 2.0)
	ci.draw_string(_font, badge.position + Vector2(0, 19), str(_count.get(u.uid, u.count)), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 19, fg)
	var hp_ratio := clampf(float(u.top_hp) / u.hp, 0.0, 1.0) if u.is_alive() else 0.0
	var bar := Rect2(badge.position + Vector2(0, badge.size.y + 1), Vector2(badge.size.x, 4))
	ci.draw_rect(bar, Color(0.1, 0.1, 0.1, alpha))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_ratio, bar.size.y)), Color(Color(0.4, 0.85, 0.4).lerp(UiKit.DANGER, 1.0 - hp_ratio), alpha))
