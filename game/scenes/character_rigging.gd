extends CharacterBody3D

# --- Node references ---
@onready var armature: Node3D = $Armature
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var stamina_bar: ProgressBar = $"/root/World/UI/Stam/ProgressBar"
@onready var pause_screen: Control = $"/root/World/Pausescreen"
@onready var crosshair: TextureRect = $"/root/World/UI/crosshair"

@onready var main_menu: Control = $"/root/World/Menu"

# --- Footsteps ---
@export var step_interval_walk: float = 0.50
@export var step_interval_sprint: float = 0.34
@export var step_interval_crouch: float = 0.70
@export var footsteps_min_speed: float = 0.25
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var footstep_timer: Timer = $FootstepTimer

# Camera pivot + camera (assigned at runtime)
var pivot_pitch: Node3D = null
var camera: Camera3D = null

# --- Movement ---
const BASE_SPEED: float = 4.0
const JUMP_VELOCITY: float = 4.5
const LERP_VAL: float = 0.15
var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Sprint / Crouch ---
var sprint_mult: float = 2.0
var crouch_mult: float = 0.5
var sprint_stamina_max: float = 5.0
var sprint_stamina: float = 5.0
var sprint_drain_rate: float = 1.0
var sprint_recovery_rate: float = 0.5
var sprint_on_cooldown: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

# --- FOV ---
var default_fov: float = 70.0
var sprint_fov: float = 80.0
var crouch_fov: float = 62.0
var fov_lerp_speed: float = 5.0

# --- Mouse look ---
@export var mouse_sensitivity: float = 0.15
@export var invert_y: bool = false
@export var pitch_min_deg: float = -80.0
@export var pitch_max_deg: float = 80.0

# --- Stamina bar state ---
var stamina_bar_empty: bool = false
var stamina_empty_locked: bool = false  # red until fully recovered

# --- Gameplay active flag ---
var gameplay_active: bool = true

func _ready() -> void:
	# Hide pause menu initially
	pause_screen.visible = false

	# Capture mouse at start
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Find camera ---
	var candidates = [
		"PivotPitch/Camera3D",
		"Camera3D",
		"Armature/PivotPitch/Camera3D"
	]
	for path in candidates:
		var c = get_node_or_null(path)
		if c and c is Camera3D:
			camera = c
			pivot_pitch = camera.get_parent() if camera.get_parent() is Node3D else null
			break

	if camera == null:
		camera = _find_camera_in_subtree(self, 4)
		if camera:
			pivot_pitch = camera.get_parent() if camera.get_parent() is Node3D else null

	if camera:
		camera.current = true
		camera.fov = default_fov
	else:
		push_error("Camera3D not found. Update script with correct path.")

	# --- UI init ---
	if stamina_bar:
		stamina_bar.min_value = 0
		stamina_bar.max_value = 100
		stamina_bar.value = 100
		_update_stamina_bar_style()

	# --- Footsteps init ---
	if footstep_timer:
		footstep_timer.stop()
		footstep_timer.timeout.connect(_on_FootstepTimer_timeout)

	# --- Connect Pause Menu Buttons ---
	$"/root/World/Pausescreen/Resume".pressed.connect(_on_resume_pressed)
	$"/root/World/Pausescreen/Quit".pressed.connect(_on_quit_pressed)

# PAUSE SYSTEM
func pause_game():
	gameplay_active = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_screen.visible = true
	pause_screen.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	for button in pause_screen.get_children():
		if button is Button:
			button.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS

func resume_game():
	gameplay_active = true
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pause_screen.visible = false
	pause_screen.process_mode = Node.ProcessMode.PROCESS_MODE_INHERIT
	for button in pause_screen.get_children():
		if button is Button:
			button.process_mode = Node.ProcessMode.PROCESS_MODE_INHERIT

func _on_resume_pressed():
	crosshair.visible = true
	resume_game()

func _on_quit_pressed():

	get_tree().paused = false
	gameplay_active = false
	pause_screen.visible = false

	# Show main menu
	if main_menu:
		main_menu.visible = true
		# If your menu script has a function to re-enable menu mode, call it here:
		main_menu.call("show_menu")

	# Lock player
	set_process_input(false)
	set_process(false)
	set_physics_process(false)

	# Show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# (Optional) hide gameplay UI bits
	if crosshair:
		crosshair.visible = false

# INPUT / CAMERA LOOK
func _unhandled_input(event):
	if event is InputEventKey and event.is_pressed() and event.keycode == Key.KEY_ESCAPE:
	 
		if main_menu.visible:
			return
	
		if get_tree().paused:
			resume_game()
		else:
			crosshair.visible = false
			pause_game()
		return 
	
	if not gameplay_active:
		return  # ignore look if paused

	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		if pivot_pitch:
			var sign = 1.0 if invert_y else -1.0
			var new_pitch = pivot_pitch.rotation_degrees.x + sign * event.relative.y * mouse_sensitivity
			new_pitch = clamp(new_pitch, pitch_min_deg, pitch_max_deg)
			pivot_pitch.rotation_degrees.x = new_pitch

# MOVEMENT / PHYSICS
func _physics_process(delta: float) -> void:
	if not gameplay_active:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var raw = Vector3(input_dir.x, 0, input_dir.y)
	var direction = (global_transform.basis * raw).normalized()

	# Sprint logic
	if sprint_stamina <= 0:
		sprint_stamina = 0
		is_sprinting = false
		sprint_on_cooldown = true
		stamina_empty_locked = true  # lock red bar

	# Always recover stamina
	sprint_stamina += sprint_recovery_rate * delta
	if sprint_stamina >= sprint_stamina_max:
		sprint_stamina = sprint_stamina_max
		sprint_on_cooldown = false
		stamina_empty_locked = false  # unlocked, can turn green

	# Sprint input
	if Input.is_action_pressed("run") and not sprint_on_cooldown and sprint_stamina > 0:
		is_sprinting = true
		sprint_stamina -= sprint_drain_rate * delta
	else:
		is_sprinting = false

	# Crouch
	is_crouching = Input.is_action_pressed("crouch")

	# Movement speed
	var speed := BASE_SPEED
	if is_sprinting:
		speed *= sprint_mult
	elif is_crouching:
		speed *= crouch_mult

	# Apply movement
	if direction.length() > 0.01:
		velocity.x = lerp(velocity.x, direction.x * speed, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * speed, LERP_VAL)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)

	# Footsteps
	_update_footsteps()

	move_and_slide()

	# Animation
	if anim_tree:
		anim_tree.set("parameters/BlendSpace1D/blend_position", velocity.length() / (BASE_SPEED * sprint_mult))

	# FOV
	var target_fov := default_fov
	if is_sprinting:
		target_fov = sprint_fov
	elif is_crouching:
		target_fov = crouch_fov

	if camera:
		camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)

	# UI Update
	if stamina_bar:
		var percent = (sprint_stamina / sprint_stamina_max) * 100.0
		stamina_bar.value = percent
		stamina_bar_empty = stamina_empty_locked or sprint_stamina <= 0.05
		_update_stamina_bar_style()

# STAMINA BAR STYLE
func _update_stamina_bar_style():
	if not stamina_bar:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	style.bg_color = Color(0.5,0,0) if stamina_bar_empty else Color(0,0.5,0)

	var theme := Theme.new()
	theme.set_stylebox("fill", "ProgressBar", style)
	stamina_bar.theme = theme

# FOOTSTEPS
func _update_footsteps() -> void:
	if not gameplay_active or not is_on_floor():
		if footstep_timer and not footstep_timer.is_stopped():
			footstep_timer.stop()
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > footsteps_min_speed
	if not moving:
		if not footstep_timer.is_stopped():
			footstep_timer.stop()
		return

	var interval: float = step_interval_walk
	if is_sprinting:
		interval = step_interval_walk
	elif is_crouching:
		interval = step_interval_crouch
	interval = max(interval, 0.05)

	if absf(footstep_timer.wait_time - interval) > 0.001:
		footstep_timer.wait_time = interval
	if footstep_timer.is_stopped():
		footstep_timer.start()

func _on_FootstepTimer_timeout() -> void:
	if not gameplay_active or not is_on_floor():
		return
	if Vector2(velocity.x, velocity.z).length() <= footsteps_min_speed:
		return
	footstep_player.play()

# CAMERA FINDER
func _find_camera_in_subtree(root: Node, max_depth: int, depth: int = 0) -> Camera3D:
	if depth > max_depth:
		return null
	if root is Camera3D:
		return root
	for c in root.get_children():
		var found = _find_camera_in_subtree(c, max_depth, depth + 1)
		if found:
			return found
	return null
