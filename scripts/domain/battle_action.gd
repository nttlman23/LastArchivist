class_name BattleAction
extends RefCounted
## Команда активного стека. Применяется только через BattleResolver.

enum Type { MOVE, MELEE, SHOOT, WAIT, DEFEND, ABILITY, HERO }

var type: Type
## MOVE: куда идти. MELEE: клетка, с которой наносится удар.
var dest := Vector2i.ZERO
## MELEE/SHOOT/ABILITY/HERO: uid цели.
var target_uid := -1
## ABILITY: id способности отряда (у Хора — echo, копия берётся из BattleState.last_ability);
## HERO: id приказа или заклинания.
var ref_id: StringName
## HERO: индекс заклинания в BattleState.hero_spells; -1 — приказ.
var slot := -1
## Вторая клетка «Соляной стены»; (-1, -1) — нет.
var dest2 := Vector2i(-1, -1)


static func move(to: Vector2i) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.MOVE
	a.dest = to
	return a


static func melee(from_hex: Vector2i, target: int) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.MELEE
	a.dest = from_hex
	a.target_uid = target
	return a


static func shoot(target: int) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.SHOOT
	a.target_uid = target
	return a


static func ability(id: StringName, target: int = -1, hex: Vector2i = Vector2i(-1, -1)) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.ABILITY
	a.ref_id = id
	a.target_uid = target
	a.dest = hex
	return a


static func order(id: StringName, target: int) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.HERO
	a.ref_id = id
	a.target_uid = target
	return a


static func spell(slot_index: int, id: StringName, target: int = -1, hex: Vector2i = Vector2i(-1, -1), hex2: Vector2i = Vector2i(-1, -1)) -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.HERO
	a.ref_id = id
	a.slot = slot_index
	a.target_uid = target
	a.dest = hex
	a.dest2 = hex2
	return a


func is_hero() -> bool:
	return type == Type.HERO


static func wait() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.WAIT
	return a


static func defend() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.DEFEND
	return a


func _to_string() -> String:
	return "%s(%s dest=%s target=%d slot=%d)" % [Type.keys()[type], ref_id, dest, target_uid, slot]
