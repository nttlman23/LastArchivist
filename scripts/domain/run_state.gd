class_name RunState
extends RefCounted
## Состояние забега. Сохраняется на чекпоинтах — при возврате на карту экспедиции.

## Версия формата; более старые (от SaveMigrations.MIN_VERSION) переводятся миграциями.
const SAVE_VERSION := 9
const REWARD_CHOICES := 3
## Награда за элиту с «Широкой полкой» и после обычного боя на Испытании 7.
const REWARD_CHOICES_WIDE := 4
const REWARD_CHOICES_TRIAL := 2

const INK := &"ink"
const PARCHMENT := &"parchment"
const AETHER := &"aether"
const RESOURCE_IDS: Array[StringName] = [INK, PARCHMENT, AETHER]
const START_RESOURCES := {INK: 2, PARCHMENT: 3, AETHER: 2}

var run_seed: int
var codex := CodexState.new()
var hero := HeroState.new()
var loot_rng := RandomNumberGenerator.new()
var map := MapState.new()
var resources: Dictionary[StringName, int] = {}
## Остров, который сейчас проходится (-1 — на карте).
var pending_node := -1
## Бой, начатый событием: встреча и карта-награда за победу.
var pending_battle: StringName
var pending_reward_card: StringName
var battles_won := 0
var elites_won := 0
## Карт потеряно за забег (угасли или стёрты Разломом) — для «лучшего Кодекса».
var cards_lost := 0
var school_id := DefsDB.DEFAULT_SCHOOL
## Сложность забега (Difficulty).
var difficulty := Difficulty.NORMAL
## Акт (SPEC_SPRINT7): 1 — до Разлома, 2 — Затопленные хранилища.
var act := 1
## Разлом закрыт, ждёт выбор на привале (сохранение посреди привала возвращает на него).
var at_camp := false
## Дары-пассивки привала (CampOps.GIFTS).
var gifts: Array[StringName] = []
## Реликвии (SPEC_SPRINT7 11).
var relics: Array[StringName] = []
## Улучшения Зала Архива, действующие в забеге (копия из профиля при старте, SPEC_SPRINT8 2).
var upgrades: Array[StringName] = []
## Ступень Испытания (0 — без Испытания, SPEC_SPRINT8 3).
var trial := 0
## Акт, в котором уже использован переброс награды / бесплатная переработка (0 — нет).
var reroll_act := 0
var free_rework_act := 0
## Пул карт наград и лавки (с повторами для веса) и пул событий — фиксируются при старте забега.
var card_pool: Array[StringName] = []
var event_pool: Array[StringName] = []


## profile — открытия игрока (пулы карт и событий); без профиля доступно всё.
static func create(db: DefsDB, seed_value: int, school_id: StringName = DefsDB.DEFAULT_SCHOOL, profile: ProfileState = null,
		difficulty: StringName = Difficulty.NORMAL, trial: int = 0) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_value
	run.difficulty = difficulty
	run.trial = clampi(trial, 0, Trials.MAX) if Trials.allowed(difficulty) else 0
	if profile:
		run.upgrades = profile.upgrades.duplicate()
	run.loot_rng.seed = hash("loot:%d" % seed_value)
	run.school_id = school_id
	var school := db.school(school_id)
	for id in school.starting_codex:
		run.codex.add(db, id)
	for id in RESOURCE_IDS:
		run.resources[id] = Difficulty.start_resource(difficulty, START_RESOURCES[id])
		if Trials.has(run, Trials.START_RESOURCES):
			run.resources[id] = maxi(0, run.resources[id] - 1)
	MetaUpgrades.apply_start(db, run, school)
	if profile:
		run.card_pool = MetaRewards.card_pool(db, profile, school, 1)
		run.event_pool = MetaRewards.event_pool(db, profile)
	else:
		run.card_pool = db.pool_memory_ids(1)
		for id in school.favored_memories:
			run.card_pool.append(id)
		run.event_pool = db.event_ids()
	run.map = MapGenerator.generate(db, seed_value, run.event_pool)
	return run


## Слой забега сквозь акты: второй акт продолжает счёт после Разлома (слои 9–16).
func total_layer() -> int:
	return (act - 1) * (MapState.LAYERS + 1) + map.current_layer()


## Уникальные карты пула (для случайных карт событий и лавки).
func pool_unique() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in card_pool:
		if not result.has(id):
			result.append(id)
	return result


## Сид, общий для всего содержимого острова (бой, лавка, событие) — повторный вход даёт то же самое.
func node_seed(node_id: int, salt: String = "") -> int:
	return hash("node:%d:%d:%s" % [run_seed, node_id, salt])


func battle_seed() -> int:
	return node_seed(pending_node, "battle:" + String(pending_battle))


func pending() -> MapState.MapNode:
	return map.node(pending_node) if pending_node >= 0 else null


func current_encounter_id(_db: DefsDB) -> StringName:
	if pending_battle != &"":
		return pending_battle
	return pending().content


func is_boss_battle(db: DefsDB) -> bool:
	return db.encounter(current_encounter_id(db)).boss


func can_afford(id: StringName, amount: int) -> bool:
	return resources.get(id, 0) >= amount


func spend(id: StringName, amount: int) -> bool:
	if not can_afford(id, amount):
		return false
	resources[id] -= amount
	return true


func gain(id: StringName, amount: int) -> void:
	resources[id] = maxi(0, resources.get(id, 0) + amount)


## После боя: стёртые разломом карты исчезают (даже при победе), участники и геройские карты угасают.
## Возвращает id угасших и стёртых карт.
func after_battle(db: DefsDB, selected: Array[int], erased: Array[int] = []) -> Array[StringName]:
	var to_decay: Array[CodexState.Card] = []
	var to_erase: Array[CodexState.Card] = []
	for i in selected:
		(to_erase if erased.has(i) else to_decay).append(codex.cards[i])
	for i in codex.hero_indices(db):
		to_decay.append(codex.cards[i])
	var gone: Array[StringName] = []
	for card in to_erase:
		gone.append(card.memory_id)
		codex.cards.erase(card)
	var indices: Array[int] = []
	for card in to_decay:
		indices.append(codex.cards.find(card))
	gone.append_array(codex.decay(indices))
	cards_lost += gone.size()
	return gone


## Переносит остаток зарядов из боя; пустые заклинания исчезают.
func apply_spell_charges(charges: Array[int]) -> void:
	for i in mini(charges.size(), hero.spells.size()):
		hero.spells[i].charges = charges[i]
	var kept: Array[HeroState.SpellSlot] = []
	kept.assign(hero.spells.filter(func(s: HeroState.SpellSlot) -> bool: return s.charges > 0))
	hero.spells = kept


## Новая карта в Кодекс во время забега (награда, лавка, событие, дар): прочность с учётом Испытания 9.
func gain_card(db: DefsDB, memory_id: StringName) -> CodexState.Card:
	var card := codex.add(db, memory_id)
	if Trials.has(self, Trials.DURABILITY):
		card.durability = maxi(1, card.durability - 1)
	return card


## Сколько карт в награде: элита (guarantee_hero) с «Широкой полкой» — 4, обычный бой на Испытании 7 — 2.
func reward_choices(guarantee_hero: bool) -> int:
	if guarantee_hero:
		return REWARD_CHOICES_WIDE if MetaUpgrades.has(self, MetaUpgrades.WIDE_SHELF) else REWARD_CHOICES
	return REWARD_CHOICES_TRIAL if Trials.has(self, Trials.REWARDS) else REWARD_CHOICES


## Случайные карты для награды (могут повторяться между боями, но не внутри выбора).
## guarantee_hero — награда за элиту: среди карт будет геройская, если её ещё нет в Кодексе.
func roll_rewards(db: DefsDB, guarantee_hero: bool = false) -> Array[StringName]:
	var choices := reward_choices(guarantee_hero)
	var pool: Array[StringName] = card_pool.duplicate()
	var result: Array[StringName] = []
	if guarantee_hero:
		for id in pool.duplicate():
			if not db.memory(id).is_unit() and not _has_card(id):
				result.append(id)
				pool.erase(id)
				break
	# Повторы в пуле дают вес, но в одном предложении карта не повторяется.
	while result.size() < choices and not pool.is_empty():
		var idx := loot_rng.randi_range(0, pool.size() - 1)
		var id: StringName = pool[idx]
		result.append(id)
		while pool.has(id):
			pool.erase(id)
	return result


func _has_card(memory_id: StringName) -> bool:
	return codex.cards.any(func(c: CodexState.Card) -> bool: return c.memory_id == memory_id)


func to_dict() -> Dictionary:
	var res := {}
	for id in resources:
		res[String(id)] = resources[id]
	return {
		"version": SAVE_VERSION,
		"run_seed": str(run_seed),
		"codex": codex.to_array(),
		"hero": hero.to_dict(),
		"loot_rng_seed": str(loot_rng.seed),
		"loot_rng_state": str(loot_rng.state),
		"map": map.to_dict(),
		"resources": res,
		"pending_node": pending_node,
		"pending_battle": String(pending_battle),
		"pending_reward_card": String(pending_reward_card),
		"battles_won": battles_won,
		"elites_won": elites_won,
		"cards_lost": cards_lost,
		"school_id": String(school_id),
		"difficulty": String(difficulty),
		"act": act,
		"at_camp": at_camp,
		"gifts": Array(gifts).map(func(x: StringName) -> String: return String(x)),
		"relics": Array(relics).map(func(x: StringName) -> String: return String(x)),
		"card_pool": Array(card_pool).map(func(x: StringName) -> String: return String(x)),
		"event_pool": Array(event_pool).map(func(x: StringName) -> String: return String(x)),
		"upgrades": Array(upgrades).map(func(x: StringName) -> String: return String(x)),
		"trial": trial,
		"reroll_act": reroll_act,
		"free_rework_act": free_rework_act,
	}


## Поля, без которых сохранение не читается.
const REQUIRED_KEYS: Array[String] = ["run_seed", "codex", "hero", "loot_rng_seed", "loot_rng_state", "map", "resources",
		"pending_node", "pending_battle", "pending_reward_card", "battles_won", "elites_won", "cards_lost",
		"school_id", "difficulty", "act", "at_camp", "gifts", "relics", "card_pool", "event_pool", "upgrades", "trial", "reroll_act", "free_rework_act"]


static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("version", 0)) != SAVE_VERSION or not d.has_all(REQUIRED_KEYS):
		return null
	var run := RunState.new()
	run.run_seed = String(d["run_seed"]).to_int()
	run.codex = CodexState.from_array(d["codex"])
	run.hero = HeroState.from_dict(d["hero"])
	run.loot_rng.seed = String(d["loot_rng_seed"]).to_int()
	run.loot_rng.state = String(d["loot_rng_state"]).to_int()
	run.map = MapState.from_dict(d["map"])
	var res: Dictionary = d["resources"]
	for id: String in res:
		run.resources[StringName(id)] = int(res[id])
	run.pending_node = int(d["pending_node"])
	run.pending_battle = StringName(d["pending_battle"])
	run.pending_reward_card = StringName(d["pending_reward_card"])
	run.battles_won = int(d["battles_won"])
	run.elites_won = int(d["elites_won"])
	run.cards_lost = int(d["cards_lost"])
	run.school_id = StringName(d["school_id"])
	run.difficulty = StringName(d["difficulty"])
	run.act = int(d["act"])
	run.at_camp = bool(d["at_camp"])
	for g: String in d["gifts"]:
		run.gifts.append(StringName(g))
	for r: String in d["relics"]:
		run.relics.append(StringName(r))
	for id: String in d["card_pool"]:
		run.card_pool.append(StringName(id))
	for id: String in d["event_pool"]:
		run.event_pool.append(StringName(id))
	for id: String in d["upgrades"]:
		run.upgrades.append(StringName(id))
	run.trial = int(d["trial"])
	run.reroll_act = int(d["reroll_act"])
	run.free_rework_act = int(d["free_rework_act"])
	return run
