class_name UiKit
extends RefCounted
## Общие элементы интерфейса-плейсхолдера.

const BG_COLOR := Color(0.07, 0.08, 0.11)
const PANEL_COLOR := Color(0.12, 0.13, 0.18)
const ACCENT := Color(0.95, 0.8, 0.4)
const ACTIVE_BORDER := Color(1.0, 0.85, 0.3)
const PLAYER_COLOR := Color(0.35, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.4, 0.35)
const MUTED := Color(0.65, 0.67, 0.72)
const DANGER := Color(1.0, 0.45, 0.4)


const BACKDROP_SHADER := preload("res://shaders/backdrop.gdshader")
## Размер запекания фона — базовое разрешение проекта.
const BAKE_SIZE := Vector2(1920, 1080)


## Фон экрана (SPEC_SPRINT6 4): шейдер с шумом и виньеткой, медленный пепел в воздухе.
## Цвет фона задаётся bg.color, как раньше.
## Фон (SPEC_SPRINT6 4). plain — сплошной цвет (бой: пол рисует само поле, а полноэкранная
## текстура при программной отрисовке стоит около 8 мс на кадр). Иначе шейдер рисуется один раз
## во вспомогательном SubViewport, копируется в текстуру и кэшируется по цвету.
## Возвращает прямоугольник фона: его color можно задать сразу после создания.
static var _baked: Dictionary = {}


## Яркость рисованных фонов: под картой и интерфейсом фон приглушён, чтобы читался текст.
## Экраны с панелями (этап B) — темнее карты: текст лежит прямо на фоне.
const ART_BG_BRIGHTNESS := {&"menu": 0.9, &"map_act1": 0.62, &"map_act2": 0.62, &"camp": 0.55, &"event": 0.5, &"haven": 0.55,
		&"hall": 0.45, &"reliquary": 0.5, &"run_end": 0.4, &"school": 0.5, &"shop": 0.5}


## Рисованный фон на весь экран с затемнением (SPEC_SPRINT9 4).
static func art_background(tex: Texture2D, brightness: float = 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate = Color(brightness, brightness, brightness)
	return r


## Фон экрана: рисованный art_id, если есть, иначе процедурный.
static func add_background(parent: Control, plain: bool = false, art_id: StringName = &"") -> Control:
	var art := ArtDB.background(art_id) if not plain else null
	if art:
		var r := art_background(art, ART_BG_BRIGHTNESS.get(art_id, 0.85))
		parent.add_child(r)
		if Settings.effects_full:
			r.add_child(ambient_ash(r))
		return r
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	if plain:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
		return bg
	var tex := TextureRect.new()
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(tex)
	bg.size = BAKE_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter("size", BAKE_SIZE)
	bg.material = mat
	_bake.call_deferred(tex, bg)
	if Settings.effects_full:
		tex.add_child(ambient_ash(tex))
	return bg


static func _bake(tex: TextureRect, bg: ColorRect) -> void:
	var key := bg.color.to_html()
	if _baked.has(key):
		tex.texture = _baked[key]
		bg.free()
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(BAKE_SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(bg)
	tex.add_child(vp)
	tex.texture = vp.get_texture()
	await RenderingServer.frame_post_draw
	if not is_instance_valid(tex):
		return
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		_baked[key] = ImageTexture.create_from_image(img)
		tex.texture = _baked[key]
		vp.queue_free()


## Редкий медленный пепел над фоном; область подгоняется под размер родителя.
static func ambient_ash(host: Control) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = FxPool.dot_texture()
	p.amount = 26
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.3, -1.0)
	p.spread = 25.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector2(3, -2)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.68, 0.6, 0.0))
	ramp.add_point(0.2, Color(0.75, 0.68, 0.6, 0.35))
	ramp.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	p.color_ramp = ramp
	var fit := func() -> void:
		p.position = host.size * 0.5
		p.emission_rect_extents = host.size * 0.5
	host.resized.connect(fit)
	fit.call()
	return p


const ROLE_COLORS := {
	CardAdvisor.Role.MELEE: Color(0.85, 0.55, 0.4),
	CardAdvisor.Role.RANGED: Color(0.55, 0.75, 0.95),
	CardAdvisor.Role.SUPPORT: Color(0.5, 0.85, 0.55),
	CardAdvisor.Role.FLYER: Color(0.8, 0.7, 1.0),
	CardAdvisor.Role.HERO: Color(0.72, 0.5, 0.95),
}


static func role_color(db: DefsDB, memory_id: StringName) -> Color:
	return ROLE_COLORS[CardAdvisor.role(db, memory_id)]


## Круглый медальон карты: объёмный круг, рамка роли, силуэт; без существа — ромб-герб.
## С какого кегля подпись — заголовок (шрифт заголовков, SPEC_SPRINT9 4).
const HEADING_SIZE := 26


class Medallion:
	extends Control
	var def_id: StringName
	## Карта Кодекса — для рисованной иллюстрации.
	var memory_id: StringName
	var body_color := Color.GRAY
	var frame_color := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 28:
			var dir := Vector2.from_angle(TAU * i / 28.0)
			pts.append(c + dir * r)
			cols.append(body_color.lightened(0.2) if dir.y < 0.0 else body_color.darkened(0.25 * dir.y))
		draw_polygon(pts, cols)
		var art := ArtDB.card(memory_id)
		var region := Rect2()
		if art:
			# Иллюстрация карты (SPEC_SPRINT9 4): центральный квадрат в круге.
			var s := art.get_size()
			region = Rect2((s.x - s.y) * 0.5, 0, s.y, s.y)
		elif def_id != &"" and ArtDB.unit(def_id):
			art = ArtDB.unit(def_id)
			region = ArtDB.portrait_region(def_id)
		if art:
			var uvs := PackedVector2Array()
			var circle := PackedVector2Array()
			var ts := art.get_size()
			for i in 40:
				var dir := Vector2.from_angle(TAU * i / 40.0)
				circle.append(c + dir * (r - 2))
				uvs.append((region.position + region.size * (dir * 0.5 + Vector2(0.5, 0.5))) / ts)
			draw_polygon(circle, PackedColorArray([Color.WHITE]), uvs, art)
		elif def_id != &"":
			var tex := IconAtlas.get_glyph(def_id, body_color)
			if tex:
				draw_texture_rect(tex, IconAtlas.glyph_rect(c, r * 0.8), false)
			else:
				UnitGlyphs.draw_unit(self, def_id, c, r * 0.8, body_color)
				UnitGlyphs.draw_details(self, def_id, c, r * 0.8, body_color)
		else:
			UnitGlyphs.draw_icon(self, UnitGlyphs.ICON_SPELL, c, r * 0.6, Color(0, 0, 0, 0), UnitGlyphs.INK, false)
		draw_arc(c, r, 0, TAU, 40, frame_color, 3.0)
		draw_arc(c, r - 5, 0, TAU, 40, Color(frame_color, 0.35), 1.0)


static func label(text: String, size: int = 0, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if size >= HEADING_SIZE and UiTheme.heading_font:
		l.add_theme_font_override("font", UiTheme.heading_font)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_pressed: Callable, min_width: int = 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.pressed.connect(Audio.play.bind(&"ui_click"))
	b.pressed.connect(on_pressed)
	add_hover_lift(b)
	return b


## Лёгкое увеличение при наведении (SPEC_SPRINT6 5); масштаб от центра.
static func add_hover_lift(c: Control, amount: float = 0.02) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(_lift.bind(c, 1.0 + amount))
	c.mouse_exited.connect(_lift.bind(c, 1.0))


static func _lift(c: Control, k: float) -> void:
	if k > 1.0 and c is BaseButton and (c as BaseButton).disabled:
		return
	c.create_tween().tween_property(c, "scale", Vector2.ONE * k, 0.08)


## Панель. ornate — процедурная рамка с орнаментом (карты, плашки); иначе плоская:
## крупные панели с текстурной рамкой заметно дороже при программной отрисовке.
static func panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, ornate: bool = false) -> StyleBox:
	if ornate and border.a > 0.0 and border_width > 0:
		return UiTheme.ornate(bg, border, border_width)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


static func centered_column(parent: Control, separation: int = 16) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


## «Чернила 2 · Пергамент 3 · Эфир 1»; signed — с плюсом («+2»), нули пропускаются.
static func resources_text(res: Dictionary, signed: bool = false) -> String:
	var parts: Array[String] = []
	for id in RunState.RESOURCE_IDS:
		var v: int = res.get(id, 0)
		if signed and v == 0:
			continue
		var num := ("%+d" % v) if signed else str(v)
		parts.append("%s %s" % [TranslationServer.translate("RES_" + String(id).to_upper()), num])
	return " · ".join(parts)


static func unit_name(db: DefsDB, def_id: StringName) -> String:
	return TranslationServer.translate(db.unit(def_id).name_key)


## Короткая подпись стека: первые буквы слов названия («Пепельный Гуль» -> «ПГ»).
static func unit_abbr(db: DefsDB, def_id: StringName) -> String:
	var words := unit_name(db, def_id).replace("-", " ").split(" ", false)
	var abbr := ""
	for i in mini(2, words.size()):
		abbr += words[i].left(1).to_upper()
	return abbr


static func unit_stats(def: UnitDef) -> String:
	var text := TranslationServer.translate("CARD_STATS") % [def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative]
	var tags: Array[String] = []
	if def.is_ranged:
		tags.append(TranslationServer.translate("TAG_RANGED") % def.shots)
	if def.is_flying:
		tags.append(TranslationServer.translate("TAG_FLYING"))
	if not tags.is_empty():
		text += "\n" + ", ".join(tags)
	return text


const HERO_CARD_COLOR := Color(0.95, 0.75, 0.3)


## Карта-воспоминание в виде кнопки. durability < 0 — показывать максимальную.
## Карта Кодекса — вертикальная карта в рамке (SPEC_SPRINT9 18.2, MemoryCard).
static func card_button(db: DefsDB, memory_id: StringName, durability: int = -1, level: int = 1) -> Button:
	return MemoryCard.build(db, memory_id, durability, level)


## Подсказка карты: способность существа или описание геройской карты.
static func _card_tooltip(db: DefsDB, mem: MemoryCardDef) -> String:
	if not mem.is_unit():
		return TranslationServer.translate(mem.desc_key)
	var def := db.unit(mem.unit_id)
	if def.ability_id == &"":
		return ""
	var ab := db.ability(def.ability_id)
	return "%s: %s" % [TranslationServer.translate(ab.name_key), TranslationServer.translate(ab.desc_key)]


## Сводка Архивариуса: приказы, улучшения, заклинания с зарядами.
static func hero_summary(db: DefsDB, run: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(PANEL_COLOR))
	var col := VBoxContainer.new()
	panel.add_child(col)
	var school := db.school(run.school_id)
	var head := label("%s · %s" % [TranslationServer.translate("PREP_HERO"), TranslationServer.translate(school.name_key)], 22, ACCENT)
	var archivist := ArtDB.portrait(&"archivist")
	if archivist:
		# Портрет Архивариуса рядом с заголовком (SPEC_SPRINT9 4).
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(portrait_disc(archivist, 56, ACCENT))
		head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(head)
		col.add_child(row)
	else:
		col.add_child(head)
	if not Settings.detailed:
		col.add_child(_hero_chips(db, run, school))
		return panel

	var orders: Array[String] = []
	for id in run.hero.available_orders(db, run.codex):
		orders.append(TranslationServer.translate(db.order(id).name_key))
	col.add_child(label(TranslationServer.translate("PREP_ORDERS") % ", ".join(orders), 18))

	var counts := {}
	for id in run.hero.active_upgrades(db, run.codex):
		counts[id] = counts.get(id, 0) + 1
	var ups: Array[String] = []
	for id: StringName in counts:
		var text := TranslationServer.translate(db.upgrade(id).name_key)
		ups.append(text if counts[id] == 1 else "%s ×%d" % [text, counts[id]])
	col.add_child(label(TranslationServer.translate("PREP_UPGRADES") % (", ".join(ups) if not ups.is_empty() else TranslationServer.translate("PREP_NONE")), 18, MUTED))

	var spells: Array[String] = []
	for slot in run.hero.spells:
		spells.append("%s ×%d" % [TranslationServer.translate(db.spell(slot.spell_id).name_key), slot.charges])
	col.add_child(label(TranslationServer.translate("PREP_SPELLS") % (", ".join(spells) if not spells.is_empty() else TranslationServer.translate("PREP_NONE")), 18, Color(0.75, 0.6, 1.0)))
	return panel


## Сводка героя чипами: пассивка школы, приказы, улучшения, заклинания; описания — по наведению.
static func _hero_chips(db: DefsDB, run: RunState, school: SchoolDef) -> HFlowContainer:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var f := flow(14)
	f.add_child(chip(UnitGlyphs.ICON_POINTS, t.call("PASSIVE_" + String(school.passive_id).to_upper()), school.color.lightened(0.2),
			t.call(school.name_key), t.call(school.desc_key)))
	for id in run.hero.available_orders(db, run.codex):
		var o := db.order(id)
		f.add_child(chip(UnitGlyphs.ICON_ORDER, t.call(o.name_key), STAT_COLOR, t.call(o.name_key), t.call(o.desc_key)))
	var counts := {}
	for id in run.hero.active_upgrades(db, run.codex):
		counts[id] = counts.get(id, 0) + 1
	for id: StringName in counts:
		var text: String = t.call(db.upgrade(id).name_key)
		f.add_child(chip(UnitGlyphs.ICON_ABILITY, text if counts[id] == 1 else "%s ×%d" % [text, counts[id]], ACCENT, text, ""))
	for slot in run.hero.spells:
		var sp := db.spell(slot.spell_id)
		f.add_child(chip(UnitGlyphs.ICON_SPELL, "%s ×%d" % [t.call(sp.name_key), slot.charges], Color(0.75, 0.6, 1.0), t.call(sp.name_key), t.call(sp.desc_key)))
	# Дары привала и реликвии (SPEC_SPRINT7) — значками, описание в подсказке.
	for g in run.gifts:
		var key := "CAMP_" + String(g).to_upper()
		f.add_child(chip(UnitGlyphs.ICON_POINTS, "", Color(0.55, 0.85, 1.0), t.call(key), t.call(key + "_TIP")))
	for id in run.relics:
		var r := db.relic(id)
		f.add_child(chip(r.icon, "", r.color, t.call(r.name_key), t.call(r.desc_key)))
	return f


# --- Значки и чипы (SPEC_SPRINT4 2) ------------------------------------------------

const RESOURCE_ICONS := {
	RunState.INK: UnitGlyphs.ICON_INK,
	RunState.PARCHMENT: UnitGlyphs.ICON_PARCHMENT,
	RunState.AETHER: UnitGlyphs.ICON_AETHER,
}
const RESOURCE_COLORS := {
	RunState.INK: Color(0.55, 0.7, 1.0),
	RunState.PARCHMENT: Color(0.95, 0.85, 0.6),
	RunState.AETHER: Color(0.8, 0.6, 1.0),
}
const STAT_COLOR := Color(0.85, 0.87, 0.92)


## Картинка из ArtDB в рамке size: covered — заполнить с обрезкой, иначе вписать. Клики проходят насквозь.
static func art_rect(tex: Texture2D, size: Vector2, covered: bool = false, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if covered else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.clip_contents = covered
	return r


static func icon_rect(icon: StringName, size: float, color: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = IconAtlas.get_icon(icon)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## «Значок + текст»; подробности — в подсказке по наведению.
static func chip(icon: StringName, text: String, color: Color = STAT_COLOR, tip_title: String = "", tip_body: String = "", size: int = 18) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(icon_rect(icon, size + 2, color))
	if text != "":
		var l := label(text, size, color)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(l)
	if tip_title != "" or tip_body != "":
		Tip.attach(box, tip_title, tip_body, icon, color)
	return box


## Почему стоит взять карту: роль, закрытая дыра Кодекса, слияние; сравнение с похожей картой — в подсказке роли.
static func advice_row(db: DefsDB, codex: CodexState, memory_id: StringName) -> HFlowContainer:
	var row := flow(12)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var reasons := CardAdvisor.reasons(db, codex, memory_id)
	for i in reasons.size():
		var r: Array = reasons[i]
		var tip: String = t.call(r[2])
		if i == 0:
			tip += _compare_tip(db, codex, memory_id)
		row.add_child(chip(r[0], r[1], ACCENT if i > 0 else STAT_COLOR, r[1], tip, 17))
	return row


const OBJECTIVE_ICONS := {
	&"eliminate": UnitGlyphs.ICON_KILL,
	&"survive": UnitGlyphs.ICON_WAIT,
	&"assassinate": UnitGlyphs.ICON_MARK,
	&"hold": UnitGlyphs.ICON_ORDER,
	&"protect": UnitGlyphs.ICON_PARCHMENT,
}
const OBJECTIVE_COLOR := Color(0.55, 0.85, 1.0)
const DIFFICULTY_COLORS := {&"easy": Color(0.45, 0.85, 0.5), &"normal": Color(0.95, 0.8, 0.35), &"hard": Color(1.0, 0.45, 0.4)}


## Цель боя чипом: значок, название (и прогресс, если задан); правило — в подсказке.
static func objective_chip(objective: StringName, rounds: int, progress: String = "", size: int = 18) -> HBoxContainer:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var key := "OBJ_" + String(objective).to_upper()
	var name: String = t.call(key)
	var body: String = t.call(key + "_DESC")
	if body.contains("%d"):
		body = body % rounds
	if objective != &"eliminate":
		body += "\n" + t.call("OBJ_BONUS_TIP")
	var text := name if progress == "" else "%s  %s" % [name, progress]
	return chip(OBJECTIVE_ICONS.get(objective, UnitGlyphs.ICON_KILL), text, OBJECTIVE_COLOR, name, body, size)


## Командир чипом: имя цветом командира, описание — в подсказке; с рисованным портретом, если он есть.
static func commander_chip(db: DefsDB, id: StringName, size: int = 18) -> HBoxContainer:
	var def := db.commander(id)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var c := chip(UnitGlyphs.ICON_ORDER, t.call(def.name_key), def.color, t.call("COMMANDER_TITLE") + ": " + t.call(def.name_key), t.call(def.desc_key), size)
	var art := ArtDB.portrait(id)
	if art:
		var glyph := c.get_child(0)
		c.remove_child(glyph)
		glyph.queue_free()
		c.add_child(portrait_disc(art, size * 2.2, def.color))
		c.move_child(c.get_child(c.get_child_count() - 1), 0)
	return c


## Круглый рисованный портрет в рамке цвета color (SPEC_SPRINT9 4).
static func portrait_disc(tex: Texture2D, diameter: float, color: Color = ACCENT) -> Control:
	var d := PortraitDisc.new()
	d.texture = tex
	d.ring = color
	d.custom_minimum_size = Vector2(diameter, diameter)
	d.mouse_filter = Control.MOUSE_FILTER_PASS
	return d


class PortraitDisc:
	extends Control
	var texture: Texture2D
	var ring := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var dir := Vector2.from_angle(TAU * i / 40.0)
			pts.append(c + dir * r)
			uvs.append(dir * 0.5 + Vector2(0.5, 0.5))
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, texture)
		draw_arc(c, r, 0, TAU, 40, ring, 2.5)


static func difficulty_chip(difficulty: StringName, size: int = 18) -> HBoxContainer:
	var key := "DIFFICULTY_" + String(difficulty).to_upper()
	return chip(UnitGlyphs.ICON_KILL, TranslationServer.translate(key), DIFFICULTY_COLORS.get(difficulty, STAT_COLOR),
			TranslationServer.translate(key), TranslationServer.translate(key + "_DESC"), size)


## Ступень Испытания «И4»; действующие правила — в подсказке.
static func trial_chip(trial: int, size: int = 18) -> HBoxContainer:
	var t := TranslationServer.translate
	return chip(UnitGlyphs.ICON_KILL, t.call("TRIAL_SHORT") % trial, DIFFICULTY_COLORS[Difficulty.HARD],
			t.call("TRIAL_LEVEL") % trial, Trials.describe(trial), size)


## Модификатор ежедневного забега (SPEC_SPRINT9 7): плюсы — зелёные, минусы — красные; описание — в подсказке.
static func modifier_chip(id: StringName, size: int = 18, with_text: bool = true) -> HBoxContainer:
	var key := "DAILY_MOD_" + String(id).to_upper()
	var color := DailyRun.PLUS_COLOR if DailyRun.PLUS.has(id) else DailyRun.MINUS_COLOR
	var name := TranslationServer.translate(key)
	return chip(DailyRun.ICONS.get(id, UnitGlyphs.ICON_POINTS), name if with_text else "", color, name,
			TranslationServer.translate(key + "_DESC"), size)


## Риск боя: сила врагов относительно лучших карт армии (три уровня, подробности в подсказке).
static func risk_chip(db: DefsDB, codex: CodexState, enc: EncounterDef, difficulty: StringName = Difficulty.NORMAL, size: int = 18) -> HBoxContainer:
	var risk := CardAdvisor.risk(db, codex, enc, difficulty)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var name: String = t.call(CardAdvisor.RISK_KEYS[risk])
	var body: String = t.call("RISK_TIP") % [roundi(CardAdvisor.encounter_power(db, enc, difficulty)), roundi(CardAdvisor.army_power(db, codex))]
	return chip(UnitGlyphs.ICON_KILL, name, CardAdvisor.RISK_COLORS[risk], t.call("RISK_TITLE") + ": " + name, body, size)


static func _compare_tip(db: DefsDB, codex: CodexState, memory_id: StringName) -> String:
	var similar := CardAdvisor.similar_card(db, codex, memory_id)
	if similar < 0:
		return ""
	var card := codex.cards[similar]
	var mine := CardAdvisor.card_power(db, card.memory_id, card.level)
	if mine <= 0.0:
		return ""
	var ratio := CardAdvisor.card_power(db, memory_id) / mine - 1.0
	return "\n" + TranslationServer.translate("ADVICE_COMPARE") % [TranslationServer.translate(db.memory(card.memory_id).name_key), "%+d%%" % roundi(ratio * 100.0)]


static func flow(separation: int = 10) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", separation)
	f.add_theme_constant_override("v_separation", 4)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	return f


## Строка характеристик значками: ОЗ, атака, защита, урон, скорость, инициатива.
## color и hp_color — для светлого фона (вертикальная карта на пергаменте, SPEC_SPRINT9 18.2).
static func stat_row(hp: int, attack: int, defense: int, dmg_min: int, dmg_max: int, speed: int, initiative: int, size: int = 17,
		color: Color = STAT_COLOR, hp_color: Color = Color(1, 0.55, 0.55)) -> HFlowContainer:
	var row := flow(10)
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	row.add_child(chip(UnitGlyphs.ICON_HP, str(hp), hp_color, t.call("STAT_HP"), t.call("STAT_HP_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_MELEE, str(attack), color, t.call("STAT_ATTACK"), t.call("STAT_ATTACK_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_DEFEND, str(defense), color, t.call("STAT_DEFENSE"), t.call("STAT_DEFENSE_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_RETALIATION, "%d–%d" % [dmg_min, dmg_max], color, t.call("STAT_DAMAGE"), t.call("STAT_DAMAGE_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_SPEED, str(speed), color, t.call("STAT_SPEED"), t.call("STAT_SPEED_TIP"), size))
	row.add_child(chip(UnitGlyphs.ICON_WAIT, str(initiative), color, t.call("STAT_INITIATIVE"), t.call("STAT_INITIATIVE_TIP"), size))
	return row


static func unit_stat_row(u: UnitState, size: int = 17) -> HFlowContainer:
	return stat_row(u.hp, u.attack, u.defense, u.dmg_min, u.dmg_max, u.speed, u.initiative, size)


static func def_stat_row(def: UnitDef, size: int = 16) -> HFlowContainer:
	return stat_row(def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative, size)


## Прочность точками ●●○ (заполненные — текущая).
static func pips(current: int, maximum: int, size: float = 12.0) -> Control:
	var p := Pips.new()
	p.current = current
	p.maximum = maximum
	p.radius = size * 0.42
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(maximum * (size + 4), size + 2)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	Tip.attach(p, TranslationServer.translate("CARD_DURABILITY") % [current, maximum], TranslationServer.translate("DURABILITY_TIP"))
	return p


class Pips:
	extends Control
	var current := 0
	var maximum := 0
	var radius := 5.0

	func _draw() -> void:
		var r := radius
		for i in maximum:
			var c := Vector2(r + 2 + i * (r * 2 + 4), size.y * 0.5)
			var col := (UiKit.DANGER if current <= 1 else UiKit.ACCENT) if i < current else Color(0.35, 0.37, 0.42)
			draw_circle(c, r, col)


## Ресурсы значками; signed — со знаком, нули пропускаются.
static func resource_row(res: Dictionary, signed: bool = false, size: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for id in RunState.RESOURCE_IDS:
		var v: int = res.get(id, 0)
		if signed and v == 0:
			continue
		var name := TranslationServer.translate("RES_" + String(id).to_upper())
		row.add_child(chip(RESOURCE_ICONS[id], ("%+d" % v) if signed else str(v), RESOURCE_COLORS[id], name, TranslationServer.translate("RES_" + String(id).to_upper() + "_TIP"), size))
	return row


## Кнопка со значком; описание — в подсказке.
static func icon_button(icon: StringName, text: String, on_pressed: Callable, tip_title: String = "", tip_body: String = "", min_width: int = 0) -> Button:
	var b := button(text, on_pressed, min_width)
	b.icon = IconAtlas.get_icon(icon)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 22)
	if tip_title != "" or tip_body != "":
		Tip.attach(b, tip_title, tip_body, icon)
	return b
