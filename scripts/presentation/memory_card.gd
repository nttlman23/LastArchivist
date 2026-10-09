class_name MemoryCard
extends Button
## Вертикальная карта Кодекса (SPEC_SPRINT9 18.2): рамка card_frame 2:3, иллюстрация в окне рамки,
## прочность — цифрой в гнезде слева сверху, ниже окна — название, численность, значки и характеристики.
## Без рисованной рамки — пергаментная панель той же раскладки. Создаётся через UiKit.card_button.

const WIDTH := 220.0
const HEIGHT := 322.0
## Подробный режим (Settings.detailed): характеристики строками — карта выше.
const DETAILED_EXTRA := 78.0
## Окно рамки, если в манифесте его нет (доли размера рамки).
const DEFAULT_WINDOW := Rect2(0.105, 0.103, 0.788, 0.411)
## Центр гнезда прочности (доли ширины и высоты рамки) и его радиус (доля ширины).
const SOCKET := Vector2(0.132, 0.07)
const SOCKET_R := 0.075
## Поля 9-slice уменьшенной рамки: верх — до низа окна, чтобы окно не растягивалось в подробном режиме.
const PATCH_SIDE := 20
const PATCH_BOTTOM := 22
## Цвета на пергаменте: тёмные чернила вместо светлых цветов интерфейса.
const INK := Color(0.2, 0.14, 0.09)
const INK_MUTED := Color(0.4, 0.31, 0.22)
const INK_ACCENT := Color(0.55, 0.2, 0.1)
const INK_DANGER := Color(0.72, 0.12, 0.08)
const INK_HP := Color(0.6, 0.14, 0.12)
const PARCHMENT := Color(0.86, 0.78, 0.62)
const SOCKET_TEXT := Color(0.97, 0.88, 0.62)
const DIM := Color(0.5, 0.5, 0.55)

## Рамка, уменьшенная до ширины карты (9-slice рисует поля 1:1), — одна на все карты.
static var _frame: Texture2D
static var _frame_checked := false
## Тема текста на пергаменте: без тёмной обводки подписей (она нужна только над рисованными фонами).
static var _ink_theme: Theme

var memory_id: StringName
var durability := -1


static func build(db: DefsDB, p_memory_id: StringName, p_durability: int = -1, level: int = 1) -> MemoryCard:
	var card := MemoryCard.new()
	card._setup(db, p_memory_id, p_durability, level)
	return card


func _setup(db: DefsDB, p_memory_id: StringName, p_durability: int, level: int) -> void:
	memory_id = p_memory_id
	durability = p_durability
	var mem := db.memory(memory_id)
	var dur := mem.max_durability if durability < 0 else durability
	var worn := durability >= 0 and dur <= 1
	var detailed := Settings.detailed
	var h := HEIGHT + (DETAILED_EXTRA if detailed else 0.0)
	custom_minimum_size = Vector2(WIDTH, h)
	# Карта не растягивается контейнером: рамка 2:3 и окно иллюстрации рассчитаны на свой размер.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_NONE
	_styles(worn)
	var frame := frame_texture()
	var win := _window_rect()
	if frame:
		add_child(_illustration(db, mem, win))
		var np := NinePatchRect.new()
		np.texture = frame
		np.patch_margin_left = PATCH_SIDE
		np.patch_margin_right = PATCH_SIDE
		np.patch_margin_top = ceili(win.end.y) + 6
		np.patch_margin_bottom = PATCH_BOTTOM
		np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(np)
	else:
		var panel := Panel.new()
		panel.add_theme_stylebox_override("panel", _fallback_style(UiKit.role_color(db, memory_id)))
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		add_child(_illustration(db, mem, win))
		var socket := Socket.new()
		socket.position = Vector2(WIDTH, HEIGHT) * SOCKET - Vector2.ONE * WIDTH * SOCKET_R
		socket.size = Vector2.ONE * WIDTH * SOCKET_R * 2.0
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(socket)
	add_child(_durability_label(dur, mem.max_durability, worn))
	add_child(_body(db, mem, dur, level, win, h, detailed))
	Tip.attach(self, TranslationServer.translate(mem.name_key), UiKit._card_tooltip(db, mem),
			UnitGlyphs.ICON_ABILITY if mem.is_unit() else UnitGlyphs.ICON_ORDER)
	pressed.connect(Audio.play.bind(&"card"))
	UiKit.add_hover_lift(self)


## Состояния обводкой вокруг карты: выбрана — золото, наведение — светлая, угасает — красная.
func _styles(worn: bool) -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", _outline(INK_DANGER, 3) if worn else empty)
	add_theme_stylebox_override("hover", _outline(Color(1, 1, 1, 0.55), 2))
	add_theme_stylebox_override("pressed", _outline(UiKit.ACTIVE_BORDER, 4))
	add_theme_stylebox_override("hover_pressed", _outline(UiKit.ACTIVE_BORDER, 4))
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


static func _outline(color: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.set_expand_margin_all(width + 1)
	return sb


static func _fallback_style(role: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = role.darkened(0.45)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(10)
	return sb


## Недоступная карта темнее (disabled меняют уже после создания — сверяем каждый кадр).
func _process(_delta: float) -> void:
	var m := DIM if disabled else Color.WHITE
	if modulate != m:
		modulate = m


## Окно иллюстрации в пикселях карты (верх рамки не растягивается — одинаково в обоих режимах).
func _window_rect() -> Rect2:
	var w := ArtDB.ui_window(&"card_frame")
	if w.size.x <= 0.0:
		w = DEFAULT_WINDOW
	return Rect2(w.position * Vector2(WIDTH, HEIGHT), w.size * Vector2(WIDTH, HEIGHT))


## Иллюстрация в окне: картинка карты, иначе фигура существа, иначе силуэт-глиф на цвете роли.
func _illustration(db: DefsDB, mem: MemoryCardDef, win: Rect2) -> Control:
	var holder := Control.new()
	holder.position = win.position
	holder.size = win.size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := ArtDB.card(memory_id)
	if art:
		var r := UiKit.art_rect(art, win.size, true)
		r.size = win.size
		holder.add_child(r)
		return holder
	var bg := ColorRect.new()
	bg.color = UiKit.role_color(db, memory_id).darkened(0.55)
	bg.size = win.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var figure := ArtDB.unit(mem.unit_id) if mem.is_unit() else null
	if figure:
		var r := UiKit.art_rect(figure, win.size - Vector2(8, 8))
		r.position = Vector2(4, 4)
		r.size = win.size - Vector2(8, 8)
		holder.add_child(r)
	else:
		var medal := UiKit.Medallion.new()
		medal.def_id = mem.unit_id if mem.is_unit() else &""
		medal.memory_id = memory_id
		medal.body_color = db.unit(mem.unit_id).color if mem.is_unit() else UiKit.HERO_CARD_COLOR
		medal.frame_color = UiKit.role_color(db, memory_id)
		var side := minf(win.size.x, win.size.y) - 12.0
		medal.position = (win.size - Vector2(side, side)) * 0.5
		medal.size = Vector2(side, side)
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(medal)
	return holder


## Прочность цифрой в гнезде; подсказка — текущая и наибольшая.
func _durability_label(dur: int, maximum: int, worn: bool) -> Label:
	var l := UiKit.label(str(dur), 22, INK_DANGER.lightened(0.25) if worn else SOCKET_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	var r := WIDTH * SOCKET_R
	l.position = Vector2(WIDTH, HEIGHT) * SOCKET - Vector2(r, r)
	l.size = Vector2(r, r) * 2.0
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	Tip.attach(l, TranslationServer.translate("CARD_DURABILITY") % [dur, maximum], TranslationServer.translate("DURABILITY_TIP"))
	return l


## Под окном: название, численность и значки, характеристики (или описание геройской карты).
func _body(db: DefsDB, mem: MemoryCardDef, dur: int, level: int, win: Rect2, h: float, detailed: bool) -> VBoxContainer:
	var t := func(key: String) -> String: return TranslationServer.translate(key)
	var col := VBoxContainer.new()
	col.position = Vector2(16, win.end.y + 8)
	col.size = Vector2(WIDTH - 32, h - win.end.y - 8 - 18)
	col.add_theme_constant_override("separation", 3)
	col.theme = ink_theme()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: String = t.call(mem.name_key)
	if level > 1:
		title += " · " + t.call("CARD_LEVEL") % level
	var title_l := UiKit.label(title, 17, INK)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.max_lines_visible = 2
	var bold := UiTheme.bold_font()
	if bold:
		title_l.add_theme_font_override("font", bold)
	title_l.add_theme_constant_override("line_spacing", -2)
	col.add_child(title_l)
	var line := UiKit.flow(8)
	line.alignment = FlowContainer.ALIGNMENT_CENTER
	col.add_child(line)
	if mem.is_unit():
		var def := db.unit(mem.unit_id)
		var count := floori(mem.count * (1.0 + 0.5 * (level - 1)))
		line.add_child(UiKit.label("×%d" % count, 16, INK))
		if def.ability_id != &"":
			var ab := db.ability(def.ability_id)
			line.add_child(UiKit.chip(UnitGlyphs.ICON_ABILITY, "", INK_ACCENT, t.call(ab.name_key), t.call(ab.desc_key), 15))
		if def.is_ranged:
			line.add_child(UiKit.chip(UnitGlyphs.ICON_RANGED, str(def.shots), INK, t.call("CHIP_RANGED"), t.call("ABILITY_RANGED") % def.shots, 15))
		if def.is_flying:
			line.add_child(UiKit.chip(UnitGlyphs.ICON_FLYING, "", INK, t.call("CHIP_FLYING"), t.call("ABILITY_FLYING"), 15))
		if durability >= 0 and dur <= 1:
			line.add_child(UiKit.chip(UnitGlyphs.ICON_KILL, "", INK_DANGER, t.call("CARD_WORN"), t.call("CARD_WORN_TIP"), 15))
		if detailed:
			var stats := UiKit.label(UiKit.unit_stats(def), 13, INK_MUTED)
			stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(stats)
			if def.ability_id != &"":
				var ab_l := UiKit.label(t.call("CARD_ABILITY") % t.call(db.ability(def.ability_id).name_key), 13, INK_ACCENT)
				ab_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col.add_child(ab_l)
		else:
			var stats := UiKit.stat_row(def.hp, def.attack, def.defense, def.dmg_min, def.dmg_max, def.speed, def.initiative, 13, INK, INK_HP)
			stats.alignment = FlowContainer.ALIGNMENT_CENTER
			col.add_child(stats)
	else:
		line.add_child(UiKit.chip(UnitGlyphs.ICON_ORDER, t.call("CARD_HERO"), INK_ACCENT, "", "", 15))
		if durability >= 0 and dur <= 1:
			line.add_child(UiKit.chip(UnitGlyphs.ICON_KILL, "", INK_DANGER, t.call("CARD_WORN"), t.call("CARD_WORN_TIP"), 15))
		var desc := UiKit.label(t.call("MEM_LAST_KING_SHORT") if mem.id == &"last_king" and not detailed else t.call(mem.desc_key), 13, INK_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Длинное описание обрезается многоточием — полностью оно в подсказке карты.
		desc.max_lines_visible = 6 if detailed else 3
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(desc)
	return col


static func ink_theme() -> Theme:
	if _ink_theme == null:
		_ink_theme = Theme.new()
		_ink_theme.set_constant("outline_size", "Label", 0)
	return _ink_theme


## Уменьшенная рамка (или null без арта).
static func frame_texture() -> Texture2D:
	if _frame_checked:
		return _frame
	_frame_checked = true
	var tex := ArtDB.ui(&"card_frame")
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(roundi(WIDTH), roundi(HEIGHT), Image.INTERPOLATE_LANCZOS)
	_frame = ImageTexture.create_from_image(img)
	return _frame


## Сброс кэша рамки (тесты включают и выключают арт).
static func reset() -> void:
	_frame = null
	_frame_checked = false


## Гнездо прочности без рисованной рамки: тёмный круг с ободком.
class Socket:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.13, 0.15, 0.24))
		draw_arc(c, r - 1.5, 0, TAU, 32, Color(0.75, 0.55, 0.3), 3.0, true)
