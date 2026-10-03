extends Node
## Значки UnitGlyphs, запечённые в текстуры, — для кнопок, чипов и строк со значками.
## Рисуются белыми (цвет задаётся modulate). Текстура выдаётся сразу (пустая) и дорисовывается
## на месте после запекания, поэтому элементы, созданные в первом кадре, тоже получают значок.
## Без рендера (headless) остаются пустыми.

const SIZE := 48
## Силуэты существ для портретов и медальонов (SPEC_SPRINT6 11): запекаются по (вид, цвет тела).
## Силуэт — сотни мелких треугольников; при программной отрисовке 19 портретов очереди
## стоили ~8 мс на кадр. Текстура — сама текстура вьюпорта (без чтения из видеопамяти).
const GLYPH_SIZE := 128
const GLYPH_R := 52.0

var _textures: Dictionary[StringName, ImageTexture] = {}
var ready_baked := false
var _glyphs: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	for id in UnitGlyphs.ALL_ICONS:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		_textures[id] = ImageTexture.create_from_image(img)
	if DisplayServer.get_name() == "headless":
		return
	_bake.call_deferred()


## Запечённый силуэт (тень, фигура, акценты) на прозрачном фоне или null без рендера.
## Нарисованный силуэт радиуса GLYPH_R занимает текстуру GLYPH_SIZE — см. glyph_rect.
func get_glyph(def_id: StringName, body: Color) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var key := "%s|%s" % [def_id, body.to_html(false)]
	if not _glyphs.has(key):
		var vp := SubViewport.new()
		vp.size = Vector2i(GLYPH_SIZE, GLYPH_SIZE)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := Node2D.new()
		painter.draw.connect(_paint_glyph.bind(painter, def_id, body))
		vp.add_child(painter)
		add_child(vp)
		_glyphs[key] = vp.get_texture()
	return _glyphs[key]


func _paint_glyph(painter: Node2D, def_id: StringName, body: Color) -> void:
	var c := Vector2.ONE * GLYPH_SIZE * 0.5
	UnitGlyphs.draw_unit(painter, def_id, c + Vector2(1.5, 2.5), GLYPH_R, body, Color(0, 0, 0, 0.3))
	UnitGlyphs.draw_unit(painter, def_id, c, GLYPH_R, body)
	UnitGlyphs.draw_details(painter, def_id, c, GLYPH_R, body)


## Прямоугольник для запечённого силуэта с центром c и радиусом фигуры r.
static func glyph_rect(c: Vector2, r: float) -> Rect2:
	var half := r * GLYPH_SIZE * 0.5 / GLYPH_R
	return Rect2(c - Vector2.ONE * half, Vector2.ONE * half * 2.0)


func get_icon(id: StringName) -> Texture2D:
	return _textures.get(id, _textures[UnitGlyphs.ICON_ABILITY])


func _bake() -> void:
	var viewports: Dictionary[StringName, SubViewport] = {}
	for id in UnitGlyphs.ALL_ICONS:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := Node2D.new()
		painter.draw.connect(_paint.bind(painter, id))
		vp.add_child(painter)
		add_child(vp)
		viewports[id] = vp
	await RenderingServer.frame_post_draw
	for id in viewports:
		var img := viewports[id].get_texture().get_image()
		if img:
			img.convert(Image.FORMAT_RGBA8)
			_textures[id].update(img)
		viewports[id].queue_free()
	ready_baked = true


func _paint(painter: Node2D, id: StringName) -> void:
	UnitGlyphs.draw_icon(painter, id, Vector2(SIZE, SIZE) * 0.5, SIZE * 0.5 - 1.0, Color(0, 0, 0, 0), Color.WHITE, false)
