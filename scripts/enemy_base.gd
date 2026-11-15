extends CharacterBody3D

class PickupItem extends Area3D:
	var ptype: int = 0
	var float_time: float = 0.0
	var target_player: Node3D
	var magnetized: bool = false
	var magnet_speed: float = 8.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2
		var shape := SphereShape3D.new()
		shape.radius = 0.45
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.18, 0.18)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 0.9, 0.25) if ptype == 0 else Color(0.2, 0.55, 1.0)
		material.emission_enabled = true
		material.emission = material.albedo_color
		var visual := MeshInstance3D.new()
		visual.mesh = box
		visual.material_override = material
		add_child(visual)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		float_time += delta
		rotate_y(delta * 2.0)
		if not magnetized:
			var players: Array = get_tree().get_nodes_in_group("player")
			for candidate in players:
				var player: Node3D = candidate as Node3D
				if player != null and global_position.distance_to(player.global_position) < 4.0:
					target_player = player
					magnetized = true
					break
		else:
			if is_instance_valid(target_player):
				var direction: Vector3 = (target_player.global_position + Vector3.UP - global_position).normalized()
				global_position += direction * magnet_speed * delta
				magnet_speed += 18.0 * delta

	func _on_body_entered(body: Node3D) -> void:
		if not body.is_in_group("player"):
			return
		if ptype == 0:
			PlayerStats.heal(15.0)
		else:
			PlayerStats.add_tech(15.0)
		queue_free()

@export_range(0, 1) var enemy_type: int = 0
@export var max_health: float = 100.0
@export var model_path: String = "res://Assets/haven-main/dusman2.fbx"
@export var model_scale: float = 1.0
@export var move_speed: float = 2.5
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2

var current_health: float = 100.0
var is_stunned: bool = false
var default_color: Color = Color(0.9, 0.12, 0.25)
var body_visual: Node3D
var visual_material: StandardMaterial3D
var model_animation_player: AnimationPlayer
var movement_animation: String = ""
var attack_animation: String = ""
var idle_animation: String = ""
var attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 + 2
	current_health = max_health
	default_color = Color(0.15, 0.55, 1.0) if enemy_type == 1 else Color(0.9, 0.12, 0.25)
	if enemy_type == 1:
		model_path = "res://Assets/haven-main/textures/soldierfemale.fbx"
		model_scale = 1.0
	else:
		model_path = "res://Assets/haven-main/dusman2.fbx"
		model_scale = 1.0
	_build_visuals()

func _build_visuals() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = -0.1
	add_child(collision)
	if ResourceLoader.exists(model_path):
		var model_resource: Resource = load(model_path)
		if model_resource is PackedScene:
			var model: Node = (model_resource as PackedScene).instantiate()
			body_visual = model as Node3D
			if body_visual != null:
				add_child(body_visual)
				_fit_model_to_height(body_visual, 1.8 * model_scale)
				model_animation_player = _find_animation_player(body_visual)
				if model_animation_player != null:
					var base_animations: PackedStringArray = model_animation_player.get_animation_list()
					if not base_animations.is_empty():
						idle_animation = base_animations[0]
				_load_external_animations()
				_play_animation(idle_animation)
	if body_visual == null:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 1.8, 0.45)
		visual_material = StandardMaterial3D.new()
		visual_material.albedo_color = default_color
		visual_material.emission_enabled = true
		visual_material.emission = default_color * 0.25
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = visual_material
		visual.position.y = 0.9
		body_visual = visual
		add_child(visual)
	var label := Label3D.new()
	label.text = "SENTINEL" if enemy_type == 0 else "HUNTER"
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _load_external_animations() -> void:
	if model_animation_player == null or enemy_type != 0:
		return
	var animation_sources := {
		"walk": "res://Assets/haven-main/dusman2walking.fbx",
		"attack": "res://Assets/haven-main/dusman2punch.fbx"
	}
	var library := AnimationLibrary.new()
	for animation_name in animation_sources:
		var path: String = animation_sources[animation_name]
		if not ResourceLoader.exists(path):
			continue
		var scene_resource: Resource = load(path)
		if not (scene_resource is PackedScene):
			continue
		var animation_root: Node = (scene_resource as PackedScene).instantiate()
		var source_player: AnimationPlayer = _find_animation_player(animation_root)
		if source_player != null:
			for source_name in source_player.get_animation_list():
				var animation: Animation = source_player.get_animation(source_name)
				if animation != null:
					library.add_animation(animation_name, animation)
					break
		animation_root.free()
	if library.get_animation_list().size() > 0:
		model_animation_player.add_animation_library("combat", library)
		movement_animation = "combat/walk"
		attack_animation = "combat/attack"

func _play_animation(animation_name: String) -> void:
	if model_animation_player == null or not model_animation_player.has_animation(animation_name):
		return
	if model_animation_player.current_animation != animation_name:
		model_animation_player.play(animation_name, 0.15)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _fit_model_to_height(model: Node3D, target_height: float) -> void:
	var bounds: AABB = _collect_model_bounds(model, model)
	if bounds.size.y <= 0.001:
		return
	var fit_scale: float = target_height / bounds.size.y
	model.scale = Vector3.ONE * fit_scale
	# Enemy roots are positioned one unit above the ground; align the mesh bottom
	# with the capsule collision bottom at local y = -1.
	model.position.y = -1.0 - bounds.position.y * fit_scale

func _collect_model_bounds(root: Node3D, node: Node) -> AABB:
	var bounds := AABB()
	var has_bounds: bool = false
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
			var relative_transform: Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
			bounds = relative_transform * mesh_bounds
			has_bounds = true
	for child in node.get_children():
		var child_bounds: AABB = _collect_model_bounds(root, child)
		if child_bounds.size != Vector3.ZERO:
			bounds = child_bounds if not has_bounds else bounds.merge(child_bounds)
			has_bounds = true
	return bounds if has_bounds else AABB()

func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	var players: Array = get_tree().get_nodes_in_group("player")
	var player: Node3D = players[0] as Node3D if not players.is_empty() else null
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	if player != null and not is_stunned and not PlayerStats.is_dead:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > attack_range:
			var direction: Vector3 = to_player.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			look_at(global_position + direction, Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				_play_animation(attack_animation)
				if player.has_method("take_damage"):
					player.call("take_damage", get_current_attack_damage())
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	move_and_slide()
	if not is_stunned and not movement_animation.is_empty():
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.15
		if attack_timer > attack_cooldown - 0.3 and not attack_animation.is_empty():
			_play_animation(attack_animation)
		else:
			_play_animation(movement_animation if moving else idle_animation)

func take_damage(damage: float, _punch_type = 0, _attacker_position: Vector3 = Vector3.ZERO) -> void:
	if not attack_animation.is_empty():
		_play_animation(attack_animation)
	current_health -= damage
	if visual_material != null:
		visual_material.albedo_color = Color.WHITE
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self) and visual_material != null:
			visual_material.albedo_color = default_color
	if current_health <= 0.0:
		_die()

func apply_launch(force: Vector3) -> void:
	velocity += force

func apply_stagger(force: Vector3 = Vector3.ZERO) -> void:
	velocity += force
	is_stunned = true
	get_tree().create_timer(0.5).timeout.connect(_clear_stun)
	_play_animation(idle_animation)

func apply_knockback(force: Vector3) -> void:
	velocity += force

func apply_parry_stun(_duration: float = 1.0) -> void:
	apply_stagger()

func get_current_attack_damage() -> float:
	return 10.0

func _clear_stun() -> void:
	is_stunned = false

func _die() -> void:
	if is_queued_for_deletion():
		return
	_spawn_pickup(0)
	_spawn_pickup(1)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(queue_free)

func _spawn_pickup(ptype: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var pickup := PickupItem.new()
	pickup.set("ptype", ptype)
	scene_root.add_child(pickup)
	pickup.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))
