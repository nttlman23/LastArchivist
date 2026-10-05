class_name MetaRewards
extends RefCounted
## Мета-прогрессия (SPEC_SPRINT4 5): очки памяти за забег, каталог открытий, пулы карт и событий.

const POINTS_PER_LAYER := 1
const POINTS_PER_ELITE := 2
const POINTS_FOR_RIFT := 5
## Босс второго акта (SPEC_SPRINT7 2).
const POINTS_FOR_ACT2_BOSS := 8

enum Kind { SCHOOL, CARD, EVENT }

## Открытия, кроме школ (школы берутся из SchoolDef.unlock_cost).
const CATALOG := [
	{"id": &"card_storm_wyrm", "kind": Kind.CARD, "target": &"storm_wyrm", "cost": 4},
	{"id": &"card_faceless_choir", "kind": Kind.CARD, "target": &"faceless_choir", "cost": 4},
	{"id": &"event_rift_whisper", "kind": Kind.EVENT, "target": &"rift_whisper", "cost": 3},
	{"id": &"event_captive_king", "kind": Kind.EVENT, "target": &"captive_king", "cost": 3},
]


static func points_for_run(run: RunState, won: bool) -> int:
	var layer := run.total_layer()
	var rift := won or run.act >= 2
	var base := maxi(0, layer - 1) * POINTS_PER_LAYER + run.elites_won * POINTS_PER_ELITE \
			+ (POINTS_FOR_RIFT if rift else 0) + (POINTS_FOR_ACT2_BOSS if won else 0)
	return Trials.points(run, Difficulty.points(run.difficulty, base, won))


## Все открытия: школы (кроме бесплатных) и каталог. Каждое — {id, kind, target, cost}.
static func all_unlocks(db: DefsDB) -> Array:
	var result: Array = []
	for school in db.schools_sorted():
		if school.unlock_cost > 0:
			result.append({"id": school_unlock_id(school.id), "kind": Kind.SCHOOL, "target": school.id, "cost": school.unlock_cost})
	result.append_array(CATALOG)
	return result


static func school_unlock_id(school_id: StringName) -> StringName:
	return StringName("school_" + String(school_id))


static func is_school_open(profile: ProfileState, school: SchoolDef) -> bool:
	return school.implemented and (school.unlock_cost == 0 or profile.is_unlocked(school_unlock_id(school.id)))


## Ключ причины, почему открыть нельзя, или "".
static func buy_reason(db: DefsDB, profile: ProfileState, unlock: Dictionary) -> String:
	if profile.is_unlocked(unlock["id"]):
		return "REASON_UNLOCKED"
	if unlock["kind"] == Kind.SCHOOL and not db.school(unlock["target"]).implemented:
		return "REASON_SOON"
	if profile.points < int(unlock["cost"]):
		return "REASON_NO_POINTS"
	return ""


static func buy(db: DefsDB, profile: ProfileState, unlock: Dictionary) -> bool:
	if buy_reason(db, profile, unlock) != "":
		return false
	profile.points -= int(unlock["cost"])
	profile.unlocked.append(unlock["id"])
	return true


## Пул карт наград и лавки: открытые карты + карты существ открытых школ; любимые карты школы — ×2.
static func card_pool(db: DefsDB, profile: ProfileState, school: SchoolDef, act: int = 1) -> Array[StringName]:
	var locked: Array[StringName] = []
	for u in CATALOG:
		if u["kind"] == Kind.CARD and not profile.is_unlocked(u["id"]):
			locked.append(u["target"])
	for s in db.schools_sorted():
		if not is_school_open(profile, s):
			locked.append_array(s.own_memories)
	var pool: Array[StringName] = []
	for id in db.pool_memory_ids(act):
		if locked.has(id):
			continue
		pool.append(id)
		if school and school.favored_memories.has(id):
			pool.append(id)
	return pool


static func event_pool(db: DefsDB, profile: ProfileState) -> Array[StringName]:
	var locked: Array[StringName] = []
	for u in CATALOG:
		if u["kind"] == Kind.EVENT and not profile.is_unlocked(u["id"]):
			locked.append(u["target"])
	var pool: Array[StringName] = []
	for id in db.event_ids():
		if not locked.has(id) and not MetaUpgrades.event_locked(profile, id):
			pool.append(id)
	return pool


## Итог забега: начисляет очки и статистику, пишет летопись, возвращает начисленные очки.
static func finish_run(profile: ProfileState, run: RunState, won: bool, db: DefsDB = null) -> int:
	var gained := points_for_run(run, won)
	profile.points += gained
	profile.runs += 1
	if won:
		profile.wins += 1
	profile.best_layer = maxi(profile.best_layer, run.total_layer())
	if won and run.difficulty == Difficulty.HARD:
		profile.open_next_trial(run.school_id, run.trial)
	profile.record_run(chronicle_entry(run, ProfileState.OUTCOME_WON if won else ProfileState.OUTCOME_LOST, gained, db))
	return gained


## Забег брошен (начат новый поверх сохранения): только запись в летопись, без очков.
static func abandon_run(profile: ProfileState, run: RunState) -> void:
	profile.record_run(chronicle_entry(run, ProfileState.OUTCOME_ABANDONED, 0, null))


static func chronicle_entry(run: RunState, outcome: String, points: int, db: DefsDB) -> Dictionary:
	var codex: Array = []
	for card in run.codex.cards:
		codex.append(String(card.memory_id))
	var encounter := ""
	if outcome != ProfileState.OUTCOME_ABANDONED and (run.pending_node >= 0 or run.pending_battle != &""):
		encounter = String(run.current_encounter_id(db))
	var date := Time.get_date_dict_from_system()
	return {
		"date": "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]],
		"school": String(run.school_id),
		"difficulty": String(run.difficulty),
		"trial": run.trial,
		"layer": run.total_layer(),
		"act": run.act,
		"outcome": outcome,
		"encounter": encounter,
		"codex": codex,
		"points": points,
		"lost": run.cards_lost,
		# Реликвии и дары привала (SPEC_SPRINT7 11) — значками в строке летописи.
		"relics": Array(run.relics).map(func(x: StringName) -> String: return String(x)),
		"gifts": Array(run.gifts).map(func(x: StringName) -> String: return String(x)),
	}
