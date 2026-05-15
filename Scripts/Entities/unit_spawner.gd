extends Node2D

@export var zone_color := Color(1, 0, 0, 0.1) # Faint red
@export var border_color := Color(1, 0, 0, 0.3) # Slightly darker red for the edge

@export_group("Spawn Settings")
@export var spawn_entries: Array[SpawnEntry] = []
@export var spawn_delay := 3.0      # Seconds between spawns
@export var spawn_range := 100.0    # Random radius around spawner

@export_group("Capture Settings")
@export var kills_required := 10
@export var capture_radius := 1000.0
var current_kills := 0
var is_captured := false

@export_group("Unit Configuration")
@export var faction_to_assign: int = 1 # 0 for Player/Ally, 1 for Enemy
@export var make_ally := false

var living_units := {}
@onready var spawn_timer = $Timer
@onready var capture_zone = $CaptureZone

func _ready():
	$CaptureZone/CollisionShape2D.shape.radius = capture_radius
	update_spawner_color()
	if not make_ally:
		add_to_group("enemy_spawners")

	spawn_timer.wait_time = spawn_delay
	spawn_timer.start()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	for entry in spawn_entries:
		living_units[entry] = []

func _on_spawn_timer_timeout():
	if is_captured: return # Stop spawning if captured

	for entry in spawn_entries:
		# Cleanup dead units
		living_units[entry] = living_units[entry].filter(
			func(unit): return is_instance_valid(unit)
		)
		# Spawn only if below max for THIS type
		if living_units[entry].size() < entry.max_alive:
			spawn_unit(entry)

func spawn_unit(entry: SpawnEntry):
	if entry.unit_scene == null:
		print("Spawner Warning: No unit scene assigned!")
		return

	var unit = entry.unit_scene.instantiate()
	get_parent().add_child(unit)

	var random_offset = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * randf_range(0, spawn_range)

	unit.global_position = global_position + random_offset

	# Apply faction settings
	if "faction" in unit:
		unit.faction = entry.faction
	if "is_ally" in unit:
		unit.is_ally = entry.make_ally

	unit.unit_died.connect(_on_unit_death)
	living_units[entry].append(unit)

func _on_unit_death(death_pos: Vector2):
	if is_captured: return
	
	# Check if the death happened inside our large capture zone
	var dist = global_position.distance_to(death_pos)
	if dist <= capture_radius:
		current_kills += 1
		print("Kill registered in zone! ", current_kills, "/", kills_required)
		
		if current_kills >= kills_required:
			capture_zone_complete()

func capture_zone_complete():
	remove_from_group("enemy_spawners")
	var manager = get_tree().get_first_node_in_group("level_manager")
	if manager:
		manager.check_victory()

	is_captured = true
	spawn_timer.stop()
	print("ZONE CAPTURED! Spawner deactivated.")
	# Optional: Change visual color of the spawner or play a sound
	modulate = Color.GREEN

func _draw():
	if Engine.is_editor_hint() or OS.is_debug_build():
		draw_circle(Vector2.ZERO, spawn_range, Color(1, 0, 0, 0.2)) # Light red circle

	draw_circle(Vector2.ZERO, capture_radius, zone_color)
	draw_arc(Vector2.ZERO, capture_radius, 0, TAU, 100, border_color, 2.0)

func update_spawner_color():
	var has_allies = false

	for entry in spawn_entries:
		if entry.make_ally:
			has_allies = true
			break

	if has_allies:
		zone_color = Color(0, 1, 0, 0.1)
		border_color = Color(0, 1, 0, 0.4)
	else:
		zone_color = Color(1, 0, 0, 0.1)
		border_color = Color(1, 0, 0, 0.4)

	queue_redraw()
