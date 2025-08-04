extends WorldEnvironment

var window_transforms = {
	1: { position = Vector3(-4.265, 1.5, 0), rotation = Vector3(0.087266, 0.436332, 0.015708), scale = Vector3(0.6, 0.6, 0.6) },
	2: { position = Vector3(-4.265, -1, 0), rotation = Vector3(0.087266, 0.436332, 0.015708), scale = Vector3(0.6, 0.6, 0.6) },
	3: { position = Vector3(-4.265, -3.5, 0), rotation = Vector3(0.087266, 0.436332, 0.015708), scale = Vector3(0.6, 0.6, 0.6) },
	4: { position = Vector3(4.265, 1.5, 0), rotation = Vector3(0.087266, -0.087267, 0.015708), scale = Vector3(0.6, 0.6, 0.6) },
	5: { position = Vector3(4.265, -1, 0), rotation = Vector3(0.087266, -0.087267, 0.015708), scale = Vector3(0.6, 0.6, 0.6) },
	6: { position = Vector3(4.265, -3.5, 0), rotation = Vector3(0.087266, -0.087267, 0.015708), scale = Vector3(0.6, 0.6, 0.6) }
}
var window_list = []
var banned_list = ["robocop.gdshader", "color_sky.gdshader"]
var WindowScene = preload("res://one_module.tscn")

func _ready() -> void:
	start_new_game()

func start_new_game():
	create_windows()
	window_list.shuffle()
	swap_window_id()
	_load_random_shader_material()

func _get_shuffled_array(arr: Array):
	var copy = arr.duplicate()
	copy.shuffle()
	return copy

func _process_window(window, key, value):
	window.value = key
	if value == 1:
		window.get_node("sign").visible = true
		window.get_node("text").visible = false
		var new_material = StandardMaterial3D.new()
		var sign_mesh = window.get_node("sign/White_background/sign")
		new_material.albedo_texture = load("res://assets/signs/" + str(data_structure.data[key][1]) + ".png")
		sign_mesh.set_surface_override_material(0, new_material)
	else:
		window.get_node("sign").visible = false
		window.get_node("text").visible = true
		var label = window.get_node("text/Text_3D")
		label.text = str(data_structure.data[key][value])

func create_windows():
	for key in window_transforms:
		var window = WindowScene.instantiate()
		var t = Transform3D()
		t.origin = window_transforms[key].position
		t.basis = Basis.from_euler(Vector3(window_transforms[key].rotation))
		t.basis = t.basis.scaled(window_transforms[key].scale)
		window.global_transform = t
		window_list.append(window)
		add_child(window)

func swap_window_id():
	var keys_for_pairs = _get_shuffled_array(range(1, 11)).slice(0, 3)
	
	# Pair windows: [0,1], [2,3], [4,5]
	for i in range(0, window_list.size(), 2):
		var window_a = window_list[i]
		var window_b = window_list[i + 1]
		var pair_key = keys_for_pairs[i / 2]
		var available_values = _get_shuffled_array([0, 1, 2])

		_process_window(window_a, pair_key, available_values[0])
		_process_window(window_b, pair_key, available_values[1])

func _load_random_shader_material() -> void:
	var dir = DirAccess.open("res://assets/shaders/")
	var shaders: Array = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gdshader") and file_name not in banned_list:
				var shader_res = load("res://assets/shaders/" + file_name)
				shaders.append({"shader": shader_res, "filename": file_name})
			file_name = dir.get_next()
		dir.list_dir_end()

	if shaders.size() > 0:
		var picked = shaders[randi() % shaders.size()]
		var random_shader = picked["shader"]
		var filename = picked["filename"]
		var color_rect = $background_shader/SubViewport/ColorRect
		var mat = ShaderMaterial.new()
		mat.shader = random_shader
		color_rect.material = mat
		print("Applied shader: ", filename)
