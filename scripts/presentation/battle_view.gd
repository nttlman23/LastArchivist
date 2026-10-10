class_name BattleView
extends Node2D
## Отрисовка поля и проигрывание событий боя. Состояние только читает.
##
## Поле разбито на слои, каждый перерисовывается только при своих изменениях:
## перестроение canvas-команд (триангуляция, сглаженные линии) дорогое,
## а повторный показ уже записанных команд почти бесплатен.
##   board   — сетка и препятствия, рисуется один раз;
##   overlay — подсветки (достижимость, путь, угроза, наведение), при смене подсветки;
##   units   — все фишки одним объектом отрисовки (при программной отрисовке отдельные узлы
##             на фишку обходятся дорого); тела — запечённые текстуры, «дыхание» и поворот —
##             трансформом при отрисовке; перерисовывается каждый кадр — это дёшево;
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
const RING_TIME := 0.45
const FLOATER_FONT := 28
## «Дыхание» фишек в покое (SPEC_SPRINT6 6).
const BREATH := 0.02
const BREATH_PERIOD := 2.6
const RECOIL := 9.0
const SHAKE_TIME := 0.3
const SHAKE_MAX := 8.0
const SHOT_ARC := 0.15
const TRAIL_POINTS := 9

## Гекс непрозрачный: под полем плит нет (каждый смешанный пиксель дорог при программной отрисовке).
const HEX_COLOR := Color(0.16, 0.175, 0.215)
const BEVEL_LIGHT := Color(1, 1, 1, 0.09)
const PLATE := Vector2(150, 96)
const PLATE_GAP := 2.0
const FLOOR_COLOR := Color(0.16, 0.155, 0.17)
const FLOOR_SEAM := Color(0.075, 0.075, 0.09)
## Затопленные хранилища (SPEC_SPRINT7 4): сине-зелёные плиты и гексы.
const FLOODED_FLOOR := Color(0.1, 0.16, 0.17)
const FLOODED_SEAM := Color(0.04, 0.07, 0.08)
const FLOODED_HEX := Color(0.12, 0.18, 0.2)
const CURRENT_COLOR := Color(0.55, 0.9, 1.0, 0.75)
const INK_COLOR := Color(0.12, 0.06, 0.18, 0.65)
const BEVEL_DARK := Color(0, 0, 0, 0.35)
const HEX_LINE := Color(0.3, 0.33, 0.4)
const OBSTACLE_COLOR := Color(0.32, 0.27, 0.22)
const REACH_COLOR := Color(0.25, 0.42, 0.32)
const PATH_COLOR := Color(0.4, 0.65, 0.45)
const HOVER_COLOR := Color(1, 1, 1, 0.12)
const ACTIVE_RING := Color(1.0, 0.85, 0.3)
const THREAT_COLOR := Color(1.0, 0.35, 0.3, 0.8)
const TARGET_COLOR := Color(1, 0.3, 0.25)
const BADGE_BG := Color(0.1, 0.11, 0.15)
const TEMP_WALL_COLOR := Color(0.62, 0.66, 0.72)
const WATER_COLOR := Color(0.25, 0.45, 0.75, 0.55)
const ILLUSION_ALPHA := 0.55
const TARGET_HEX_COLOR := Color(0.62, 0.4, 0.95, 0.45)
const AFFECTED_ALLY := Color(1, 0.3, 0.25)
const AFFECTED_ENEMY := Color(0.95, 0.8, 0.4)
const HEAL_COLOR := Color(0.45, 0.95, 0.5)
const DAMAGE_COLOR := Color(1, 0.4, 0.35)
const NAME_COLOR := Color(0.95, 0.85, 0.5)
const RIFT_COLOR := Color(0.8, 0.5, 1.0)
const ATTACK_ZONE_COLOR := Color(1.0, 0.3, 0.25, 0.22)
const HEAT_COLOR := Color(1.0, 0.3, 0.25)
const HEAT_STEP := 0.13
const HEAT_MAX := 0.55
const DIM_COLOR := Color(0, 0, 0, 0.22)
const WAVE_COLOR := Color(0.6, 0.8, 1.0, 0.8)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.9)
const SIDE_RING_WIDTH := 5.0
const MAX_STATUS_ICONS := 3
const HOLD_COLOR := Color(0.55, 0.85, 1.0, 0.28)
const HOLD_FLAG := Color(0.55, 0.85, 1.0)
const TARGET_MARK := Color(1.0, 0.35, 0.3)
## Рисованные фигуры (SPEC_SPRINT9 3): высота на поле, где стоят ноги, тень и подставка стороны.
const FIGURE_HEIGHT := HEX_SIZE * 2.6
const FIGURE_HEIGHT_LARGE := HEX_SIZE * 3.1
const FEET_Y := HEX_SIZE * 0.22
const FLYER_BOB := 4.0
const SHADOW_COLOR := Color(0, 0, 0, 0.38)
const ART_HEX_ALPHA := 0.32

var state: BattleState
var db: DefsDB

# Подсветка, задаётся экраном боя; после изменения вызвать refresh_highlights().
var reachable: Dictionary[Vector2i, int] = {}
var preview_path: Array[Vector2i] = []
var preview_target := -1
var hover_hex := Vector2i(-1, -1)
## Клетки, куда может дойти враг под курсором (зона угрозы).
var threat: Dictionary[Vector2i, int] = {}
## Клетки, которые враг под курсором может атаковать (кроме тех, куда может дойти).
var threat_attack: Dictionary[Vector2i, bool] = {}
## Суммарная угроза всех врагов (удержание Alt): клетка -> число достающих стеков.
var heat: Dictionary[Vector2i, int] = {}
## Свои стеки, которых враг может атаковать в этот раунд (значок «под ударом»).
var threatened: Dictionary[int, bool] = {}
## Цели выстрела вражеского стрелка под курсором: uid -> дальний выстрел (урон снижен).
var shot_targets: Dictionary[int, bool] = {}
## Предполагаемые действия врагов (EnemyIntents.predict) — значок у каждого врага.
var enemy_intents: Dictionary[int, Dictionary] = {}
## Стрелка намерения: у врага под курсором или у всех (Alt).
var intent_hover := -1
var intent_arrows_all := false
## Стек, подсвеченный из полосы очереди (или -1).
var highlight_uid := -1
## Затемнять клетки, недоступные для хода (во время хода игрока).
var dim_unreachable := false
## Режим прицеливания: допустимые клетки-цели и стеки, которых заденет действие (uid -> свой ли).
var targets: Dictionary[Vector2i, bool] = {}
var affected: Dictionary[int, bool] = {}
## Подпись для ABILITY_USED/HERO_ACTED (название способности, приказа, заклинания); задаёт экран.
var event_label: Callable = func(_e: BattleEvent) -> String: return ""
var show_active := true
## Рисованный пол под полем (SPEC_SPRINT9 4): гексы полупрозрачные, плиты не рисуются. Задаёт экран до setup().
var art_floor := false

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
## Куда смотрит фишка: 1 — вправо, -1 — влево.
var _facing: Dictionary[int, float] = {}
var _fx_pool: FxPool
## Вспышки-кольца: {"pos", "color", "t", "r"}.
var _rings: Array[Dictionary] = []
## Рост временных стен: клетка -> 0..1.
var _grow: Dictionary[Vector2i, float] = {}
var _trail := PackedVector2Array()
var _shake_t := 0.0
var _shake_power := 0.0
var _shake_base := Vector2.ZERO
var _marker_pos := Vector2.ZERO
var _marker_uid := -1
## Сколько проигрываний событий идёт сейчас (фишки перерисовываются каждый кадр).
var _playing := 0
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
		_fx_pool = FxPool.new()
		add_child(_fx_pool)
		_fx_pool.prewarm()
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
	_ensure_unit_nodes()
	_redraw_units()
	_update_units()
	_overlay.queue_redraw()


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
	threat_attack = {}
	shot_targets = {}
	heat = {}
	targets = {}
	affected = {}
	dim_unreachable = false
	_cursor.kind = &""
	_overlay.queue_redraw()


func _add_layer(parent: Node, painter: Callable) -> Layer:
	var layer := Layer.new(painter)
	parent.add_child(layer)
	return layer


func _process(delta: float) -> void:
	_time += delta
	_update_marker(delta)
	_update_units()
	var sp := Settings.anim_speed
	if not _floaters.is_empty() or not _rings.is_empty() or not _trail.is_empty():
		for f in _floaters:
			f["t"] = float(f["t"]) + delta * sp
		_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < FLOATER_TIME)
		for r in _rings:
			r["t"] = float(r["t"]) + delta * sp
		_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < RING_TIME)
		_fx.queue_redraw()
	if not _flash.is_empty():
		for uid in _flash.keys():
			_flash[uid] -= delta
			if _flash[uid] <= 0.0:
				_flash.erase(uid)
			_redraw_unit(uid)
	_update_shake(delta)


## Маркер перетекает к новому ходящему стеку и пульсирует без перерисовки.
func _update_marker(delta: float = 0.0) -> void:
	var active := state.active_unit()
	_marker.visible = show_active and active != null and _pos.has(active.uid)
	if not _marker.visible:
		return
	var target := _pos[active.uid]
	if _marker_uid != active.uid and _marker_uid >= 0 and delta > 0.0:
		_marker_pos = _marker_pos.lerp(target, minf(1.0, delta * 12.0 * Settings.anim_speed))
		if _marker_pos.distance_to(target) < 1.5:
			_marker_uid = active.uid
	else:
		_marker_pos = target
		_marker_uid = active.uid
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_marker.position = _marker_pos
	_marker.modulate.a = 0.55 + 0.45 * pulse
	_marker.scale = Vector2.ONE * (1.0 + 0.05 * pulse)
	_marker_arrow.position.y = -6.0 * pulse


# --- Узлы фишек ----------------------------------------------------------------

func _ensure_unit_nodes() -> void:
	for u in state.units:
		if not _facing.has(u.uid):
			_facing[u.uid] = 1.0 if u.side == UnitState.Side.PLAYER else -1.0
		if not _body_tex.has(_body_key(u)):
			_body_tex[_body_key(u)] = _bake_body(u)


## Слой фишек: во время анимаций — каждый кадр, в покое — каждый третий («дыхание» медленное,
## а запись слоя стоит ~1 мс).
func _update_units() -> void:
	if _playing > 0 or Engine.get_process_frames() % 3 == 0:
		_units.queue_redraw()


func _redraw_units() -> void:
	_units.queue_redraw()


func _redraw_unit(_uid: int) -> void:
	_units.queue_redraw()


func _face(uid: int, dx: float) -> void:
	if absf(dx) > 1.0:
		_facing[uid] = signf(dx)


# --- Эффекты --------------------------------------------------------------------

func _ring(pos: Vector2, color: Color, radius: float = UNIT_RADIUS * 1.8) -> void:
	_rings.append({"pos": pos, "color": color, "t": 0.0, "r": radius})


## Тряска поля: сила 0..1 от доли потерь стека.
func _shake(power: float) -> void:
	if not Settings.screen_shake or power <= 0.0:
		return
	if _shake_t <= 0.0:
		_shake_base = position
	_shake_t = SHAKE_TIME
	_shake_power = maxf(_shake_power if _shake_t > 0.0 else 0.0, clampf(power, 0.15, 1.0))


func _update_shake(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t -= delta
	if _shake_t <= 0.0:
		position = _shake_base
		_shake_power = 0.0
		return
	var k := _shake_t / SHAKE_TIME * _shake_power * SHAKE_MAX
	position = _shake_base + Vector2(sin(_time * 71.0), cos(_time * 53.0)) * k


## Таймер с учётом скорости анимаций.
func _timer(t: float) -> SceneTreeTimer:
	return get_tree().create_timer(t / Settings.anim_speed)


# --- Проигрывание событий ---------------------------------------------------

## Звук на событие боя (id из Audio.SFX); ATTACKED озвучивается отдельно.
const EVENT_SOUNDS := {
	BattleEvent.MOVED: &"move",
	BattleEvent.DIED: &"death",
	BattleEvent.HEALED: &"heal",
	BattleEvent.DAMAGED: &"impact",
	BattleEvent.PUSHED: &"push",
	BattleEvent.OBSTACLE_ADDED: &"wall",
	BattleEvent.ABILITY_USED: &"ability",
	BattleEvent.ERASED: &"erase",
	BattleEvent.RIFT_MARKED: &"order",
	BattleEvent.PHASE_CHANGED: &"erase",
	BattleEvent.SUMMONED: &"spell",
	BattleEvent.COMMANDER_ACTED: &"spell",
	BattleEvent.OBJECTIVE_PROGRESS: &"order",
}


static func sound_for(e: BattleEvent) -> StringName:
	match e.type:
		BattleEvent.ATTACKED:
			return &"shoot" if e.data["ranged"] else &"melee"
		BattleEvent.HERO_ACTED:
			return &"spell" if e.data["spell"] else &"order"
	return EVENT_SOUNDS.get(e.type, &"")


## Звук удара по классу атакующего (SPEC_SPRINT9 12, UnitDef.sound_class) или &"" — тогда общий.
static func hit_sound(p_db: DefsDB, p_state: BattleState, e: BattleEvent) -> StringName:
	if e.type != BattleEvent.ATTACKED or p_db == null or p_state == null:
		return &""
	var attacker := p_state.get_unit(int(e.data.get("attacker", -1)))
	if attacker == null or not p_db.units.has(attacker.def_id):
		return &""
	var cls := p_db.unit(attacker.def_id).sound_class
	return StringName("hit_" + cls) if cls != &"" else &""


func play(events: Array[BattleEvent]) -> void:
	_playing += 1
	for e in events:
		var hit := hit_sound(db, state, e)
		var sound := hit if hit != &"" else sound_for(e)
		if sound != &"":
			Audio.play(sound, Audio.HIT_JITTER if hit != &"" else Audio.PITCH_JITTER)
		match e.type:
			BattleEvent.MOVED:
				await _play_move(e.data["uid"], e.data["path"])
			BattleEvent.ATTACKED:
				await _play_attack(e.data)
			BattleEvent.DIED:
				# Гибель: рассыпается пеплом (иллюзия — стеклом).
				var uid: int = e.data["uid"]
				var dead := state.get_unit(uid)
				if _pos.has(uid):
					_fx_pool.burst(FxPool.GLASS if dead and dead.illusion else FxPool.ASH, _pos[uid])
				_shake(0.6)
				await _tween_value(func(v: float) -> void: _alpha[uid] = v, 1.0, 0.0, FADE_TIME, null)
			BattleEvent.PUSHED:
				var uid: int = e.data["uid"]
				var from := hex_center(e.data["from"])
				var to := hex_center(e.data["to"])
				await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, STEP_TIME * 1.5, null)
			BattleEvent.HEALED:
				var uid: int = e.data["uid"]
				_count[uid] = _count.get(uid, 0) + int(e.data["revived"])
				_float_text(uid, "+%d" % int(e.data["amount"]), HEAL_COLOR)
				if _pos.has(uid):
					_fx_pool.burst(FxPool.HEAL, _pos[uid])
				_redraw_units()
				await _timer(0.3).timeout
			BattleEvent.DAMAGED:
				var uid: int = e.data["uid"]
				_count[uid] = maxi(0, _count.get(uid, 0) - int(e.data["killed"]))
				_flash[uid] = 0.25
				_float_text(uid, _damage_text(e.data["damage"], e.data["killed"]), DAMAGE_COLOR, 0.0, int(e.data["killed"]))
				if _pos.has(uid):
					_fx_pool.burst(FxPool.SPARK, _pos[uid])
				_redraw_units()
				await _timer(0.25).timeout
			BattleEvent.ABILITY_USED, BattleEvent.HERO_ACTED:
				# Название способности/приказа/заклинания над тем, кто действует (или над целью).
				var who: int = e.data["uid"] if e.data.has("uid") else int(e.data["target"])
				var label: String = event_label.call(e)
				var magic := NAME_COLOR if e.type == BattleEvent.ABILITY_USED else Color(0.75, 0.6, 1.0)
				var at := _pos[who] if _pos.has(who) else (hex_center(e.data["hex"]) if e.data.has("hex") and _hex_fill.has(e.data["hex"]) else Vector2.INF)
				if at != Vector2.INF:
					_ring(at, magic)
					_fx_pool.burst(FxPool.MAGIC, at, magic)
				if label != "" and _pos.has(who):
					_float_text(who, label, NAME_COLOR, -26.0)
					await _timer(0.35).timeout
			BattleEvent.OBSTACLE_ADDED:
				# Стена «вырастает», вода расходится кругами.
				var hex: Vector2i = e.data["hex"]
				if e.data.get("water", false):
					_ring(hex_center(hex), WAVE_COLOR, HEX_SIZE * 1.6)
					_fx_pool.burst(FxPool.RIPPLE, hex_center(hex), WAVE_COLOR)
					_overlay.queue_redraw()
				else:
					await _tween_value(func(v: float) -> void: _grow[hex] = v, 0.0, 1.0, 0.25, _overlay, Tween.EASE_OUT, Tween.TRANS_BACK)
					_grow.erase(hex)
					_overlay.queue_redraw()
			BattleEvent.OBSTACLE_EXPIRED, BattleEvent.ROUND_STARTED:
				_overlay.queue_redraw()
			BattleEvent.SUMMONED:
				# Новый стек: добавить в отображение и проявить.
				var uid: int = e.data["uid"]
				var u := state.get_unit(uid)
				_pos[uid] = hex_center(u.hex)
				_count[uid] = u.count
				_alpha[uid] = 0.0
				_ensure_unit_nodes()
				_ring(_pos[uid], Color(0.8, 0.85, 1.0))
				_fx_pool.burst(FxPool.RIPPLE, _pos[uid], Color(0.8, 0.85, 1.0))
				await _tween_value(func(v: float) -> void: _alpha[uid] = v, 0.0, 1.0, FADE_TIME, null)
			BattleEvent.COMMANDER_INTENT:
				_overlay.queue_redraw()
			BattleEvent.COMMANDER_ACTED:
				# Название действия командира — над целью (или над клеткой стены).
				var label: String = event_label.call(e)
				var uid: int = e.data["target"]
				var pos := _pos[uid] if _pos.has(uid) else hex_center(e.data["hex"])
				_floaters.append({"text": label, "pos": pos + Vector2(0, -26), "t": 0.0, "color": _commander_color()})
				_ring(pos, _commander_color())
				_fx_pool.burst(FxPool.MAGIC, pos, _commander_color())
				_overlay.queue_redraw()
				await _timer(0.45).timeout
			BattleEvent.OBJECTIVE_PROGRESS:
				_overlay.queue_redraw()
			BattleEvent.PHASE_CHANGED:
				# Вторая фаза босса: поле затапливает, течения разворачиваются.
				var uid: int = e.data["uid"]
				if _pos.has(uid):
					_float_text(uid, event_label.call(e), RIFT_COLOR, -26.0)
					_ring(_pos[uid], WAVE_COLOR, HEX_SIZE * 4.0)
					_fx_pool.burst(FxPool.RIPPLE, _pos[uid], WAVE_COLOR)
				_shake(1.0)
				_overlay.queue_redraw()
				await _timer(0.8).timeout
			BattleEvent.RIFT_MARKED:
				_float_text(int(e.data["uid"]), event_label.call(e), RIFT_COLOR, -26.0)
				_redraw_units()
				await _timer(0.5).timeout
			BattleEvent.ERASED:
				var uid: int = e.data["uid"]
				_float_text(uid, event_label.call(e), RIFT_COLOR, -26.0)
				_flash[uid] = 0.4
				_ring(_pos[uid], RIFT_COLOR)
				_fx_pool.burst(FxPool.MAGIC, _pos[uid], RIFT_COLOR)
				await _tween_value(func(v: float) -> void: _alpha[uid] = v, 1.0, 0.0, FADE_TIME * 2.0, null)
	_playing -= 1
	sync()


func _float_text(uid: int, text: String, color: Color, rise: float = 0.0, kills: int = 0) -> void:
	_floaters.append({"text": text, "pos": _pos[uid] + Vector2(0, rise), "t": 0.0, "color": color, "kills": kills})


## Урон для всплывающего текста; погибшие рисуются отдельно черепом.
static func _damage_text(damage: int, _killed: int = 0) -> String:
	return "-%d" % damage


func _play_move(uid: int, path: Array) -> void:
	for i in range(1, path.size()):
		var from := hex_center(path[i - 1])
		var to := hex_center(path[i])
		_face(uid, to.x - from.x)
		var time := STEP_TIME * (HexGrid.distance(path[i - 1], path[i]))
		await _tween_value(func(t: float) -> void: _pos[uid] = from.lerp(to, t), 0.0, 1.0, time, null)


func _play_attack(d: Dictionary) -> void:
	var attacker: int = d["attacker"]
	var target: int = d["target"]
	var from := _pos[attacker]
	var to := _pos[target]
	_face(attacker, to.x - from.x)
	if d["ranged"]:
		var height := from.distance_to(to) * SHOT_ARC
		_trail = PackedVector2Array()
		await _tween_value(_shot_step.bind(from, to, height), 0.0, 1.0, SHOT_TIME, _fx)
		_projectile_t = -1.0
		_trail = PackedVector2Array()
		_fx.queue_redraw()
		Audio.play(&"impact")
	else:
		var lunge := from.lerp(to, 0.35)
		await _tween_value(func(t: float) -> void: _pos[attacker] = from.lerp(lunge, t), 0.0, 1.0, LUNGE_TIME, null, Tween.EASE_OUT, Tween.TRANS_QUAD)
		_tween_value(func(t: float) -> void: _pos[attacker] = lunge.lerp(from, t), 0.0, 1.0, LUNGE_TIME, null)
	var before: int = _count.get(target, 1)
	_count[target] = maxi(0, _count[target] - int(d["killed"]))
	_flash[target] = 0.25
	_fx_pool.burst(FxPool.SPARK, from.lerp(to, 0.75) if not d["ranged"] else to)
	_floaters.append({"text": _damage_text(d["damage"]), "pos": to, "t": 0.0, "color": DAMAGE_COLOR, "kills": int(d["killed"])})
	if int(d["killed"]) > 0:
		_shake(float(d["killed"]) / maxi(1, before))
	_redraw_unit(target)
	# Отдача: цель отшатывается от удара и возвращается.
	var away := (to - from).normalized() * RECOIL
	await _tween_value(func(t: float) -> void: _pos[target] = to + away * sin(t * PI), 0.0, 1.0, 0.18, null)
	_pos[target] = to
	await _timer(0.1).timeout


func _shot_step(t: float, from: Vector2, to: Vector2, height: float) -> void:
	_projectile_t = t
	_trail.append(_shot_point(from, to, height, t))
	if _trail.size() > TRAIL_POINTS:
		_trail.remove_at(0)


## Точка полёта снаряда по дуге.
static func _shot_point(from: Vector2, to: Vector2, height: float, t: float) -> Vector2:
	return from.lerp(to, t) + Vector2(0, -height * sin(t * PI))


func _tween_value(setter: Callable, from: float, to: float, time: float, layer: CanvasItem,
		ease_type: Tween.EaseType = Tween.EASE_IN_OUT, trans: Tween.TransitionType = Tween.TRANS_LINEAR) -> void:
	var tw := create_tween()
	tw.tween_method(_tween_step.bind(setter, layer), from, to, time / Settings.anim_speed).set_ease(ease_type).set_trans(trans)
	await tw.finished


## layer — слой для перерисовки на каждом шаге; null — без перерисовки (позиция и прозрачность фишек).
func _tween_step(value: float, setter: Callable, layer: CanvasItem) -> void:
	setter.call(value)
	if layer:
		layer.queue_redraw()


# --- Слои --------------------------------------------------------------------

## Пакет выпуклых многоугольников: все заливки слоя уходят одним вызовом отрисовки
## (каждый draw_colored_polygon — отдельный draw call).
class FillBatch:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(pts: PackedVector2Array, color: Color) -> void:
		var base := points.size()
		for p in pts:
			points.append(p)
			colors.append(color)
		for i in range(1, pts.size() - 1):
			indices.append_array([base, base + i, base + i + 1])

	func draw(ci: CanvasItem) -> void:
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)


## Пол арены: каменные плиты рядами со сдвигом, оттенок по хешу, края темнеют.
## Одна заливка статичного слоя — без текстуры, дёшево при программной отрисовке.
func _draw_floor(fills: FillBatch) -> void:
	var size := board_size()
	var origin := Vector2(-HexGrid.SQRT3 * HEX_SIZE * 0.5, -HEX_SIZE)
	var margin := Vector2(PLATE.x * 1.5, PLATE.y * 1.5)
	var from := origin - margin
	var to := origin + size + margin
	var center := origin + size * 0.5
	var reach := (to - from).length() * 0.5
	var flooded := state.biome == &"flooded"
	fills.add(PackedVector2Array([from, Vector2(to.x, from.y), to, Vector2(from.x, to.y)]), FLOODED_SEAM if flooded else FLOOR_SEAM)
	# Плиты, целиком скрытые под гексами, не рисуются.
	var hidden := Rect2(origin + Vector2.ONE * HEX_SIZE, size - Vector2.ONE * HEX_SIZE * 2.0)
	var row := 0
	var y := from.y
	while y < to.y:
		var x := from.x - (PLATE.x * 0.5 if row % 2 == 1 else 0.0)
		while x < to.x:
			var h := absi(hash(Vector2i(int(x), int(y)))) % 1000 / 1000.0
			var col := (FLOODED_FLOOR if flooded else FLOOR_COLOR).lightened(h * 0.12).darkened((1.0 - h) * 0.1)
			# Края пола уходят в темноту — вместо виньетки.
			var fade := clampf((Vector2(x, y) + PLATE * 0.5 - center).length() / reach, 0.0, 1.0)
			col = col.lerp(UiKit.BG_COLOR, smoothstep(0.45, 1.0, fade))
			var a := Vector2(x + PLATE_GAP, y + PLATE_GAP)
			var b := Vector2(x + PLATE.x - PLATE_GAP, y + PLATE.y - PLATE_GAP)
			if not hidden.encloses(Rect2(a, b - a)):
				fills.add(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), col)
			x += PLATE.x
		y += PLATE.y
		row += 1


func _draw_board(ci: CanvasItem) -> void:
	var fills := FillBatch.new()
	if not art_floor:
		_draw_floor(fills)
	var outlines := PackedVector2Array()
	var light := PackedVector2Array()
	var dark := PackedVector2Array()
	for hex in _hex_fill:
		var pts := _hex_fill[hex]
		var c := hex_center(hex)
		var hex_col := OBSTACLE_COLOR if state.obstacles.has(hex) else (FLOODED_HEX if state.biome == &"flooded" else HEX_COLOR)
		if art_floor and not state.obstacles.has(hex):
			hex_col.a = ART_HEX_ALPHA
		fills.add(pts, hex_col)
		for i in 6:
			outlines.append(pts[i])
			outlines.append(pts[(i + 1) % 6])
			# Фаска: верхние кромки светлее, нижние темнее.
			var a := c.lerp(pts[i], 0.9)
			var b := c.lerp(pts[(i + 1) % 6], 0.9)
			if (a.y + b.y) * 0.5 < c.y:
				light.append_array([a, b])
			else:
				dark.append_array([a, b])
		if state.obstacles.has(hex):
			# Камень: тень, тело, блик.
			fills.add(_rock(c + Vector2(4, 6)), Color(0, 0, 0, 0.35))
			fills.add(_rock(c), OBSTACLE_COLOR.darkened(0.35))
			fills.add(PackedVector2Array([c + Vector2(-12, -9), c + Vector2(3, -17), c + Vector2(14, -6), c + Vector2(-2, -4)]), OBSTACLE_COLOR.lightened(0.15))
	fills.draw(ci)
	# Все контуры одним вызовом.
	ci.draw_multiline(outlines, HEX_LINE, 1.5)
	ci.draw_multiline(light, BEVEL_LIGHT, 3.0)
	ci.draw_multiline(dark, BEVEL_DARK, 3.0)


func _draw_overlay(ci: CanvasItem) -> void:
	var fills := FillBatch.new()
	var wall_dark := TEMP_WALL_COLOR.darkened(0.3)
	for hex in state.temp_obstacles:
		var c := hex_center(hex)
		var g: float = _grow.get(hex, 1.0)
		fills.add(_hex_fill[hex], OBSTACLE_COLOR.lerp(TEMP_WALL_COLOR, 0.5))
		fills.add(PackedVector2Array([c + g * Vector2(-26, 14), c + g * Vector2(-26, -10), c + g * Vector2(26, -10), c + g * Vector2(26, 14)]), wall_dark)
		for x: float in [-26.0, -9.0, 8.0]:
			fills.add(PackedVector2Array([c + g * Vector2(x, -18), c + g * Vector2(x + 10, -18), c + g * Vector2(x + 10, -10), c + g * Vector2(x, -10)]), wall_dark)
	for hex in state.water:
		fills.add(_hex_fill[hex], WATER_COLOR)
	for hex in state.hold_hexes:
		fills.add(_hex_fill[hex], HOLD_COLOR)
	if dim_unreachable and not reachable.is_empty():
		var active := state.active_unit()
		for hex in _hex_fill:
			if not reachable.has(hex) and (active == null or hex != active.hex) and not state.obstacles.has(hex):
				fills.add(_hex_fill[hex], DIM_COLOR)
	for hex in heat:
		fills.add(_hex_fill[hex], Color(HEAT_COLOR, minf(HEAT_MAX, HEAT_STEP * heat[hex])))
	for hex in threat_attack:
		if not threat.has(hex):
			fills.add(_hex_fill[hex], ATTACK_ZONE_COLOR)
	for hex in targets:
		fills.add(_hex_fill[hex], TARGET_HEX_COLOR)
	for hex in reachable:
		fills.add(_hex_fill[hex], REACH_COLOR)
	for hex in preview_path:
		fills.add(_hex_fill[hex], PATH_COLOR)
	if _hex_fill.has(hover_hex):
		fills.add(_hex_fill[hover_hex], HOVER_COLOR)
	fills.draw(ci)

	# Вода: волнистая штриховка и оставшиеся раунды; временные стены: контур и раунды.
	var waves := PackedVector2Array()
	for hex in state.water:
		var c := hex_center(hex)
		for y: float in [-16.0, 0.0, 16.0]:
			for k in 6:
				var x0 := -27.0 + k * 9.0
				waves.append(c + Vector2(x0, y + 4.0 * sin(k * 1.7)))
				waves.append(c + Vector2(x0 + 9.0, y + 4.0 * sin((k + 1) * 1.7)))
	if not waves.is_empty():
		ci.draw_multiline(waves, WAVE_COLOR, 2.0)
	for hex in state.water:
		# Постоянная вода — без счётчика.
		if state.water[hex] != BattleState.WATER_PERMANENT:
			_draw_rounds(ci, hex_center(hex) + Vector2(14, -14), state.water[hex], WAVE_COLOR)
	# Чернильное облако: тёмная клетка, капли, раунды.
	for hex in state.ink:
		ci.draw_colored_polygon(_hex_fill[hex], INK_COLOR)
		for d: Vector2 in [Vector2(-14, -6), Vector2(10, 4), Vector2(-2, 14)]:
			ci.draw_circle(hex_center(hex) + d, 5.0, Color(0.05, 0.02, 0.08, 0.9))
		_draw_rounds(ci, hex_center(hex) + Vector2(14, -14), state.ink[hex], Color(0.8, 0.6, 1.0))
	# Течения: стрелки по направлению — древки одним вызовом, наконечники одной заливкой.
	if not state.currents.is_empty():
		var shafts := PackedVector2Array()
		var heads := FillBatch.new()
		for hex in state.currents:
			var c := hex_center(hex)
			var dir := (hex_center(HexGrid.step(hex, state.currents[hex])) - c).normalized()
			var tip := c + dir * 18
			shafts.append_array([c - dir * 18, tip])
			heads.add(PackedVector2Array([tip + dir * 6, tip - dir * 6 + dir.orthogonal() * 8, tip - dir * 6 - dir.orthogonal() * 8]), CURRENT_COLOR)
		ci.draw_multiline(shafts, CURRENT_COLOR, 3.0)
		heads.draw(ci)
	for hex in state.temp_obstacles:
		ci.draw_polyline(_hex_inner[hex], TEMP_WALL_COLOR.lightened(0.2), 2.5)
		_draw_rounds(ci, hex_center(hex) + Vector2(0, 30), state.temp_obstacles[hex], Color.WHITE)
	# Знамёна цели «Удержать»: контур и флажок в углу клетки.
	for hex in state.hold_hexes:
		ci.draw_polyline(_hex_inner[hex], HOLD_FLAG, 2.5)
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_ORDER, hex_center(hex) + Vector2(-26, -22), 11, BADGE_BG, HOLD_FLAG)
	_draw_intent(ci)

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
	for uid in shot_targets:
		if _pos.has(uid):
			ci.draw_arc(_pos[uid], UNIT_RADIUS + 7, 0, TAU, 32, THREAT_COLOR, 3.0)
			if shot_targets[uid]:
				# Дальний выстрел — половина урона.
				var p := _pos[uid] + Vector2(UNIT_RADIUS * 0.7, -UNIT_RADIUS * 0.7)
				ci.draw_circle(p, 12, BADGE_BG)
				ci.draw_string(_font, p + Vector2(-12, 6), "½", HORIZONTAL_ALIGNMENT_CENTER, 24, 17, THREAT_COLOR)
	_draw_intent_arrows(ci)
	if highlight_uid >= 0 and _pos.has(highlight_uid):
		ci.draw_arc(_pos[highlight_uid], UNIT_RADIUS + 10, 0, TAU, 40, HIGHLIGHT_COLOR, 3.0)
	for uid in affected:
		if _pos.has(uid):
			ci.draw_arc(_pos[uid], UNIT_RADIUS + 12, 0, TAU, 32, AFFECTED_ALLY if affected[uid] else AFFECTED_ENEMY, 3.0)


const INTENT_ICONS := {
	BattleAction.Type.MOVE: UnitGlyphs.ICON_MOVE,
	BattleAction.Type.MELEE: UnitGlyphs.ICON_MELEE,
	BattleAction.Type.SHOOT: UnitGlyphs.ICON_RANGED,
	BattleAction.Type.ABILITY: UnitGlyphs.ICON_ABILITY,
	BattleAction.Type.DEFEND: UnitGlyphs.ICON_DEFEND,
	BattleAction.Type.WAIT: UnitGlyphs.ICON_WAIT,
}


## Куда направлено намерение врага: позиция цели или клетки; Vector2.INF — некуда.
func intent_point(uid: int) -> Vector2:
	var it: Dictionary = enemy_intents.get(uid, {})
	if it.is_empty():
		return Vector2.INF
	var t := int(it["target"])
	if t >= 0 and _pos.has(t):
		return _pos[t]
	var h: Vector2i = it["hex"]
	return hex_center(h) if _hex_fill.has(h) else Vector2.INF


## Изогнутые стрелки от врага к цели его предполагаемого действия.
func _draw_intent_arrows(ci: CanvasItem) -> void:
	for uid in enemy_intents:
		if not intent_arrows_all and uid != intent_hover:
			continue
		if not _pos.has(uid):
			continue
		var to := intent_point(uid)
		if to == Vector2.INF:
			continue
		var from := _pos[uid]
		var mid := (from + to) * 0.5 + (to - from).orthogonal().normalized() * minf(60.0, from.distance_to(to) * 0.2)
		var pts := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			pts.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
		var col := Color(THREAT_COLOR, 0.85 if uid == intent_hover else 0.55)
		ci.draw_polyline(pts, col, 3.0)
		var dir := (pts[16] - pts[14]).normalized()
		var tip := to - dir * (UNIT_RADIUS * 0.7)
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14 + dir.orthogonal() * 8, tip - dir * 14 - dir.orthogonal() * 8]), col)


func _commander_color() -> Color:
	return db.commander(state.commander_id).color if state.commander_id != &"" else RIFT_COLOR


## Намерение командира: кольцо цвета командира и значок действия над целью или клеткой.
func _draw_intent(ci: CanvasItem) -> void:
	if state.intent.is_empty():
		return
	var id := StringName(state.intent["action"])
	var uid := int(state.intent.get("target", -1))
	var color := _commander_color()
	var c: Vector2
	if uid >= 0 and _pos.has(uid):
		c = _pos[uid]
	else:
		var h: Vector2i = state.intent.get("hex", Vector2i(-1, -1))
		if not _hex_fill.has(h):
			return
		c = hex_center(h)
	# Пунктирное кольцо одним вызовом.
	var dashes := PackedVector2Array()
	for i in 10:
		var a0 := TAU * i / 10.0
		for k in 3:
			dashes.append(c + Vector2.from_angle(a0 + TAU / 60.0 * k) * (UNIT_RADIUS + 14))
			dashes.append(c + Vector2.from_angle(a0 + TAU / 60.0 * (k + 1)) * (UNIT_RADIUS + 14))
	ci.draw_multiline(dashes, color, 3.0)
	UnitGlyphs.draw_icon(ci, CommanderActions.ICONS.get(id, UnitGlyphs.ICON_SPELL), c + Vector2(UNIT_RADIUS * 0.75, -UNIT_RADIUS - 14), 13, BADGE_BG, color)


## Число оставшихся раундов в кружке.
func _draw_rounds(ci: CanvasItem, pos: Vector2, rounds: int, color: Color) -> void:
	ci.draw_circle(pos, 11, Color(0, 0, 0, 0.6))
	ci.draw_string(_font, pos + Vector2(-11, 6), str(rounds), HORIZONTAL_ALIGNMENT_CENTER, 22, 16, color)


func _draw_marker_ring(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(HexGrid.corners(Vector2.ZERO, HEX_SIZE - 1.5), Color(ACTIVE_RING, 0.3))
	ci.draw_arc(Vector2.ZERO, UNIT_RADIUS + 7, 0, TAU, 40, ACTIVE_RING, 5.0)


func _draw_marker_arrow(ci: CanvasItem) -> void:
	var tip := Vector2(0, -UNIT_RADIUS - 18)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16)]), ACTIVE_RING)


func _draw_fx(ci: CanvasItem) -> void:
	for r in _rings:
		var k := float(r["t"]) / RING_TIME
		var col: Color = r["color"]
		var radius := lerpf(UNIT_RADIUS * 0.6, float(r["r"]), 1.0 - pow(1.0 - k, 3.0))
		ci.draw_arc(r["pos"], radius, 0, TAU, 40, Color(col, 1.0 - k), 5.0 * (1.0 - k) + 1.0)
	if _trail.size() >= 2:
		for i in range(1, _trail.size()):
			var a := float(i) / _trail.size()
			ci.draw_line(_trail[i - 1], _trail[i], Color(UiKit.ACCENT, a), 1.0 + 4.0 * a)
		ci.draw_circle(_trail[_trail.size() - 1], 4.0, Color(1, 0.95, 0.75))
	for f in _floaters:
		var t := float(f["t"])
		# «Пружина»: масштаб трансформом — размер шрифта постоянный, иначе движок растеризует
		# глифы под каждый новый размер (рывки при программной отрисовке).
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t / 0.15)
		var size := FLOATER_FONT
		var pos: Vector2 = f["pos"] + Vector2(-30, -UNIT_RADIUS - 10 - 40 * t)
		var col: Color = f.get("color", DAMAGE_COLOR)
		col.a = clampf(1.6 - t * 1.4, 0, 1)
		ci.draw_set_transform(pos, 0.0, Vector2.ONE * pop)
		ci.draw_string_outline(_font, Vector2.ZERO, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, col.a))
		ci.draw_string(_font, Vector2.ZERO, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		var kills := int(f.get("kills", 0))
		if kills > 0:
			var w := _font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var ip := Vector2(w + 16, -size * 0.35)
			UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_KILL, ip, 11, Color(0, 0, 0, 0.6 * col.a), Color(1, 1, 1, col.a))
			ci.draw_string_outline(_font, ip + Vector2(13, size * 0.35), str(kills), HORIZONTAL_ALIGNMENT_LEFT, -1, size - 4, 6, Color(0, 0, 0, col.a))
			ci.draw_string(_font, ip + Vector2(13, size * 0.35), str(kills), HORIZONTAL_ALIGNMENT_LEFT, -1, size - 4, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rock(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(-24, 14), c + Vector2(-14, -12), c + Vector2(4, -20), c + Vector2(22, -6), c + Vector2(20, 16)])


## Значки временных состояний: [значок, цвет]. Порядок — по важности.
static func status_icons(u: UnitState) -> Array:
	var list: Array = []
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		list.append([UnitGlyphs.ICON_MARK, RIFT_COLOR])
	if u.has_status(UnitState.STATUS_MARKED):
		list.append([UnitGlyphs.ICON_MARK, DAMAGE_COLOR])
	if u.defending:
		list.append([UnitGlyphs.ICON_DEFEND, UiKit.PLAYER_COLOR.lightened(0.3)])
	if u.has_status(UnitState.STATUS_SHIELD_WALL):
		list.append([UnitGlyphs.ICON_RETALIATION, UiKit.ACCENT])
	elif u.retaliated:
		list.append([UnitGlyphs.ICON_RETALIATION_USED, UiKit.MUTED])
	if u.has_status(UnitState.STATUS_RUST_ARMOR):
		list.append([UnitGlyphs.ICON_ARMOR, UiKit.ACCENT])
	if u.has_status(UnitState.STATUS_ADVANCE):
		list.append([UnitGlyphs.ICON_ORDER, UiKit.ACCENT])
	if u.fury > 0:
		list.append([UnitGlyphs.ICON_MELEE, UiKit.DANGER])
	return list


## Тело фишки: круг с объёмом, кольцо стороны, силуэт. Рисуется в начале координат узла;
## «дыхание» и поворот — масштабом узла.
## Фишка целиком: тело (зеркально, если смотрит влево), затем значки без поворота.
## Тела фишек запекаются в текстуры: при программной отрисовке каждый вызов дорог,
## а тело (круг, кольцо, тень, силуэт, акценты) — десяток вызовов. Ключ — вид, сторона, иллюзия.
## Текстура — сама текстура вьюпорта, без чтения из видеопамяти (оно давало рывки до 200 мс);
## вьюпорт рисуется один раз и остаётся в дереве выключенным. Все тела боя запекаются при открытии.
const BODY_TEX := 96
var _body_tex: Dictionary = {}


func _draw_units(ci: CanvasItem) -> void:
	# Ближние (ниже на экране) перекрывают дальних — рисованные фигуры выше гекса.
	var order: Array[UnitState] = []
	for u in state.units:
		if float(_alpha.get(u.uid, 0.0)) > 0.0 and _pos.has(u.uid):
			order.append(u)
	order.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		return _pos[a.uid].y < _pos[b.uid].y or (_pos[a.uid].y == _pos[b.uid].y and a.uid < b.uid))
	for u in order:
		_draw_unit_node(ci, u, float(_alpha[u.uid]) * (ILLUSION_ALPHA if u.illusion else 1.0))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Высота рисованной фигуры на поле (0 — фигуры нет, рисуется глиф).
func figure_height(u: UnitState) -> float:
	if ArtDB.unit(u.def_id) == null:
		return 0.0
	return FIGURE_HEIGHT_LARGE if db.unit(u.def_id).size_class == &"large" else FIGURE_HEIGHT


## Рисованная фигура: тень и подставка цвета стороны, затем картинка по точке опоры
## («дыхание» — по вертикали от ног, летуны покачиваются, вспышка — осветлением, гибель — в чернила).
func _draw_figure(ci: CanvasItem, u: UnitState, pos: Vector2, alpha: float, tex: Texture2D) -> void:
	var feet := pos + Vector2(0, FEET_Y)
	var side_color := UiKit.PLAYER_COLOR if u.side == UnitState.Side.PLAYER else UiKit.ENEMY_COLOR
	var base_r := HEX_SIZE * (0.62 if db.unit(u.def_id).size_class == &"large" else 0.5)
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.34))
	ci.draw_circle(Vector2.ZERO, base_r, Color(SHADOW_COLOR, SHADOW_COLOR.a * alpha))
	ci.draw_arc(Vector2.ZERO, base_r, 0, TAU, 40, Color(side_color, 0.85 * alpha), 6.0 if show_active and u.uid == state.active_uid else 4.0)
	var breath := 1.0 + BREATH * 0.75 * sin(_time * TAU / BREATH_PERIOD + u.uid * 1.7)
	if u.is_flying:
		feet.y -= FLYER_BOB * (1.0 + sin(_time * 1.8 + u.uid))
	if show_active and u.uid == state.active_uid:
		feet.y -= 4.0
	var h := figure_height(u)
	var size := tex.get_size() * (h / tex.get_size().y)
	var anchor := ArtDB.anchor(u.def_id)
	ci.draw_set_transform(feet, 0.0, Vector2(_facing.get(u.uid, 1.0), breath))
	var mod := Color(1, 1, 1, alpha)
	var life: float = _alpha.get(u.uid, 1.0)
	if life < 1.0 and not u.is_alive():
		# Гибель: фигура темнеет в чернила, пока тает.
		mod = Color(UnitGlyphs.INK.lerp(Color.WHITE, life * life), alpha)
	if _flash.has(u.uid):
		var f := 1.0 + 1.6 * clampf(_flash[u.uid] / 0.25, 0.0, 1.0)
		mod = Color(mod.r * f, mod.g * f, mod.b * f, mod.a)
	ci.draw_texture_rect(tex, Rect2(-anchor * size, size), false, mod)


## Фишка: тело (зеркально, если смотрит влево, с «дыханием»), вспышка, метки, значки.
func _draw_unit_node(ci: CanvasItem, u: UnitState, alpha: float) -> void:
	var pos := _pos[u.uid]
	var art := ArtDB.unit(u.def_id)
	if art:
		_draw_figure(ci, u, pos, alpha, art)
		ci.draw_set_transform(pos, 0.0, Vector2.ONE)
		_draw_unit_marks(ci, u, alpha)
		_draw_unit_badges(ci, u, alpha)
		return
	var breath := 1.0 + BREATH * sin(_time * TAU / BREATH_PERIOD + u.uid * 1.7)
	var tex := _body_texture(u)
	ci.draw_set_transform(pos, 0.0, Vector2(_facing.get(u.uid, 1.0) * breath, breath))
	if tex:
		ci.draw_texture(tex, -Vector2.ONE * BODY_TEX * 0.5, Color(1, 1, 1, alpha))
	else:
		_draw_unit_body(ci, u, alpha)
	ci.draw_set_transform(pos, 0.0, Vector2.ONE)
	if _flash.has(u.uid):
		ci.draw_circle(Vector2.ZERO, UNIT_RADIUS, Color(1, 1, 1, 0.55 * alpha * clampf(_flash[u.uid] / 0.25, 0.0, 1.0)))
	_draw_unit_marks(ci, u, alpha)
	_draw_unit_badges(ci, u, alpha)


func _body_key(u: UnitState) -> String:
	return "%s|%d|%s" % [u.def_id, u.side, u.illusion]


func _body_texture(u: UnitState) -> Texture2D:
	var key := _body_key(u)
	if not _body_tex.has(key):
		_body_tex[key] = _bake_body(u)
	return _body_tex[key] as Texture2D


func _bake_body(u: UnitState) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(BODY_TEX, BODY_TEX)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _add_layer(vp, func(ci: CanvasItem) -> void: _draw_unit_body(ci, u, 1.0))
	painter.position = Vector2.ONE * BODY_TEX * 0.5
	add_child(vp)
	return vp.get_texture()


## Метки поверх тела (не запекаются): Разлом, мишень цели.
func _draw_unit_marks(ci: CanvasItem, u: UnitState, alpha: float) -> void:
	if u.has_status(UnitState.STATUS_RIFT_MARKED):
		ci.draw_arc(Vector2.ZERO, UNIT_RADIUS + 9, 0, TAU, 32, Color(RIFT_COLOR, alpha), 3.0)
	if u.is_boss and state.objective == ObjectiveRule.ASSASSINATE:
		# Мишень цели «Уничтожить цель».
		ci.draw_arc(Vector2.ZERO, UNIT_RADIUS + 6, 0, TAU, 32, Color(TARGET_MARK, alpha), 2.5)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			ci.draw_line(d * (UNIT_RADIUS + 1), d * (UNIT_RADIUS + 12), Color(TARGET_MARK, alpha), 3.0)


func _draw_unit_body(ci: CanvasItem, u: UnitState, alpha: float) -> void:
	var c := Vector2.ZERO
	var is_player := u.side == UnitState.Side.PLAYER
	var side_color := UiKit.PLAYER_COLOR if is_player else UiKit.ENEMY_COLOR
	var body := db.unit(u.def_id).color
	body.a = alpha
	var ink := Color(UnitGlyphs.INK, alpha)
	var ring := Color(side_color, alpha)

	_shaded_circle(ci, c, UNIT_RADIUS, body)
	if u.illusion:
		# Иллюзия: пунктирное кольцо.
		for i in 12:
			var a0 := TAU * i / 12.0
			ci.draw_arc(c, UNIT_RADIUS, a0, a0 + TAU / 24.0, 4, Color(side_color, alpha), SIDE_RING_WIDTH)
	else:
		ci.draw_arc(c, UNIT_RADIUS, 0, TAU, 32, ring, SIDE_RING_WIDTH + (0.0 if is_player else 1.0))
	# Двухтоновый силуэт: мягкая тень, затем сам силуэт.
	UnitGlyphs.draw_unit(ci, u.def_id, c + Vector2(1.5, 2.5), UNIT_RADIUS * 0.82, body, Color(0, 0, 0, 0.3))
	UnitGlyphs.draw_unit(ci, u.def_id, c, UNIT_RADIUS * 0.82, body, ink)
	UnitGlyphs.draw_details(ci, u.def_id, c, UNIT_RADIUS * 0.82, body)


## Значки, численность и полоска здоровья — не поворачиваются и не «дышат».
func _draw_unit_badges(ci: CanvasItem, u: UnitState, alpha: float) -> void:
	var k := 1.3 if Settings.large_icons else 1.0
	var c := Vector2.ZERO
	var is_player := u.side == UnitState.Side.PLAYER
	var side_color := UiKit.PLAYER_COLOR if is_player else UiKit.ENEMY_COLOR
	var body := db.unit(u.def_id).color
	if _flash.has(u.uid):
		body = body.lerp(Color.WHITE, 0.7)
	body.a = alpha
	var ink := Color(UnitGlyphs.INK, alpha)
	var ring := Color(side_color, alpha)
	var fg := Color(1, 1, 1, alpha)
	var bg := Color(BADGE_BG, alpha)


	# Постоянные свойства по бокам: стрелок (с выстрелами) слева, летун справа, способность снизу слева.
	var badge_r := 11.0 * k
	var font_size := int(15 * k)
	if u.is_ranged:
		var pos := c + Vector2(-UNIT_RADIUS - 2, -6)
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_RANGED, pos, badge_r, bg, fg if u.shots_left > 0 else Color(UiKit.MUTED, alpha))
		_outlined(ci, pos + Vector2(-badge_r - 18 * k, 6 * k), str(u.shots_left), HORIZONTAL_ALIGNMENT_RIGHT, 16 * k, font_size, fg, alpha)
	if u.is_flying:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_FLYING, c + Vector2(UNIT_RADIUS + 2, -6), badge_r, bg, fg)
	if u.ability_id != &"":
		# Способность: золотая звезда — готова, серая с цифрой — раунды до готовности.
		var pos := c + Vector2(-UNIT_RADIUS - 2, UNIT_RADIUS - 10)
		var ready := u.ability_cd <= 0
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_ABILITY, pos, badge_r, bg, Color(UiKit.ACCENT if ready else UiKit.MUTED, alpha))
		if not ready:
			_outlined(ci, pos + Vector2(-8 * k, 6 * k), str(u.ability_cd), HORIZONTAL_ALIGNMENT_CENTER, 16 * k, font_size, fg, alpha)
	if enemy_intents.has(u.uid) and (Settings.show_intents or intent_arrows_all or u.uid == intent_hover):
		# Предполагаемое действие врага — снизу справа.
		var kind: int = enemy_intents[u.uid]["type"]
		UnitGlyphs.draw_icon(ci, INTENT_ICONS.get(kind, UnitGlyphs.ICON_MOVE), c + Vector2(UNIT_RADIUS + 2, UNIT_RADIUS - 10), badge_r, bg, Color(THREAT_COLOR.lightened(0.2), alpha))
	if threatened.has(u.uid):
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_THREAT, c + Vector2(UNIT_RADIUS + 2, UNIT_RADIUS - 10), badge_r, bg, Color(UiKit.DANGER, alpha))
	if u.illusion:
		UnitGlyphs.draw_icon(ci, UnitGlyphs.ICON_MASK, c + Vector2(UNIT_RADIUS + 2, UNIT_RADIUS - 10 - (2.2 * badge_r if threatened.has(u.uid) else 0.0)),
				badge_r, bg, Color(0.85, 0.85, 1.0, alpha))

	# Временные состояния — рядом над фишкой, не больше трёх, остальное «+N».
	var statuses := status_icons(u)
	# Над головой рисованной фигуры, иначе — над фишкой.
	var fig_h := figure_height(u)
	var status_y := FEET_Y - fig_h * 0.92 if fig_h > 0.0 else -UNIT_RADIUS - 2.0
	var shown := mini(statuses.size(), MAX_STATUS_ICONS)
	var step := badge_r * 2.1
	var extra := statuses.size() - shown
	var total := shown + (1 if extra > 0 else 0)
	for i in total:
		var pos := c + Vector2((i - (total - 1) * 0.5) * step, status_y)
		if i < shown:
			UnitGlyphs.draw_icon(ci, statuses[i][0], pos, badge_r, bg, Color(statuses[i][1], alpha))
		else:
			ci.draw_circle(pos, badge_r, bg)
			_outlined(ci, pos + Vector2(-badge_r, 5 * k), "+%d" % extra, HORIZONTAL_ALIGNMENT_CENTER, badge_r * 2, int(13 * k), fg, alpha)

	# Численность: у своих — прямоугольник, у врагов — заострённый книзу щиток (различимо без цвета).
	var bw := 48.0 * k
	var bh := 24.0 * k
	var top := c + Vector2(-bw * 0.5, UNIT_RADIUS - 12)
	var shape := PackedVector2Array([top, top + Vector2(bw, 0), top + Vector2(bw, bh), top + Vector2(0, bh)])
	var tip := 0.0
	if not is_player:
		tip = 7.0 * k
		shape = PackedVector2Array([top, top + Vector2(bw, 0), top + Vector2(bw, bh), top + Vector2(bw * 0.5, bh + tip), top + Vector2(0, bh)])
	ci.draw_colored_polygon(shape, Color(side_color.darkened(0.55), alpha))
	var outline := shape.duplicate()
	outline.append(shape[0])
	ci.draw_polyline(outline, ring, 2.0)
	ci.draw_string(_font, top + Vector2(0, 19 * k), str(_count.get(u.uid, u.count)), HORIZONTAL_ALIGNMENT_CENTER, bw, int(19 * k), fg)
	var hp_ratio := clampf(float(u.top_hp) / u.hp, 0.0, 1.0) if u.is_alive() else 0.0
	var bar := Rect2(top + Vector2(0, bh + tip + 1), Vector2(bw, 4))
	ci.draw_rect(bar, Color(0.1, 0.1, 0.1, alpha))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_ratio, bar.size.y)), Color(Color(0.4, 0.85, 0.4).lerp(UiKit.DANGER, 1.0 - hp_ratio), alpha))


## Круг с объёмом: светлее сверху-слева, темнее снизу-справа, блик.
func _shaded_circle(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 28:
		var dir := Vector2.from_angle(TAU * i / 28.0)
		pts.append(c + dir * r)
		cols.append(color.lightened(0.18) if dir.dot(Vector2(-0.6, -0.8)) > 0.0 else color.darkened(0.22 * -dir.dot(Vector2(-0.6, -0.8))))
	ci.draw_polygon(pts, cols)
	ci.draw_arc(c, r * 0.78, deg_to_rad(200), deg_to_rad(250), 10, Color(1, 1, 1, 0.22 * color.a), r * 0.12)


func _outlined(ci: CanvasItem, pos: Vector2, text: String, align: HorizontalAlignment, width: float, font_size: int, color: Color, alpha: float) -> void:
	ci.draw_string_outline(_font, pos, text, align, width, font_size, 4, Color(0, 0, 0, alpha))
	ci.draw_string(_font, pos, text, align, width, font_size, color)
