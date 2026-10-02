class_name SchoolPassives
extends RefCounted
## Пассивки Архивариуса по школам (SPEC_SPRINT4 6–7). Применяются к событиям боя после каждого действия.

const ASH_SACRIFICE := &"ash_sacrifice"
const ASH_FURY_ATTACK := 1


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
