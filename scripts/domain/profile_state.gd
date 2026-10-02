class_name ProfileState
extends RefCounted
## Профиль игрока между забегами (SPEC_SPRINT4 5): очки памяти, открытия, подсказки, статистика.
## Хранится отдельно от сохранения забега.

const DEFAULT_PATH := "user://profile.cfg"
const VERSION := 1

var points := 0
var unlocked: Array[StringName] = []
var seen_hints: Array[StringName] = []
var runs := 0
var wins := 0
var best_layer := 0


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func save(path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", VERSION)
	cfg.set_value("profile", "points", points)
	cfg.set_value("profile", "unlocked", Array(unlocked).map(func(x: StringName) -> String: return String(x)))
	cfg.set_value("profile", "seen_hints", Array(seen_hints).map(func(x: StringName) -> String: return String(x)))
	cfg.set_value("stats", "runs", runs)
	cfg.set_value("stats", "wins", wins)
	cfg.set_value("stats", "best_layer", best_layer)
	cfg.save(path)


static func load_or_new(path: String = DEFAULT_PATH) -> ProfileState:
	var p := ProfileState.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("profile", "version", 0)) != VERSION:
		return p
	p.points = int(cfg.get_value("profile", "points", 0))
	for id in cfg.get_value("profile", "unlocked", []):
		p.unlocked.append(StringName(id))
	for id in cfg.get_value("profile", "seen_hints", []):
		p.seen_hints.append(StringName(id))
	p.runs = int(cfg.get_value("stats", "runs", 0))
	p.wins = int(cfg.get_value("stats", "wins", 0))
	p.best_layer = int(cfg.get_value("stats", "best_layer", 0))
	return p
