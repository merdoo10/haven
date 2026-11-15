# pickup.gd — Standalone script, spawned by enemies on death
extends Area3D

enum PickupType { CPU, RAM }

var pickup_type: PickupType = PickupType.CPU
var magnet_speed: float = 8.0
var magnet_range: float = 3.0
var is_magnetized: bool = false
var target_player: Node3D = null
var float_time: float = 0.0

const CPU_HEAL: float = 15.0
const RAM_TECH: float = 15.0


static func spawn(parent: Node, pos: Vector3, type: PickupType) -> void:
	var pickup := Area3D.new()
	pickup.set_script(load("res://scripts/pickup.gd"))
	pickup.set("pickup_type", type)
	pickup.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
	parent.get_tree().current_scene.add_child(pickup)


func _ready() -> void:
	# Collision
	collision_layer = 8  # Layer 4
	collision_mask = 2   # Player layer
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	col.shape = sphere
	add_child(col)

	# Visual
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()

	match pickup_type:
		PickupType.CPU:
			box.size = Vector3(0.2, 0.2, 0.2)
			add_to_group("pickup_cpu")
		PickupType.RAM:
			box.size = Vector3(0.25, 0.1, 0.15)
			add_to_group("pickup_ram")

	mesh.mesh = box
	var mat := StandardMaterial3D.new()

	match pickup_type:
		PickupType.CPU:
			mat.albedo_color = Color(0.1, 0.9, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.9, 0.2)
			mat.emission_energy_multiplier = 2.0
		PickupType.RAM:
			mat.albedo_color = Color(0.2, 0.5, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.5, 1.0)
			mat.emission_energy_multiplier = 2.0

	mesh.material_override = mat
	add_child(mesh)

	body_entered.connect(_on_body_entered)

	# Initial pop-up velocity
	var tween := create_tween()
	tween.tween_property(self, "position:y", global_position.y + 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", global_position.y + 0.3, 0.2).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	# Float animation
	float_time += delta
	position.y += sin(float_time * 3.0) * 0.003

	# Rotate
	rotate_y(delta * 2.0)

	# Magnet to player
	if not is_magnetized:
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player: Node3D = players[0] as Node3D
			if global_position.distance_to(player.global_position) < magnet_range:
				is_magnetized = true
				target_player = player

	if is_magnetized and target_player != null:
		var dir := (target_player.global_position + Vector3(0, 1, 0) - global_position).normalized()
		global_position += dir * magnet_speed * delta
		magnet_speed += 15.0 * delta  # Accelerate


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	match pickup_type:
		PickupType.CPU:
			PlayerStats.heal(CPU_HEAL)
			print("[PICKUP] CPU +%.0f HP" % CPU_HEAL)
		PickupType.RAM:
			PlayerStats.add_tech(RAM_TECH)
			print("[PICKUP] RAM +%.0f TECH" % RAM_TECH)

	queue_free()
