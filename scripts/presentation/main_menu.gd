extends Control
## Главное меню: экспедиция, архив открытий, настройки (громкость переехала в настройки).


func _ready() -> void:
	UiKit.add_background(self)
	var emblem := MenuEmblem.new()
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(emblem)
	var box := UiKit.centered_column(self, 18)
	var title := UiKit.label(tr("GAME_TITLE"), 64, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var points := UiKit.chip(UnitGlyphs.ICON_POINTS, str(Game.profile.points), UiKit.ACCENT, tr("META_POINTS"), tr("META_POINTS_TIP"), 22)
	points.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(points)
	box.add_child(Control.new())

	box.add_child(UiKit.button(tr("MENU_NEW_RUN"), Game.goto.bind(Game.SCENE_SCHOOL), 360))
	var cont := UiKit.button(tr("MENU_CONTINUE"), Game.continue_run, 360)
	cont.disabled = SaveService.load_run() == null
	if SaveService.is_broken():
		# Файл есть, но ни он, ни резервная копия не читаются — подсказка вместо молчания.
		Tip.attach(cont, tr("MENU_CONTINUE"), tr("MENU_SAVE_BROKEN"))
	box.add_child(cont)
	box.add_child(UiKit.button(tr("MENU_META"), Game.goto.bind(Game.SCENE_META), 360))
	box.add_child(UiKit.button(tr("MENU_CHRONICLE"), Game.goto.bind(Game.SCENE_CHRONICLE), 360))
	box.add_child(UiKit.button(tr("MENU_SETTINGS"), Game.goto.bind(Game.SCENE_SETTINGS), 360))
	box.add_child(UiKit.button(tr("MENU_QUIT"), Game.quit_game, 360))


## Большой бледный силуэт архива за меню; медленно «дышит».
class MenuEmblem:
	extends Control
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = 0.75 + 0.25 * sin(_t * 0.8)

	func _draw() -> void:
		var c := size * Vector2(0.5, 0.52)
		var r := size.y * 0.42
		draw_circle(c, r, Color(0.95, 0.75, 0.4, 0.025))
		draw_arc(c, r, 0, TAU, 96, Color(0.95, 0.75, 0.4, 0.06), 3.0)
		UnitGlyphs.draw_unit(self, &"archive_relic", c, r * 0.7, Color(0, 0, 0, 0), Color(0.95, 0.8, 0.5, 0.045))
