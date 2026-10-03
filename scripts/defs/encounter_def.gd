class_name EncounterDef
extends Resource
## Состав противника и арена для одного боя.

@export var id: StringName
@export var name_key: String
## Параллельные массивы: unit_ids[i] в количестве counts[i].
@export var unit_ids: Array[StringName] = []
@export var counts: Array[int] = []
@export var obstacles: Array[Vector2i] = []
## Уровень 1–3 для подбора на карте (SPEC_SPRINT3 6.1).
@export var tier: int = 1
@export var elite := false
## Бой с Хранителем Разлома: действует правило «Стирание».
@export var boss := false

# Цель боя (SPEC_SPRINT5 11): eliminate, survive, assassinate, hold, protect.
@export var objective: StringName = &"eliminate"
## survive/protect — продержаться до конца раунда N; hold — K раундов на точках.
@export var objective_rounds: int = 0
## assassinate — индекс цели в unit_ids.
@export var target_index: int = 0
## hold — клетки-знамёна.
@export var hold_hexes: Array[Vector2i] = []
## protect — клетка архива.
@export var archive_hex := Vector2i(2, 4)
## survive — подкрепления врага (параллельные массивы): существо, численность, раунд появления.
@export var reinforce_ids: Array[StringName] = []
@export var reinforce_counts: Array[int] = []
@export var reinforce_rounds: Array[int] = []
