extends Node
## Настройки интерфейса (SPEC_SPRINT4 4): подробные описания и подсказки обучения.
## Громкость — в Audio; обе части живут в одном user://settings.cfg.

signal changed

const SECTION := "ui"

var settings_path := "user://settings.cfg"
## Полные тексты в карточках вместо коротких подписей.
var detailed := false
## Одноразовые подсказки обучения.
var hints := true
## Крупные значки и числа на поле боя (SPEC_SPRINT5 3).
var large_icons := false
## Значки намерений врагов постоянно (иначе — по наведению и Alt), SPEC_SPRINT7 7.
var show_intents := false
## Подача (SPEC_SPRINT6 3): скорость анимаций, тряска камеры, полные эффекты (частицы).
const ANIM_SPEEDS: Array[float] = [1.0, 1.5, 2.0]
var anim_speed := 1.0
var screen_shake := true
var effects_full := true
## Запуск в окне (иначе — во весь экран); применяется сразу и при каждом запуске.
var windowed := true
const WINDOW_SIZE := Vector2i(1600, 900)


func _ready() -> void:
	load_settings()
	apply_window()


func set_detailed(value: bool) -> void:
	detailed = value
	save_settings()
	changed.emit()


func set_hints(value: bool) -> void:
	hints = value
	save_settings()
	changed.emit()


func set_show_intents(value: bool) -> void:
	show_intents = value
	save_settings()
	changed.emit()


func set_large_icons(value: bool) -> void:
	large_icons = value
	save_settings()
	changed.emit()


func set_anim_speed(value: float) -> void:
	anim_speed = value
	save_settings()
	changed.emit()


func set_screen_shake(value: bool) -> void:
	screen_shake = value
	save_settings()
	changed.emit()


func set_effects_full(value: bool) -> void:
	effects_full = value
	save_settings()
	changed.emit()


func load_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg:
		detailed = bool(cfg.get_value(SECTION, "detailed", detailed))
		hints = bool(cfg.get_value(SECTION, "hints", hints))
		large_icons = bool(cfg.get_value(SECTION, "large_icons", large_icons))
		show_intents = bool(cfg.get_value(SECTION, "show_intents", show_intents))
		anim_speed = float(cfg.get_value(SECTION, "anim_speed", anim_speed))
		if not ANIM_SPEEDS.has(anim_speed):
			anim_speed = 1.0
		screen_shake = bool(cfg.get_value(SECTION, "screen_shake", screen_shake))
		effects_full = bool(cfg.get_value(SECTION, "effects_full", effects_full))
		windowed = bool(cfg.get_value(SECTION, "windowed", windowed))


func save_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg == null:
		cfg = ConfigFile.new()
	cfg.set_value(SECTION, "detailed", detailed)
	cfg.set_value(SECTION, "hints", hints)
	cfg.set_value(SECTION, "large_icons", large_icons)
	cfg.set_value(SECTION, "show_intents", show_intents)
	cfg.set_value(SECTION, "anim_speed", anim_speed)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "effects_full", effects_full)
	cfg.set_value(SECTION, "windowed", windowed)
	SafeFile.save_config(cfg, settings_path)


func set_windowed(value: bool) -> void:
	windowed = value
	save_settings()
	apply_window()
	changed.emit()


## Окно 1600×900 по центру экрана или полный экран (без рамки). В headless (тесты, сборка) — ничего.
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not windowed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	var screen := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - WINDOW_SIZE) / 2)
