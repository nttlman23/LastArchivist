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


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		detailed = bool(cfg.get_value(SECTION, "detailed", detailed))
		hints = bool(cfg.get_value(SECTION, "hints", hints))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, "detailed", detailed)
	cfg.set_value(SECTION, "hints", hints)
	cfg.save(settings_path)
