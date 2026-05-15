extends Node

@onready var bgm_player = $BGMPlayer

var current_track_path = ""

func play_track(track_path: String):
	# Don't restart the song if it's already playing (e.g., map reloads)
	if current_track_path == track_path:
		return
	
	# Load the new song
	var stream = load(track_path)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()
		current_track_path = track_path
	else:
		print("Error: Could not load music at ", track_path)

func stop_music():
	bgm_player.stop()
	current_track_path = ""
