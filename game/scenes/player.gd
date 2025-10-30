extends RigidBody3D

# Colon before equal allows Godot to keep track of the variable type

# How fast camera rotates with the mouse
var mouse_sens := 0.003
# Horizontal Movement
var twist_input := 0.0
#Vertical Movement
var pitch_input := 0.0

#Annotation onready - variable related to node within scene tree
@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame, updates game in real time. Virtual Function.
# Delta tells how many seconds have passed since the last frame.
func _process(delta: float) -> void:
	var input := Vector3.ZERO
	# X Axis is set to 1.0 when 'A' key is pressed, and -1.0 when 'D' is pressed.
	input.x = Input.get_axis("move_left", "move_right")
	# Z Axis is set to 1.0 when 'W' key is pressed, and -1.0 when 'S' is pressed.
	input.z = Input.get_axis("move_forward", "move_backward")
	
	apply_central_force(twist_pivot.basis * input * 1200.0 * delta)
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	#$ - accessing nodes within scene tree
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(
		pitch_pivot.rotation.x,
		deg_to_rad(-30),
		deg_to_rad(30)
	)
	twist_input = 0.0
	pitch_input = 0.0
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sens
			pitch_input = - event.relative.y * mouse_sens
