extends Node3D

@onready var bat_attack_collision: Area3D = $BatAttackCollision

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect bat attack collision to detect hits
	if bat_attack_collision:
		print("Bat: bat_attack_collision connected successfully")
		bat_attack_collision.area_entered.connect(_on_bat_attack_collision_area_entered)
	else:
		print("ERROR: BatAttackCollision node not found!")

func _on_bat_attack_collision_area_entered(area: Area3D) -> void:
	print("BAT HIT SOMETHING! Area: ", area.name, " | Type: ", area.get_class())
	
	# Check if the area's ancestor is a bat_enemy
	var parent = area.get_parent()
	while parent != null:
		print("  Checking parent: ", parent.name, " | Class: ", parent.get_class())
		if parent is bat_enemy:
			print("  -> Found bat_enemy ancestor! Calling take_damage()")
			parent.take_damage()
			return
		parent = parent.get_parent()
	
	print("  -> No bat_enemy ancestor found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
