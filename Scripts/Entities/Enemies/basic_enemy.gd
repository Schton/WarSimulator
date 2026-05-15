extends CharacterBody2D

enum Faction { PLAYER, ENEMY }
@export var faction = Faction.ENEMY  # enemy default

var current_duelist: CharacterBody2D = null # The person currently fighting me
@export var is_ally := false # Set true for followers, false for enemies

@export var strafe_time_limit := 2.5 # How long they circle before charging back in
@export var hits_to_trigger_strafe := 2 # How many hits they take before backing off

signal unit_died(pos)

var strafe_timer := 0.0
var hits_taken_recently := 0
var retarget_timer := 0.0

var is_attacking_anim := false
var think_offset = randi() % 120

@onready var nav_agent := $NavigationAgent2D
var path_refresh_time := 0.2 # Don't recalculate every single frame
var path_timer := 0.0

var external_push := Vector2.ZERO # For knockback and physics impacts
var mass = 1.0

var visual_dir := Vector2.DOWN
var turn_lock_timer := 0.0

@export var turn_lock_duration := 0.12
@export var min_turn_velocity := 20.0

# =====================================================
# ADVANCED SOULSLIKE ENEMY AI (Godot 4)
# Features:
# - Idle patrol
# - Aggro detection
# - Chase player
# - Strafe / surround player
# - Attack combos
# - Cooldowns
# - Hit stun
# - Knockback
# - Return home if player escapes
# - Multi-enemy attack slot system
# =====================================================

enum State {
	IDLE,
	PATROL,
	CHASE,
	STRAFE,
	ATTACK,
	STUN,
	DEAD,
	RETURN_HOME
}

var state = State.IDLE

# ==========================
# SETTINGS
# ==========================
@export var move_speed := 60.0
@export var detect_range := 420.0
@export var lose_range := 700.0
@export var attack_range := 55.0
@export var strafe_range := 70.0

@export var max_health := 100
@export var attack_damage := 15

@export var attack_cooldown := 1.2
@export var stun_time := 0.35

# ==========================
# REFERENCES
# ==========================
@onready var anim = $AnimatedSprite2D
var target

# ==========================
# RUNTIME
# ==========================
var health := 100
var facing_dir := Vector2.DOWN
var last_move_dir := Vector2.DOWN
var spawn_position := Vector2.ZERO
var attack_dir := Vector2.DOWN

var can_attack := true
var strafe_dir := 1
var stun_timer := 0.0
var attack_timer := 0.0

var current_anim := ""

# =====================================================
# READY
# =====================================================
func _ready():
	health = max_health
	spawn_position = global_position
	target = get_tree().get_first_node_in_group("player")
	add_to_group("units")
	add_to_group("enemy_units")

	randomize()

# =====================================================
# MAIN LOOP
# =====================================================
func _physics_process(delta):
	turn_lock_timer -= delta
	external_push = external_push.move_toward(Vector2.ZERO, 500.0 * delta)

	# =========================
	# PERIODIC RETARGETING
	# =========================
	retarget_timer -= delta
	if retarget_timer <= 0:
		find_target()
		retarget_timer = randf_range(0.5, 1.2)

	if target == null or not is_instance_valid(target):
		find_target()

	# Determine State Logic
	match state:
		State.IDLE: state_idle()
		State.CHASE: state_chase()
		State.STRAFE: state_strafe()
		State.ATTACK: state_attack()
		State.STUN: state_stun(delta)
		State.RETURN_HOME: state_return_home()
		State.DEAD:
			velocity = external_push
			move_and_slide()
			return

# =========================================
# MOVEMENT
# =========================================

	if state in [State.CHASE, State.RETURN_HOME]:

		path_timer += delta

		if path_timer >= path_refresh_time:
			update_path()
			path_timer = 0.0

		move_along_path()

	elif state == State.STRAFE:
		velocity += external_push

	elif state == State.STUN:
		velocity = external_push

	else:
		velocity += external_push

# =========================================
# SINGLE PHYSICS MOVE
# =========================================

	move_and_slide()

# =========================================
# PUSH LOGIC
# =========================================

	for i in get_slide_collision_count():

		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is CharacterBody2D and "faction" in collider:

			if collider.faction == Faction.PLAYER:

				var push_strength = 0.8 if is_ally else 0.4

				external_push += collider.velocity * push_strength * delta

	update_animation()

# =====================================================
# STATES
# =====================================================

func state_idle():
	velocity = Vector2.ZERO

	if distance_to_target() < detect_range:
		state = State.CHASE

func state_patrol():
	velocity = Vector2.ZERO

func state_chase():
	var dist = distance_to_target()
	if dist > lose_range:
		state = State.RETURN_HOME
		return

	if dist <= attack_range + 5:
		try_attack()
		return

	# Trigger Strafe logic
	if dist <= strafe_range:
		if randf() < 0.01 or hits_taken_recently >= hits_to_trigger_strafe:
			state = State.STRAFE
			strafe_timer = strafe_time_limit
			return

func state_strafe():
	if not is_instance_valid(target):
		state = State.CHASE
		return

	var health_pct = float(health) / max_health

# --- TIMER LOGIC ---
	strafe_timer -= get_physics_process_delta_time()
	if strafe_timer <= 0:
		hits_taken_recently = 0 # Reset hit counter to be aggressive again
		state = State.CHASE
		return

	var to_target = direction_to_target()
	var dist = distance_to_target()

	# --- ORBIT SETTINGS ---
	var desired_radius = 65.0 
	var push_weight = 0.2     

	if health_pct < 0.3:
		desired_radius = 110.0 # Back up even further than 90
		push_weight = 0.8      # Retreat much faster

	var orbit_speed = move_speed * 0.8
	
	# 1. Calculate the raw sideways vector
	var tangent = to_target.rotated(deg_to_rad(90 * strafe_dir))
	
	# 2. BLEND: Instead of just going sideways, we mix in a "Seek" vector
	# If they are too far, they steer significantly toward the player while orbiting
	var spiral_dir = tangent # Default to pure sideways
	
	if dist > desired_radius:
		# PULL IN: Same as your current logic
		var weight = clamp((dist - desired_radius) / 20.0, 0.0, 1.0)
		spiral_dir = tangent.lerp(-to_target, weight).normalized()
	elif dist < desired_radius - 10.0:
		# PUSH BACK: This is where you control the "Back Off"
		# Increase the 0.5 to push back harder, or decrease it to drift back slowly
		spiral_dir = tangent.lerp(to_target, push_weight).normalized()

	# 3. SEPARATION: Keep this very low during strafe so it doesn't push them out
	var sep = apply_separation() * 0.2 

	velocity = (spiral_dir * orbit_speed) + apply_separation()

	# Face target
	last_move_dir = to_target

	# Randomly change direction
	if randf() < 0.005:
		strafe_dir *= -1

	# ATTACK CHECK (Close the gap if they are in range)
	if dist <= attack_range + 5:
		try_attack()
	elif dist > detect_range: # If they somehow drift too far, go back to chase
		state = State.CHASE

func state_attack():
	velocity = Vector2.ZERO

func state_stun(delta):
	velocity = Vector2.ZERO

	stun_timer -= delta
	if stun_timer <= 0:
# Instead of going straight to CHASE, decide based on hits
		if hits_taken_recently >= hits_to_trigger_strafe:
			state = State.STRAFE
			strafe_timer = strafe_time_limit
		else:
			state = State.CHASE

func state_return_home():

	var dist = global_position.distance_to(spawn_position)

	if dist < 10:
		state = State.IDLE
		return

	var dir = global_position.direction_to(spawn_position)
	velocity = (dir * move_speed) + apply_separation()
	velocity = velocity.limit_length(move_speed)
	last_move_dir = dir

# =====================================================
# ATTACK SYSTEM
# =====================================================

func try_attack():

	if not can_attack:
		state = State.STRAFE
		return

	var attackers = get_tree().get_nodes_in_group("attackers")

	# max 2 enemies attack simultaneously
	if attackers.size() >= 2:
		state = State.STRAFE
		return

	start_attack()

func start_attack():

	state = State.ATTACK
	can_attack = false
	add_to_group("attackers")

	velocity = Vector2.ZERO

	is_attacking_anim = true

	attack_dir = direction_to_target()
	anim.play("attack_" + get_dir(attack_dir))

	# DAMAGE TIMING (instead of waiting whole animation)
	await get_tree().create_timer(0.15).timeout

	# Apply damage mid-swing
	if is_instance_valid(target) and distance_to_target() <= attack_range + 10:
		if target.has_method("take_damage") and target.faction != faction:
			target.take_damage(attack_damage, attack_dir, self)

	# Finish animation WITHOUT blocking
	await get_tree().create_timer(0.2).timeout

	is_attacking_anim = false

	remove_from_group("attackers")

	state = State.CHASE

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func find_target():

	var units = get_tree().get_nodes_in_group("units")
	var best_target = null
	var best_score = INF

	for u in units:
		if u == self:
			continue
		if not is_instance_valid(u):
			continue
		if u.state == State.DEAD:
			continue
		if u.faction == faction:
			continue

		var dist = global_position.distance_to(u.global_position)

		# Ignore faraway units
		if dist > detect_range:
			continue

		var score = dist

		# -------------------------
		# PLAYER BONUS (SMALL)
		# -------------------------
		# Slight preference for player,
		# but NOT enough to break formation
		if u.faction == Faction.PLAYER and not u.is_ally:
			score -= 40

		# -------------------------
		# FREE TARGET BONUS
		# -------------------------
		if u.current_duelist == null:
			score -= 80

		# -------------------------
		# CROWDING PENALTY
		# -------------------------
		elif u.current_duelist != self:
			score += 120

		# -------------------------
		# LOW HP BONUS
		# -------------------------
		if "health" in u:
			score -= (100 - u.health) * 0.3

		# -------------------------
		# CLOSE TARGET BONUS
		# -------------------------
		score -= max(0, 150 - dist) * 0.5

		if score < best_score:
			best_score = score
			best_target = u

	# -------------------------
	# APPLY TARGET
	# -------------------------
	if best_target != target:

		if is_instance_valid(target) and "current_duelist" in target:
			if target.current_duelist == self:
				target.current_duelist = null

		target = best_target
		if is_instance_valid(target) and "current_duelist" in target:
			target.current_duelist = self

# =====================================================
# DAMAGE / HITSTUN
# =====================================================

func take_damage(amount, knock_dir := Vector2.ZERO, attacker = null):
	if state == State.DEAD:
		return

	var final_damage = amount
	if attacker and attacker.faction != Faction.PLAYER:
		final_damage = amount * 0.5 # AI deals 50% less damage to each other

	health -= final_damage

# INTERVENTION LOGIC:
	# If the player hits us, drop the current duel and target the player
	if attacker and "faction" in attacker and attacker.faction == Faction.PLAYER:
		if is_instance_valid(target) and "current_duelist" in target:
			target.current_duelist = null
		target = attacker
		state = State.CHASE # Force switch to player pursuit

		await get_tree().create_timer(1.5).timeout
		find_target()

	if health <= 0:
		die()
		return

	state = State.STUN
	stun_timer = stun_time

# Knockback as damage indicator?
	# Use external_push instead of velocity
	#external_push = knock_dir * 250.0 
	# Reset pathfinding so they don't instantly snap back
	#nav_agent.target_position = global_position

	var hurt_anim = "hurt_" + get_dir(direction_to_target())
	anim.play(hurt_anim)
	current_anim = ""
	#print("Enemy HP:", health)

func die():
	unit_died.emit(global_position)

	state = State.DEAD

	remove_from_group("enemy_units")
	var manager = get_tree().get_first_node_in_group("level_manager")
	if manager:
		manager.check_victory()

	if is_instance_valid(target) and "current_duelist" in target:
		target.current_duelist = null

	velocity = Vector2.ZERO
	anim.play("death")

	await anim.animation_finished

# Notify all units that this one is gone
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u):
			continue
		if not u.has_method("distance_to_target"): # or check variable instead
			continue
		if "target" in u and u.target == self:
			u.target = null

	queue_free()

# =====================================================
# HELPERS
# =====================================================

func distance_to_target():
	if target == null or not is_instance_valid(target):
		return INF # Return "Infinity" so the AI thinks the target is too far
	return global_position.distance_to(target.global_position)

func direction_to_target():
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)

func update_animation():

	if is_attacking_anim:
		return

	if state == State.STUN or state == State.DEAD:
		return

	var next_anim

# 1. Use a threshold to prevent "micro-walk" animations
	# If the unit is moving slower than 15 pixels/sec, force IDLE
	if velocity.length() > min_turn_velocity:
		var desired_dir = velocity.normalized()
		# Only allow turning if timer expired
		if turn_lock_timer <= 0.0:
			# Prevent tiny twitch turns
			if visual_dir.dot(desired_dir) < 0.85:
				visual_dir = desired_dir
				turn_lock_timer = turn_lock_duration
		next_anim = "walk_" + get_dir(visual_dir)
	else:
		next_anim = "idle_" + get_dir(visual_dir)

	if current_anim != next_anim:
		anim.play(next_anim)
		current_anim = next_anim

func get_dir(dir: Vector2) -> String:

	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"

	return "front" if dir.y > 0 else "back"

func apply_separation():
	var units = get_tree().get_nodes_in_group("units")
	var push = Vector2.ZERO
	var my_mass: float = mass if mass > 0.01 else 1.0

	for u in units:
		if u == self or not is_instance_valid(u):
			continue

		var dist = global_position.distance_to(u.global_position)
		# 25.0 is a bit tight; 30.0-35.0 often feels "cleaner" for 16x16 or 32x32 sprites
		if dist >= 30.0: 
			continue

		var other_mass: float = u.get("mass") if "mass" in u else 1.0
		var strength = 1.0 - (dist / 30.0)
		var mass_ratio = other_mass / my_mass

		push += (global_position - u.global_position).normalized() * strength * mass_ratio

	# THE CRITICAL CHANGE:
	# We multiply by a strength factor, then LIMIT it.
	# This prevents the "explosion" effect in large groups.
	return (push * 10.0).limit_length(move_speed * 0.15)

# =====================================================
# Pathfinding
# =====================================================

# 1. Tell the agent where to go
func update_path():
	if nav_agent == null: 
		return
		
	if state == State.RETURN_HOME:
		nav_agent.target_position = spawn_position
	# ADD THE "is_instance_valid" CHECK HERE:
	elif target != null and is_instance_valid(target):
		nav_agent.target_position = target.global_position
	else:
		# If no target, stay where you are to avoid errors
		nav_agent.target_position = global_position

# 2. Get the next physical direction to move
func move_along_path():

	if nav_agent.is_navigation_finished():
		velocity = apply_separation()
		return

	var next_path_pos = nav_agent.get_next_path_position()

	var dir = global_position.direction_to(next_path_pos)

	velocity = dir * move_speed
	velocity += apply_separation()

	last_move_dir = dir

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	pass
