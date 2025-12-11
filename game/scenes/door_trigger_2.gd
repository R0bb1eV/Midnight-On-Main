extends Area3D

@export var hold_time_required: float = 1.0              # seconds to hold E
@export var required_books: int = 5                      # how many needed to leave
@export var teleport_target_path: NodePath               # Marker3D to teleport to (optional)
@export var ui_exit_hold_prompt_path: NodePath           # ExitHoldPrompt Control
@export var ui_collect_prompt_path: NodePath             # CollectPrompt Control
@export var show_endscreen: bool = false                 # Set true for final exit door

# --- Music nodes ---
@onready var ambient_music: AudioStreamPlayer2D = $"/root/World/AmbientMusic"
@onready var building_music: AudioStreamPlayer = $"/root/World/ThemeMusic"

# --- Endscreen nodes ---
@onready var endscreen: Control = $"/root/World/Endscreen"
@onready var endscreen_camera: Camera3D = endscreen.get_node("Camera3D") as Camera3D
@onready var restart_button: Button = endscreen.get_node("Button")
@onready var quit_button: Button = endscreen.get_node("Button2")

# --- HUD ---
@onready var crosshair: TextureRect = $"/root/World/UI/crosshair"
@onready var stam: ProgressBar = $"/root/World/UI/Stam/ProgressBar"
@onready var label: Label = $"/root/World/UI/Label"

var player: CharacterBody3D = null
var hold_timer: float = 0.0
var is_holding: bool = false

# Ternary for optional teleport
@onready var teleport_target: Node3D = get_node(teleport_target_path) as Node3D if teleport_target_path != null else null

# Exit hold prompt UI
@onready var exit_hold_prompt: Control = get_node(ui_exit_hold_prompt_path) as Control
@onready var exit_progress_bar: ProgressBar = exit_hold_prompt.get_node("Progress") as ProgressBar
@onready var exit_label: Label = exit_hold_prompt.get_node("Label_exit") as Label

# Collect prompt UI
@onready var collect_prompt: Control = get_node(ui_collect_prompt_path) as Control
@onready var collect_label: Label = collect_prompt.get_node("Label_collect") as Label


func _ready() -> void:
	# Initial UI state
	exit_hold_prompt.visible = false
	collect_prompt.visible = false
	endscreen.visible = false

	if endscreen_camera:
		endscreen_camera.current = false

	exit_progress_bar.value = 0.0
	exit_label.text = "Hold E to Exit"
	collect_label.text = ""

	# Connect Endscreen buttons
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		player = body
		hold_timer = 0.0
		exit_progress_bar.value = 0.0
		_update_prompts()


func _on_body_exited(body: Node) -> void:
	if body == player:
		player = null
		is_holding = false
		hold_timer = 0.0
		exit_progress_bar.value = 0.0
		exit_hold_prompt.visible = false
		collect_prompt.visible = false


func _process(delta: float) -> void:
	if player == null:
		return

	# Not enough books – show collect prompt only
	if Global.books_collected < required_books:
		_update_collect_prompt()
		exit_hold_prompt.visible = false
		collect_prompt.visible = true
		is_holding = false
		hold_timer = 0.0
		exit_progress_bar.value = 0.0
		return

	# Enough books – show hold prompt, hide collect prompt
	collect_prompt.visible = false
	exit_hold_prompt.visible = true
	exit_label.text = "Hold E to Exit"

	if Input.is_action_pressed("interact"):  # E
		is_holding = true
		hold_timer += delta
		exit_progress_bar.value = clamp(hold_timer / hold_time_required, 0.0, 1.0)

		if hold_timer >= hold_time_required:
			_teleport_player()
	else:
		if is_holding:
			is_holding = false
			hold_timer = 0.0
			exit_progress_bar.value = 0.0


func _teleport_player() -> void:
	_show_endscreen()


func _show_endscreen() -> void:
	if player == null or endscreen == null:
		return

	if crosshair:
		crosshair.visible = false
	
	if stam:
		stam.visible = false
	
	if label:
		label.visible = false

	# Show mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	print("Showing Endscreen")  # Debug

	# Stop current music and play ambience
	if building_music and building_music.playing:
		building_music.stop()
		ambient_music.play()
	if ambient_music and ambient_music.playing:
		ambient_music.stop()
		ambient_music.play()

	# Switch to Endscreen camera
	if endscreen_camera:
		endscreen_camera.current = true

	# Show Endscreen UI
	endscreen.visible = true

	# Hide in-game UI
	exit_hold_prompt.visible = false
	collect_prompt.visible = false

	# Disable player input
	if player:
		player.set_physics_process(false)

	# Reset player state
	player = null
	is_holding = false
	hold_timer = 0.0
	exit_progress_bar.value = 0.0


func _update_prompts() -> void:
	if Global.books_collected < required_books:
		_update_collect_prompt()
		collect_prompt.visible = true
		exit_hold_prompt.visible = false
	else:
		collect_prompt.visible = false
		exit_hold_prompt.visible = true


func _update_collect_prompt() -> void:
	var current: int = Global.books_collected
	collect_label.text = "Collect %d / %d Books to Exit" % [current, required_books]


# --- Endscreen button callbacks ---
func _on_restart_pressed() -> void:
	# Reload current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
