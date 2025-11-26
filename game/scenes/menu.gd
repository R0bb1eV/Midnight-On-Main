extends Control

# --- Menu Camera ---
@onready var menu_camera: Camera3D = $Camera3D

# --- Player Node ---
var player: CharacterBody3D = null
var player_mesh: Node = null

# --- Menu active flag ---
var menu_active: bool = true

# --- Gameplay UI nodes ---
@onready var gameplay_ui: Node = $"/root/World/Stamina"
@onready var ui_label: Node = $"/root/World/UI"

# --- Menu CanvasLayer (title, etc) ---
@onready var menu_canvas: CanvasLayer = $CanvasLayer

# --- Menu music ---
@onready var menu_music: AudioStreamPlayer = $MenuMusic

# --- Gameplay music ---
@onready var gameplay_music: AudioStreamPlayer2D = $"/root/World/AmbientMusic"

# --- Camera motion settings ---
var camera_base_transform: Transform3D
@export var camera_move_radius: Vector2 = Vector2(0.25, 0.15) # x: horizontal, y: vertical
@export var camera_tilt_angle: float = 2.0 # degrees
@export var camera_speed: float = 0.4

var camera_time: float = 0.0

func _ready() -> void:
	# Store menu camera starting transform
	if menu_camera:
		camera_base_transform = menu_camera.transform

	# Find player
	player = get_tree().current_scene.get_node("Character_Rigging") as CharacterBody3D
	if not player:
		push_error("Character_Rigging node not found!")

	# Find player mesh/armature
	player_mesh = player.get_node_or_null("Armature")

	# Disable player camera at start
	var player_camera: Camera3D = player.get_node_or_null("CameraHolder/PivotPitch/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = false

	# Hide and freeze player
	_freeze_player(true)

	# Unlock mouse for menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Connect buttons
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	# Force menu camera active next frame
	call_deferred("_activate_menu_camera")

	# Hide gameplay UI at menu
	if gameplay_ui:
		gameplay_ui.visible = false
	if ui_label:
		ui_label.visible = false

	# Ensure menu CanvasLayer is visible at start
	if menu_canvas:
		menu_canvas.visible = true

	# Play menu music
	if menu_music:
		menu_music.play()


func _process(delta: float) -> void:
	# Animate menu camera while active
	if menu_active and menu_camera:
		camera_time += delta * camera_speed

		var offset = Vector3(
			sin(camera_time) * camera_move_radius.x,
			sin(camera_time * 0.7) * camera_move_radius.y,
			0
		)
		var tilt = deg_to_rad(sin(camera_time * 0.5) * camera_tilt_angle)

		var new_transform = camera_base_transform
		new_transform.origin += offset
		new_transform.basis = Basis(Vector3(1,0,0), tilt) * new_transform.basis
		menu_camera.transform = new_transform


# ----------------------
# Menu camera activation
# ----------------------
func _activate_menu_camera() -> void:
	if menu_active and menu_camera:
		menu_camera.current = true


# ----------------------
# Start button logic
# ----------------------
func _on_start_pressed() -> void:
	# Stop forcing menu camera
	menu_active = false

	# Unfreeze player
	_freeze_player(false)

	# Enable gameplay in player script
	player.gameplay_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Hide menu UI and CanvasLayer
	self.visible = false
	if menu_canvas:
		menu_canvas.visible = false

	# Stop menu music immediately
	if menu_music and menu_music.playing:
		menu_music.stop()

	# Start gameplay music immediately
	if gameplay_music:
		gameplay_music.play()

	# Show gameplay UI
	if gameplay_ui:
		gameplay_ui.visible = true
	if ui_label:
		ui_label.visible = true

	# Switch to player camera next frame
	call_deferred("_activate_player_camera")


func _activate_player_camera() -> void:
	if not player:
		return
	var player_camera: Camera3D = player.get_node_or_null("CameraHolder/PivotPitch/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = true


# ----------------------
# Quit button
# ----------------------
func _on_quit_pressed() -> void:
	get_tree().quit()


# ----------------------
# Freeze/unfreeze player
# ----------------------
func _freeze_player(state: bool) -> void:
	# Hide/show player mesh/armature
	if player_mesh:
		player_mesh.visible = not state

	# Freeze/unfreeze player scripts (but NOT camera)
	player.set_process_input(not state)
	player.set_process(not state)
	player.set_physics_process(not state)
