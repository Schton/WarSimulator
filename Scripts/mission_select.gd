extends Control

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_balduin_chapter_pressed() -> void:
		get_tree().change_scene_to_file("res://Scenes/balduin_cutscene.tscn")

func _on_seraphina_chapter_pressed() -> void:
	pass # Replace with function body.

func _on_gold_hawk_chapter_pressed() -> void:
	pass # Replace with function body.
