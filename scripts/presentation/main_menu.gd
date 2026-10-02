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
	cont.disabled = SaveService.load_run() == null
	box.add_child(cont)
	box.add_child(UiKit.button(tr("MENU_QUIT"), get_tree().quit, 360))
	box.add_child(Control.new())
	box.add_child(_volume_row(tr("MENU_MUSIC"), Audio.music_volume, Audio.set_music_volume))
	box.add_child(_volume_row(tr("MENU_SFX"), Audio.sfx_volume, _on_sfx_volume))


func _volume_row(title: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiKit.label(title, 0, UiKit.MUTED)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(224, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


## Пробный звук, чтобы было слышно новую громкость эффектов.
func _on_sfx_volume(value: float) -> void:
	Audio.set_sfx_volume(value)
	Audio.play(&"ui_click")
