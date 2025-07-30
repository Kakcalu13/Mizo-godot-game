extends Area3D

# -- Shake Config --
@export var shake_time = 0.1
@export var shake_strength = 0.1

# -- State --
var _shaking = false
var _shake_timer = 0.0
var _original_position: Vector3
var _mouse_inside = false
var _dragging = false

# -- Cached node references --
var _particles_top: GPUParticles3D
var _particles_main: GPUParticles3D

func _ready():
	_original_position = global_transform.origin
	
	# Cache references to your particle nodes
	_particles_main = $window/window/GPUParticles3D
	_particles_top = $window/window/top

	_stop_drag_effects()


func _process(delta):
	if _shaking:
		_shake_timer += delta
		if _shake_timer < shake_time:
			var offset = Vector3(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
			global_transform.origin = _original_position + offset
		else:
			global_transform.origin = _original_position
			_shaking = false


func _on_mouse_entered():
	if not _mouse_inside:
		_mouse_inside = true
		_start_shake()


func _on_mouse_exited():
	_mouse_inside = false


func _input(event):
	if event is InputEventMouseButton and not Input.is_action_pressed("hold_click"):
		if event.pressed:
			_start_drag_effects()
			_dragging = true
		else:
			global_transform.origin = _original_position
			_stop_drag_effects()
			_dragging = false

	elif event is InputEventMouseMotion and Input.is_action_pressed("hold_click"):
		var offset = Vector3(event.relative.x, -event.relative.y, 0) * 0.011
		global_translate(offset)
		if not _dragging:
			_start_drag_effects()
			_dragging = true

	else:
		# Optional fallback if needed
		if _dragging:
			_stop_drag_effects()
			_dragging = false



func _start_shake():
	_shaking = true
	_shake_timer = 0.0


func _start_drag_effects():
	_particles_main.emitting = true
	_particles_top.emitting = false


func _stop_drag_effects():
	_particles_main.emitting = false
	_particles_top.emitting = true
