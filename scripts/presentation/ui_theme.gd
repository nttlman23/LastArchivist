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
	return t


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
