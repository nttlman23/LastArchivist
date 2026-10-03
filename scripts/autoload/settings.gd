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
## Подача (SPEC_SPRINT6 3): скорость анимаций, тряска камеры, полные эффекты (частицы).
const ANIM_SPEEDS: Array[float] = [1.0, 1.5, 2.0]
var anim_speed := 1.0
var screen_shake := true
var effects_full := true


func _ready() -> void:
	load_settings()


func set_detailed(value: bool) -> void:
	detailed = value
	save_settings()
	changed.emit()


func set_hints(value: bool) -> void:
	hints = value
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
		anim_speed = float(cfg.get_value(SECTION, "anim_speed", anim_speed))
		if not ANIM_SPEEDS.has(anim_speed):
			anim_speed = 1.0
		screen_shake = bool(cfg.get_value(SECTION, "screen_shake", screen_shake))
		effects_full = bool(cfg.get_value(SECTION, "effects_full", effects_full))


func save_settings() -> void:
	var cfg := SafeFile.load_config(settings_path)
	if cfg == null:
		cfg = ConfigFile.new()
	cfg.set_value(SECTION, "detailed", detailed)
	cfg.set_value(SECTION, "hints", hints)
	cfg.set_value(SECTION, "large_icons", large_icons)
	cfg.set_value(SECTION, "anim_speed", anim_speed)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "effects_full", effects_full)
	SafeFile.save_config(cfg, settings_path)
