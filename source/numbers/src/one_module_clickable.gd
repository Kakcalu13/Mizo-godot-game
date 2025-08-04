extends Area3D

# -- Shake Config --
@export var shake_time = 0.1
@export var shake_strength = 0.1
@export var value = 0
@export var return_speed := 5.0  # Adjust for speed of returning

# -- State --
var _shaking = false
var _shake_timer = 0.0
var _original_position: Vector3
var _returning_home := false
var _mouse_inside = false
var _dragging = false
# -- Cached node references --
var _particles_top: GPUParticles3D
var _particles_main: GPUParticles3D

func _ready():
	_original_position = self.transform.origin
	
	# Cache references to your particle nodes
	_particles_main = $window/window/GPUParticles3D
	_particles_top = $window/window/top
	_stop_drag_effects()


func _process(delta):
	if _returning_home:
		var current_pos = self.transform.origin
		var new_pos = current_pos.lerp(_original_position, return_speed * delta)
		self.transform.origin = new_pos

		if current_pos.distance_to(_original_position) < 0.01:
			self.transform.origin = _original_position
			_returning_home = false
			_stop_drag_effects()
			_dragging = false
	if _shaking:
		_shake_timer += delta
		if _shake_timer < shake_time:
			var offset = Vector3(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
			self.transform.origin = _original_position + offset
		else:
			self.transform.origin = _original_position
			_shaking = false


func _on_mouse_entered():
	if not _mouse_inside:
		_mouse_inside = true
		_start_shake()


func _on_mouse_exited():
	_mouse_inside = false
	_stop_drag_effects()
	_dragging = false


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not Input.is_action_pressed("hold_click"):
		if event.pressed:
			_start_drag_effects()
			_dragging = true
		else:
			self.transform.origin = _original_position
			_stop_drag_effects()
			_dragging = false

	elif event is InputEventMouseMotion and Input.is_action_pressed("hold_click"):
		var offset = Vector3(event.relative.x, -event.relative.y, 0) * 0.011
		#global_translate(offset)
		self.transform.origin += offset
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


func _on_area_entered(area: Area3D) -> void:
	if self.value == area.value:
		var grab_player = get_node("./window/window/AnimationPlayer")
		get_node("./text").visible = false
		get_node("./sign").visible = false
		grab_player.active = true
		get_node("./window/exploded").emitting = true
	else:
		_returning_home = true


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	var window_list = $"..".window_list
	var index = window_list.find(self)
	if index != -1:
		window_list.remove_at(index)
	self.queue_free()
	if len(window_list) == 0:
		get_parent().start_new_game()
