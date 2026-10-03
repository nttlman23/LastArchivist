class_name CommanderActions
extends RefCounted
## Действия вражеского командира (SPEC_SPRINT5 10). Командир объявляет намерение в начале
## раунда и выполняет его в конце раунда — у игрока всегда есть ход, чтобы ответить.

const BOLT := &"cmd_bolt"
const CURSE := &"cmd_curse"
const HEAL := &"cmd_heal"
const WALL := &"cmd_wall"
const GUARD := &"cmd_guard"
const HASTE := &"cmd_haste"
const FURY := &"cmd_fury"

const BOLT_DAMAGE := 25
const HEAL_AMOUNT := 30
const WALL_ROUNDS := 2
const GUARD_ROUNDS := 2
const FURY_ATTACK := 2

const NO_HEX := Vector2i(-1, -1)

## Значки намерения (для HUD и поля).
const ICONS := {
	BOLT: UnitGlyphs.ICON_SPELL,
	CURSE: UnitGlyphs.ICON_MARK,
	HEAL: UnitGlyphs.ICON_HEAL,
	WALL: UnitGlyphs.ICON_DEFEND,
	GUARD: UnitGlyphs.ICON_RETALIATION,
	HASTE: UnitGlyphs.ICON_SPEED,
	FURY: UnitGlyphs.ICON_MELEE,
}


## Цель действия: стек игрока (true), стек врага (false) или клетка.
static func targets_player(id: StringName) -> bool:
	return id == BOLT or id == CURSE


static func targets_hex(id: StringName) -> bool:
	return id == WALL


## Допустимо ли намерение сейчас.
static func valid(state: BattleState, intent: Dictionary) -> bool:
	if intent.is_empty():
		return false
	var id := StringName(intent["action"])
	if int(state.commander_charges.get(id, 0)) <= 0:
		return false
	if targets_hex(id):
		var h: Vector2i = intent["hex"]
		return state.is_free(h)
	var t := state.get_unit(int(intent["target"]))
	if t == null or not t.is_alive() or t.inert:
		return false
	var side := UnitState.Side.PLAYER if targets_player(id) else UnitState.Side.ENEMY
	return t.side == side


static func apply(state: BattleState, intent: Dictionary, events: Array[BattleEvent]) -> void:
	var id := StringName(intent["action"])
	state.commander_charges[id] = int(state.commander_charges[id]) - 1
	var t := state.get_unit(int(intent.get("target", -1)))
	events.append(BattleEvent.new(BattleEvent.COMMANDER_ACTED, {"action": id, "target": t.uid if t else -1, "hex": intent.get("hex", NO_HEX)}))
	match id:
		BOLT:
			BattleResolver.deal_damage(t, BOLT_DAMAGE, id, events)
		CURSE:
			BattleResolver.add_status(t, UnitState.STATUS_MARKED, UnitState.PERMANENT, events)
		HEAL:
			BattleResolver.heal(t, HEAL_AMOUNT, events)
		WALL:
			BattleResolver.add_temp_obstacle(state, intent["hex"], WALL_ROUNDS, events)
		GUARD:
			BattleResolver.set_defending(t, events)
			BattleResolver.add_status(t, UnitState.STATUS_SHIELD_WALL, GUARD_ROUNDS, events)
		HASTE:
			BattleResolver.add_status(t, UnitState.STATUS_ADVANCE, UnitState.PERMANENT, events)
		FURY:
			t.attack += FURY_ATTACK
			t.fury += FURY_ATTACK
			events.append(BattleEvent.new(BattleEvent.STATUS_CHANGED, {"uid": t.uid, "status": UnitState.STATUS_ASH_FURY, "on": true}))
