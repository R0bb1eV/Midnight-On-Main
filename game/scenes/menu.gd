extends Control

@onready var menu_camera: Camera3D = $Camera3D

var player: CharacterBody3D = null
var player_mesh: Node = null
var menu_active: bool = true

@onready var gameplay_ui: Node = $"/root/World/Stamina"
@onready var ui_label: Node = $"/root/World/UI"
@onready var menu_canvas: CanvasLayer = $CanvasLayer

@onready var menu_music: AudioStreamPlayer2D = $MenuMusic
@onready var gameplay_music: AudioStreamPlayer2D = $"/root/World/AmbientMusic"

# --- NEW: overlay UI ---
@onready var overlay: Control = $CanvasLayer/Overlay
@onready var htp_image: TextureRect = $CanvasLayer/Overlay/HTPImage
@onready var credits_image: TextureRect = $CanvasLayer/Overlay/CreditsImage
@onready var filter: ColorRect = $"../filter/ColorRect"

# --- NEW: saves UI ---
@onready var saves_panel: Control = $Saves
@onready var save_slots: VBoxContainer = $Saves/SaveSlots

@onready var slot1_label: Label = $Saves/SaveSlots/Slot1/Label
@onready var slot1_play: Button = $Saves/SaveSlots/Slot1/Button
@onready var slot1_delete: Button = $Saves/SaveSlots/Slot1/Button2

@onready var slot2_label: Label = $Saves/SaveSlots/Slot2/Label
@onready var slot2_play: Button = $Saves/SaveSlots/Slot2/Button
@onready var slot2_delete: Button = $Saves/SaveSlots/Slot2/Button2

@onready var slot3_label: Label = $Saves/SaveSlots/Slot3/Label
@onready var slot3_play: Button = $Saves/SaveSlots/Slot3/Button
@onready var slot3_delete: Button = $Saves/SaveSlots/Slot3/Button2

var camera_base_transform: Transform3D
@export var camera_move_radius: Vector2 = Vector2(0.25, 0.15)
@export var camera_tilt_angle: float = 2.0
@export var camera_speed: float = 0.4
var camera_time: float = 0.0


func _ready() -> void:
	if menu_camera:
		camera_base_transform = menu_camera.transform

	player = get_tree().current_scene.get_node("Character_Rigging") as CharacterBody3D
	if not player:
		push_error("Character_Rigging node not found!")

	player_mesh = player.get_node_or_null("Armature")

	var player_camera: Camera3D = player.get_node_or_null("CameraHolder/PivotPitch/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = false

	_freeze_player(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	$VBoxContainer/HTP.pressed.connect(_on_htp_pressed)

	# Make sure your Credits button path matches your scene:
	$VBoxContainer/Credits.pressed.connect(_on_credits_pressed)

	# --- NEW: save slot buttons ---
	slot1_play.pressed.connect(func(): _on_slot_play(1))
	slot2_play.pressed.connect(func(): _on_slot_play(2))
	slot3_play.pressed.connect(func(): _on_slot_play(3))

	slot1_delete.pressed.connect(func(): _on_slot_delete(1))
	slot2_delete.pressed.connect(func(): _on_slot_delete(2))
	slot3_delete.pressed.connect(func(): _on_slot_delete(3))

	call_deferred("_activate_menu_camera")

	if gameplay_ui: gameplay_ui.visible = false
	if ui_label: ui_label.visible = false
	if menu_canvas: menu_canvas.visible = true

	# Hide overlays at start
	_hide_overlay()

	# --- NEW: hide saves at start ---
	_hide_saves_menu()

	if menu_music:
		menu_music.play()


func _process(delta: float) -> void:
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


# --- NEW: Esc handling ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ui_cancel is Esc by default
		if overlay and overlay.visible:
			_hide_overlay()
			get_viewport().set_input_as_handled()
			return

		# --- NEW: close saves menu with Esc ---
		if saves_panel and saves_panel.visible:
			_hide_saves_menu()
			get_viewport().set_input_as_handled()
			return


func _activate_menu_camera() -> void:
	if menu_active and menu_camera:
		menu_camera.current = true


func _on_start_pressed() -> void:
	# --- NEW: Start opens SaveSlots instead of instantly starting ---
	_show_saves_menu()


func _start_gameplay_now() -> void:
	# This is your original start behavior, moved into its own function.
	menu_active = false
	_hide_overlay() # ensure overlays are gone
	_hide_saves_menu()

	_freeze_player(false)
	player.gameplay_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	self.visible = false
	if menu_canvas:
		menu_canvas.visible = false

	if menu_music and menu_music.playing:
		menu_music.stop()

	if gameplay_music:
		gameplay_music.play()

	if gameplay_ui: gameplay_ui.visible = true
	if ui_label: ui_label.visible = true

	call_deferred("_activate_player_camera")


func _activate_player_camera() -> void:
	if not player:
		return
	var player_camera: Camera3D = player.get_node_or_null("CameraHolder/PivotPitch/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _freeze_player(state: bool) -> void:
	if player_mesh:
		player_mesh.visible = not state
	player.set_process_input(not state)
	player.set_process(not state)
	player.set_physics_process(not state)


# --- NEW: overlay helpers ---
func _show_overlay(which: String) -> void:
	if not overlay:
		return
	overlay.visible = true
	filter.visible = false

	if htp_image: htp_image.visible = (which == "htp")
	if credits_image: credits_image.visible = (which == "credits")


func _hide_overlay() -> void:
	if overlay:
		overlay.visible = false
		filter.visible = true
	if htp_image:
		htp_image.visible = false
		filter.visible = true
	if credits_image:
		credits_image.visible = false
		filter.visible = true


func _on_htp_pressed() -> void:
	_show_overlay("htp")


func _on_credits_pressed() -> void:
	_show_overlay("credits")


# --- NEW: saves menu helpers ---
func _show_saves_menu() -> void:
	_hide_overlay()

	$VBoxContainer.visible = false
	saves_panel.visible = true
	save_slots.visible = true

	_refresh_save_slots()


func _hide_saves_menu() -> void:
	saves_panel.visible = false
	save_slots.visible = false
	$VBoxContainer.visible = true


func _refresh_save_slots() -> void:
	_apply_slot_ui(1, slot1_label, slot1_play, slot1_delete)
	_apply_slot_ui(2, slot2_label, slot2_play, slot2_delete)
	_apply_slot_ui(3, slot3_label, slot3_play, slot3_delete)

func show_menu() -> void:
	menu_active = true
	visible = true
	if menu_canvas:
		menu_canvas.visible = true
	if gameplay_ui: gameplay_ui.visible = false
	if ui_label: ui_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if menu_music and not menu_music.playing:
		menu_music.play()
	call_deferred("_activate_menu_camera")

func _apply_slot_ui(slot: int, info_label: Label, play_btn: Button, del_btn: Button) -> void:
	var exists: bool = SaveManager.slot_exists(slot)

	if exists:
		var meta: Dictionary = SaveManager.get_slot_meta(slot)
		var books: int = int(meta.get("books_collected", 0))
		info_label.text = "Slot %d — Books: %d / 5" % [slot, books]
		play_btn.text = "Continue"
		del_btn.disabled = false
	else:
		info_label.text = "Slot %d — Empty" % [slot]
		play_btn.text = "New Game"
		del_btn.disabled = true


func _on_slot_play(slot: int) -> void:
	SaveManager.set_active_slot(slot)

	if SaveManager.slot_exists(slot):
		await SaveManager.load_from_slot(slot)
	else:
		Global.books_collected = 0
		Global.collected_book_ids = []
		SaveManager.save_to_slot(slot)

	_start_gameplay_now()


func _on_slot_delete(slot: int) -> void:
	SaveManager.delete_slot(slot)
	_refresh_save_slots()
