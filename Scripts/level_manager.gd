extends Node

func _ready():
	add_to_group("level_manager")

func check_victory():

	var enemies_alive = get_tree().get_nodes_in_group("enemy_units").size()

	var active_spawners = get_tree().get_nodes_in_group("enemy_spawners").size()

	print("Enemies:", enemies_alive)
	print("Spawners:", active_spawners)

	if enemies_alive == 0 and active_spawners == 0:
		victory()

func victory():
	get_tree().change_scene_to_file("res://Scenes/victory_screen.tscn")

	# Future:
	# show victory UI
	# stop enemy AI
	# load next level
	# reward player
