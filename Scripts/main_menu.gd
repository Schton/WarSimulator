extends CanvasLayer

func _ready():
	MusicManager.play_menu_music()

func _on_start_pressed() -> void:
	var game_manager = get_tree().root.get_node_or_null("GameScene") 
	
	if game_manager:
		# Access the constant or variable on your GameScene node
		var loading_instance = game_manager.LOADING_SCREEN.instantiate()
		game_manager.change_scene(loading_instance)
	else:
		# Fallback if you are testing this scene by itself (F6)
		print("Running standalone menu. Falling back to global scene change.")
		get_tree().change_scene_to_file("res://Scenes/main_cutscene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
