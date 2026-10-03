class_name SchoolPassives
extends RefCounted
## Пассивки Архивариуса по школам (SPEC_SPRINT4 6–7). Применяются к событиям боя после каждого действия.

const ASH_SACRIFICE := &"ash_sacrifice"
const ASH_FURY_ATTACK := 1
const TIDE_CURRENT := &"tide_current"
const SYNOD_REPAIR := &"synod_repair"
const SYNOD_REPAIR_SHARE := 0.1
const GARDEN_MASKS := &"garden_masks"
const GARDEN_SHARE := 0.75


## Начало боя: «Маски» — иллюзия случайного стека игрока.
static func on_battle_start(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.passive_id != GARDEN_MASKS:
		return
	var mine := ObjectiveRule.fighters(state, UnitState.Side.PLAYER)
	if mine.is_empty():
		return
	var src := mine[state.rng.randi_range(0, mine.size() - 1)]
	var hex := Abilities.illusion_hex(state, src, src)
	if hex != Abilities.NO_HEX:
		Abilities.summon_illusion(state, src, hex, GARDEN_SHARE, events)


## Начало раунда: «Ремонт» — конструкты игрока восстанавливают 10% ОЗ стека (без воскрешения).
static func on_round_start(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.passive_id != SYNOD_REPAIR:
		return
	for u in state.alive(UnitState.Side.PLAYER):
		if u.construct:
			var healed := u.heal_no_revive(ceili(u.count * u.hp * SYNOD_REPAIR_SHARE))
			if healed > 0:
				events.append(BattleEvent.new(BattleEvent.HEALED, {"uid": u.uid, "amount": healed, "revived": 0}))


## Обработка событий только что применённого действия (гибель стеков и т.п.).
static func after_events(state: BattleState, events: Array[BattleEvent]) -> void:
	if state.passive_id == &"":
		return
	var added: Array[BattleEvent] = []
	for e in events:
		if e.type == BattleEvent.DIED:
			_on_died(state, state.get_unit(e.data["uid"]), added)
	events.append_array(added)


static func _on_died(state: BattleState, dead: UnitState, events: Array[BattleEvent]) -> void:
	if dead == null or dead.side != UnitState.Side.PLAYER:
		return
	match state.passive_id:
		ASH_SACRIFICE:
			# «Пепельная жертва»: гибель своего стека — +1 к атаке остальным до конца боя.
			for u in state.alive(UnitState.Side.PLAYER):
				u.attack += ASH_FURY_ATTACK
				u.fury += 1
				BattleResolver.add_status(u, UnitState.STATUS_ASH_FURY, UnitState.PERMANENT, events)
