class_name SchoolDef
extends Resource
## Школа памяти (SPEC_SPRINT4 6): стиль Кодекса — старт, пассивка Архивариуса, любимые карты.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var color := Color.WHITE
@export var starting_codex: Array[StringName] = []
@export var passive_id: StringName
## В наградах и лавке этой школы — вес ×2.
@export var favored_memories: Array[StringName] = []
## Карты существ школы: попадают в общий пул наград, когда школа открыта.
@export var own_memories: Array[StringName] = []
## Цена открытия в очках памяти (0 — открыта с начала).
@export var unlock_cost: int = 0
## Школа реализована (этап B добавляет новые школы).
@export var implemented := true
@export var order: int = 0
