class_name Difficulty
extends RefCounted
## Сложность забега (SPEC_SPRINT5 9): численность врагов, стартовые ресурсы, командиры,
## цели боя и очки памяти. «Нормально» — баланс Спринта 4.

const EASY := &"easy"
const NORMAL := &"normal"
const HARD := &"hard"
const ALL: Array[StringName] = [EASY, NORMAL, HARD]

const ENEMY_COUNT := {EASY: 0.7, NORMAL: 1.0, HARD: 1.25}
const START_RESOURCES := {EASY: 1.5, NORMAL: 1.0, HARD: 1.0}
const POINTS := {EASY: 0.5, NORMAL: 1.0, HARD: 1.5}
## Бонус очков за победу на «Тяжело».
const HARD_WIN_BONUS := 3
## С какого слоя на «Тяжело» командир есть во всех боях.
const HARD_COMMANDER_LAYER := 3
## На «Тяжело» цели боя строже: +1 раунд к N/K.
const HARD_OBJECTIVE_EXTRA := 1


static func enemy_count(difficulty: StringName, count: int) -> int:
	return maxi(1, roundi(count * float(ENEMY_COUNT.get(difficulty, 1.0))))


static func start_resource(difficulty: StringName, amount: int) -> int:
	return ceili(amount * float(START_RESOURCES.get(difficulty, 1.0)))


static func points(difficulty: StringName, base: int, won: bool) -> int:
	var total := roundi(base * float(POINTS.get(difficulty, 1.0)))
	if won and difficulty == HARD:
		total += HARD_WIN_BONUS
	return total


## Заряды каждого действия командира: на «Тяжело» — как в данных, иначе на один меньше (не меньше 1).
static func commander_charges(difficulty: StringName, base: int) -> int:
	return base if difficulty == HARD else maxi(1, base - 1)


## Цели боя кроме «уничтожить всех»: на «Легко» их нет.
static func objectives_enabled(difficulty: StringName) -> bool:
	return difficulty != EASY


static func objective_extra(difficulty: StringName) -> int:
	return HARD_OBJECTIVE_EXTRA if difficulty == HARD else 0


## Есть ли командир у боя: «Нормально» — элита и Разлом, «Тяжело» — ещё все бои со слоя 3.
static func has_commander(difficulty: StringName, encounter: EncounterDef, layer: int) -> bool:
	match difficulty:
		NORMAL:
			return encounter.elite or encounter.boss
		HARD:
			return encounter.elite or encounter.boss or layer >= HARD_COMMANDER_LAYER
	return false


## Командир боя (детерминированно по сиду острова) или пусто.
static func commander_for(db: DefsDB, run: RunState, encounter: EncounterDef) -> StringName:
	var node := run.pending()
	var layer := node.layer if node else 0
	var all_battles := Trials.has(run, Trials.COMMANDERS)
	if not (all_battles or has_commander(run.difficulty, encounter, layer)) or db.commanders.is_empty():
		return &""
	var ids := db.commander_ids()
	return ids[absi(run.node_seed(run.pending_node, "commander")) % ids.size()]
