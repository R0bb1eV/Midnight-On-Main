extends CharacterBody3D

# --- Node references ---
@onready var armature: Node3D = $Armature
@onready var anim_tree: AnimationTree = $AnimationTree

# --- UI (absolute path from scene root) ---
@onready var stamina_bar: ProgressBar = $"/root/World/UI/Stam/ProgressBar"

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

# --- Gameplay active flag ---
var gameplay_active: bool = false


func _ready() -> void:
	# Only capture mouse if gameplay is active
	if gameplay_active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Initialize camera ---
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
		if pivot_pitch:
			pivot_pitch.rotation_degrees.x = 0
	else:
		push_error("Camera3D not found. Update script with correct path.")

	# --- Initialize UI ---
	if stamina_bar:
		stamina_bar.min_value = 0
		stamina_bar.max_value = 100
		stamina_bar.value = 100
		_update_stamina_bar_style()


func _unhandled_input(event):
	if not gameplay_active:
		return  # ignore all input until gameplay starts

	if event is InputEventMouseMotion:
		# Yaw
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		# Pitch
		if pivot_pitch:
			var sign = 1.0 if invert_y else -1.0
			var delta_pitch = sign * event.relative.y * mouse_sensitivity
			var new_pitch = pivot_pitch.rotation_degrees.x + delta_pitch
			new_pitch = clamp(new_pitch, pitch_min_deg, pitch_max_deg)
			pivot_pitch.rotation_degrees.x = new_pitch

	if event is InputEventKey and event.is_pressed() and event.keycode == Key.KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			get_tree().quit()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	if not gameplay_active:
		return  # don't move or process physics until gameplay starts

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- Jump ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Movement input ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var raw = Vector3(input_dir.x, 0, input_dir.y)
	var direction = (global_transform.basis * raw).normalized()

	# --- Sprint logic ---
	if sprint_stamina <= 0:
		sprint_stamina = 0
		is_sprinting = false
		sprint_on_cooldown = true

	# Always recover stamina
	sprint_stamina += sprint_recovery_rate * delta
	if sprint_stamina >= sprint_stamina_max:
		sprint_stamina = sprint_stamina_max
		sprint_on_cooldown = false

	# Allow sprint only if not on cooldown
	if Input.is_action_pressed("run") and not sprint_on_cooldown and sprint_stamina > 0:
		is_sprinting = true
		sprint_stamina -= sprint_drain_rate * delta
	else:
		is_sprinting = false

	# --- Crouch ---
	is_crouching = Input.is_action_pressed("crouch")

	# --- Final movement speed ---
	var speed := BASE_SPEED
	if is_sprinting:
		speed *= sprint_mult
	elif is_crouching:
		speed *= crouch_mult

	# --- Apply movement ---
	if direction.length() > 0.01:
		velocity.x = lerp(velocity.x, direction.x * speed, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * speed, LERP_VAL)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)

	move_and_slide()

	# --- Animation ---
	if anim_tree:
		anim_tree.set("parameters/BlendSpace1D/blend_position", velocity.length() / (BASE_SPEED * sprint_mult))

	# --- FOV ---
	var target_fov := default_fov
	if is_sprinting:
		target_fov = sprint_fov
	elif is_crouching:
		target_fov = crouch_fov

	if camera:
		camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)

	# --- UI Update ---
	if stamina_bar:
		var percent = (sprint_stamina / sprint_stamina_max) * 100.0
		stamina_bar.value = percent

		# Track empty state
		if sprint_stamina <= 0.05:
			stamina_bar_empty = true
		elif sprint_stamina >= sprint_stamina_max:
			stamina_bar_empty = false

		# Update bar color
		_update_stamina_bar_style()


func _update_stamina_bar_style():
	if not stamina_bar:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if stamina_bar_empty:
		style.bg_color = Color(0.5, 0, 0) 
	else:
		style.bg_color = Color(0, 0.5, 0)

	var theme := Theme.new()
	theme.set_stylebox("fill", "ProgressBar", style)
	stamina_bar.theme = theme


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
