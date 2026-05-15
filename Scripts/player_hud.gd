extends MarginContainer

@onready var health_label = $HBoxContainer/HealthLabel

var player = null
func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if player == null or not is_instance_valid(player):
		return
	health_label.text = str(player.hp) + " / " + str(player.max_hp)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
