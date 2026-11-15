# boss_alien.gd
extends CharacterBody3D

class PickupItem extends Area3D:
	var ptype: int = 0
	var float_time: float = 0.0
	var magnetized: bool = false
	var magnet_speed: float = 8.0
	var follow_target: Node3D = null

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2
		var col: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.5
		col.shape = sphere
		add_child(col)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		if ptype == 0:
			box.size = Vector3(0.2, 0.2, 0.2)
			mat.albedo_color = Color(0.1, 0.9, 0.2)
			mat.emission = Color(0.1, 0.9, 0.2)
		else:
			box.size = Vector3(0.26, 0.12, 0.16)
			mat.albedo_color = Color(0.2, 0.5, 1.0)
			mat.emission = Color(0.2, 0.5, 1.0)
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 2.0
		mesh_inst.mesh = box
		mesh_inst.material_override = mat
		add_child(mesh_inst)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		float_time += delta
		rotate_y(delta * 2.5)
		if not magnetized:
			position.y += sin(float_time * 3.0) * 0.004
			var players: Array = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				var pl: Node3D = players[0] as Node3D
				if pl != null and global_position.distance_to(pl.global_position) < 4.0:
					magnetized = true
					follow_target = pl
		else:
			if follow_target != null and is_instance_valid(follow_target):
				var dir: Vector3 = (follow_target.global_position + Vector3(0, 1, 0) - global_position).normalized()
				global_position += dir * magnet_speed * delta
				magnet_speed += 20.0 * delta
			else:
				magnetized = false

	func _on_body_entered(body: Node3D) -> void:
		if body.is_in_group("player"):
			if ptype == 0:
				PlayerStats.heal(15.0)
			else:
				PlayerStats.add_tech(15.0)
			queue_free()


enum BossState { IDLE, CHASE, SPIN_ATTACK, COOLDOWN, DYING }

const MAX_HEALTH: float = 800.0
const CHASE_SPEED: float = 5.5
const SPIN_DAMAGE: float = 30.0
const SPIN_RANGE: float = 3.0
const SPIN_DURATION: float = 1.2
const COOLDOWN_DURATION: float = 2.0
const ATTACK_RANGE: float = 3.0
const SPIN_HIT_INTERVAL: float = 0.4

var current_health: float = MAX_HEALTH
var state: int = BossState.IDLE
var state_timer: float = 0.0
var spin_hit_timer: float = 0.0
var target_player: Node3D = null

var drop_thresholds: Array[float] = [0.75, 0.50, 0.25]
var next_drop_index: int = 0

var body_mesh: MeshInstance3D
var boss_visual: Node3D
var boss_visual_base_scale: Vector3 = Vector3.ONE
var health_bar_fill: MeshInstance3D
var default_color: Color = Color(0.1, 0.8, 0.3)


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1 + 2
	state_timer = 1.0
	_build_visuals()


func _build_visuals() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.8
	capsule.height = 3.0
	col.shape = capsule
	col.position.y = 0.5
	add_child(col)

	if not _load_boss_model():
		body_mesh = MeshInstance3D.new()
		var mesh: CapsuleMesh = CapsuleMesh.new()
		mesh.radius = 0.75
		mesh.height = 2.8
		body_mesh.mesh = mesh
		body_mesh.position.y = 0.5
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = default_color
		mat.emission_enabled = true
		mat.emission = default_color * 0.4
		mat.emission_energy_multiplier = 1.5
		body_mesh.material_override = mat
		add_child(body_mesh)
		boss_visual = body_mesh
		boss_visual_base_scale = Vector3.ONE
		for side in [-0.4, 0.4]:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var leg_mesh: CylinderMesh = CylinderMesh.new()
			leg_mesh.top_radius = 0.15
			leg_mesh.bottom_radius = 0.2
			leg_mesh.height = 1.0
			leg.mesh = leg_mesh
			leg.position = Vector3(side, 0.5, 0.0)
			var leg_mat: StandardMaterial3D = StandardMaterial3D.new()
			leg_mat.albedo_color = default_color * 0.7
			leg.material_override = leg_mat
			add_child(leg)
		for side in [-0.3, 0.3]:
			var eye: MeshInstance3D = MeshInstance3D.new()
			var eye_mesh: SphereMesh = SphereMesh.new()
			eye_mesh.radius = 0.15
			eye_mesh.height = 0.3
			eye.mesh = eye_mesh
			eye.position = Vector3(side, 2.4, -0.55)
			var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.0, 0.0)
			eye_mat.emission_energy_multiplier = 3.0
			eye.material_override = eye_mat
			add_child(eye)

	var bg: MeshInstance3D = MeshInstance3D.new()
	var bg_mesh: BoxMesh = BoxMesh.new()
	bg_mesh.size = Vector3(2.0, 0.1, 0.03)
	bg.mesh = bg_mesh
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.0, 0.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	bg.position.y = 3.5
	add_child(bg)

	health_bar_fill = MeshInstance3D.new()
	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(1.96, 0.08, 0.04)
	health_bar_fill.mesh = fill_mesh
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(1.0, 0.0, 0.0)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(1.0, 0.0, 0.0) * 0.5
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_bar_fill.material_override = fill_mat
	health_bar_fill.position.y = 3.5
	add_child(health_bar_fill)

	var label: Label3D = Label3D.new()
	label.text = "XENO-KICKER"
	label.font_size = 48
	label.position.y = 3.85
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.3, 0.3)
	add_child(label)

func _load_boss_model() -> bool:
	const MODEL_PATH := "res://Assets/haven-main/havenboss.fbx"
	if not ResourceLoader.exists(MODEL_PATH):
		push_warning("Boss model is missing: %s" % MODEL_PATH)
		return false
	var resource: Resource = load(MODEL_PATH)
	if not (resource is PackedScene):
		push_warning("Boss model could not be loaded as a scene: %s" % MODEL_PATH)
		return false
	boss_visual = (resource as PackedScene).instantiate() as Node3D
	if boss_visual == null:
		return false
	boss_visual.name = "BossAlienModel"
	add_child(boss_visual)
	var bounds: AABB = _collect_model_bounds(boss_visual, boss_visual)
	if bounds.size.y > 0.001:
		var fit_scale: float = 2.8 / bounds.size.y
		boss_visual.scale = Vector3.ONE * fit_scale
		boss_visual_base_scale = boss_visual.scale
		boss_visual.position.y = -1.0 - bounds.position.y * fit_scale
	body_mesh = _find_first_mesh(boss_visual)
	return true

func _collect_model_bounds(root: Node3D, node: Node) -> AABB:
	var bounds := AABB()
	var has_bounds: bool = false
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
			mesh_bounds = root.global_transform.affine_inverse() * mesh_instance.global_transform * mesh_bounds
			bounds = mesh_bounds
			has_bounds = true
	for child in node.get_children():
		var child_bounds: AABB = _collect_model_bounds(root, child)
		if child_bounds.size != Vector3.ZERO:
			bounds = child_bounds if not has_bounds else bounds.merge(child_bounds)
			has_bounds = true
	return bounds if has_bounds else AABB()

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_first_mesh(child)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	if state == BossState.DYING:
		return

	if not is_on_floor():
		velocity.y -= 25.0 * delta

	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		move_and_slide()
		return

	target_player = players[0] as Node3D
	if target_player == null or PlayerStats.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		move_and_slide()
		return

	state_timer -= delta

	if state == BossState.IDLE:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		if state_timer <= 0.0:
			state = BossState.CHASE

	elif state == BossState.CHASE:
		var to_player: Vector3 = target_player.global_position - global_position
		to_player.y = 0.0
		var dist: float = to_player.length()

		if dist > ATTACK_RANGE:
			var move_dir: Vector3 = to_player.normalized()
			velocity.x = move_dir.x * CHASE_SPEED
			velocity.z = move_dir.z * CHASE_SPEED
			var look_target: Vector3 = target_player.global_position
			look_target.y = global_position.y
			if global_position.distance_to(look_target) > 0.2:
				look_at(look_target, Vector3.UP)
		else:
			state = BossState.SPIN_ATTACK
			state_timer = SPIN_DURATION
			spin_hit_timer = 0.0
			print("[BOSS] SPINNY KICK!")

	elif state == BossState.SPIN_ATTACK:
		rotate_y(delta * 20.0)
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

		spin_hit_timer -= delta
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist < SPIN_RANGE and spin_hit_timer <= 0.0:
			spin_hit_timer = SPIN_HIT_INTERVAL
			PlayerStats.take_damage(SPIN_DAMAGE)
			var kb: Vector3 = (target_player.global_position - global_position).normalized() * 10.0
			kb.y = 4.0
			if target_player.has_method("apply_knockback"):
				target_player.call("apply_knockback", kb)
			print("[BOSS] spin kick hit")

		var mat_spin: StandardMaterial3D = null
		if body_mesh != null:
			mat_spin = body_mesh.material_override as StandardMaterial3D
		if mat_spin != null:
			mat_spin.emission = Color(0.0, 1.0, 0.0)
			mat_spin.emission_energy_multiplier = 4.0

		if state_timer <= 0.0:
			state = BossState.COOLDOWN
			state_timer = COOLDOWN_DURATION
			if mat_spin != null:
				mat_spin.emission = default_color * 0.4
				mat_spin.emission_energy_multiplier = 1.5

	elif state == BossState.COOLDOWN:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		var breathe: float = 1.0 + sin(state_timer * 5.0) * 0.05
		if boss_visual != null:
			boss_visual.scale = boss_visual_base_scale * Vector3(breathe, 1.0, breathe)
		if state_timer <= 0.0:
			state = BossState.CHASE
			if boss_visual != null:
				boss_visual.scale = boss_visual_base_scale

	move_and_slide()


func take_damage(damage: float, _punch_type, _attacker_pos: Vector3) -> void:
	if state == BossState.DYING:
		return

	current_health -= damage
	_update_health_bar()
	_flash_hit()

	var health_ratio: float = current_health / MAX_HEALTH
	while next_drop_index < drop_thresholds.size() and health_ratio <= drop_thresholds[next_drop_index]:
		_drop_loot()
		next_drop_index += 1

	if current_health <= 0.0:
		_die()


func apply_launch(_force: Vector3) -> void:
	pass


func apply_stagger(_force: Vector3) -> void:
	pass


func apply_knockback(force: Vector3) -> void:
	velocity += force * 0.3


func apply_parry_stun() -> void:
	if state == BossState.DYING:
		return
	state = BossState.COOLDOWN
	state_timer = 1.0


func get_current_attack_damage() -> float:
	return SPIN_DAMAGE


func _update_health_bar() -> void:
	var ratio: float = clampf(current_health / MAX_HEALTH, 0.0, 1.0)
	health_bar_fill.scale.x = ratio
	health_bar_fill.position.x = -(1.0 - ratio) * 0.98


func _flash_hit() -> void:
	if body_mesh == null:
		return
	var mat: StandardMaterial3D = body_mesh.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		mat.albedo_color = default_color


func _drop_loot() -> void:
	print("[BOSS] dropping 2 CPU + 2 RAM")
	for i in 2:
		_spawn_pickup_at(global_position + Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5)), 0)
		_spawn_pickup_at(global_position + Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5)), 1)


func _spawn_pickup_at(pos: Vector3, ptype: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var p: PickupItem = PickupItem.new()
	p.set("ptype", ptype)
	scene_root.add_child(p)
	p.global_position = pos


func _die() -> void:
	state = BossState.DYING
	print("[BOSS] XENO-KICKER DEFEATED!")

	var fx: Node = get_node_or_null("/root/FX")
	if fx != null and fx.has_method("spawn_explosion"):
		fx.call("spawn_explosion", global_position + Vector3(0, 1.5, 0))

	_drop_loot()

	var tween: Tween = create_tween()
	if boss_visual != null:
		tween.tween_property(boss_visual, "rotation_degrees", Vector3(0, 720, 90), 1.0)
	tween.parallel().tween_property(self, "scale", Vector3(2.0, 0.1, 2.0), 1.0)
	tween.tween_callback(queue_free)
