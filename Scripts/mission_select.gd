extends CanvasLayer

func _on_button_pressed() -> void:
	# Go back to the main menu with a fade
	_change_scene_with_fade("res://Scenes/main_menu.tscn")

func _on_balduin_chapter_pressed() -> void:
	# Go to Balduin's cutscene with a fade
	_change_scene_with_fade("res://Scenes/balduin_cutscene.tscn")

func _on_seraphina_chapter_pressed() -> void:
	# Future-proofed: Just drop the path here when ready!
	pass 

func _on_gold_hawk_chapter_pressed() -> void:
	# Future-proofed: Just drop the path here when ready!
	pass 

# ================= CUSTOM TRANSITION HELPER =================
# This function handles talking to GameScene so your buttons stay clean!
func _change_scene_with_fade(scene_path: String):
	var game_manager = get_tree().root.get_node_or_null("GameScene")
	
	if game_manager:
		# Dynamic loading based on the path string sent by the button
		var next_scene = load(scene_path).instantiate()
		game_manager.change_scene(next_scene)
	else:
		# Fallback method if you are testing this menu directly (F6)
		print("Warning: Running standalone mission select. Bypassing fade.")
		get_tree().change_scene_to_file(scene_path)
