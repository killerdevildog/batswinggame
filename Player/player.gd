extends CharacterBody3D
@onready var animation_player: AnimationPlayer = $SubViewportContainer/SubViewport/Camera3D/BaseBallBatHolder/AnimationPlayer
const swing_animation = "Swing"

const SPEED = 5.0
const JUMP_VELOCITY = 8.0
const MOUSE_SENSITIVITY := 0.1
const LOOK_SMOOTHING := 10.0
const MAX_PITCH := deg_to_rad(89.0)

var _yaw: float = 0.0
var _pitch: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
@onready var collder: CollisionShape3D = $CollisionShape3D

@onready var _camera: Camera3D = $"smooth camera"
@onready var smooth_camera: Camera3D = $"smooth camera"
@onready var bat_target: Area3D = $BatTarget

var max_health: float = 150
var health = max_health

var vigante_intensity = 0

@onready var damage_vignette: ColorRect = $"smooth camera/DamageVignette"

func _ready() -> void:
	# Register player with Globals
	Globals.player = self
	
	# Capture mouse for FPS-style camera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Initialize angles from current transforms
	_yaw = rotation.y
	if _camera:
		_pitch = _camera.rotation.x
	
	# Connect animation finished signal to reset
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

	Globals.player = self

func _notification(what: int) -> void:
	# Re-capture mouse when the window regains focus
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump - check if Space is pressed directly as fallback
	if Input.is_action_just_pressed("kb_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	elif Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction using kb_* actions only
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("kb_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("kb_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("kb_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("kb_down"):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	# Smooth mouse look (FPS camera) - only when mouse is captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Use event.relative directly to avoid casting issues
		_target_yaw -= deg_to_rad(event.relative.x * MOUSE_SENSITIVITY)
		_target_pitch -= deg_to_rad(event.relative.y * MOUSE_SENSITIVITY)
		_target_pitch = clamp(_target_pitch, -MAX_PITCH, MAX_PITCH)
	
	# Play swing animation on left mouse button click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if animation_player and not animation_player.is_playing():
			animation_player.play(swing_animation)

func _process(delta: float) -> void:
	# Lerp towards target angles for smoothing
	_yaw = lerp_angle(_yaw, _target_yaw, clamp(LOOK_SMOOTHING * delta, 0.0, 1.0))
	_pitch = lerp_angle(_pitch, _target_pitch, clamp(LOOK_SMOOTHING * delta, 0.0, 1.0))

	# Apply yaw to player body and pitch to camera.
	rotation.y = _yaw
	if _camera:
		# Directly set camera local rotation X to pitch.
		var cam_rot := _camera.rotation
		cam_rot.x = _pitch
		_camera.rotation = cam_rot
	
	# Lerp vignette intensity back to 0
	if vigante_intensity > 0:
		vigante_intensity = lerp(vigante_intensity, 0.0, 0.5 * delta)
		if vigante_intensity < 0.01:
			vigante_intensity = 0.0
		var mat := damage_vignette.material
		if mat:
			mat.set_shader_parameter("intensity", vigante_intensity)

	# Optional: toggle mouse capture with Escape
	if Input.is_action_just_pressed("ui_cancel"):
		var mm = Input.get_mouse_mode()
		if mm == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 


func _on_animation_finished(anim_name: String) -> void:
	# Reset to idle position when swing animation finishes
	if anim_name == swing_animation:
		animation_player.play("RESET")

func take_damage():
	health = health - 10
	var mat := damage_vignette.material
	mat.set_shader_parameter("intensity", 1.0)
	vigante_intensity = 1.0
	print("health: " , health)
