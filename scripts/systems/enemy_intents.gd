class_name EnemyIntents
extends RefCounted
## Предполагаемые действия врагов (SPEC_SPRINT6 7): что сделал бы каждый враг, ходи он сейчас.
## Считается на копии боя — исходное состояние не меняется; командир на копии не действует.


## uid врага -> {"type": BattleAction.Type, "target": uid или -1, "hex": клетка или (-1, -1), "ability": id}.
static func predict(state: BattleState) -> Dictionary[int, Dictionary]:
	var result: Dictionary[int, Dictionary] = {}
	var copy := BattleState.from_dict(state.to_dict())
	copy.commander_id = &""
	copy.intent = {}
	for e in copy.alive(UnitState.Side.ENEMY):
		if e.inert:
			continue
		copy.active_uid = e.uid
		var a := AiController.choose_action(copy, e.uid)
		if a == null:
			continue
		var hex := a.dest
		if a.type == BattleAction.Type.MELEE or a.type == BattleAction.Type.SHOOT:
			hex = Vector2i(-1, -1)
		result[e.uid] = {"type": a.type, "target": a.target_uid, "hex": hex, "ability": a.ref_id}
	return result
