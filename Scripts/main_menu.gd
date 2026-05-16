extends Control

func _ready():
	MusicManager.play_menu_music()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_cutscene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
