class_name ContrastAudit
extends RefCounted
## Аудит контраста текста (SPEC_SPRINT12 7): для каждой видимой надписи и кнопки на снимке экрана —
## цвет текста против фона под ней (медиана яркости пикселей прямоугольника: текст занимает малую долю).
## Контраст по формуле WCAG; у надписей с тёмной обводкой текст читается и при меньшем контрасте.
## Запуск: godot --path . res://tools/screenshots.tscn -- <папка> --contrast (нужно окно).

## Порог: основной текст — 4,5 : 1; с обводкой — 3 : 1.
const MIN_CONTRAST := 4.5
## Строгий режим (--contrast-strict): и надписи с обводкой — по 4,5.
static var strict := false
const MIN_OUTLINED := 3.0


static func luminance(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func ratio(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Фон под прямоугольником: цвет пикселя с медианной яркостью.
static func background(img: Image, rect: Rect2i) -> Color:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return Color.BLACK
	var samples: Array = []
	var step := maxi(1, int(sqrt(float(r.size.x * r.size.y) / 400.0)))
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			samples.append(img.get_pixel(x, y))
	samples.sort_custom(func(a: Color, b: Color) -> bool: return luminance(a) < luminance(b))
	return samples[samples.size() / 2]


static func report(screen: String, img: Image, root: Node) -> void:
	var scale := Vector2(img.get_size()) / root.get_viewport().get_visible_rect().size
	for c in _texts(root):
		var text: String = c.text
		var color: Color
		var outline := 0
		if c is Label:
			color = c.get_theme_color("font_color")
			outline = c.get_theme_constant("outline_size")
		else:
			color = c.get_theme_color("font_color")
		var rect: Rect2 = c.get_global_rect()
		var px := Rect2i(Vector2i(rect.position * scale), Vector2i(rect.size * scale))
		var bg := background(img, px)
		var k := ratio(color * Color(1, 1, 1, 1), bg)
		var need := MIN_OUTLINED if outline > 0 and not strict else MIN_CONTRAST
		if k < need:
			print("CONTRAST %s %.2f %s outline=%d text=#%s bg=#%s «%s»" % [screen, k, c.get_class(), outline,
					color.to_html(false), bg.to_html(false), text.substr(0, 40).replace("\n", " ")])


static func _texts(node: Node) -> Array:
	var out: Array = []
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return out
	if (node is Label or node is Button) and String(node.text).strip_edges() != "":
		var r: Rect2 = node.get_global_rect()
		if r.size.x > 4 and r.size.y > 4:
			out.append(node)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out
