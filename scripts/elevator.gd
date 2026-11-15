extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var label_text: String = "[E] Take Elevator"

var prompt: Label3D
var player_inside: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 3.0, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.5
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.15, 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.7, 0.9)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.5
	mesh.surface_set_material(0, material)
	var platform := MeshInstance3D.new()
	platform.mesh = mesh
	platform.position.y = 0.08
	add_child(platform)
	prompt = Label3D.new()
	prompt.text = label_text
	prompt.position.y = 2.2
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.visible = false
	add_child(prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or not event.is_action_pressed("interact"):
		return
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_warning("Elevator target scene is missing: %s" % target_scene)
		return
	LevelManager.transition_to_level(target_scene)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt.visible = false
