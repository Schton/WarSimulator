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
		# 2. Load and INSTANTIATE the mission select scene
		var mission_select = load("res://Scenes/mission_select.tscn").instantiate()
		
		# 3. Tell GameScene to handle the transition with a fade!
		game_manager.change_scene(mission_select)
	else:
		# Fallback if you are testing the cutscene scene by itself (F6)
		print("Warning: Running standalone cutscene. Bypassing fade.")
		get_tree().change_scene_to_file("res://Scenes/mission_select.tscn")
