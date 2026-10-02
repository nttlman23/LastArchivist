class_name EventOptionDef
extends Resource
## Вариант выбора в событии.

@export var label_key: String
@export var result_key: String
## Итог при неудаче рискованного варианта (chance < 1).
@export var fail_result_key: String
## Требование ресурса: resource ≥ amount.
@export var requires_resource: StringName
@export var requires_amount: int = 0
## Вариант применяется к выбранной игроком карте отряда.
@export var needs_card := false
## Нужно хотя бы одно заклинание.
@export var needs_spell := false
@export var chance: float = 1.0
## Массивы EventEffect (нетипизированные — проще писать .tres руками).
@export var effects: Array = []
@export var fail_effects: Array = []
