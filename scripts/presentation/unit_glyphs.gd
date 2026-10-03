class_name UnitGlyphs
extends RefCounted
## Процедурные силуэты существ и значки способностей (плейсхолдер вместо арта).
## Все фигуры задаются в нормированных координатах [-1, 1] и масштабируются радиусом.

const INK := Color(0.07, 0.07, 0.1)

# Значки способностей и состояний.
const ICON_MELEE := &"melee"
const ICON_RANGED := &"ranged"
const ICON_FLYING := &"flying"
const ICON_RETALIATION := &"retaliation"
const ICON_RETALIATION_USED := &"retaliation_used"
const ICON_DEFEND := &"defend"
const ICON_WAIT := &"wait"
const ICON_MOVE := &"move"
const ICON_ABILITY := &"ability"
const ICON_MARK := &"mark"
const ICON_ARMOR := &"armor"
const ICON_HEAL := &"heal"
const ICON_ORDER := &"order"
const ICON_SPELL := &"spell"
const ICON_INK := &"ink"
const ICON_PARCHMENT := &"parchment"
const ICON_AETHER := &"aether"
const ICON_HP := &"hp"
const ICON_SPEED := &"speed"
const ICON_KILL := &"kill"
const ICON_POINTS := &"points"
const ICON_LOCK := &"lock"
const ICON_MASK := &"mask"
const ICON_THREAT := &"threat"
const ICON_WATER := &"water"
const ICON_CHALICE := &"chalice"

## Все значки — для запекания в текстуры (IconAtlas).
const ALL_ICONS: Array[StringName] = [
	ICON_MELEE, ICON_RANGED, ICON_FLYING, ICON_RETALIATION, ICON_RETALIATION_USED, ICON_DEFEND, ICON_WAIT,
	ICON_MOVE, ICON_ABILITY, ICON_MARK, ICON_ARMOR, ICON_HEAL, ICON_ORDER, ICON_SPELL,
	ICON_INK, ICON_PARCHMENT, ICON_AETHER, ICON_HP, ICON_SPEED, ICON_KILL, ICON_POINTS, ICON_LOCK,
	ICON_MASK, ICON_THREAT, ICON_WATER, ICON_CHALICE,
]


## Силуэт существа по id определения.
static func draw_unit(ci: CanvasItem, def_id: StringName, c: Vector2, r: float, body: Color, ink: Color = INK) -> void:
	match def_id:
		&"salt_guard":
			_shield(ci, c, r * 0.95, ink, body)
		&"chronicler":
			_scroll_and_quill(ci, c, r, ink, body)
		&"ash_ghoul":
			_claws(ci, c, r, ink)
		&"shard_archer":
			_bow(ci, c, r, ink)
		&"storm_wyrm_echo":
			_poly(ci, c, r, [Vector2(0.15, -0.8), Vector2(-0.45, 0.12), Vector2(-0.02, 0.12), Vector2(-0.22, 0.8), Vector2(0.48, -0.18), Vector2(0.05, -0.18)], ink)
		&"rust_sentinel":
			_tower(ci, c, r, ink, body)
		&"faceless_choir":
			_masks(ci, c, r, ink, body)
		&"ash_priest":
			_chalice(ci, c, r, ink)
		&"tide_warden":
			# Трезубец.
			ci.draw_line(c + Vector2(0, -0.55) * r, c + Vector2(0, 0.85) * r, ink, maxf(2.0, r * 0.14))
			ci.draw_line(c + Vector2(-0.45, -0.25) * r, c + Vector2(0.45, -0.25) * r, ink, maxf(2.0, r * 0.12))
			for x: float in [-0.45, 0.0, 0.45]:
				_poly(ci, c, r, [Vector2(x - 0.1, -0.25), Vector2(x, -0.85), Vector2(x + 0.1, -0.25)], ink)
		&"deep_jelly":
			# Медуза: купол и щупальца.
			ci.draw_arc(c + Vector2(0, 0.05) * r, r * 0.55, PI, TAU, 16, ink, maxf(3.0, r * 0.5))
			for x: float in [-0.35, 0.0, 0.35]:
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(c + Vector2(x + 0.1 * sin(k * 1.4), 0.1 + k * 0.14) * r)
				ci.draw_polyline(pts, ink, maxf(2.0, r * 0.1))
		&"clock_turret":
			# Шестерня со стволом.
			ci.draw_circle(c + Vector2(-0.1, 0.15) * r, r * 0.42, ink)
			for k in 8:
				var a := TAU * k / 8.0
				ci.draw_line(c + Vector2(-0.1, 0.15) * r + Vector2.from_angle(a) * r * 0.4,
						c + Vector2(-0.1, 0.15) * r + Vector2.from_angle(a) * r * 0.6, ink, maxf(2.0, r * 0.14))
			ci.draw_circle(c + Vector2(-0.1, 0.15) * r, r * 0.15, body)
			ci.draw_line(c + Vector2(0.1, -0.05) * r, c + Vector2(0.75, -0.6) * r, ink, maxf(3.0, r * 0.2))
		&"brass_tinker":
			# Гаечный ключ.
			ci.draw_line(c + Vector2(-0.55, 0.55) * r, c + Vector2(0.25, -0.25) * r, ink, maxf(3.0, r * 0.22))
			ci.draw_arc(c + Vector2(0.38, -0.38) * r, r * 0.28, deg_to_rad(-200), deg_to_rad(60), 12, ink, maxf(3.0, r * 0.18))
		&"mirror_double":
			# Ручное зеркало с отражением.
			ci.draw_circle(c + Vector2(0, -0.2) * r, r * 0.48, ink)
			ci.draw_circle(c + Vector2(0, -0.2) * r, r * 0.32, body)
			ci.draw_line(c + Vector2(-0.12, -0.38) * r, c + Vector2(0.1, -0.05) * r, ink, maxf(1.5, r * 0.08))
			ci.draw_line(c + Vector2(0, 0.28) * r, c + Vector2(0, 0.85) * r, ink, maxf(3.0, r * 0.18))
		&"face_thief":
			# Полумаска с прорезями.
			_poly(ci, c, r, [Vector2(-0.75, -0.35), Vector2(0.75, -0.35), Vector2(0.6, 0.25), Vector2(0.15, 0.35), Vector2(0, 0.15), Vector2(-0.15, 0.35), Vector2(-0.6, 0.25)], ink)
			_poly(ci, c, r, [Vector2(-0.5, -0.12), Vector2(-0.15, -0.12), Vector2(-0.22, 0.02), Vector2(-0.45, 0.02)], body)
			_poly(ci, c, r, [Vector2(0.5, -0.12), Vector2(0.15, -0.12), Vector2(0.22, 0.02), Vector2(0.45, 0.02)], body)
		&"archive_relic":
			# Стопка книг.
			for i in 3:
				var y := 0.45 - i * 0.38
				_poly(ci, c, r, [Vector2(-0.7 + i * 0.08, y - 0.15), Vector2(0.7 - i * 0.05, y - 0.15), Vector2(0.7 - i * 0.05, y + 0.15), Vector2(-0.7 + i * 0.08, y + 0.15)], ink)
				ci.draw_line(c + Vector2(-0.5 + i * 0.08, y) * r, c + Vector2(0.5 - i * 0.05, y) * r, body, maxf(1.5, r * 0.06))
		&"drowned_scribe":
			# Свиток под каплей.
			_poly(ci, c, r, [Vector2(-0.6, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 0.7), Vector2(-0.6, 0.7)], ink)
			ci.draw_line(c + Vector2(-0.75, 0.0) * r, c + Vector2(0.75, 0.0) * r, ink, maxf(2.0, r * 0.16))
			var drop := PackedVector2Array([c + Vector2(0, -0.85) * r])
			for k in 9:
				var a := PI * k / 8.0
				drop.append(c + Vector2(cos(a) * 0.3, -0.35 + sin(a) * 0.3) * r)
			ci.draw_colored_polygon(drop, ink)
		&"abyss_warden":
			# Шлем с гребнем.
			_poly(ci, c, r, [Vector2(-0.6, 0.75), Vector2(-0.6, -0.15), Vector2(-0.3, -0.55), Vector2(0.3, -0.55), Vector2(0.6, -0.15), Vector2(0.6, 0.75)], ink)
			_poly(ci, c, r, [Vector2(-0.4, 0.05), Vector2(0.4, 0.05), Vector2(0.4, 0.2), Vector2(-0.4, 0.2)], body)
			_poly(ci, c, r, [Vector2(-0.08, -0.55), Vector2(0.08, -0.55), Vector2(0.15, -0.95), Vector2(-0.15, -0.95)], ink)
		&"ink_kraken":
			# Голова спрута и щупальца.
			ci.draw_circle(c + Vector2(0, -0.3) * r, r * 0.42, ink)
			for x: float in [-0.5, -0.2, 0.2, 0.5]:
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(c + Vector2(x + 0.12 * sin(k * 1.3 + x * 4.0), 0.05 + k * 0.15) * r)
				ci.draw_polyline(pts, ink, maxf(2.0, r * 0.12))
			ci.draw_circle(c + Vector2(-0.15, -0.35) * r, r * 0.07, body)
			ci.draw_circle(c + Vector2(0.15, -0.35) * r, r * 0.07, body)
		&"siren":
			# Хвост и плавник.
			_poly(ci, c, r, [Vector2(-0.2, -0.75), Vector2(0.25, -0.6), Vector2(0.3, 0.1), Vector2(0.1, 0.55), Vector2(-0.15, 0.2)], ink)
			_poly(ci, c, r, [Vector2(0.1, 0.5), Vector2(0.7, 0.85), Vector2(0.2, 0.35), Vector2(-0.3, 0.85)], ink)
			ci.draw_circle(c + Vector2(0.0, -0.75) * r, r * 0.22, ink)
		&"deep_eel":
			# Изогнутый угорь.
			var pts := PackedVector2Array()
			for k in 12:
				var t := k / 11.0
				pts.append(c + Vector2(-0.75 + 1.5 * t, 0.3 * sin(t * TAU)) * r)
			ci.draw_polyline(pts, ink, maxf(3.0, r * 0.28))
			ci.draw_circle(pts[pts.size() - 1], r * 0.2, ink)
		&"abyss_lord":
			# Корона над водоворотом.
			for i in 3:
				ci.draw_arc(c + Vector2(0, 0.25) * r, r * (0.18 + 0.18 * i), i * 1.3, i * 1.3 + PI * 1.4, 18, ink, maxf(2.0, r * 0.1))
			_poly(ci, c, r, [Vector2(-0.6, -0.25), Vector2(-0.6, -0.8), Vector2(-0.3, -0.5), Vector2(0, -0.9), Vector2(0.3, -0.5), Vector2(0.6, -0.8), Vector2(0.6, -0.25)], ink)
		&"rift_warden":
			for i in 3:
				ci.draw_arc(c, r * (0.25 + 0.22 * i), i * 1.1, i * 1.1 + PI * 1.5, 20, ink, maxf(2.0, r * 0.12))
			ci.draw_circle(c, r * 0.12, ink)
		&"rift_ram":
			_poly(ci, c, r, [Vector2(-0.75, 0.55), Vector2(-0.35, -0.55), Vector2(0.15, -0.75), Vector2(0.8, -0.2), Vector2(0.25, -0.15), Vector2(0.1, 0.55)], ink)
		_:
			ci.draw_circle(c, r * 0.45, ink)


## Второй тон силуэта (SPEC_SPRINT6 6): светлые и цветные акценты поверх тёмной фигуры.
## Рисуется после draw_unit; light — блик в тон тела, ember/glow — свои цвета существа.
static func draw_details(ci: CanvasItem, def_id: StringName, c: Vector2, r: float, body: Color) -> void:
	var light := Color(body.lightened(0.55), 0.9 * body.a)
	var w := maxf(1.5, r * 0.07)
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * r
	match def_id:
		&"salt_guard":
			for v: Vector2 in [Vector2(-0.3, -0.35), Vector2(0.3, -0.35), Vector2(0, 0.3)]:
				ci.draw_circle(p.call(v.x, v.y), r * 0.06, light)
			ci.draw_line(p.call(-0.55, -0.62), p.call(0.55, -0.62), light, w)
		&"chronicler":
			for i in 4:
				ci.draw_line(p.call(0.2 + i * 0.08, -0.6 + i * 0.1), p.call(0.38 + i * 0.08, -0.7 + i * 0.1), light, w * 0.8)
		&"ash_ghoul":
			for x: float in [-0.38, -0.05, 0.28]:
				ci.draw_circle(p.call(x, -0.62), r * 0.07, Color(1.0, 0.55, 0.25, body.a))
		&"shard_archer":
			ci.draw_line(p.call(-0.1, -0.8), p.call(-0.1, 0.8), Color(light, 0.7 * body.a), w * 0.7)
			ci.draw_circle(p.call(0.62, 0.0), r * 0.08, Color(0.7, 0.9, 1.0, body.a))
		&"storm_wyrm_echo":
			for a: float in [0.3, 2.2, 4.1]:
				var d := Vector2.from_angle(a)
				ci.draw_line(c + d * r * 0.62, c + d * r * 0.82, Color(0.75, 0.9, 1.0, body.a), w)
		&"rust_sentinel":
			ci.draw_line(p.call(-0.15, -0.2), p.call(0.15, -0.2), Color(1.0, 0.75, 0.35, body.a), w * 1.4)
			ci.draw_circle(p.call(0.3, 0.35), r * 0.08, Color(0.75, 0.38, 0.2, body.a))
		&"faceless_choir":
			for x: float in [-0.4, 0.0, 0.4]:
				ci.draw_circle(p.call(x, -0.12), r * 0.05, light)
		&"ash_priest":
			ci.draw_circle(p.call(0, -0.62), r * 0.13, Color(1.0, 0.6, 0.2, body.a))
			ci.draw_circle(p.call(0, -0.68), r * 0.07, Color(1.0, 0.9, 0.5, body.a))
		&"tide_warden":
			var wave := PackedVector2Array()
			for k in 9:
				wave.append(p.call(-0.6 + k * 0.15, 0.62 + 0.06 * sin(k * 1.8)))
			ci.draw_polyline(wave, Color(0.6, 0.85, 1.0, body.a), w)
		&"deep_jelly":
			ci.draw_arc(p.call(-0.12, -0.05), r * 0.32, PI * 1.15, PI * 1.55, 8, light, w)
		&"clock_turret":
			ci.draw_circle(p.call(-0.1, 0.15), r * 0.07, Color(1.0, 0.8, 0.4, body.a))
			ci.draw_circle(p.call(0.75, -0.6), r * 0.09, Color(1.0, 0.6, 0.3, body.a))
		&"brass_tinker":
			ci.draw_circle(p.call(0.38, -0.38), r * 0.08, light)
			ci.draw_line(p.call(-0.45, 0.45), p.call(-0.1, 0.1), light, w * 0.7)
		&"mirror_double":
			for a: float in [0.6, 2.0, 3.4, 4.8]:
				ci.draw_circle(p.call(0, -0.2) + Vector2.from_angle(a) * r * 0.48, r * 0.045, light)
		&"face_thief":
			ci.draw_line(p.call(-0.6, -0.3), p.call(0.6, -0.3), light, w)
		&"archive_relic":
			ci.draw_line(p.call(0.3, -0.45), p.call(0.3, 0.05), Color(0.85, 0.25, 0.2, body.a), w * 1.6)
		&"rift_warden":
			ci.draw_circle(c, r * 0.2, Color(0.8, 0.5, 1.0, 0.6 * body.a))
			ci.draw_circle(c, r * 0.09, Color(1, 0.9, 1, body.a))
		&"rift_ram":
			ci.draw_line(p.call(-0.3, -0.45), p.call(0.1, -0.65), light, w)
			ci.draw_circle(p.call(0.45, -0.25), r * 0.06, Color(0.85, 0.5, 1.0, body.a))


## Значок способности/состояния в круглом медальоне.
## ring = false — без медальона (значок крупнее; для текстур IconAtlas).
static func draw_icon(ci: CanvasItem, kind: StringName, c: Vector2, r: float, bg: Color, fg: Color = Color.WHITE, ring: bool = true) -> void:
	var s := r * 0.75
	if ring:
		ci.draw_circle(c, r, bg)
		ci.draw_circle(c, r, Color(fg, 0.35 * fg.a), false, 1.5)
	else:
		s = r * 0.95
	match kind:
		ICON_MELEE:
			_sword(ci, c, s, fg, -45.0)
		ICON_RANGED:
			_arrow(ci, c, s, fg)
		ICON_FLYING:
			_poly(ci, c, s, [Vector2(-0.9, 0.5), Vector2(-0.2, -0.8), Vector2(0.9, -0.9), Vector2(0.5, -0.3), Vector2(0.75, -0.2), Vector2(0.3, 0.2), Vector2(0.5, 0.3), Vector2(-0.1, 0.6)], fg)
		ICON_RETALIATION, ICON_RETALIATION_USED:
			_sword(ci, c, s, fg, -45.0)
			_sword(ci, c, s, fg, 45.0)
			if kind == ICON_RETALIATION_USED:
				ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), UiKit.DANGER, 3.0)
		ICON_DEFEND:
			_shield(ci, c, s, fg, bg)
		ICON_WAIT:
			_poly(ci, c, s, [Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0, 0)], fg)
			_poly(ci, c, s, [Vector2(0, 0), Vector2(0.6, 0.8), Vector2(-0.6, 0.8)], fg)
		ICON_MOVE:
			_poly(ci, c, s, [Vector2(-0.8, -0.25), Vector2(0.1, -0.25), Vector2(0.1, -0.7), Vector2(0.85, 0), Vector2(0.1, 0.7), Vector2(0.1, 0.25), Vector2(-0.8, 0.25)], fg)
		ICON_ABILITY:
			_star(ci, c, s, fg)
		ICON_MARK:
			ci.draw_arc(c, s * 0.6, 0, TAU, 16, fg, maxf(1.5, s * 0.15))
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * s * 0.35, c + d * s, fg, maxf(1.5, s * 0.15))
		ICON_ARMOR:
			_shield(ci, c, s, fg, bg)
			ci.draw_line(c + Vector2(-0.3, 0.1) * s, c + Vector2(0.3, 0.1) * s, bg, maxf(1.5, s * 0.2))
		ICON_HEAL:
			ci.draw_line(c + Vector2(0, -0.75) * s, c + Vector2(0, 0.75) * s, fg, maxf(2.0, s * 0.35))
			ci.draw_line(c + Vector2(-0.75, 0) * s, c + Vector2(0.75, 0) * s, fg, maxf(2.0, s * 0.35))
		ICON_ORDER:
			# Флажок на древке.
			ci.draw_line(c + Vector2(-0.5, 0.85) * s, c + Vector2(-0.5, -0.85) * s, fg, maxf(1.5, s * 0.15))
			_poly(ci, c, s, [Vector2(-0.45, -0.85), Vector2(0.8, -0.5), Vector2(-0.45, -0.1)], fg)
		ICON_SPELL:
			_poly(ci, c, s, [Vector2(0, -0.9), Vector2(0.6, 0), Vector2(0, 0.9), Vector2(-0.6, 0)], fg)
		ICON_INK:
			# Капля.
			var drop := PackedVector2Array([c + Vector2(0, -0.95) * s])
			for i in 13:
				var a := PI * i / 12.0
				drop.append(c + Vector2(cos(a) * 0.55, 0.3 + sin(a) * 0.55) * s)
			ci.draw_colored_polygon(drop, fg)
		ICON_PARCHMENT:
			# Свиток: лист и два валика.
			_poly(ci, c, s, [Vector2(-0.55, -0.6), Vector2(0.55, -0.6), Vector2(0.55, 0.6), Vector2(-0.55, 0.6)], fg)
			ci.draw_line(c + Vector2(-0.75, -0.65) * s, c + Vector2(0.75, -0.65) * s, fg, maxf(2.0, s * 0.25))
			ci.draw_line(c + Vector2(-0.75, 0.65) * s, c + Vector2(0.75, 0.65) * s, fg, maxf(2.0, s * 0.25))
			for y: float in [-0.25, 0.05, 0.35]:
				ci.draw_line(c + Vector2(-0.35, y) * s, c + Vector2(0.35, y) * s, bg if bg.a > 0.5 else Color(0, 0, 0, 0.6), maxf(1.0, s * 0.1))
		ICON_AETHER:
			# Четырёхлучевая искра.
			_poly(ci, c, s, [Vector2(0, -1), Vector2(0.22, -0.22), Vector2(1, 0), Vector2(0.22, 0.22), Vector2(0, 1), Vector2(-0.22, 0.22), Vector2(-1, 0), Vector2(-0.22, -0.22)], fg)
		ICON_HP:
			# Сердце.
			ci.draw_circle(c + Vector2(-0.33, -0.25) * s, s * 0.38, fg)
			ci.draw_circle(c + Vector2(0.33, -0.25) * s, s * 0.38, fg)
			_poly(ci, c, s, [Vector2(-0.7, -0.1), Vector2(0.7, -0.1), Vector2(0, 0.85)], fg)
		ICON_SPEED:
			# Сапог.
			_poly(ci, c, s, [Vector2(-0.35, -0.85), Vector2(0.15, -0.85), Vector2(0.15, 0.2), Vector2(0.85, 0.35), Vector2(0.85, 0.75), Vector2(-0.35, 0.75)], fg)
		ICON_KILL:
			# Череп: голова, челюсть, глазницы.
			ci.draw_circle(c + Vector2(0, -0.15) * s, s * 0.65, fg)
			_poly(ci, c, s, [Vector2(-0.35, 0.3), Vector2(0.35, 0.3), Vector2(0.3, 0.8), Vector2(-0.3, 0.8)], fg)
			var hole := bg if bg.a > 0.5 else Color(0, 0, 0, 0.85)
			ci.draw_circle(c + Vector2(-0.25, -0.2) * s, s * 0.17, hole)
			ci.draw_circle(c + Vector2(0.25, -0.2) * s, s * 0.17, hole)
		ICON_POINTS:
			# Раскрытая книга.
			_poly(ci, c, s, [Vector2(-0.9, -0.5), Vector2(-0.05, -0.3), Vector2(-0.05, 0.7), Vector2(-0.9, 0.5)], fg)
			_poly(ci, c, s, [Vector2(0.9, -0.5), Vector2(0.05, -0.3), Vector2(0.05, 0.7), Vector2(0.9, 0.5)], fg)
		ICON_LOCK:
			ci.draw_arc(c + Vector2(0, -0.2) * s, s * 0.38, PI, TAU, 12, fg, maxf(2.0, s * 0.18))
			_poly(ci, c, s, [Vector2(-0.6, -0.15), Vector2(0.6, -0.15), Vector2(0.6, 0.8), Vector2(-0.6, 0.8)], fg)
		ICON_MASK:
			# Полумаска с прорезями.
			var hole := bg if bg.a > 0.5 else Color(0, 0, 0, 0.85)
			_poly(ci, c, s, [Vector2(-0.95, -0.45), Vector2(0.95, -0.45), Vector2(0.75, 0.3), Vector2(0.2, 0.45), Vector2(0, 0.2), Vector2(-0.2, 0.45), Vector2(-0.75, 0.3)], fg)
			_poly(ci, c, s, [Vector2(-0.65, -0.15), Vector2(-0.2, -0.15), Vector2(-0.28, 0.05), Vector2(-0.58, 0.05)], hole)
			_poly(ci, c, s, [Vector2(0.65, -0.15), Vector2(0.2, -0.15), Vector2(0.28, 0.05), Vector2(0.58, 0.05)], hole)
		ICON_THREAT:
			# Треугольник с восклицательным знаком: «под ударом».
			var mark := bg if bg.a > 0.5 else Color(0, 0, 0, 0.85)
			_poly(ci, c, s, [Vector2(0, -0.95), Vector2(0.95, 0.8), Vector2(-0.95, 0.8)], fg)
			ci.draw_line(c + Vector2(0, -0.4) * s, c + Vector2(0, 0.25) * s, mark, maxf(2.0, s * 0.2))
			ci.draw_circle(c + Vector2(0, 0.52) * s, maxf(1.2, s * 0.11), mark)
		ICON_CHALICE:
			# Чаша реликвария.
			_poly(ci, c, s, [Vector2(-0.75, -0.7), Vector2(0.75, -0.7), Vector2(0.45, 0.05), Vector2(-0.45, 0.05)], fg)
			ci.draw_line(c + Vector2(0, 0.05) * s, c + Vector2(0, 0.6) * s, fg, maxf(2.0, s * 0.2))
			_poly(ci, c, s, [Vector2(-0.5, 0.6), Vector2(0.5, 0.6), Vector2(0.5, 0.85), Vector2(-0.5, 0.85)], fg)
		ICON_WATER:
			# Три волны.
			for y: float in [-0.45, 0.0, 0.45]:
				var pts := PackedVector2Array()
				for k in 9:
					var x := -0.85 + k * 0.2125
					pts.append(c + Vector2(x, y + 0.15 * sin(k * 1.6)) * s)
				ci.draw_polyline(pts, fg, maxf(1.5, s * 0.16))


# --- Примитивы ---------------------------------------------------------------

static func _star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var radius := r * (0.95 if i % 2 == 0 else 0.42)
		pts.append(c + Vector2.from_angle(deg_to_rad(-90 + 36 * i)) * radius)
	ci.draw_colored_polygon(pts, color)


static func _masks(ci: CanvasItem, c: Vector2, r: float, ink: Color, body: Color) -> void:
	for p: Vector2 in [Vector2(-0.45, 0.2), Vector2(0.45, 0.2), Vector2(0, -0.3)]:
		var center := c + p * r
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(center + Vector2(cos(a) * 0.32, sin(a) * 0.42) * r)
		ci.draw_colored_polygon(pts, ink)
		ci.draw_circle(center + Vector2(-0.11, -0.08) * r, r * 0.06, body)
		ci.draw_circle(center + Vector2(0.11, -0.08) * r, r * 0.06, body)


static func _chalice(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	_poly(ci, c, r, [Vector2(-0.6, -0.1), Vector2(0.6, -0.1), Vector2(0.3, 0.3), Vector2(-0.3, 0.3)], ink)
	_poly(ci, c, r, [Vector2(-0.08, 0.3), Vector2(0.08, 0.3), Vector2(0.08, 0.6), Vector2(-0.08, 0.6)], ink)
	_poly(ci, c, r, [Vector2(-0.4, 0.6), Vector2(0.4, 0.6), Vector2(0.4, 0.75), Vector2(-0.4, 0.75)], ink)
	_poly(ci, c, r, [Vector2(-0.3, -0.15), Vector2(-0.1, -0.55), Vector2(0.0, -0.35), Vector2(0.15, -0.8), Vector2(0.3, -0.15)], ink)

static func _poly(ci: CanvasItem, c: Vector2, r: float, pts: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for p: Vector2 in pts:
		packed.append(c + p * r)
	ci.draw_colored_polygon(packed, color)


static func _shield(ci: CanvasItem, c: Vector2, r: float, ink: Color, accent: Color) -> void:
	_poly(ci, c, r, [Vector2(-0.6, -0.65), Vector2(0.6, -0.65), Vector2(0.6, 0.1), Vector2(0, 0.8), Vector2(-0.6, 0.1)], ink)
	ci.draw_line(c + Vector2(0, -0.5) * r, c + Vector2(0, 0.6) * r, accent, maxf(2.0, r * 0.12))
	ci.draw_line(c + Vector2(-0.45, -0.15) * r, c + Vector2(0.45, -0.15) * r, accent, maxf(2.0, r * 0.12))


static func _scroll_and_quill(ci: CanvasItem, c: Vector2, r: float, ink: Color, body: Color) -> void:
	# Свиток
	_poly(ci, c, r, [Vector2(-0.6, 0.0), Vector2(0.45, 0.0), Vector2(0.45, 0.55), Vector2(-0.6, 0.55)], ink)
	ci.draw_circle(c + Vector2(-0.6, 0.27) * r, r * 0.27, ink)
	ci.draw_circle(c + Vector2(0.45, 0.27) * r, r * 0.27, ink)
	for y: float in [0.17, 0.37]:
		ci.draw_line(c + Vector2(-0.45, y) * r, c + Vector2(0.3, y) * r, body, maxf(1.5, r * 0.06))
	# Перо
	_poly(ci, c, r, [Vector2(0.05, -0.05), Vector2(0.35, -0.85), Vector2(0.7, -0.75), Vector2(0.2, -0.1)], ink)


static func _claws(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	for i in 3:
		var dx := (i - 1) * 0.38
		var pts := PackedVector2Array()
		for t in 7:
			var k := t / 6.0
			pts.append(c + Vector2(dx - 0.3 + 0.55 * k + 0.12 * sin(k * PI), -0.7 + 1.4 * k) * r)
		ci.draw_polyline(pts, ink, maxf(3.0, r * 0.2))


static func _bow(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	var center := c + Vector2(-0.35, 0) * r
	ci.draw_arc(center, r * 0.75, deg_to_rad(-70), deg_to_rad(70), 16, ink, maxf(3.0, r * 0.15))
	var top := center + Vector2.from_angle(deg_to_rad(-70)) * r * 0.75
	var bottom := center + Vector2.from_angle(deg_to_rad(70)) * r * 0.75
	ci.draw_line(top, bottom, ink, maxf(1.0, r * 0.05))
	ci.draw_line(c + Vector2(-0.55, 0) * r, c + Vector2(0.55, 0) * r, ink, maxf(2.0, r * 0.08))
	_poly(ci, c, r, [Vector2(0.85, 0), Vector2(0.5, -0.2), Vector2(0.5, 0.2)], ink)


static func _tower(ci: CanvasItem, c: Vector2, r: float, ink: Color, body: Color) -> void:
	_poly(ci, c, r, [
		Vector2(-0.5, 0.7), Vector2(-0.5, -0.45), Vector2(-0.3, -0.45), Vector2(-0.3, -0.7),
		Vector2(-0.1, -0.7), Vector2(-0.1, -0.45), Vector2(0.1, -0.45), Vector2(0.1, -0.7),
		Vector2(0.3, -0.7), Vector2(0.3, -0.45), Vector2(0.5, -0.45), Vector2(0.5, 0.7),
	], ink)
	_poly(ci, c, r, [Vector2(-0.15, 0.7), Vector2(-0.15, 0.3), Vector2(0, 0.15), Vector2(0.15, 0.3), Vector2(0.15, 0.7)], body)
	ci.draw_line(c + Vector2(-0.25, -0.15) * r, c + Vector2(0.25, -0.15) * r, body, maxf(2.0, r * 0.1))


static func _sword(ci: CanvasItem, c: Vector2, r: float, color: Color, angle_deg: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var perp := dir.orthogonal()
	ci.draw_line(c - dir * r * 0.9, c + dir * r * 0.9, color, maxf(2.0, r * 0.18))
	ci.draw_line(c - dir * r * 0.45 - perp * r * 0.35, c - dir * r * 0.45 + perp * r * 0.35, color, maxf(2.0, r * 0.16))


static func _arrow(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var dir := Vector2(1, -1).normalized()
	ci.draw_line(c - dir * r * 0.85, c + dir * r * 0.4, color, maxf(2.0, r * 0.16))
	var tip := c + dir * r * 0.9
	var perp := dir.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * r * 0.55 + perp * r * 0.35, tip - dir * r * 0.55 - perp * r * 0.35]), color)
	var tail := c - dir * r * 0.85
	ci.draw_line(tail, tail + (perp - dir) * r * 0.3, color, maxf(1.5, r * 0.12))
	ci.draw_line(tail, tail + (-perp - dir) * r * 0.3, color, maxf(1.5, r * 0.12))
