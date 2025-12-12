extends Area3D

@export var hold_time_required: float = 1.0          # seconds to hold E
@export var teleport_target_path: NodePath           # assign TeleportTarget Marker3D in inspector
@export var ui_hold_prompt_path: NodePath            # assign UI/HoldPrompt in inspector

# --- Music nodes ---
@onready var building_music: AudioStreamPlayer2D = $"/root/World/ThemeMusic"
@onready var ambient_music: AudioStreamPlayer2D = $"/root/World/AmbientMusic"

var player: CharacterBody3D = null
var hold_timer: float = 0.0
var is_holding: bool = false

@onready var teleport_target: Node3D = get_node(teleport_target_path) as Node3D
@onready var hold_prompt: Control = get_node(ui_hold_prompt_path) as Control
@onready var progress_bar: ProgressBar = hold_prompt.get_node("Progress") as ProgressBar
@onready var label: Label = hold_prompt.get_node("Label_enter") as Label

# --- SFX ---
@onready var door_confirm_sfx: AudioStreamPlayer = $"/root/World/DoorConfirmSFX"

func _play_confirm_sfx() -> void:
	if door_confirm_sfx:
		door_confirm_sfx.stop()
		door_confirm_sfx.play()

func _ready() -> void:
	hold_prompt.visible = false
	progress_bar.value = 0.0
	label.text = "Hold E to Enter"


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		player = body
		hold_prompt.visible = true
		hold_timer = 0.0
		progress_bar.value = 0.0


func _on_body_exited(body: Node) -> void:
	if body == player:
		player = null
		hold_prompt.visible = false
		hold_timer = 0.0
		progress_bar.value = 0.0


func _process(delta: float) -> void:
	if player == null:
		return

	if Input.is_action_pressed("interact"):
		is_holding = true
		hold_timer += delta
		progress_bar.value = clamp(hold_timer / hold_time_required, 0.0, 1.0)

		if hold_timer >= hold_time_required:
			_play_confirm_sfx()
			_teleport_player()
			
	else:
		if is_holding:
			is_holding = false
			hold_timer = 0.0
			progress_bar.value = 0.0

func _teleport_player() -> void:
	if player == null or teleport_target == null:
		return

	# Teleport player
	player.global_transform.origin = teleport_target.global_transform.origin
	player.velocity = Vector3.ZERO

	# Hide UI
	hold_prompt.visible = false
	hold_timer = 0.0
	progress_bar.value = 0.0
	player = null
	is_holding = false

	# --- Music switch ---
	if building_music:
		# Stop ambient music only
		if ambient_music and ambient_music.playing:
			ambient_music.stop()

		# Restart building music from top
		building_music.stop()
		building_music.play()
