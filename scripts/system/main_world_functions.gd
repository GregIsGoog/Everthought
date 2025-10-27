extends Node2D

var open_ui: bool = false

@onready var skeleton_instance = preload("res://scenes/sub/scene_sub_skeleton.tscn").instantiate()

func _physics_process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _process(delta):
	if not open_ui:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif open_ui:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _ready():
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		enemy.connect("died", Callable(self, "spawn_new_enemy"))

func die():
	_physics_process(false)

