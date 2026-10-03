class_name HeroActions
extends RefCounted
## Приказы и заклинания Архивариуса (SPEC_SPRINT2 3). Одно действие за раунд,
## в ход любого своего отряда; ход отряда не заканчивает.

const ADVANCE := &"order_advance"
const CLOSE_RANKS := &"order_close_ranks"
const ROYAL := &"order_royal"

const SALT_WALL := &"salt_wall"
const ASH_RECORD := &"ash_record"
const HUNGER := &"hunger"
const CHAIN_SPELL := &"chain_spell"
const RUST_ARMOR := &"rust_armor"
const SHARD_RAIN := &"shard_rain"
const ECHO_SPELL := &"echo_spell"
# Спринт 4, этап B.
const WHIRLPOOL := &"whirlpool"
const BARRIER := &"barrier_spell"
const MIRAGE := &"mirage"

const CHAIN_FACTORS: Array[float] = [0.5, 0.25]
const NO_HEX := Vector2i(-1, -1)


static func target_kind(id: StringName) -> Targeting.Kind:
	match id:
		ADVANCE, CLOSE_RANKS, ROYAL, HUNGER, RUST_ARMOR, MIRAGE:
			return Targeting.Kind.ALLY
		ASH_RECORD, CHAIN_SPELL:
			return Targeting.Kind.ENEMY
		SALT_WALL, SHARD_RAIN, WHIRLPOOL, BARRIER:
			return Targeting.Kind.HEX
	return Targeting.Kind.NONE


## Все допустимые применения приказа/заклинания — для подсветки целей и AI.
## slot < 0 — приказ id; иначе заклинание из state.hero_spells[slot].
static func options(state: BattleState, id: StringName, slot: int) -> Array[BattleAction]:
	var candidates: Array[BattleAction] = []
	match target_kind(id):
		Targeting.Kind.NONE:
			candidates.append(_make(id, slot, -1, NO_HEX))
		Targeting.Kind.ALLY:
			for u in state.alive(UnitState.Side.PLAYER):
				# Объект цели (архив) не ходит: приказы и миражи на него не действуют, лечить можно.
				if not u.inert or id == HUNGER or id == RUST_ARMOR:
					candidates.append(_make(id, slot, u.uid, NO_HEX))
		Targeting.Kind.ENEMY:
			for u in state.alive(UnitState.Side.ENEMY):
				candidates.append(_make(id, slot, u.uid, NO_HEX))
		Targeting.Kind.HEX:
			for h in state.grid.all_hexes():
				candidates.append(_make(id, slot, -1, h))
	var result: Array[BattleAction] = []
	for a in candidates:
		if validate(state, a):
			result.append(a)
	return result


static func validate(state: BattleState, action: BattleAction) -> bool:
	if not state.can_hero_act():
		return false
	var t := state.get_unit(action.target_uid)
	if action.slot < 0:
		if not state.hero_orders.has(action.ref_id):
			return false
		if not _is_side(t, UnitState.Side.PLAYER) or t.inert:
			return false
		if action.ref_id == ROYAL:
			return state.has_acted(t)
		return true

	if action.slot >= state.hero_spells.size():
		return false
	var sp := state.hero_spells[action.slot]
	if StringName(sp["spell_id"]) != action.ref_id or int(sp["charges"]) <= 0:
		return false
	match action.ref_id:
		ASH_RECORD, CHAIN_SPELL:
			return _is_side(t, UnitState.Side.ENEMY)
		HUNGER, RUST_ARMOR:
			return _is_side(t, UnitState.Side.PLAYER)
		SALT_WALL, BARRIER:
			if not state.is_free(action.dest):
				return false
			return action.dest2 == NO_HEX or (HexGrid.are_adjacent(action.dest, action.dest2) and state.is_free(action.dest2))
		SHARD_RAIN, WHIRLPOOL:
			return state.grid.in_bounds(action.dest)
		MIRAGE:
			return _is_side(t, UnitState.Side.PLAYER) and not t.illusion and not t.inert and Abilities.illusion_hex(state, t, t) != NO_HEX
		ECHO_SPELL:
			return true
	return false


static func apply(state: BattleState, action: BattleAction, events: Array[BattleEvent]) -> void:
	state.hero_actions_left -= 1
	var t := state.get_unit(action.target_uid)
	events.append(BattleEvent.new(BattleEvent.HERO_ACTED, {
		"action": action.ref_id, "spell": action.slot >= 0, "target": action.target_uid, "hex": action.dest,
	}))
	if action.slot < 0:
		match action.ref_id:
			ADVANCE:
				BattleResolver.add_status(t, UnitState.STATUS_ADVANCE, UnitState.PERMANENT, events)
			CLOSE_RANKS:
				BattleResolver.set_defending(t, events)
				for n in state.neighbors_of(t.hex):
					if n.side == t.side:
						BattleResolver.set_defending(n, events)
			ROYAL:
				# Стек ходит сразу после текущего.
				state.queue.push_front(t.uid)
		return

	var sp := state.hero_spells[action.slot]
	sp["charges"] = int(sp["charges"]) - 1
	var power := int(sp["power"])
	match action.ref_id:
		ASH_RECORD:
			BattleResolver.deal_damage(t, power, action.ref_id, events)
		CHAIN_SPELL:
			var prev := t.hex
			var hit: Array[int] = [t.uid]
			BattleResolver.deal_damage(t, power, action.ref_id, events)
			for f in CHAIN_FACTORS:
				var next := Abilities.chain_next(state, prev, hit)
				if next == null:
					break
				hit.append(next.uid)
				BattleResolver.deal_damage(next, maxi(1, floori(power * f)), action.ref_id, events)
				prev = next.hex
		HUNGER:
			BattleResolver.heal(t, power, events)
		RUST_ARMOR:
			t.defense += power
			BattleResolver.add_status(t, UnitState.STATUS_RUST_ARMOR, UnitState.PERMANENT, events)
		SALT_WALL, BARRIER:
			BattleResolver.add_temp_obstacle(state, action.dest, power, events)
			if action.dest2 != NO_HEX:
				BattleResolver.add_temp_obstacle(state, action.dest2, power, events)
		WHIRLPOOL:
			for h in Abilities.flood_area(state, action.dest):
				state.water[h] = power
			events.append(BattleEvent.new(BattleEvent.OBSTACLE_ADDED, {"hex": action.dest, "rounds": power, "water": true}))
		MIRAGE:
			Abilities.summon_illusion(state, t, Abilities.illusion_hex(state, t, t), power / 100.0, events)
		SHARD_RAIN:
			var victims: Array[UnitState] = state.neighbors_of(action.dest)
			var center := state.unit_at(action.dest)
			if center:
				victims.push_front(center)
			for v in victims:
				BattleResolver.deal_damage(v, power, action.ref_id, events)
		ECHO_SPELL:
			state.hero_actions_left += 1


## Вторая клетка «Соляной стены»: свободный сосед в сторону точки dir_hint (локальное направление курсора)
## или первый свободный сосед по часовой стрелке.
static func salt_wall_second(state: BattleState, hex: Vector2i, toward: Vector2 = Vector2.ZERO) -> Vector2i:
	var best := NO_HEX
	var best_dot := -INF
	var center := HexGrid.to_pixel(hex, 1.0)
	for n in state.grid.neighbors(hex):
		if not state.is_free(n):
			continue
		var dot := toward.dot((HexGrid.to_pixel(n, 1.0) - center).normalized()) if toward != Vector2.ZERO else 0.0
		if best == NO_HEX or dot > best_dot:
			best = n
			best_dot = dot
	return best


static func _make(id: StringName, slot: int, target: int, hex: Vector2i) -> BattleAction:
	if slot < 0:
		return BattleAction.order(id, target)
	return BattleAction.spell(slot, id, target, hex)


static func _is_side(u: UnitState, side: int) -> bool:
	return u != null and u.is_alive() and u.side == side
