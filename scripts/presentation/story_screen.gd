extends Control
## Сценка истории (SPEC_SPRINT10 4): иллюстрация (этап B; пока — процедурный фон), заголовок и короткие абзацы,
## появляющиеся по клику. «Пропустить» — сразу дальше. Что показать и куда перейти — Game.story_scene / story_next.

const FADE := 0.5

var scene_id: StringName
var _paragraphs: Array[String] = []
var _shown := 0
var _text_box: VBoxContainer
var _next_button: Button
var _done := false


func _ready() -> void:
	scene_id = Game.story_scene if Game.story_scene != &"" else Story.PROLOGUE
	_paragraphs = Story.paragraphs(scene_id)
	var art := ArtDB.texture(&"scene", scene_id)
	if art:
		add_child(UiKit.art_background(art, 0.55))
	else:
		UiKit.add_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 260)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 22)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	var title := UiKit.label(tr("STORY_SCENE_%s_TITLE" % String(scene_id).to_upper()), 48, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_text_box = VBoxContainer.new()
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_theme_constant_override("separation", 16)
	col.add_child(_text_box)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	_next_button = UiKit.button(tr("STORY_NEXT"), _advance, 300)
	buttons.add_child(_next_button)
	buttons.add_child(UiKit.button(tr("STORY_SKIP"), _finish, 300))
	_advance()


## Клик по экрану или пробел — следующий абзац.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		_finish()


func _advance() -> void:
	if _shown >= _paragraphs.size():
		_finish()
		return
	var l := UiKit.label(_paragraphs[_shown], 24, Color(0.92, 0.9, 0.84))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	_text_box.add_child(l)
	l.create_tween().tween_property(l, "modulate:a", 1.0, FADE)
	_shown += 1
	_next_button.text = tr("STORY_CONTINUE") if _shown >= _paragraphs.size() else tr("STORY_NEXT")


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.finish_story()
