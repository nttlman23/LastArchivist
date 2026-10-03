extends Control
## Настройки (SPEC_SPRINT4 4): громкость, подробные описания, подсказки обучения.


func _ready() -> void:
	UiKit.add_background(self)
	var box := UiKit.centered_column(self, 18)
	box.add_child(UiKit.label(tr("SETTINGS_TITLE"), 44, UiKit.ACCENT))
	box.add_child(_slider_row(tr("MENU_MUSIC"), Audio.music_volume, Audio.set_music_volume))
	box.add_child(_slider_row(tr("MENU_SFX"), Audio.sfx_volume, _on_sfx))
	box.add_child(_toggle(tr("SETTINGS_DETAILED"), tr("SETTINGS_DETAILED_TIP"), Settings.detailed, Settings.set_detailed))
	box.add_child(_toggle(tr("SETTINGS_HINTS"), tr("SETTINGS_HINTS_TIP"), Settings.hints, Settings.set_hints))
	box.add_child(_toggle(tr("SETTINGS_LARGE_ICONS"), tr("SETTINGS_LARGE_ICONS_TIP"), Settings.large_icons, Settings.set_large_icons))
	var reset := UiKit.button(tr("SETTINGS_RESET_HINTS"), _reset_hints, 420)
	box.add_child(reset)
	box.add_child(Control.new())
	box.add_child(UiKit.button(tr("SETTINGS_BACK"), Game.to_main_menu, 420))


func _slider_row(title: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiKit.label(title, 0, UiKit.MUTED)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


func _toggle(title: String, tip: String, value: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = value
	c.toggled.connect(on_change)
	c.toggled.connect(func(_on: bool) -> void: Audio.play(&"ui_click"))
	Tip.attach(c, title, tip)
	return c


func _on_sfx(value: float) -> void:
	Audio.set_sfx_volume(value)
	Audio.play(&"ui_click")


func _reset_hints() -> void:
	Hints.reset()
	Audio.play(&"card")
