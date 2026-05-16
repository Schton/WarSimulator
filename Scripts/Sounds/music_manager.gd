extends Node

@onready var bgm_player = $BGMPlayer

# Your map playlist
var playlist: Array[String] = [
	"res://Assets/Sounds/Before_the_First_Strike.mp3",
	"res://Assets/Sounds/Vanguard_at_the_Iron_Keep.mp3"
]

var current_index: int = 0
var is_playlist_running: bool = false
var current_track_path: String = ""

func _ready():
	bgm_player.finished.connect(_on_track_finished)

# --- NEW: Call this in your Main Menu scene script ---
func play_menu_music():
	is_playlist_running = false # Turns off map playlist logic
	_play_track("res://Assets/Sounds/Vigil_at_the_Gate.mp3") # <-- Update your path

# --- NEW: Call this in your Loading Screen scene script ---
func play_loading_music():
	is_playlist_running = false # Turns off map playlist logic
	_play_track("") # <-- Update your path

# --- Existing Map Playlist Logic ---
func start_playlist():
	if is_playlist_running:
		return
	is_playlist_running = true
	_play_current_track()

func _play_current_track():
	if playlist.is_empty():
		return
	_play_track(playlist[current_index])

# Helper function to handle loading and playing
func _play_track(track_path: String):
	# Don't interrupt the song if it's already playing
	if current_track_path == track_path and bgm_player.is_playing():
		return
		
	var stream = load(track_path)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()
		current_track_path = track_path
		print("MusicManager playing: ", track_path)
	else:
		print("Error loading track: ", track_path)

func _on_track_finished():
	# CRITICAL: If the playlist is turned off, stop running this sequence!
	if not is_playlist_running:
		return
		
	print("Playlist song ended. Waiting 10 seconds...")
	current_index = (current_index + 1) % playlist.size()
	
	# Wait for 10 seconds
	await get_tree().create_timer(10.0).timeout
	
	# Double check flag in case player clicked "Start Game" during the 10 second delay
	if is_playlist_running:
		_play_current_track()
