class_name UpgradeNodeDef
extends Resource
## Узел дерева улучшений Зала Архива (SPEC_SPRINT8 2). Эффект — по id в MetaUpgrades.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
## Ветвь: supplies, knowledge, expedition.
@export var branch: StringName
## Позиция в ветви (1–5): узел открыт, если куплен предыдущий.
@export var tier: int = 1
@export var cost: int = 1
@export var icon: StringName
