extends WorldEnvironment

func _ready() -> void:
	var number = randi_range(1, 10)
	print(data_structure.data[number])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
