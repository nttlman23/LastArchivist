class_name UnitState
extends RefCounted
## Состояние стека в бою. Характеристики копируются из UnitDef,
## чтобы бой можно было симулировать и сериализовать без реестра.

enum Side { PLAYER = 0, ENEMY = 1 }

# Статусы: значение — оставшиеся раунды (уменьшается в начале раунда),
# PERMANENT — до снятия логикой (метка снимается атакой, рывок — концом хода).
const PERMANENT := -1
const STATUS_ADVANCE := &"advance"
const STATUS_MARKED := &"marked"
const STATUS_SHIELD_WALL := &"shield_wall"
const STATUS_RUST_ARMOR := &"rust_armor"
const STATUS_RIFT_MARKED := &"rift_marked"
const STATUS_ASH_FURY := &"ash_fury"
const ADVANCE_BONUS := 2

var uid: int
var def_id: StringName
var side: int
var hex: Vector2i
var count: int
## Численность в начале боя — потолок для воскрешения.
var start_count: int
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
var ability_id: StringName
## Раунды до готовности способности; 0 — готова.
var ability_cd := 0
## Хранитель Разлома: его гибель выигрывает бой.
var is_boss := false
## Стаки «Пепельной жертвы» (+атака за погибших союзников).
var fury := 0

var retaliated := false
var waited := false
var defending := false
var statuses: Dictionary[StringName, int] = {}


static func from_def(def: UnitDef, p_uid: int, p_side: int, p_count: int, p_hex: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.uid = p_uid
	u.def_id = def.id
	u.side = p_side
	u.hex = p_hex
	u.count = p_count
	u.start_count = p_count
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
	u.ability_id = def.ability_id
	return u


func is_alive() -> bool:
	return count > 0


func total_hp() -> int:
	if count <= 0:
		return 0
	return (count - 1) * hp + top_hp


## Скорость перемещения с учётом приказа «Вперёд!».
func move_speed() -> int:
	return speed + (ADVANCE_BONUS if has_status(STATUS_ADVANCE) else 0)


func has_status(id: StringName) -> bool:
	return statuses.has(id)


func ability_ready() -> bool:
	return ability_id != &"" and ability_cd <= 0


## Наносит урон стеку, возвращает число погибших существ.
func take_damage(amount: int) -> int:
	var before := count
	_set_total_hp(total_hp() - amount)
	return before - count


## Лечит стек, поднимая погибших не выше стартовой численности.
## Возвращает фактически восстановленные ОЗ.
func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before := total_hp()
	_set_total_hp(mini(before + amount, start_count * hp))
	return total_hp() - before


func can_shoot() -> bool:
	return is_ranged and shots_left > 0


func _set_total_hp(value: int) -> void:
	if value <= 0:
		count = 0
		top_hp = 0
		return
	count = ceili(float(value) / hp)
	top_hp = value - (count - 1) * hp


func to_dict() -> Dictionary:
	var st := {}
	for k in statuses:
		st[String(k)] = statuses[k]
	return {
		"uid": uid, "def_id": String(def_id), "side": side,
		"hex": [hex.x, hex.y], "count": count, "start_count": start_count, "top_hp": top_hp, "card_index": card_index,
		"hp": hp, "attack": attack, "defense": defense, "dmg_min": dmg_min, "dmg_max": dmg_max,
		"speed": speed, "initiative": initiative, "is_ranged": is_ranged, "is_flying": is_flying,
		"shots_left": shots_left, "ability_id": String(ability_id), "ability_cd": ability_cd, "is_boss": is_boss, "fury": fury,
		"retaliated": retaliated, "waited": waited, "defending": defending, "statuses": st,
	}


static func from_dict(d: Dictionary) -> UnitState:
	var u := UnitState.new()
	u.uid = int(d["uid"])
	u.def_id = StringName(d["def_id"])
	u.side = int(d["side"])
	var h: Array = d["hex"]
	u.hex = Vector2i(int(h[0]), int(h[1]))
	u.count = int(d["count"])
	u.start_count = int(d["start_count"])
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
	u.ability_id = StringName(d["ability_id"])
	u.ability_cd = int(d["ability_cd"])
	u.is_boss = bool(d.get("is_boss", false))
	u.fury = int(d.get("fury", 0))
	u.retaliated = bool(d["retaliated"])
	u.waited = bool(d["waited"])
	u.defending = bool(d["defending"])
	var st: Dictionary = d["statuses"]
	for k: String in st:
		u.statuses[StringName(k)] = int(st[k])
	return u
