class_name CommanderDef
extends Resource
## Вражеский командир (SPEC_SPRINT5 10): вне поля, одно действие за раунд из своего набора.

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var color := Color.WHITE
## Действия из CommanderActions.
@export var actions: Array[StringName] = []
## Заряды каждого действия на бой.
@export var charges: int = 2
