extends Node2D

@export var zone_color := Color(1, 0, 0, 0.1) # Faint red
@export var border_color := Color(1, 0, 0, 0.3) # Slightly darker red for the edge

@export_group("Spawn Settings")
@export var unit_scene: PackedScene # Drag Enemy.tscn or Ally.tscn here
@export var max_units := 5           # Max units this spawner can have alive
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

var living_units: Array[Node2D] = []
@onready var spawn_timer = $Timer
@onready var capture_zone = $CaptureZone

func _ready():
	$CaptureZone/CollisionShape2D.shape.radius = capture_radius

	spawn_timer.wait_time = spawn_delay
	spawn_timer.start()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout():
	if is_captured: return # Stop spawning if captured

	# Clean up the list: remove units that were killed (freed)
	living_units = living_units.filter(func(unit): return is_instance_valid(unit))

	if living_units.size() < max_units:
		spawn_unit()

func spawn_unit():
	if unit_scene == null:
		print("Spawner Warning: No unit scene assigned!")
		return

	# 1. Create the instance
	var unit = unit_scene.instantiate()

	# 2. Add it to the world BEFORE setting position
	# This ensures the unit has a valid 'global' space to live in
	get_parent().add_child(unit)

	# 3. Calculate and set the position globally
	# This bypasses any scale/rotation issues from parent nodes
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, spawn_range)
	unit.global_position = self.global_position + random_offset

	# 4. Set up the unit data
	if "faction" in unit: unit.faction = faction_to_assign
	if "is_ally" in unit: unit.is_ally = make_ally

	# 5. Connect signals and track the unit
	unit.unit_died.connect(_on_unit_death)
	living_units.append(unit)

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
