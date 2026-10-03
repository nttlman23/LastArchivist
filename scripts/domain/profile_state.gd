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
## Летопись (SPEC_SPRINT5 6): последние забеги, новые — первыми.
var chronicle: Array[Dictionary] = []
## Сводка по школам за всё время: id школы -> {"runs", "wins", "best"}.
var school_stats: Dictionary[StringName, Dictionary] = {}

const CHRONICLE_SIZE := 20

## Исходы забега в летописи.
const OUTCOME_WON := "won"
const OUTCOME_LOST := "lost"
const OUTCOME_ABANDONED := "abandoned"


## Запись в летопись и сводку школы. entry: date, school, difficulty, layer, outcome, encounter, codex, points.
func record_run(entry: Dictionary) -> void:
	chronicle.push_front(entry)
	while chronicle.size() > CHRONICLE_SIZE:
		chronicle.pop_back()
	var school := StringName(entry.get("school", ""))
	var stats: Dictionary = school_stats.get(school, {"runs": 0, "wins": 0, "best": 0})
	stats["runs"] = int(stats["runs"]) + 1
	if entry.get("outcome", "") == OUTCOME_WON:
		stats["wins"] = int(stats["wins"]) + 1
	stats["best"] = maxi(int(stats["best"]), int(entry.get("layer", 0)))
	if entry.get("outcome", "") == OUTCOME_WON and is_better_codex(entry, stats.get("best_codex", {})):
		stats["best_codex"] = {
			"codex": entry.get("codex", []), "difficulty": entry.get("difficulty", "normal"),
			"lost": int(entry.get("lost", 0)), "date": entry.get("date", ""),
		}
	school_stats[school] = stats


const DIFFICULTY_RANK := {"easy": 0, "normal": 1, "hard": 2}


## Лучший победный Кодекс (SPEC_SPRINT6 8): выше сложность, затем меньше потерь, затем новее.
static func is_better_codex(entry: Dictionary, best: Dictionary) -> bool:
	if best.is_empty():
		return true
	var a := int(DIFFICULTY_RANK.get(String(entry.get("difficulty", "normal")), 1))
	var b := int(DIFFICULTY_RANK.get(String(best.get("difficulty", "normal")), 1))
	if a != b:
		return a > b
	return int(entry.get("lost", 0)) <= int(best.get("lost", 0))


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
	cfg.set_value("chronicle", "entries", chronicle)
	var schools := {}
	for id in school_stats:
		schools[String(id)] = school_stats[id]
	cfg.set_value("chronicle", "schools", schools)
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
	# Летопись появилась в Спринте 5: в старых профилях её нет — пустая.
	for e in cfg.get_value("chronicle", "entries", []):
		if e is Dictionary:
			p.chronicle.append(e)
	var schools: Dictionary = cfg.get_value("chronicle", "schools", {})
	for id in schools:
		p.school_stats[StringName(id)] = schools[id]
	return p
