# turret.gd
extends StaticBody3D

const FIRE_RATE: float = 1.5
const DAMAGE: float = 10.0
const RANGE: float = 20.0
const MAX_HP: float = 50.0

var hp: float = MAX_HP
var fire_timer: float = 0.0
var barrel_mesh: MeshInstance3D
var target_player: Node3D = null
var is_active: bool = true


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	_build_visuals()


func _build_visuals() -> void:
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.4
	base_mesh.bottom_radius = 0.5
	base_mesh.height = 0.6
	base.mesh = base_mesh
	base.position.y = 0.3
	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.3, 0.3, 0.35)
	base.material_override = base_mat
	add_child(base)

	barrel_mesh = MeshInstance3D.new()
	var barrel: CylinderMesh = CylinderMesh.new()
	barrel.top_radius = 0.08
	barrel.bottom_radius = 0.1
	barrel.height = 0.8
	barrel_mesh.mesh = barrel
	barrel_mesh.position = Vector3(0, 0.7, -0.3)
	barrel_mesh.rotation_degrees.x = -90
	var barrel_mat: StandardMaterial3D = StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.5, 0.1, 0.1)
	barrel_mat.emission_enabled = true
	barrel_mat.emission = Color(1.0, 0.2, 0.0) * 0.3
	barrel_mesh.material_override = barrel_mat
	add_child(barrel_mesh)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.5
	add_child(col)

	var label: Label3D = Label3D.new()
	label.text = "TURRET"
	label.font_size = 24
	label.position.y = 1.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.3, 0.3)
	add_child(label)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	target_player = players[0] as Node3D
	if target_player == null or PlayerStats.is_dead:
		return

	var dist: float = global_position.distance_to(target_player.global_position)
	if dist > RANGE:
		return

	var look_target: Vector3 = target_player.global_position
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.2:
		look_at(look_target, Vector3.UP)

	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire()
		fire_timer = FIRE_RATE


func _fire() -> void:
	if target_player == null:
		return

	var origin: Vector3 = global_position + Vector3(0, 0.7, 0)
	var dir: Vector3 = (target_player.global_position + Vector3(0, 1, 0) - origin).normalized()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE)
	query.collision_mask = 1 + 2
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	var hit_point: Vector3 = origin + dir * RANGE
	if not result.is_empty():
		hit_point = result["position"]
		var collider: Node = result["collider"] as Node
		if collider != null and collider.is_in_group("player"):
			PlayerStats.take_damage(DAMAGE)

	_create_tracer(origin, hit_point)

	var mat: StandardMaterial3D = barrel_mesh.material_override as StandardMaterial3D
	if mat != null:
		mat.emission = Color(1.0, 0.5, 0.0)
		mat.emission_energy_multiplier = 5.0
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):
			mat.emission = Color(1.0, 0.2, 0.0) * 0.3
			mat.emission_energy_multiplier = 1.0


func _create_tracer(from: Vector3, to: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var tracer: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	var length: float = from.distance_to(to)
	mesh.size = Vector3(0.03, 0.03, maxf(length, 0.1))
	tracer.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	scene_root.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	if length > 0.05:
		tracer.look_at(to, Vector3.UP)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(tracer.queue_free)


func take_damage(damage: float, _punch_type, _pos: Vector3) -> void:
	if not is_active:
		return
	hp -= damage
	print("[TURRET] hp %.0f" % hp)
	if hp <= 0.0:
		_destroy()


func apply_launch(_force: Vector3) -> void:
	pass


func apply_stagger(_force: Vector3) -> void:
	pass


func apply_knockback(_force: Vector3) -> void:
	pass


func apply_parry_stun() -> void:
	pass


func get_current_attack_damage() -> float:
	return DAMAGE


func _destroy() -> void:
	is_active = false
	var fx: Node = get_node_or_null("/root/FX")
	if fx != null and fx.has_method("spawn_explosion"):
		fx.call("spawn_explosion", global_position + Vector3(0, 0.5, 0))
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(queue_free)
