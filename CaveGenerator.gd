extends Node3D

# Cave section packed scenes
var navigation_sections = []
var intersection_sections = []
var chamber_sections = []
var dead_end_sections = []

# Generation parameters
@export var main_path_length: int = 20  # Number of sections in main path
@export var branch_chance: float = 0.3  # Probability of creating a branch at intersections
@export var max_branches: int = 5  # Maximum number of branches

# Tracking
var placed_sections = []
var available_exits = []  # List of connection points that can be extended
var first_entry_point = null  # Track the first entry point for player placement

func _ready():
	setup_lighting()
	load_sections()
	generate_cave()
	spawn_player()

func setup_lighting():
	# Add WorldEnvironment
	var world_env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.1, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.35)
	environment.ambient_light_energy = 0.5
	world_env.environment = environment
	add_child(world_env)
	
	# Add DirectionalLight3D
	var light = DirectionalLight3D.new()
	light.light_energy = 0.8
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	add_child(light)

func load_sections():
	# Load all navigation sections
	navigation_sections = [
		preload("res://CaveSections/StraightForward.tscn"),
		preload("res://CaveSections/StraightWide.tscn"),
		preload("res://CaveSections/StraightNarrow.tscn"),
		preload("res://CaveSections/StraightForwardIncline.tscn"),
		preload("res://CaveSections/StraightForwardDecline.tscn"),
		preload("res://CaveSections/TurnLeft.tscn"),
		preload("res://CaveSections/TurnRight.tscn"),
	]
	
	# Load intersection sections
	intersection_sections = [
		preload("res://CaveSections/IntersectionT.tscn"),
		preload("res://CaveSections/Intersection4way.tscn"),
	]
	
	# Load chamber sections
	chamber_sections = [
		preload("res://CaveSections/ChamberSmall.tscn"),
		preload("res://CaveSections/ChamberMedium.tscn"),
		preload("res://CaveSections/ChamberLarge.tscn"),
	]
	
	# Load dead end
	dead_end_sections = [
		preload("res://CaveSections/DeadEnd.tscn"),
	]

func generate_cave():
	# Clear any existing cave
	for child in get_children():
		child.queue_free()
	placed_sections.clear()
	available_exits.clear()
	
	# Start position
	var current_position = Vector3.ZERO
	var current_rotation = 0  # In degrees, multiples of 90
	
	# Phase 1: Generate main path
	for i in range(main_path_length):
		var section_scene
		
		# Decide what type of section to place
		if i == 0:
			# First section is always straight
			section_scene = navigation_sections[0]  # StraightForward
		elif i == main_path_length - 1:
			# Last section could be a chamber or dead end
			section_scene = chamber_sections.pick_random()
		elif randf() < 0.15:
			# 15% chance for intersection (creates branch opportunity)
			section_scene = intersection_sections.pick_random()
		elif randf() < 0.1:
			# 10% chance for chamber
			section_scene = chamber_sections.pick_random()
		else:
			# Regular navigation section
			section_scene = navigation_sections.pick_random()
		
		# Place the section
		var exit_info = place_section(section_scene, current_position, current_rotation)
		
		if exit_info:
			current_position = exit_info.position
			current_rotation = exit_info.rotation
			
			# If this section has extra exits (like intersections), add them to available_exits
			if exit_info.has("extra_exits"):
				for extra_exit in exit_info.extra_exits:
					available_exits.append(extra_exit)
	
	# Phase 2: Generate branches from intersections
	var branches_created = 0
	while available_exits.size() > 0 and branches_created < max_branches:
		if randf() < branch_chance:
			var exit_point = available_exits.pop_front()
			generate_branch(exit_point, randi_range(3, 8))  # Branches are 3-8 sections long
			branches_created += 1
		else:
			available_exits.pop_front()

func place_section(section_scene: PackedScene, position: Vector3, rotation_deg: int) -> Dictionary:
	var section = section_scene.instantiate()
	add_child(section)
	
	# Apply rotation (around Y axis)
	section.rotation_degrees.y = rotation_deg
	section.position = position
	
	placed_sections.append(section)
	
	# Find connection points in the section
	var entry_point = null
	var exit_points = []
	
	# Store the first entry point for player spawn
	if first_entry_point == null:
		for child in section.get_children():
			if child.name.begins_with("ConnectionPoint") and "Entry" in child.name:
				first_entry_point = child.global_position
				break
	
	for child in section.get_children():
		if child.name.begins_with("ConnectionPoint"):
			if "Entry" in child.name:
				entry_point = child
			elif "Exit" in child.name:
				exit_points.append(child)
	
	# Calculate next position based on the primary exit
	if exit_points.size() > 0:
		var primary_exit = exit_points[0]
		var exit_global_pos = primary_exit.global_position
		
		# Determine rotation change based on exit direction in the CURRENT section's local space
		var exit_local_pos = primary_exit.position
		var new_rotation = rotation_deg
		
		# Simple rotation detection based on exit position relative to center
		if abs(exit_local_pos.x) > abs(exit_local_pos.z):
			if exit_local_pos.x > 0:
				new_rotation = rotation_deg + 90  # Turn right
			else:
				new_rotation = rotation_deg - 90  # Turn left
		else:
			if exit_local_pos.z > 0:
				new_rotation = rotation_deg + 180  # Turn around
			else:
				new_rotation = rotation_deg  # Continue straight
		
		# Normalize rotation to 0-359
		new_rotation = fmod(new_rotation + 360, 360)
		
		# Calculate where to place the next section so its entry point matches this exit point
		# Entry point is always at local (0, -5, 0), need to find what that becomes in global space
		var entry_local = Vector3(0, -5, 0)
		var rotation_rad = deg_to_rad(new_rotation)
		var entry_rotated = entry_local.rotated(Vector3.UP, rotation_rad)
		
		# Next section's origin should be: exit position - where the entry point would be
		var next_position = exit_global_pos - entry_rotated
		
		var result = {
			"position": next_position,
			"rotation": new_rotation
		}
		
		# Add extra exits for intersections
		if exit_points.size() > 1:
			var extra = []
			for i in range(1, exit_points.size()):
				extra.append({
					"position": exit_points[i].global_position,
					"rotation": calculate_rotation_for_exit(exit_points[i].position)
				})
			result["extra_exits"] = extra
		
		return result
	
	return {}

func generate_branch(start_info: Dictionary, length: int):
	var current_position = start_info.position
	var current_rotation = start_info.rotation
	
	for i in range(length):
		var section_scene
		
		if i == length - 1:
			# End branches with dead ends
			section_scene = dead_end_sections[0]
		else:
			# Branches are mostly straight navigation
			section_scene = navigation_sections.pick_random()
		
		var exit_info = place_section(section_scene, current_position, current_rotation)
		if exit_info:
			current_position = exit_info.position
			current_rotation = exit_info.rotation
		else:
			break

func calculate_rotation_for_exit(exit_local_pos: Vector3) -> int:
	if abs(exit_local_pos.x) > abs(exit_local_pos.z):
		return 90 if exit_local_pos.x > 0 else 270
	else:
		return 180 if exit_local_pos.z > 0 else 0

func spawn_player():
	if first_entry_point == null:
		push_warning("No entry point found for player spawn")
		return
	
	# Load and instantiate player scene
	var player_scene = preload("res://Player/Player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	# Position player 1 meter forward on Z axis from first entry point
	player.global_position = first_entry_point + Vector3(0, 0, -1)
