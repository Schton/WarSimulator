extends Node

@onready var current_scene_container = $CurrentScene
@onready var anim_player = $ScreenFade/AnimationPlayer

# Preload your core scenes for fast access
const MAIN_MENU = preload("res://Scenes/main_menu.tscn")
const LOADING_SCREEN = preload("res://Scenes/main_cutscene.tscn")

# Store paths to your maps so you can load them dynamically
var maps: Dictionary = {
	"map1": "res://Scenes/World/map_1.tscn",
	"map2": "res://Scenes/World/map_2.tscn",
	"map3": "res://Scenes/World/map_3.tscn"
}

func _ready():
	# Start the game by loading the main menu
	$ScreenFade/ColorRect.modulate.a = 0.0
	change_scene(MAIN_MENU.instantiate())

func change_scene(new_scene: Node):
	# 1. Fade out to black
	print("Triggering transition...")
	anim_player.play("fade_to_black")
	
	# Wait here until the half-second fade animation finishes!
	await anim_player.animation_finished
	
	# 2. Clean up the old scene (Done in total darkness)
	for child in current_scene_container.get_children():
		child.queue_free()
	 
	# 3. Add the new scene
	current_scene_container.add_child(new_scene)
	
	# 4. Fade back in to reveal the new map/menu
	anim_player.play("fade_to_normal")
