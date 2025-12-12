extends Node

# Drag your random scare AudioStream files into this array in the Inspector
@export var sounds: Array[AudioStream] = []

# Random delay range between plays (seconds)
@export var min_delay: float = 5.0
@export var max_delay: float = 10.0

# Toggle random audio on/off
@export var enabled: bool = true

# If you accidentally instance this manager multiple times, this prevents duplicates
static var _already_running: bool = false

@onready var timer: Timer = $RandomTimer
@onready var player: AudioStreamPlayer = $AudioPlayer

func _ready() -> void:
	# --- Singleton guard ---
	if _already_running:
		queue_free()
		return
	_already_running = true

	randomize()

	# Timer must be one-shot so it doesn't auto-repeat
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)

	# (Optional) keep working even if the game pauses
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_ALWAYS

	if enabled and not sounds.is_empty():
		_schedule_next()
	else:
		print("[RandomScareStream] Not starting (enabled =", enabled, ", sounds =", sounds.size(), ")")

func _exit_tree() -> void:
	# Allow manager to be recreated cleanly on scene reload
	_already_running = false

func _schedule_next() -> void:
	if not enabled:
		return

	var delay: float = randf_range(min_delay, max_delay)
	delay = max(delay, 0.1) # Timer wait_time must be > 0

	print("[RandomScareStream] Next in", delay, "sec")

	timer.stop()
	timer.wait_time = delay
	timer.start()

func _on_timer_timeout() -> void:
	if not enabled:
		return
	if sounds.is_empty():
		print("[RandomScareStream] sounds is empty")
		_schedule_next()
		return

	var index: int = randi_range(0, sounds.size() - 1)
	print("[RandomScareStream] Playing index", index)

	player.stop()
	player.stream = sounds[index]
	player.play()

	# Schedule the next random play AFTER starting this one
	_schedule_next()

# --- Optional controls you can call from anywhere ---

func stop_all() -> void:
	enabled = false
	if timer:
		timer.stop()
	if player:
		player.stop()

func start_all() -> void:
	if enabled:
		return
	enabled = true
	if not sounds.is_empty():
		_schedule_next()

func play_now(index: int = -1) -> void:
	if sounds.is_empty():
		return
	var i: int = index
	if i < 0 or i >= sounds.size():
		i = randi_range(0, sounds.size() - 1)
	player.stop()
	player.stream = sounds[i]
	player.volume_db = -20.0
	player.play()
