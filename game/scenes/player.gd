#extends RigidBody3D
#
## Colon before equal allows Godot to keep track of the variable type
#
## How fast camera rotates with the mouse
#var mouse_sens := 0.003
## Horizontal Movement
#var twist_input := 2.0
##Vertical Movement
#var pitch_input := 0.0
#
##Annotation onready - variable related to node within scene tree
#@onready var twist_pivot := $TwistPivot
#@onready var pitch_pivot := $TwistPivot/PitchPivot 
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#
## Called every frame, updates game in real time. Virtual Function.
## Delta tells how many seconds have passed since the last frame.
#func _process(delta: float) -> void:
	#var input := Vector3.ZERO
	## X Axis is set to 1.0 when 'A' key is pressed, and -1.0 when 'D' is pressed.
	#input.x = Input.get_axis("move_left", "move_right")
	## Z Axis is set to 1.0 when 'W' key is pressed, and -1.0 when 'S' is pressed.
	#input.z = Input.get_axis("move_forward", "move_backward")
	#
	#apply_central_force(twist_pivot.basis * input * 1200.0 * delta)
	#
	#if Input.is_action_just_pressed("ui_cancel"):
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#
	##$ - accessing nodes within scene tree
	#twist_pivot.rotate_y(twist_input)
	#pitch_pivot.rotate_x(pitch_input)
	#pitch_pivot.rotation.x = clamp(
		#pitch_pivot.rotation.x,
		#deg_to_rad(-30),
		#deg_to_rad(30)
	#)
	#twist_input = 0.0
	#pitch_input = 0.0
	#
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			#twist_input = - event.relative.x * mouse_sens
			#pitch_input = - event.relative.y * mouse_sens


extends RigidBody3D

# ---------------- Camera Look ----------------
var mouse_sens := 0.003
var twist_input := 0.0
var pitch_input := 0.0

@onready var twist_pivot: Node3D = $TwistPivot
@onready var pitch_pivot: Node3D = $TwistPivot/PitchPivot
@onready var ground_ray: RayCast3D = $GroundRay

# ---------------- Movement / Jump (tweak these) ----------------
@export var move_force: float = 1600.0          # base push strength
@export var run_multiplier: float = 1.6         # sprint boost
@export var air_control_scale: float = 0.55     # 0..1 control in air
@export var max_speed: float = 10.0             # m/s walking top speed
@export var jump_impulse: float = 12.0          # upward impulse for jump
@export var max_pitch_deg: float = 75.0
@export var min_pitch_deg: float = -75.0
@export var invert_y: bool = false

# Optional little forgiveness
@export var coyote_time: float = 0.10           # seconds after leaving ground
@export var jump_buffer_time: float = 0.12      # press jump slightly early

var _coyote: float = 0.0
var _jump_buffer: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		twist_input = -mm.relative.x * mouse_sens
		pitch_input = -(mm.relative.y * mouse_sens) * (-1.0 if invert_y else 1.0)

func _physics_process(delta: float) -> void:
	# ----- Mouse look -----
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(
		pitch_pivot.rotation.x,
		deg_to_rad(min_pitch_deg),
		deg_to_rad(max_pitch_deg)
	)
	twist_input = 0.0
	pitch_input = 0.0

	# ----- Grounding -----
	var grounded := ground_ray.is_colliding()
	if grounded:
		_coyote = coyote_time
	else:
		_coyote = max(_coyote - delta, 0.0)

	# ----- Read movement input -----
	var dir_local := Vector3.ZERO
	dir_local.x = Input.get_axis("move_left", "move_right")
	dir_local.z = Input.get_axis("move_forward", "move_backward")

	var wants_move := dir_local.length() > 0.001
	var dir_world := Vector3.ZERO
	if wants_move:
		# convert local (relative to camera/body yaw) to world space
		dir_world = (twist_pivot.basis * dir_local).normalized()

	# Sprint?
	var speed_mul := (run_multiplier if Input.is_action_pressed("run") else 1.0)

	# ----- Apply movement force -----
	if wants_move:
		var control := 1.0 if grounded else air_control_scale
		apply_central_force(dir_world * move_force * control * speed_mul)

	# ----- Clamp horizontal top speed -----
	var lv := linear_velocity
	var h := Vector3(lv.x, 0.0, lv.z)
	var max_h := max_speed * speed_mul
	if h.length() > max_h:
		h = h.normalized() * max_h
		linear_velocity = Vector3(h.x, lv.y, h.z)

	# ----- Jump buffering -----
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	_jump_buffer = max(_jump_buffer - delta, 0.0)

	# Jump if buffered and allowed by coyote window
	if _jump_buffer > 0.0 and (_coyote > 0.0 or grounded):
		var v := linear_velocity
		# prevent downwards momentum from eating the jump
		if v.y < 0.0:
			v.y = 0.0
		v.y = jump_impulse              # treat as a velocity in m/s
		linear_velocity = v
		# (optional extra kick if you like impulses)
		# apply_central_impulse(Vector3.UP * 1.0)

		_jump_buffer = 0.0
		_coyote = 0.0
