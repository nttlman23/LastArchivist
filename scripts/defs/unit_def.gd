class_name UnitDef
extends Resource
## Неизменяемое описание типа существа.

@export var id: StringName
@export var name_key: String
@export var hp: int = 10
@export var attack: int = 1
@export var defense: int = 1
@export var dmg_min: int = 1
@export var dmg_max: int = 1
@export var speed: int = 3
@export var initiative: int = 5
@export var is_ranged := false
@export var shots: int = 0
@export var is_flying := false
@export var ability_id: StringName
## Конструкт Машинного Синода (пассивка «Ремонт»).
@export var construct := false
## Неживой объект цели боя (архив): не ходит, не отвечает, не считается бойцом.
@export var inert := false
@export var color := Color.WHITE
## Размер фигуры на поле (SPEC_SPRINT9 2): normal или large (крупные существа и боссы).
@export var size_class: StringName = &"normal"
## Класс звука удара (SPEC_SPRINT9 12): metal, claw, magic, shard, heavy; пусто — общий звук ближнего боя или выстрела.
@export var sound_class: StringName
