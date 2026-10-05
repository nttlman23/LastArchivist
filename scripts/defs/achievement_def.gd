class_name AchievementDef
extends Resource
## Достижение (SPEC_SPRINT9 6): условие-ключ с порогом и награда — очки памяти или открытие.
## Условия проверяет Achievements по ключу.

@export var id: StringName
## Порядок на экране «Достижения».
@export var order: int = 0
@export var name_key: String
## Условие — текст подсказки.
@export var desc_key: String
@export var icon: StringName = &"points"
@export var color := Color(0.95, 0.8, 0.4)
## Ключ условия (Achievements.COND_*) и порог, если условие числовое.
@export var condition: StringName
@export var threshold: int = 0
## Награда: очки памяти или открытие (unlock_kind — card / relic / event, unlock_id — id карты, реликвии, события).
@export var points: int = 0
@export var unlock_kind: StringName
@export var unlock_id: StringName
