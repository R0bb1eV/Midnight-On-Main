extends CharacterBody3D

# --- Movement settings ---
@export var move_speed: float = 2.5
@export var chase_speed: float = 4.0
@export var detection_radius: float = 50.0
@export var patrol_points: Array[NodePath] = []
@export var chase_predict_time: float = 0.5  # seconds ahead to predict player movement

# --- Node references ---
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hitbox: Area3D = $Hitbox

# --- State ---
var player: Node3D
var current_patrol := 0
var chasing := false
var velocity_smooth: Vector3 = Vector3.ZERO
var previous_player_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		previous_player_pos = player.global_position

	_set_next_patrol_point()

	if anim_tree:
		anim_tree.active = true
		anim_tree["parameters/BlendSpace1D/blend_position"] = 1.0

	hitbox.body_entered.connect(_on_Hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if not player:
		return

	# --- Detect player ---
	var dist = global_position.distance_to(player.global_position)
	chasing = dist < detection_radius

	if chasing:
		# --- Predict player movement ---
		var player_velocity = (player.global_position - previous_player_pos) / delta
		var predicted_pos = player.global_position + player_velocity * chase_predict_time
		previous_player_pos = player.global_position

		agent.target_position = predicted_pos
		_move_with_agent(delta, chase_speed)
	else:
		if agent.is_navigation_finished():
			_set_next_patrol_point()
		_move_with_agent(delta, move_speed)

	if anim_tree:
		anim_tree["parameters/BlendSpace1D/blend_position"] = 1.0

func _set_next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	var node = get_node_or_null(patrol_points[current_patrol])
	if node:
		agent.target_position = node.global_position
	current_patrol = (current_patrol + 1) % patrol_points.size()

func _move_with_agent(delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		velocity_smooth = velocity_smooth.lerp(Vector3.ZERO, 0.15)
	else:
		var next_pos = agent.get_next_path_position()
		var dir = (next_pos - global_position)
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			var target_velocity = dir * speed
			velocity_smooth = velocity_smooth.lerp(target_velocity, 0.2)

			# Smooth rotation
			var target_rot_y = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot_y, 0.15)
		else:
			velocity_smooth = velocity_smooth.lerp(Vector3.ZERO, 0.2)

	# Apply movement
	velocity = velocity_smooth
	move_and_slide()

func _on_Hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player caught! Restarting scene...")
		Global.books_collected = 0
		get_tree().reload_current_scene()
