extends Node3D
class_name bat_enemy


@onready var animation_player: AnimationPlayer = $bat_animflapping/AnimationPlayer
const animation_flapping = "flapping"
# Called when the node enters the scene tree for the first time.
@onready var detection_ray: RayCast3D = $detectionRay
@onready var main_player: AnimationPlayer = $main_player
const wakeupanimation = "FlyOffWall"
var awake = false

var detection_distence = 6.5

# Flight behavior variables
var flight_speed = 2.5
var turn_speed = 3.0
var bob_frequency = 2.0  # How fast the bat bobs up and down
var bob_amplitude = 0.5  # How much the bat bobs up and down
var time_passed = 0.0

# Retreat behavior variables
var is_retreating = false
var retreat_distance = 1.5  # How far to fly back
var retreat_speed = 1.5  # Retreat speed
var retreat_position = Vector3.ZERO

@onready var bat_collision: Area3D = $BatCollision
@onready var damage_timer: Timer = $DamageTimer
@onready var retreat_timer: Timer = $RetreatTimer
@onready var attack_timer: Timer = $AttackTimer

var is_colliding_with_player = false

var max_health = 100
var health = max_health
var dead = false

# Ragdoll physics variables
@onready var ragdoll_body: RigidBody3D = $RigidBody3D
var velocity = Vector3.ZERO

func _ready() -> void:
	# Check if ragdoll body exists
	if ragdoll_body:
		print("Enemy bat: RigidBody3D found and ready")
	else:
		print("ERROR: RigidBody3D not found on enemy bat!")
	
	# Connect bat collision signals
	if bat_collision:
		bat_collision.area_entered.connect(_on_bat_collision_area_entered)
		bat_collision.area_exited.connect(_on_bat_collision_area_exited)
	
	# Connect damage timer
	if damage_timer:
		damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	# Connect retreat timer
	if retreat_timer:
		retreat_timer.timeout.connect(_on_retreat_timer_timeout)
	
	# Connect attack timer
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func _on_bat_collision_area_entered(area: Area3D) -> void:
	# Check if the area entered is the BatTarget
	if area.name == "BatTarget" and Globals.player != null and not is_retreating:
		is_colliding_with_player = true
		# Deal initial damage
		Globals.player.take_damage()
		# Start attack timer - retreat after it completes
		if attack_timer:
			attack_timer.start()

func _on_bat_collision_area_exited(area: Area3D) -> void:
	# Check if the player's BatTarget area exited
	if area.name == "BatTarget":
		is_colliding_with_player = false
		# Stop the damage timer when collision ends
		if damage_timer:
			damage_timer.stop()
		# Stop attack timer and trigger retreat if player backs away
		if attack_timer and attack_timer.time_left > 0:
			attack_timer.stop()
			start_retreat()

func _on_damage_timer_timeout() -> void:
	# Deal damage again if still colliding
	if is_colliding_with_player and Globals.player != null:
		Globals.player.take_damage()
		# Restart the timer for next damage tick
		if damage_timer:
			damage_timer.start()

func start_retreat() -> void:
	if Globals.player == null:
		return
	
	is_retreating = true
	is_colliding_with_player = false
	
	# Stop damage timer during retreat
	if damage_timer:
		damage_timer.stop()
	
	# Calculate retreat position (away from player)
	var direction_from_player = (global_position - Globals.player.global_position).normalized()
	retreat_position = global_position + direction_from_player * retreat_distance
	
	# Start timer to return to attack after retreat
	if retreat_timer:
		retreat_timer.start()

func _on_attack_timer_timeout() -> void:
	# Attack time is over, now retreat
	start_retreat()

func _on_retreat_timer_timeout() -> void:
	# After retreat timer completes, check if player is still detectable
	# If yes, re-engage. If no, stay in retreat hover mode
	if check_player_detection():
		is_retreating = false
	else:
		# Player not in extended range, restart timer to check again
		if retreat_timer:
			retreat_timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle death ragdoll
	if dead:
		ragdoll_to_ground(delta)
		return
	
	if not awake:
		update_detection_point()
	else:
		flap_wings()
		if is_retreating:
			fly_to_retreat_position(delta)
		else:
			fly_towards_player(delta)

func flap_wings() -> void:
	if not animation_player.is_playing():
		animation_player.play(animation_flapping)

func fly_towards_player(delta: float) -> void:
	if Globals.player == null:
		return
	
	# Get the smooth camera node reference
	var smooth_camera = Globals.player.get_node("smooth camera")
	if smooth_camera == null:
		return
	
	time_passed += delta
	
	# Get direction to player's camera (head position)
	var target_position = Globals.player.bat_target.global_position
	var distance_to_camera = global_position.distance_to(target_position)
	var direction = (target_position - global_position).normalized()
	
	# Smoothly rotate to face the direction of movement
	if direction.length() > 0.01:
		# Calculate the target rotation without applying it
		var look_direction = global_position - direction
		var angle_to_target = atan2(-direction.x, -direction.z)
		
		# Smoothly interpolate Y rotation only
		rotation.y = lerp_angle(rotation.y, angle_to_target, turn_speed * delta)
		
		# Tilt up when close to player
		var target_pitch = 0.0
		if distance_to_camera < 0.7:
			target_pitch = deg_to_rad(35.0)  # 35 degrees up
		rotation.x = lerp_angle(rotation.x, target_pitch, turn_speed * delta)
	
	# Only move towards player if farther than 0.3 meter
	if distance_to_camera > 0.3:
		# Add bobbing motion for bird-like flight when flying
		var bob_offset = Vector3.UP * sin(time_passed * bob_frequency) * bob_amplitude
		global_position += direction * flight_speed * delta + bob_offset * delta
	elif distance_to_camera < 0.15:
		# Push back if too close
		global_position -= direction * flight_speed * delta * 0.5
		# Hover side-to-side in front of player when close
		var hover_offset = Vector3.RIGHT * sin(time_passed * 1.5) * 0.3
		global_position += hover_offset * delta
	else:
		# Hover side-to-side in front of player at ideal distance
		var hover_offset = Vector3.RIGHT * sin(time_passed * 1.5) * 0.3
		global_position += hover_offset * delta

func fly_to_retreat_position(delta: float) -> void:
	var distance_to_retreat = global_position.distance_to(retreat_position)
	
	# If reached retreat position, hover and face player
	if distance_to_retreat < 0.5:
		# Face towards player
		if Globals.player != null:
			var direction_to_player = (Globals.player.global_position - global_position).normalized()
			if direction_to_player.length() > 0.01:
				var angle_to_player = atan2(-direction_to_player.x, -direction_to_player.z)
				rotation.y = lerp_angle(rotation.y, angle_to_player, turn_speed * delta)
				rotation.x = lerp_angle(rotation.x, 0.0, turn_speed * delta)  # Level out
		
		# Gentle bobbing while waiting
		var hover_offset = Vector3.UP * sin(time_passed * 1.0) * 0.2
		global_position += hover_offset * delta
		return
	
	# Fly towards retreat position
	var direction = (retreat_position - global_position).normalized()
	
	# Rotate to face retreat direction
	if direction.length() > 0.01:
		var angle_to_target = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, angle_to_target, turn_speed * delta)
		rotation.x = lerp_angle(rotation.x, 0.0, turn_speed * delta)  # Level out
	
	# Move faster during retreat
	global_position += direction * retreat_speed * delta

func ragdoll_to_ground(delta: float) -> void:
	# Stop all animations once
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	if main_player and main_player.is_playing():
		main_player.stop()
	
	if not ragdoll_body:
		print("ERROR: No ragdoll_body in ragdoll_to_ground!")
		return
	
	# Enable RigidBody3D physics (only on first call)
	if ragdoll_body.freeze:
		ragdoll_body.freeze = false
		# Set initial velocity for falling
		ragdoll_body.linear_velocity = velocity if velocity.length() > 0 else Vector3(0, -2, 0)
		# Add tumbling motion
		ragdoll_body.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	
	# Make the entire bat follow the RigidBody3D transform
	global_position = ragdoll_body.global_position
	global_rotation = ragdoll_body.global_rotation

func check_player_detection() -> bool:
	# Reusable function to check if player is detectable
	if Globals.player == null:
		return false
	
	# Point detection ray at player
	var direction_to_player = to_local(Globals.player.global_position)
	detection_ray.target_position = direction_to_player
	
	# Check if player is within extended detection range (1.5x for re-engagement)
	var distance_to_player = global_position.distance_to(Globals.player.global_position)
	var extended_range = detection_distence * 1.5
	
	if distance_to_player <= extended_range:
		return true
	return false

func update_detection_point() -> void:
	if Globals.player != null:
		# Calculate direction to player in local space
		var direction_to_player = to_local(Globals.player.global_position)
		detection_ray.target_position = direction_to_player
		
		# Check if player is within detection distance
		var distance_to_player = global_position.distance_to(Globals.player.global_position)
		if distance_to_player <= detection_distence:
			# Wake up if within range, regardless of raycast (line of sight not required)
			main_player.play(wakeupanimation)
			awake = true

func take_damage() ->void:
	health = health - 40
	if health <= 0:
		queue_free()
