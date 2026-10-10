class_name Achievements
extends RefCounted
## Достижения (SPEC_SPRINT9 6): проверка условий на ключевых событиях забега, награда — один раз.
## Награды-открытия попадают в ProfileState.unlocked под ключом «вид_id» (card_ash_keepers, relic_rift_shard…).

## События, на которых проверяются условия.
enum Event { BATTLE_WON, RUN_END, RELIC, PURCHASE, REWORK, NODE, DAILY }

const FIRST_CHAPTER := &"first_chapter"
const DROWNED_VICTORY := &"drowned_victory"
const HARD_HAND := &"hard_hand"
const EVERY_SCHOOL := &"every_school"
const NO_LOSSES := &"no_losses"
const LIGHTNING := &"lightning"
const FOUR_WARS := &"four_wars"
const ON_THE_EDGE := &"on_the_edge"
const ARCHIVE_INTACT := &"archive_intact"
const CLEAN_SLATE := &"clean_slate"
const NOTHING_FORGOTTEN := &"nothing_forgotten"
const MEMORY_ALCHEMIST := &"memory_alchemist"
const MISER := &"miser"
const COLLECTOR := &"collector"
const REGULAR_CUSTOMER := &"regular_customer"
const FULL_CHRONICLE := &"full_chronicle"
const FIRST_STEP := &"first_step"
const TESTED := &"tested"
const ARCHIVE_KEEPER := &"archive_keeper"
const DAILY_THREE := &"daily_three"

const CARD := &"card"
const RELIC := &"relic"
const EVENT := &"event"

## На каких событиях проверяется условие.
const EVENTS := {
	FIRST_CHAPTER: [Event.BATTLE_WON],
	DROWNED_VICTORY: [Event.RUN_END],
	HARD_HAND: [Event.RUN_END],
	EVERY_SCHOOL: [Event.RUN_END],
	NO_LOSSES: [Event.BATTLE_WON],
	LIGHTNING: [Event.BATTLE_WON],
	FOUR_WARS: [Event.BATTLE_WON],
	ON_THE_EDGE: [Event.BATTLE_WON],
	ARCHIVE_INTACT: [Event.BATTLE_WON],
	CLEAN_SLATE: [Event.RUN_END],
	NOTHING_FORGOTTEN: [Event.RUN_END],
	MEMORY_ALCHEMIST: [Event.REWORK],
	MISER: [Event.RUN_END],
	# Реликвия из события приходит без отдельного вызова — проверяется по завершении острова.
	COLLECTOR: [Event.RELIC, Event.NODE],
	REGULAR_CUSTOMER: [Event.PURCHASE],
	FULL_CHRONICLE: [Event.NODE],
	FIRST_STEP: [Event.RUN_END],
	TESTED: [Event.RUN_END],
	ARCHIVE_KEEPER: [Event.RUN_END],
	DAILY_THREE: [Event.DAILY],
}

## Цели «Четырёх войн» и бои на время, которые не считаются для «Молниеносно».
const WAR_OBJECTIVES: Array[StringName] = [ObjectiveRule.SURVIVE, ObjectiveRule.ASSASSINATE, ObjectiveRule.HOLD, ObjectiveRule.PROTECT]
const TIMED_OBJECTIVES: Array[StringName] = [ObjectiveRule.SURVIVE, ObjectiveRule.HOLD, ObjectiveRule.PROTECT]


## Проверяет неполученные достижения события event; выдаёт награды и возвращает id новых.
## ctx — подробности события: для боя — battle_context, для конца забега — {"won": bool}.
static func check(db: DefsDB, profile: ProfileState, run: RunState, event: Event, ctx: Dictionary = {}) -> Array[StringName]:
	var earned: Array[StringName] = []
	if profile == null or not counts(run):
		return earned
	for a in db.achievements_sorted():
		if profile.has_achievement(a.id) or not EVENTS.get(a.condition, []).has(event):
			continue
		if _met(profile, run, a, ctx):
			grant(db, profile, a.id)
			earned.append(a.id)
	return earned


## Повторная попытка ежедневного забега достижений не даёт (SPEC_SPRINT9 1).
static func counts(run: RunState) -> bool:
	return run == null or run.daily_date == "" or run.daily_ranked


## Выдать достижение: дата, очки, открытие.
static func grant(db: DefsDB, profile: ProfileState, id: StringName, date: String = "") -> void:
	if profile.has_achievement(id):
		return
	var a := db.achievement(id)
	profile.achievements[id] = date if date != "" else today()
	profile.points += a.points
	if a.unlock_kind != &"":
		var key := unlock_key(a.unlock_kind, a.unlock_id)
		if not profile.is_unlocked(key):
			profile.unlocked.append(key)


static func unlock_key(kind: StringName, id: StringName) -> StringName:
	return StringName("%s_%s" % [kind, id])


## Содержимое вида kind, открываемое достижениями и ещё не открытое (без профиля — всё закрыто).
static func locked(db: DefsDB, profile: ProfileState, kind: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for a in db.achievements.values():
		if a.unlock_kind == kind and (profile == null or not profile.is_unlocked(unlock_key(kind, a.unlock_id))):
			result.append(a.unlock_id)
	return result


## Реликвии, открытые достижениями, — копируются в забег при старте (реликварий не видит профиль).
static func relic_unlocks(db: DefsDB, profile: ProfileState) -> Array[StringName]:
	var result: Array[StringName] = []
	for a in db.achievements.values():
		if a.unlock_kind == RELIC and profile != null and profile.is_unlocked(unlock_key(RELIC, a.unlock_id)):
			result.append(a.unlock_id)
	return result


static func relic_locked(db: DefsDB, run: RunState, id: StringName) -> bool:
	for a in db.achievements.values():
		if a.unlock_kind == RELIC and a.unlock_id == id:
			return not run.relic_unlocks.has(id)
	return false


## Подробности выигранного боя для условий: элита, босс, акт, цель, раунды, выставленные и выжившие стеки, цел ли Архив.
## Считаются стеки из карт Кодекса; призванные, иллюзии и Архив — нет.
static func battle_context(state: BattleState, enc: EncounterDef, act: int) -> Dictionary:
	var fielded := 0
	var survived := 0
	var archive_intact := true
	for u in state.units:
		if u.side != UnitState.Side.PLAYER:
			continue
		if u.uid == state.archive_uid:
			archive_intact = u.is_alive() and u.count == u.start_count and u.top_hp >= u.hp
			continue
		if u.card_index < 0 or u.illusion or u.inert:
			continue
		fielded += 1
		if u.is_alive():
			survived += 1
	return {
		"elite": enc.elite, "boss": enc.boss, "act": act, "objective": state.objective, "rounds": state.round_number,
		"fielded": fielded, "survived": survived, "archive_intact": archive_intact and state.archive_uid >= 0,
		"commander": state.commander_id != &"",
	}


static func _met(profile: ProfileState, run: RunState, a: AchievementDef, ctx: Dictionary) -> bool:
	var won := bool(ctx.get("won", false))
	match a.condition:
		FIRST_CHAPTER:
			return bool(ctx.get("boss", false)) and int(ctx.get("act", 0)) == 1
		DROWNED_VICTORY:
			return won
		HARD_HAND:
			return won and run.difficulty == Difficulty.HARD
		EVERY_SCHOOL:
			return _schools_won(profile) >= a.threshold
		NO_LOSSES:
			return bool(ctx.get("elite", false)) and int(ctx.get("fielded", 0)) > 0 \
					and int(ctx.get("survived", 0)) == int(ctx.get("fielded", 0))
		LIGHTNING:
			return int(ctx.get("rounds", 99)) <= a.threshold and not TIMED_OBJECTIVES.has(StringName(ctx.get("objective", &"")))
		FOUR_WARS:
			return WAR_OBJECTIVES.filter(func(o: StringName) -> bool: return run.objectives_won.has(o)).size() >= a.threshold
		ON_THE_EDGE:
			return int(ctx.get("fielded", 0)) >= a.threshold and int(ctx.get("survived", 0)) == 1
		ARCHIVE_INTACT:
			return StringName(ctx.get("objective", &"")) == ObjectiveRule.PROTECT and bool(ctx.get("archive_intact", false))
		CLEAN_SLATE:
			return won and run.codex.cards.size() <= a.threshold
		NOTHING_FORGOTTEN:
			return won and run.cards_lost <= a.threshold
		MEMORY_ALCHEMIST:
			return run.reworks.size() >= a.threshold
		MISER:
			return run.resources.values().any(func(v: int) -> bool: return v >= a.threshold)
		COLLECTOR:
			return run.relics.size() >= a.threshold
		REGULAR_CUSTOMER:
			return run.shop_buys >= a.threshold
		FULL_CHRONICLE:
			return run.node_types.size() >= a.threshold
		FIRST_STEP, TESTED, ARCHIVE_KEEPER:
			return won and run.trial >= a.threshold
		DAILY_THREE:
			return profile.daily_count >= a.threshold
	return false


static func _schools_won(profile: ProfileState) -> int:
	var n := 0
	for id in profile.school_stats:
		if int(profile.school_stats[id].get("wins", 0)) > 0:
			n += 1
	return n


# --- Старые профили --------------------------------------------------------------------

## Профиль из версии до 3: выдать с наградами достижения, вычислимые по накопленной статистике.
static func grant_retro(db: DefsDB, profile: ProfileState) -> Array[StringName]:
	var earned: Array[StringName] = []
	var wins := _won_entries(profile)
	for a in db.achievements_sorted():
		if not profile.has_achievement(a.id) and _retro_met(profile, a, wins):
			grant(db, profile, a.id)
			earned.append(a.id)
	profile.needs_retro = false
	return earned


## Победные записи: летопись и лучшие Кодексы школ (в летописи хранятся только последние забеги).
static func _won_entries(profile: ProfileState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in profile.chronicle:
		if e.get("outcome", "") == ProfileState.OUTCOME_WON:
			result.append(e)
	for id in profile.school_stats:
		var best: Dictionary = profile.school_stats[id].get("best_codex", {})
		if not best.is_empty():
			result.append(best)
	return result


static func _retro_met(profile: ProfileState, a: AchievementDef, wins: Array[Dictionary]) -> bool:
	match a.condition:
		FIRST_CHAPTER:
			return profile.wins > 0 or profile.best_layer > MapState.LAYERS
		DROWNED_VICTORY:
			return profile.wins > 0
		HARD_HAND:
			return profile.trials.values().any(func(t: int) -> bool: return t > 0) \
					or wins.any(func(e: Dictionary) -> bool: return e.get("difficulty", "") == String(Difficulty.HARD))
		EVERY_SCHOOL:
			return _schools_won(profile) >= a.threshold
		CLEAN_SLATE:
			return wins.any(func(e: Dictionary) -> bool: return (e.get("codex", []) as Array).size() <= a.threshold)
		NOTHING_FORGOTTEN:
			return wins.any(func(e: Dictionary) -> bool: return int(e.get("lost", 99)) <= a.threshold)
		COLLECTOR:
			return profile.chronicle.any(func(e: Dictionary) -> bool: return (e.get("relics", []) as Array).size() >= a.threshold)
		FIRST_STEP, TESTED, ARCHIVE_KEEPER:
			# Победа на ступени N открывает ступень N + 1; на ступени 10 — видна только по записям.
			return profile.trials.values().any(func(t: int) -> bool: return t > a.threshold) \
					or wins.any(func(e: Dictionary) -> bool: return int(e.get("trial", 0)) >= a.threshold)
	return false


## Текст награды: очки или открытие.
static func reward_text(db: DefsDB, a: AchievementDef) -> String:
	match a.unlock_kind:
		CARD:
			return TranslationServer.translate("ACH_REWARD_CARD") % TranslationServer.translate(db.memory(a.unlock_id).name_key)
		RELIC:
			return TranslationServer.translate("ACH_REWARD_RELIC") % TranslationServer.translate(db.relic(a.unlock_id).name_key)
		EVENT:
			return TranslationServer.translate("ACH_REWARD_EVENT") % TranslationServer.translate(db.event(a.unlock_id).title_key)
	return TranslationServer.translate("ACH_REWARD_POINTS") % a.points


static func today() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]
