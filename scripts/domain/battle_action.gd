class_name BattleAction
extends RefCounted
## Команда активного стека. Применяется только через BattleResolver.

enum Type { MOVE, MELEE, SHOOT, WAIT, DEFEND }

var type: Type
## MOVE: куда идти. MELEE: клетка, с которой наносится удар.
var dest := Vector2i.ZERO
## MELEE/SHOOT: uid цели.
var target_uid := -1


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


static func wait() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.WAIT
	return a


static func defend() -> BattleAction:
	var a := BattleAction.new()
	a.type = Type.DEFEND
	return a


func _to_string() -> String:
	return "%s(dest=%s, target=%d)" % [Type.keys()[type], dest, target_uid]
