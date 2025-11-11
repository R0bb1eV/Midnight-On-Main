extends CharacterBody3D

@export var move_speed: float = 2.5
@export var chase_speed: float = 4.0
@export var detection_radius: float = 10.0
@export var patrol_points: Array[NodePath] = []   # assign in the main scene

@onready var agent: NavigationAgent3D = $NavigationAgent3D
var player: Node3D
var current_patrol := 0
var chasing := false

func _ready() -> void:
	# find the player (must be in group "player")
	player = get_tree().get_first_node_in_group("player")
	_set_next_patrol_point()

func _physics_process(delta: float) -> void:
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)
	chasing = dist < detection_radius

	if chasing:
		agent.target_position = player.global_position
		print("chase")
		_move_with_agent(delta, chase_speed)
	else:
		print("patrol")
		if agent.is_navigation_finished():
			_set_next_patrol_point()
		_move_with_agent(delta, move_speed)

func _set_next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	var node = get_node_or_null(patrol_points[current_patrol])
	if node:
		agent.target_position = node.global_position
	current_patrol = (current_patrol + 1) % patrol_points.size()

func _move_with_agent(delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		velocity = Vector3.ZERO
	else:
		var next_pos = agent.get_next_path_position()
		var dir = (next_pos - global_position)
		dir.y = 0.0
		dir = dir.normalized()

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

		if dir.length() > 0.01:
			var target_rot_y = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot_y, 0.15)

	move_and_slide()
