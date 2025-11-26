extends Area3D

@export var hold_time_required: float = 1.0              # seconds to hold E
@export var required_books: int = 5                      # how many needed to leave
@export var teleport_target_path: NodePath               # Marker3D to teleport to
@export var ui_exit_hold_prompt_path: NodePath           # ExitHoldPrompt Control
@export var ui_collect_prompt_path: NodePath             # CollectPrompt Control

var player: CharacterBody3D = null
var hold_timer: float = 0.0
var is_holding: bool = false

@onready var teleport_target: Node3D = get_node(teleport_target_path) as Node3D

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

	exit_progress_bar.value = 0.0
	exit_label.text = "Hold E to Exit"

	collect_label.text = ""

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
		# no hold logic while locked
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
		var t: float = clamp(hold_timer / hold_time_required, 0.0, 1.0)
		exit_progress_bar.value = t

		if hold_timer >= hold_time_required:
			_teleport_player()
	else:
		if is_holding:
			is_holding = false
			hold_timer = 0.0
			exit_progress_bar.value = 0.0

func _teleport_player() -> void:
	if player == null or teleport_target == null:
		return

	player.global_transform.origin = teleport_target.global_transform.origin
	player.velocity = Vector3.ZERO

	# Reset UI & state
	exit_hold_prompt.visible = false
	collect_prompt.visible = false
	hold_timer = 0.0
	exit_progress_bar.value = 0.0
	player = null
	is_holding = false

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
