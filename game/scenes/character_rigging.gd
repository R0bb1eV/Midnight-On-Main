extends CharacterBody3D

@onready var armature = $Armature
@onready var spring_arm_pivot = $SpringArmPivot
@onready var spring_arm = $SpringArmPivot/SpringArm3D
@onready var anim_tree = $AnimationTree
@onready var camera = $SpringArmPivot/SpringArm3D/Camera3D

const BASE_SPEED = 4.0
const JUMP_VELOCITY = 4.5
const LERP_VAL = 0.15
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")

var sprint_mult := 2.0
var crouch_mult := 0.5

var sprint_stamina_max := 5.0
var sprint_stamina := 5.0
var sprint_drain_rate := 1.0
var sprint_recovery_rate := 0.5
var sprint_on_cooldown := false
var is_sprinting := false
var is_crouching := false

# --- POV Change ---
var default_fov := 70.0
var sprint_fov := 80.0
var crouch_fov := 62.0
var fov_lerp_speed := 5.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if event is InputEventMouseMotion:
		spring_arm_pivot.rotate_y(-event.relative.x * 0.005)
		spring_arm.rotate_x(-event.relative.y * 0.005)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/4)

func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- Jump ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Input Direction ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, spring_arm_pivot.rotation.y)

	# --- Sprinting & Crouching Logic ---
	if Input.is_action_pressed("run") and not sprint_on_cooldown and sprint_stamina > 0.0:
		is_sprinting = true
	else:
		is_sprinting = false

	if is_sprinting:
		sprint_stamina -= sprint_drain_rate * delta
		if sprint_stamina <= 0.0:
			sprint_stamina = 0.0
			is_sprinting = false
			sprint_on_cooldown = true
	else:
		sprint_stamina += sprint_recovery_rate * delta
		if sprint_stamina >= sprint_stamina_max:
			sprint_stamina = sprint_stamina_max

	if sprint_on_cooldown and sprint_stamina >= sprint_stamina_max * 0.5:
		sprint_on_cooldown = false

	is_crouching = Input.is_action_pressed("crouch")

	# --- Determine Final Speed ---
	var speed := BASE_SPEED
	if is_sprinting:
		speed *= sprint_mult
	elif is_crouching:
		speed *= crouch_mult

	# --- Movement ---
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * speed, LERP_VAL)
		armature.rotation.y = lerp_angle(armature.rotation.y, atan2(-velocity.x, -velocity.z), LERP_VAL)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)

	move_and_slide()

	# --- Animation Blend ---
	anim_tree.set("parameters/BlendSpace1D/blend_position", velocity.length() / (BASE_SPEED * sprint_mult))

	# --- Release Mouse ---
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var target_fov := default_fov
	if is_sprinting:
		target_fov = sprint_fov
	elif is_crouching:
		target_fov = crouch_fov
		
	camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)
