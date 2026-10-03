extends Control
## Главное меню: экспедиция, архив открытий, настройки (громкость переехала в настройки).


func _ready() -> void:
	UiKit.add_background(self)
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
	box.add_child(cont)
	box.add_child(UiKit.button(tr("MENU_META"), Game.goto.bind(Game.SCENE_META), 360))
	box.add_child(UiKit.button(tr("MENU_CHRONICLE"), Game.goto.bind(Game.SCENE_CHRONICLE), 360))
	box.add_child(UiKit.button(tr("MENU_SETTINGS"), Game.goto.bind(Game.SCENE_SETTINGS), 360))
	box.add_child(UiKit.button(tr("MENU_QUIT"), get_tree().quit, 360))
