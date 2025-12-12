extends Control

@onready var menu_camera: Camera3D = $Camera3D

var player: CharacterBody3D = null
var player_mesh: Node = null
var menu_active: bool = true

@onready var gameplay_ui: Node = $"/root/World/Stamina"
@onready var ui_label: Node = $"/root/World/UI"
@onready var menu_canvas: CanvasLayer = $CanvasLayer

@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var gameplay_music: AudioStreamPlayer2D = $"/root/World/AmbientMusic"

# --- NEW: overlay UI ---
@onready var overlay: Control = $CanvasLayer/Overlay
@onready var htp_image: TextureRect = $CanvasLayer/Overlay/HTPImage
@onready var credits_image: TextureRect = $CanvasLayer/Overlay/CreditsImage
@onready var filter: ColorRect = $"../filter/ColorRect"

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

	call_deferred("_activate_menu_camera")

	if gameplay_ui: gameplay_ui.visible = false
	if ui_label: ui_label.visible = false
	if menu_canvas: menu_canvas.visible = true

	# Hide overlays at start
	_hide_overlay()

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


func _activate_menu_camera() -> void:
	if menu_active and menu_camera:
		menu_camera.current = true


func _on_start_pressed() -> void:
	menu_active = false
	_hide_overlay() # ensure overlays are gone

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
