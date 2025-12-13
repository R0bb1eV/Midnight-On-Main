extends Node3D

@export var book_id: String = ""
# Player is in range flag
var player_in_range := false

func _ready():
	# Connect signals
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	
	if book_id == "":
		# fallback: node name is fine IF you don’t spawn duplicate names
		book_id = name
	
	add_to_group("books")
	
	if Global.collected_book_ids.has(book_id):
		queue_free()
		return
	
	# Check for overlapping bodies at start (handles player starting inside)
	for body in $Area3D.get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body):
	print("[DEBUG] Body entered Area3D:", body.name)
	if body.is_in_group("player"):
		player_in_range = true
		print("[DEBUG] Player entered book pickup range:", name)

func _on_body_exited(body):
	print("[DEBUG] Body exited Area3D:", body.name)
	if body.is_in_group("player"):
		player_in_range = false
		print("[DEBUG] Player LEFT book pickup range:", name)

func pick_up():
	print("[DEBUG] Book collected:", name)
	print("PICKUP ID:", book_id)

	if Global.collected_book_ids.has(book_id):
		return

	Global.collected_book_ids.append(book_id)
	Global.books_collected += 1

	var label = get_tree().root.get_node("World/UI/Label")
	if label:
		label.text = "Books: %d / %d" % [Global.books_collected, Global.total_books]

	# autosave AFTER updating global state
	SaveManager.autosave()

	queue_free()

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		pick_up()
