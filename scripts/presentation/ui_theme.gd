class_name UiTheme
extends RefCounted
## Общая тема «Пепельный архив» (SPEC_SPRINT6 2, 5): рамки с орнаментом, кнопки, отступы.
## Всё собирается кодом; рамки — процедурные текстуры с кэшем.

const FRAME_SIZE := 48
const FRAME_MARGIN := 14

static var _frames: Dictionary = {}


static func build(font_size: int) -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size
	var border := Color(0.38, 0.34, 0.28)
	t.set_stylebox("normal", "Button", _button_box(UiKit.PANEL_COLOR.lightened(0.04), border))
	t.set_stylebox("hover", "Button", _button_box(UiKit.PANEL_COLOR.lightened(0.1), UiKit.ACCENT.darkened(0.25)))
	var pressed := _button_box(UiKit.PANEL_COLOR.darkened(0.15), UiKit.ACCENT)
	pressed.content_margin_top += 2
	pressed.content_margin_bottom -= 2
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", _button_box(UiKit.PANEL_COLOR.darkened(0.25), border.darkened(0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.92, 0.89, 0.82))
	t.set_color("font_hover_color", "Button", UiKit.ACCENT.lightened(0.2))
	t.set_color("font_pressed_color", "Button", UiKit.ACCENT)
	t.set_color("font_disabled_color", "Button", UiKit.MUTED.darkened(0.2))
	var panel := StyleBoxFlat.new()
	panel.bg_color = UiKit.PANEL_COLOR
	panel.border_color = border
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "TooltipPanel", ornate(UiKit.PANEL_COLOR, border, 1))
	_apply_art(t)
	_apply_fonts(t)
	return t


## Шрифты (SPEC_SPRINT9 4): текст — PT Sans, заголовки — Cormorant Garamond (UiKit.label крупным кеглем).
const TEXT_FONT := "res://fonts/PT_Sans-Web-Regular.ttf"
const HEADING_FONT := "res://fonts/CormorantGaramond.ttf"
const BOLD_FONT := "res://fonts/PT_Sans-Web-Bold.ttf"
static var heading_font: Font


static func _apply_fonts(t: Theme) -> void:
	var text := _font(TEXT_FONT)
	if text:
		t.default_font = text
	var heading := _font(HEADING_FONT)
	if heading:
		var v := FontVariation.new()
		v.base_font = heading
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
		heading_font = v


## Жирный PT Sans — мелкие заголовки на светлом фоне (вертикальные карты): Cormorant мелким кеглем расплывается.
static func bold_font() -> Font:
	return _font(BOLD_FONT)


## Шрифт: импортированный, иначе прямо из файла (проект не открывали в редакторе).
static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			return f
	return null


## Рисованные кнопки и панели (SPEC_SPRINT9 4): кожа переплёта — кнопки, пергамент — панели и подсказки.
## Пергамент затемнён: интерфейс тёмный, светлый текст должен читаться.
const PANEL_TINT := Color(0.34, 0.31, 0.28)


static func _apply_art(t: Theme) -> void:
	var btn := ArtDB.ui(&"button")
	if btn:
		var states := {"normal": Color(1, 1, 1), "hover": Color(1.25, 1.18, 1.05), "pressed": Color(0.8, 0.78, 0.74),
				"hover_pressed": Color(0.8, 0.78, 0.74), "disabled": Color(0.55, 0.55, 0.55, 0.8)}
		for state: String in states:
			var sb := art_box(btn, ArtDB.ui_patch(&"button"), states[state])
			sb.content_margin_left = 26
			sb.content_margin_right = 26
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			if state.contains("pressed"):
				sb.content_margin_top += 2
			t.set_stylebox(state, "Button", sb)
	if btn:
		# Над рисованными фонами текст без подложки — с тёмной обводкой.
		t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
		t.set_constant("outline_size", "Label", 5)
	var panel := ArtDB.ui(&"panel")
	if panel:
		var sb := art_box(panel, ArtDB.ui_patch(&"panel"), PANEL_TINT)
		sb.set_content_margin_all(16)
		t.set_stylebox("panel", "PanelContainer", sb)
		var tip := art_box(panel, ArtDB.ui_patch(&"panel"), PANEL_TINT)
		tip.set_content_margin_all(14)
		t.set_stylebox("panel", "TooltipPanel", tip)


static func art_box(tex: Texture2D, patch: int, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(maxi(patch, 8))
	sb.modulate_color = tint
	return sb


static func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## Панель с двойной рамкой и ромбами в углах (9-patch из процедурной текстуры).
static func ornate(bg: Color, border: Color, width: int = 2) -> StyleBoxTexture:
	var key := "%s|%s|%d" % [bg.to_html(), border.to_html(), width]
	if not _frames.has(key):
		_frames[key] = ImageTexture.create_from_image(_frame_image(bg, border, width))
	var sb := StyleBoxTexture.new()
	sb.texture = _frames[key]
	sb.set_texture_margin_all(FRAME_MARGIN)
	sb.set_content_margin_all(12)
	return sb


static func _frame_image(bg: Color, border: Color, width: int) -> Image:
	var n := FRAME_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := 7.0
	for y in n:
		for x in n:
			# Скруглённый прямоугольник: расстояние до ближайшего угла.
			var cx := clampf(x + 0.5, r, n - r)
			var cy := clampf(y + 0.5, r, n - r)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > r:
				continue
			var edge := minf(minf(x, n - 1 - x), minf(y, n - 1 - y))
			var col := bg
			if d > r - width or edge < width:
				col = border
			elif edge >= width + 3 and edge < width + 4:
				col = Color(border, 0.45)
			img.set_pixel(x, y, col)
	# Ромбы в углах на внутренней линии.
	for corner: Vector2i in [Vector2i(8, 8), Vector2i(n - 9, 8), Vector2i(8, n - 9), Vector2i(n - 9, n - 9)]:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if absi(dx) + absi(dy) <= 3:
					img.set_pixel(corner.x + dx, corner.y + dy, border.lightened(0.25))
	return img
