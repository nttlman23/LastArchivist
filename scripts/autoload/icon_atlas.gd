extends Node
## Значки UnitGlyphs, запечённые в текстуры, — для кнопок, чипов и строк со значками.
## Рисуются белыми (цвет задаётся modulate). Текстура выдаётся сразу (пустая) и дорисовывается
## на месте после запекания, поэтому элементы, созданные в первом кадре, тоже получают значок.
## Без рендера (headless) остаются пустыми.

const SIZE := 48

var _textures: Dictionary[StringName, ImageTexture] = {}
var ready_baked := false


func _ready() -> void:
	for id in UnitGlyphs.ALL_ICONS:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		_textures[id] = ImageTexture.create_from_image(img)
	if DisplayServer.get_name() == "headless":
		return
	_bake.call_deferred()


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
