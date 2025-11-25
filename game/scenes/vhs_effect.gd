extends CanvasLayer

@onready var mat: ShaderMaterial = $ColorRect.material

func _process(delta: float) -> void:
	if mat:
		var t: float = mat.get_shader_parameter("u_time")
		if t == null:
			t = 0.0
		mat.set_shader_parameter("u_time", t + delta)
