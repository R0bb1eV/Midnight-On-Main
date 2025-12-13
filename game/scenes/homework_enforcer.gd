extends CharacterBody3D

# --- Movement settings ---
@export var move_speed: float = 2.5
@export var chase_speed: float = 4.0
@export var detection_radius: float = 75.0
@export var patrol_points: Array[NodePath] = []
@export var chase_predict_time: float = 0.5  # seconds ahead to predict player movement

# --- Footsteps settings ---
@export var footsteps_min_speed: float = 0.25
@export var patrol_step_interval: float = 0.45
@export var chase_step_interval: float = 0.32

# --- Node references ---
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hitbox: Area3D = $Hitbox

@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var footstep_timer: Timer = $FootstepTimer
@onready var attack_player: AudioStreamPlayer3D = $AttackPlayer

# --- State ---
var player: Node3D
var current_patrol := 0
var chasing := false
var velocity_smooth: Vector3 = Vector3.ZERO
var previous_player_pos: Vector3 = Vector3.ZERO
var has_attacked: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		previous_player_pos = player.global_position

	_set_next_patrol_point()

	if anim_tree:
		anim_tree.active = true
		anim_tree["parameters/BlendSpace1D/blend_position"] = 1.0

	hitbox.body_entered.connect(_on_Hitbox_body_entered)
	footstep_timer.timeout.connect(_on_FootstepTimer_timeout)

	# Start in a clean audio state
	footstep_timer.stop()

func _physics_process(delta: float) -> void:
	if not player:
		return

	# --- Detect player ---
	var dist: float = global_position.distance_to(player.global_position)
	chasing = dist < detection_radius

	if chasing:
		# --- Predict player movement ---
		var player_velocity: Vector3 = (player.global_position - previous_player_pos) / max(delta, 0.00001)
		var predicted_pos: Vector3 = player.global_position + player_velocity * chase_predict_time
		previous_player_pos = player.global_position

		agent.target_position = predicted_pos
		_move_with_agent(delta, chase_speed)
	else:
		if agent.is_navigation_finished():
			_set_next_patrol_point()
		_move_with_agent(delta, move_speed)

	if anim_tree:
		anim_tree["parameters/BlendSpace1D/blend_position"] = 1.0

	_update_footsteps()

func _set_next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	var node: Node3D = get_node_or_null(patrol_points[current_patrol]) as Node3D
	if node:
		agent.target_position = node.global_position
	current_patrol = (current_patrol + 1) % patrol_points.size()

func _move_with_agent(_delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		velocity_smooth = velocity_smooth.lerp(Vector3.ZERO, 0.15)
	else:
		var next_pos: Vector3 = agent.get_next_path_position()
		var dir: Vector3 = (next_pos - global_position)
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			var target_velocity: Vector3 = dir * speed
			velocity_smooth = velocity_smooth.lerp(target_velocity, 0.2)

			# Smooth rotation
			var target_rot_y: float = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot_y, 0.15)
		else:
			velocity_smooth = velocity_smooth.lerp(Vector3.ZERO, 0.2)

	# Apply movement
	velocity = velocity_smooth
	move_and_slide()

#Footsteps (3D)
func _update_footsteps() -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > footsteps_min_speed

	if not moving:
		if not footstep_timer.is_stopped():
			footstep_timer.stop()
		return

	var interval: float = patrol_step_interval
	if chasing:
		interval = chase_step_interval

	footstep_timer.wait_time = interval
	if footstep_timer.is_stopped():
		footstep_timer.start()

func _on_FootstepTimer_timeout() -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed <= footsteps_min_speed:
		return
	footstep_player.play()

#Attack / Caught Player
func _on_Hitbox_body_entered(body: Node) -> void:
	if has_attacked:
		return

	if body.is_in_group("player"):
		has_attacked = true

		# Stop footsteps immediately
		if not footstep_timer.is_stopped():
			footstep_timer.stop()

		# Play attack sound from the enforcer (3D)
		if attack_player:
			attack_player.play()

		# Trigger caught screen on player
		if body.has_method("on_caught"):
			body.on_caught()
