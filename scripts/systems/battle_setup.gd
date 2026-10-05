class_name BattleSetup
extends RefCounted
## Сборка боя текущего острова забега: встреча, сложность, командир (SPEC_SPRINT5 9–11).
## Одна точка для экрана боя, симуляции и автопрогона.


static func for_run(db: DefsDB, run: RunState, selected: Array[int]) -> BattleState:
	var enc := db.encounter(run.current_encounter_id(db))
	var s := BattleState.create(db, enc, run.codex, selected, run.battle_seed(), run.hero,
			db.school(run.school_id).passive_id, run.difficulty, Difficulty.commander_for(db, run, enc))
	CampOps.apply_gifts(run, s)
	RelicOps.apply_battle(run, s)
	Trials.apply_battle(run, enc, s)
	DailyRun.apply_battle(run, enc, s)
	return s


## Цель боя с учётом сложности: на «Легко» — всегда «уничтожить всех».
static func objective_of(run: RunState, enc: EncounterDef) -> StringName:
	return enc.objective if Difficulty.objectives_enabled(run.difficulty) else ObjectiveRule.ELIMINATE


## Награда за необычную цель: +1 ресурс случайного вида (детерминированно по острову).
static func objective_bonus(run: RunState, enc: EncounterDef) -> StringName:
	if objective_of(run, enc) == ObjectiveRule.ELIMINATE or enc.boss:
		return &""
	return RunState.RESOURCE_IDS[absi(run.node_seed(run.pending_node, "objective_bonus")) % RunState.RESOURCE_IDS.size()]
