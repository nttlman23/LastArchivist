class_name UnitState
extends RefCounted
## Состояние стека в бою. Характеристики копируются из UnitDef,
## чтобы бой можно было симулировать и сериализовать без реестра.

enum Side { PLAYER = 0, ENEMY = 1 }

var uid: int
var def_id: StringName
var side: int
var hex: Vector2i
var count: int
var top_hp: int
## Индекс карты в Кодексе (только для стеков игрока), иначе -1.
var card_index := -1

var hp: int
var attack: int
var defense: int
var dmg_min: int
var dmg_max: int
var speed: int
var initiative: int
var is_ranged := false
var is_flying := false
var shots_left := 0

var retaliated := false
var waited := false
var defending := false


static func from_def(def: UnitDef, p_uid: int, p_side: int, p_count: int, p_hex: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.uid = p_uid
	u.def_id = def.id
	u.side = p_side
	u.hex = p_hex
	u.count = p_count
	u.hp = def.hp
	u.top_hp = def.hp
	u.attack = def.attack
	u.defense = def.defense
	u.dmg_min = def.dmg_min
	u.dmg_max = def.dmg_max
	u.speed = def.speed
	u.initiative = def.initiative
	u.is_ranged = def.is_ranged
	u.is_flying = def.is_flying
	u.shots_left = def.shots
	return u


func is_alive() -> bool:
	return count > 0


func total_hp() -> int:
	if count <= 0:
		return 0
	return (count - 1) * hp + top_hp


## Наносит урон стеку, возвращает число погибших существ.
func take_damage(amount: int) -> int:
	var remaining := total_hp() - amount
	var before := count
	if remaining <= 0:
		count = 0
		top_hp = 0
		return before
	count = ceili(float(remaining) / hp)
	top_hp = remaining - (count - 1) * hp
	return before - count


func can_shoot() -> bool:
	return is_ranged and shots_left > 0


func to_dict() -> Dictionary:
	return {
		"uid": uid, "def_id": String(def_id), "side": side,
		"hex": [hex.x, hex.y], "count": count, "top_hp": top_hp, "card_index": card_index,
		"hp": hp, "attack": attack, "defense": defense, "dmg_min": dmg_min, "dmg_max": dmg_max,
		"speed": speed, "initiative": initiative, "is_ranged": is_ranged, "is_flying": is_flying,
		"shots_left": shots_left, "retaliated": retaliated, "waited": waited, "defending": defending,
	}


static func from_dict(d: Dictionary) -> UnitState:
	var u := UnitState.new()
	u.uid = int(d["uid"])
	u.def_id = StringName(d["def_id"])
	u.side = int(d["side"])
	var h: Array = d["hex"]
	u.hex = Vector2i(int(h[0]), int(h[1]))
	u.count = int(d["count"])
	u.top_hp = int(d["top_hp"])
	u.card_index = int(d["card_index"])
	u.hp = int(d["hp"])
	u.attack = int(d["attack"])
	u.defense = int(d["defense"])
	u.dmg_min = int(d["dmg_min"])
	u.dmg_max = int(d["dmg_max"])
	u.speed = int(d["speed"])
	u.initiative = int(d["initiative"])
	u.is_ranged = bool(d["is_ranged"])
	u.is_flying = bool(d["is_flying"])
	u.shots_left = int(d["shots_left"])
	u.retaliated = bool(d["retaliated"])
	u.waited = bool(d["waited"])
	u.defending = bool(d["defending"])
	return u
