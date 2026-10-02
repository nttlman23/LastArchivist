class_name BattleEvent
extends RefCounted
## Факт, произошедший в бою. Представление проигрывает события, но не меняет состояние.

const ROUND_STARTED := &"round_started"     # {round}
const TURN_STARTED := &"turn_started"       # {uid}
const MOVED := &"moved"                     # {uid, path: Array[Vector2i]}
const ATTACKED := &"attacked"               # {attacker, target, damage, killed, ranged, retaliation}
const DIED := &"died"                       # {uid}
const WAITED := &"waited"                   # {uid}
const DEFENDED := &"defended"               # {uid}
const BATTLE_ENDED := &"battle_ended"       # {outcome}

var type: StringName
var data: Dictionary


func _init(p_type: StringName = &"", p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func _to_string() -> String:
	return "%s %s" % [type, data]
