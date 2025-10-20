extends Area3D

# Exports
@export var camera_path: NodePath
@export var value: int = 0  # your matching value

# -- Shake & Return (unchanged) --
@export var shake_time = 0.1
@export var shake_strength = 0.1
@export var return_speed := 5.0

# State
var _original_position: Vector3
var _dragging = false
var _drag_depth = 0.0
var _drag_offset = Vector3.ZERO
# -- State --
var _shaking = false
var _shake_timer = 0.0
var _returning_home := false
var _mouse_inside = false
# -- Cached node references --
var _particles_top: GPUParticles3D
var _particles_main: GPUParticles3D

# Nodes
var _camera: Camera3D

func _ready():
	_original_position = global_transform.origin
	_camera = get_parent().get_child(0)
	_particles_main = $window/window/GPUParticles3D
	_particles_top = $window/window/top
	_start_drag_effects()
	_stop_drag_effects()

func _on_input_event(_camera_node, event: InputEvent, _pos, _normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dragging = true
			var ray_origin = _camera.project_ray_origin(event.position)
			var ray_dir    = _camera.project_ray_normal(event.position)
			_drag_depth = ray_origin.distance_to(global_transform.origin) 
			var hit_point = ray_origin + ray_dir * _drag_depth
			_drag_offset = global_transform.origin - hit_point
			_start_drag_effects()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			global_transform.origin = _original_position
			_stop_drag_effects()

	elif event is InputEventMouseMotion and _dragging:
		var ray_origin = _camera.project_ray_origin(event.position)
		var ray_dir    = _camera.project_ray_normal(event.position)
		var hit_point  = ray_origin + ray_dir * _drag_depth
		global_transform.origin = hit_point + _drag_offset


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

#
	#else:
		#print(event)
		#if _dragging:
			#print("hjere")
			#_stop_drag_effects()
			#_dragging = false



func _start_shake():
	_shaking = true
	_shake_timer = 0.0
	$hover.play()


func _start_drag_effects():
	_particles_main.emitting = true
	_particles_top.emitting = false
	$humming.play()


func _stop_drag_effects():
	_particles_main.emitting = false
	_particles_top.emitting = true
	$humming.stop()


func _on_area_entered(area: Area3D) -> void:
	if self.value == area.value:
		var grab_player = get_node("./window/window/AnimationPlayer")
		get_node("./text").visible = false
		get_node("./sign").visible = false
		grab_player.active = true
		get_node("./window/exploded").emitting = true
		$exploded_sound.play()
		$humming.stop()
		get_parent().correct_total += 0.5
		get_parent().find_child("background_shader").get_child(2).text = str(get_parent().correct_total)
	else:
		_dragging = false
		_returning_home = true
		_stop_drag_effects()
		$humming.stop()
		get_parent().wrong_total += 0.5
		get_parent().find_child("background_shader").get_child(4).text = str(get_parent().wrong_total)


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	var window_list = $"..".window_list
	var index = window_list.find(self)
	if index != -1:
		window_list.remove_at(index)
	self.queue_free()
	$humming.stop()
	if len(window_list) == 0:
		get_parent().start_new_game()
