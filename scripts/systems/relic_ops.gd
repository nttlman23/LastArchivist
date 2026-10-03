class_name RelicOps
extends RefCounted
## Реликвии (SPEC_SPRINT7 11): выбор на острове «Реликварий» и эффекты на забег.
## Цена одной частью сразу (ресурсы, прочность), другой — в каждом бою (характеристики).

const SALT_CROWN := &"salt_crown"            ## +1 защита отрядам; −1 прочности случайной карте сейчас
const HOURGLASS := &"drowned_hourglass"      ## +1 действие героя в первом раунде; −2 Эфира сейчас
const PEARL := &"memory_pearl"               ## +1 Пергамент за победу; ремонт вдвое дороже
const COMPASS := &"tide_compass"             ## течения не сносят ваши отряды; −1 инициатива отрядам
const INKWELL := &"kraken_inkwell"           ## заклинания сильнее на 25%; −2 Чернил сейчас
const SCALE := &"siren_scale"                ## +1 скорость отрядам; −10% ОЗ
const LANTERN := &"abyss_lantern"            ## враги «промокли» в первом раунде; −3 Пергамента сейчас
const SHELL := &"warden_shell"               ## +15% ОЗ отрядам; −1 атака

const OFFER := 2
const SPELL_POWER := 1.25
const SCALE_HP := 0.1
const SHELL_HP := 0.15
const LANTERN_ROUNDS := 2


## Две реликвии на выбор (по сиду острова), без уже полученных.
static func offer(db: DefsDB, run: RunState, node_id: int) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id in db.relic_ids():
		if not run.relics.has(id):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node_id, "reliquary")
	var result: Array[StringName] = []
	while result.size() < OFFER and not pool.is_empty():
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return result


## Взять реликвию: запомнить и заплатить разовую цену.
static func take(db: DefsDB, run: RunState, id: StringName, seed_value: int = 0) -> void:
	run.relics.append(id)
	match id:
		SALT_CROWN:
			if not run.codex.cards.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value
				var card := run.codex.cards[rng.randi_range(0, run.codex.cards.size() - 1)]
				card.durability = maxi(1, card.durability - 1)
		HOURGLASS:
			run.gain(RunState.AETHER, -2)
		INKWELL:
			run.gain(RunState.INK, -2)
		LANTERN:
			run.gain(RunState.PARCHMENT, -3)


## Эффекты реликвий в бою (после создания боя, до начала).
static func apply_battle(run: RunState, state: BattleState) -> void:
	if run.relics.is_empty():
		return
	for u in state.alive(UnitState.Side.PLAYER):
		if u.inert:
			continue
		if run.relics.has(SALT_CROWN):
			u.defense += 1
		if run.relics.has(COMPASS):
			u.initiative -= 1
		if run.relics.has(SCALE):
			u.speed += 1 if u.speed > 0 else 0
			_scale_hp(u, -SCALE_HP)
		if run.relics.has(SHELL):
			u.attack = maxi(0, u.attack - 1)
			_scale_hp(u, SHELL_HP)
	if run.relics.has(HOURGLASS):
		state.hero_first_round_bonus = 1
	if run.relics.has(COMPASS):
		state.player_ignores_currents = true
	if run.relics.has(INKWELL):
		for sp in state.hero_spells:
			sp["power"] = roundi(int(sp["power"]) * SPELL_POWER)
	if run.relics.has(LANTERN):
		for e in state.alive(UnitState.Side.ENEMY):
			e.statuses[UnitState.STATUS_SOAKED] = LANTERN_ROUNDS


## Пергамент за победу в бою (Жемчужина памяти).
static func battle_bonus(run: RunState) -> Dictionary[StringName, int]:
	var bonus: Dictionary[StringName, int] = {}
	if run.relics.has(PEARL):
		bonus[RunState.PARCHMENT] = 1
	return bonus


## Множитель цены ремонта в лавке.
static func repair_multiplier(run: RunState) -> int:
	return 2 if run != null and run.relics.has(PEARL) else 1


static func _scale_hp(u: UnitState, share: float) -> void:
	var delta := roundi(u.hp * share)
	u.hp = maxi(1, u.hp + delta)
	u.top_hp = clampi(u.top_hp + delta, 1, u.hp)
