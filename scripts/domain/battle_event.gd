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
const ABILITY_USED := &"ability_used"       # {uid, ability, target, hex}
const HERO_ACTED := &"hero_acted"           # {action: id, spell: bool, target, hex}
const HEALED := &"healed"                   # {uid, amount, revived}
const PUSHED := &"pushed"                   # {uid, from, to}
const OBSTACLE_ADDED := &"obstacle_added"   # {hex, rounds}
const OBSTACLE_EXPIRED := &"obstacle_expired"  # {hex}
const STATUS_CHANGED := &"status_changed"   # {uid, status, on}
const RIFT_MARKED := &"rift_marked"         # {uid} — будет стёрт в начале следующего раунда
const ERASED := &"erased"                   # {uid} — стёрт разломом
const DAMAGED := &"damaged"                 # {uid, damage, killed, source} — урон без атаки (заклинания, рикошеты)

var type: StringName
var data: Dictionary


func _init(p_type: StringName = &"", p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func _to_string() -> String:
	return "%s %s" % [type, data]
