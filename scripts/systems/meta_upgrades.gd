class_name MetaUpgrades
extends RefCounted
## Дерево улучшений Зала Архива (SPEC_SPRINT8 2): покупка за очки памяти и эффекты на забег.
## Набор улучшений копируется в забег при старте (RunState.upgrades) — покупки посреди забега его не меняют.

const SUPPLIES := &"supplies"
const KNOWLEDGE := &"knowledge"
const EXPEDITION := &"expedition"
const BRANCHES: Array[StringName] = [SUPPLIES, KNOWLEDGE, EXPEDITION]

# «Запасы»
const STOCK_INK := &"hall_stock_ink"              ## +1 Чернила на старте
const STOCK_PARCHMENT := &"hall_stock_parchment"  ## +1 Пергамент на старте
const DISCOUNT := &"hall_discount"                ## карты в лавке −1 Пергамент (не ниже 1)
const STOCK_AETHER := &"hall_stock_aether"        ## +1 Эфир на старте
const CAMP_SUPPLIES := &"hall_camp_supplies"      ## после привала +2 каждого ресурса
# «Знание»
const SECOND_LOOK := &"hall_second_look"          ## раз за акт — перебросить карты награды
const BINDING := &"hall_binding"                  ## «Починить» в гавани: +2 прочности вместо +1
const WIDE_SHELF := &"hall_wide_shelf"            ## награда за элиту — 4 карты
const COPYIST := &"hall_copyist"                  ## первая переработка в лавке за акт — бесплатно
const FAMILY := &"hall_family"                    ## старт с дополнительной картой школы (прочность 1)
# «Экспедиция»
const MARKED_MAP := &"hall_marked_map"            ## разведка на 1 Эфир дешевле
const RUMORS := &"hall_rumors"                    ## открывает 2 события
const KNOWN_RELIQUARY := &"hall_known_reliquary"  ## реликварий предлагает 3 реликвии
const SECRET_PATHS := &"hall_secret_paths"        ## перелёт на 1 полосу дальше
const LOST_RELICS := &"hall_lost_relics"          ## открывает 2 реликвии

## Контент, открываемый узлами.
const RUMOR_EVENTS: Array[StringName] = [&"archive_dust", &"old_cartographer"]
const LOST_RELIC_IDS: Array[StringName] = [&"chronicler_quill", &"false_bottom_chest"]

const CAMP_SUPPLY_AMOUNT := 2
const BINDING_REPAIR := 2
const FAMILY_DURABILITY := 1


static func has(run: RunState, id: StringName) -> bool:
	return run != null and run.upgrades.has(id)


# --- Покупка в профиле ------------------------------------------------------------

## Ключ причины, почему узел нельзя купить, или "".
static func buy_reason(db: DefsDB, profile: ProfileState, id: StringName) -> String:
	if profile.upgrades.has(id):
		return "REASON_UNLOCKED"
	var node := db.hall_node(id)
	for other in db.hall_branch(node.branch):
		if other.tier == node.tier - 1 and not profile.upgrades.has(other.id):
			return "REASON_NEEDS_PREVIOUS"
	if profile.points < node.cost:
		return "REASON_NO_POINTS"
	return ""


static func buy(db: DefsDB, profile: ProfileState, id: StringName) -> bool:
	if buy_reason(db, profile, id) != "":
		return false
	profile.points -= db.hall_node(id).cost
	profile.upgrades.append(id)
	return true


## Очки, потраченные на дерево.
static func spent(db: DefsDB, profile: ProfileState) -> int:
	var total := 0
	for id in profile.upgrades:
		if db.hall_nodes.has(id):
			total += db.hall_node(id).cost
	return total


## Сброс дерева: все очки за узлы возвращаются (открытия не трогаются).
static func reset(db: DefsDB, profile: ProfileState) -> int:
	var back := spent(db, profile)
	profile.points += back
	profile.upgrades.clear()
	return back


# --- Эффекты на забег ---------------------------------------------------------------

## Старт забега: ресурсы и дополнительная карта школы.
static func apply_start(db: DefsDB, run: RunState, school: SchoolDef) -> void:
	if has(run, STOCK_INK):
		run.gain(RunState.INK, 1)
	if has(run, STOCK_PARCHMENT):
		run.gain(RunState.PARCHMENT, 1)
	if has(run, STOCK_AETHER):
		run.gain(RunState.AETHER, 1)
	if has(run, FAMILY) and not run.codex.is_full():
		var pool: Array[StringName] = school.favored_memories.duplicate()
		if pool.is_empty():
			pool = school.starting_codex.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("family:%d" % run.run_seed)
		# Прочность 1: подмога на первый бой, а не постоянный лишний стек (баланс, SPEC_SPRINT8 10).
		run.codex.add(db, pool[rng.randi_range(0, pool.size() - 1)]).durability = FAMILY_DURABILITY


## После привала (начало второго акта).
static func apply_camp(run: RunState) -> void:
	if has(run, CAMP_SUPPLIES):
		for id in RunState.RESOURCE_IDS:
			run.gain(id, CAMP_SUPPLY_AMOUNT)


static func can_reroll(run: RunState) -> bool:
	return has(run, SECOND_LOOK) and run.reroll_act != run.act


## Перебросить предложение карт награды (раз за акт).
static func reroll(db: DefsDB, run: RunState, guarantee_hero: bool) -> Array[StringName]:
	run.reroll_act = run.act
	return run.roll_rewards(db, guarantee_hero)


static func event_locked(profile: ProfileState, id: StringName) -> bool:
	return RUMOR_EVENTS.has(id) and not profile.upgrades.has(RUMORS)


static func relic_locked(run: RunState, id: StringName) -> bool:
	return LOST_RELIC_IDS.has(id) and not has(run, LOST_RELICS)
