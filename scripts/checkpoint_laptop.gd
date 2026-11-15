extends Area3D

var prompt: Label3D
var player_inside: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	col.shape = box
	col.position.y = 0.75
	add_child(col)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	bm.surface_set_material(0, mat)
	mesh.mesh = bm
	mesh.position.y = 0.5
	add_child(mesh)

	prompt = Label3D.new()
	prompt.text = "[E] SAVE"
	prompt.position = Vector3(0, 1.2, 0)
	prompt.font_size = 20
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.visible = false
	add_child(prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return
	if event.is_action_pressed("interact"):
		PlayerStats.set_checkpoint(global_position, get_tree().current_scene.scene_file_path)
		if prompt != null:
			prompt.text = "SAVED!"
			_restore_prompt_after_delay()

func _restore_prompt_after_delay() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(prompt):
		prompt.text = "[E] SAVE"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		if prompt != null:
			prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if prompt != null:
			prompt.visible = false
