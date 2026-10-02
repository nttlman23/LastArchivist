extends Control


func _ready() -> void:
	UiKit.add_background(self)
	var box := UiKit.centered_column(self, 20)
	var title := UiKit.label(tr("GAME_TITLE"), 64, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(Control.new())

	box.add_child(UiKit.button(tr("MENU_NEW_RUN"), Game.new_run, 360))
	var cont := UiKit.button(tr("MENU_CONTINUE"), Game.continue_run, 360)
	cont.disabled = not SaveService.has_save()
	box.add_child(cont)
	box.add_child(UiKit.button(tr("MENU_QUIT"), get_tree().quit, 360))
