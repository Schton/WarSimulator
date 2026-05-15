extends Resource
class_name SpawnEntry

@export var unit_scene: PackedScene
@export var max_alive := 3

@export_group("Faction")
@export var faction := 1
@export var make_ally := false
