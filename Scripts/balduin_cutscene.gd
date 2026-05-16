extends CanvasLayer

@export var slides: Array[Texture2D]
var current_slide := 0
@onready var image = $TextureRect

func _ready():
	show_slide()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		next_slide() 

func show_slide():
	if current_slide >= slides.size():
		end_cutscene()
		return
		
	image.texture = slides[current_slide]

func next_slide():
	current_slide += 1
	show_slide()

func end_cutscene():
	# 1. Look up the tree for your master manager
	var game_manager = get_tree().root.get_node_or_null("GameScene")
	
	if game_manager:
		# 2. Load and INSTANTIATE your Map 1 scene
		var map_1 = load("res://Scenes/World/map_1.tscn").instantiate()
		
		# 3. Hand it off to GameScene to fade out the cutscene and fade in the map
		game_manager.change_scene(map_1)
	else:
		# Fallback method if you are testing this cutscene directly (F6)
		print("Warning: Running standalone cutscene. Bypassing fade.")
		get_tree().change_scene_to_file("res://Scenes/World/map_1.tscn")
