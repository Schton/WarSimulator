extends Control

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
	get_tree().change_scene_to_file("res://Scenes/World/map_1.tscn")
