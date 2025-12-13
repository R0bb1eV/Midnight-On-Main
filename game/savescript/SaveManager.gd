extends Node

const SAVE_DIR := "user://saves/"
const SLOT_FILES := {
	1: "slot1.json",
	2: "slot2.json",
	3: "slot3.json",
}

var active_slot: int = 1

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func set_active_slot(slot: int) -> void:
	active_slot = clamp(slot, 1, 3)

func get_slot_path(slot: int) -> String:
	return SAVE_DIR + SLOT_FILES[clamp(slot, 1, 3)]

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

func delete_slot(slot: int) -> void:
	var path := get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_slot_meta(slot: int) -> Dictionary:
	# Returns lightweight info for UI (timestamp, books, scene)
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return {
		"timestamp": data.get("timestamp", ""),
		"books_collected": data.get("books_collected", 0),
		"scene_path": data.get("scene_path", "")
	}

func autosave() -> void:
	save_to_slot(active_slot)

func save_to_slot(slot: int) -> void:
	_ensure_save_dir()
	slot = clamp(slot, 1, 3)

	var data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"scene_path": get_tree().current_scene.scene_file_path,
		"books_collected": Global.books_collected,
		"total_books": Global.total_books,

		# Critical: which books are already collected (so they stay removed on load)
		"collected_book_ids": Global.collected_book_ids,

		# Optional: player position
		"player_pos": _get_player_pos()
	}

	var path := get_slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Failed to open for write: " + path)
		return
	f.store_string(JSON.stringify(data))
	f.close()

	print("[SaveManager] Saved slot", slot, "->", path)

func load_from_slot(slot: int) -> void:
	slot = clamp(slot, 1, 3)
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] No save in slot " + str(slot))
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveManager] Failed to open for read: " + path)
		return
	var text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveManager] Save file invalid JSON: " + path)
		return

	var data: Dictionary = parsed
	active_slot = slot

	# --- Apply globals first ---
	Global.books_collected = int(data.get("books_collected", 0))
	Global.total_books = int(data.get("total_books", Global.total_books))

	var raw_ids: Variant = data.get("collected_book_ids", [])
	var ids: Array = []
	if typeof(raw_ids) == TYPE_ARRAY:
		ids = raw_ids
	Global.collected_book_ids = ids

	# Player pos from save
	var player_pos: Vector3 = _vec3_from(data.get("player_pos", null))

	# Scene logic
	var saved_scene_path: String = str(data.get("scene_path", ""))
	var current_scene_path: String = ""
	if get_tree().current_scene:
		current_scene_path = get_tree().current_scene.scene_file_path

	# --- If we are already in the right scene ---
	if saved_scene_path == "" or saved_scene_path == current_scene_path:
		await get_tree().process_frame
		await get_tree().process_frame
		_set_player_pos(player_pos)
		apply_collected_books_to_scene()
		refresh_books_ui()
		print("[SaveManager] Loaded slot", slot, "(same scene) from", path)
		return

	# --- Otherwise change scene, then apply ---
	get_tree().change_scene_to_file(saved_scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_set_player_pos(player_pos)
	apply_collected_books_to_scene()
	refresh_books_ui()
	print("[SaveManager] Loaded slot", slot, "(scene changed) from", path)

func _get_player_pos() -> Variant:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return null
	return {"x": p.global_position.x, "y": p.global_position.y, "z": p.global_position.z}

func _set_player_pos(pos: Vector3) -> void:
	if pos == Vector3.ZERO:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		p.global_position = pos

func apply_collected_books_to_scene() -> void:
	var books := get_tree().get_nodes_in_group("books")
	for b in books:
		if b == null:
			continue
		# book script must have book_id
		if "book_id" in b:
			var id: String = str(b.book_id)
			if Global.collected_book_ids.has(id):
				b.queue_free()
			print("CHECK BOOK:", id, " collected=", Global.collected_book_ids.has(id))

func _vec3_from(v: Variant) -> Vector3:
	if typeof(v) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var d: Dictionary = v
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	
func refresh_books_ui() -> void:
	var label := get_tree().root.get_node_or_null("World/UI/Label") as Label
	if label:
		label.text = "Books: %d / %d" % [Global.books_collected, Global.total_books]
