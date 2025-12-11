extends Control

@export var main_scene_path: String = "res://Level.tscn"

func _ready():
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_button_pressed() -> void:
	# Reload main scene
	Global.books_collected = 0
	get_tree().change_scene_to_file(main_scene_path)
