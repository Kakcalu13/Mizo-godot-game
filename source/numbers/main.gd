extends WorldEnvironment

var location_of_window = {1: Vector3(-4.265, 0, 0), 2: Vector3(-4.265, -1.5, 0), 3: Vector3(-4.265, -3, 0)}
var window_list = []

func _ready() -> void:
	window_list = [$left_window_1, $left_window_2, $left_window_3, $right_window_1, $right_window_2, $right_window_3]
	window_list.shuffle()

	var keys_for_pairs = _get_shuffled_array(range(1, 11)).slice(0, 3)
	
	# Pair windows: [0,1], [2,3], [4,5]
	for i in range(0, 6, 2):
		var window_a = window_list[i]
		var window_b = window_list[i + 1]
		var pair_key = keys_for_pairs[i / 2]
		var available_values = _get_shuffled_array([0, 1, 2])

		_process_window(window_a, pair_key, available_values[0])
		_process_window(window_b, pair_key, available_values[1])

func _get_shuffled_array(arr: Array):
	var copy = arr.duplicate()
	copy.shuffle()
	return copy

func _process_window(window, key, value):
	window.value = key
	if value == 1: # this willd isplays like 001, 002 etc etc as a value
		window.get_node("sign").visible = true
		window.get_node("text").visible = false
		var new_material = StandardMaterial3D.new()
		var sign_mesh = window.get_node("sign/White_background/sign")
		new_material.albedo_texture = load("res://assets/signs/" + str(data_structure.data[key][1]) + ".png")
		sign_mesh.set_surface_override_material(0, new_material)
	else:  # can be updated with just a text/string
		window.get_node("sign").visible = false
		window.get_node("text").visible = true
		var label = window.get_node("text/Text_3D")
		label.text = str(data_structure.data[key][value])
