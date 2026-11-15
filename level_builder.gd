extends Node3D

const PLAYER_SCRIPT: Script = preload("res://scripts/player.gd")
const ENEMY_SCRIPT: Script = preload("res://scripts/enemy_base.gd")
const BOSS_SCRIPT: Script = preload("res://scripts/boss_alien.gd")
const TURRET_SCRIPT: Script = preload("res://scripts/turret.gd")
const CHECKPOINT_SCRIPT: Script = preload("res://scripts/checkpoint_laptop.gd")
const ELEVATOR_SCRIPT: Script = preload("res://scripts/elevator.gd")
const ARENA_SIZE: float = 60.0
const GROUND_HEIGHT: float = 0.0
const LEVEL_MODEL_BASE_HEIGHT: float = -13.5

@export var level_number: int = 1
var imported_level_loaded: bool = false

func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_walls()
	_spawn_player()
	_spawn_combatants()
	_spawn_utilities()

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 3.0
	light.shadow_enabled = true
	add_child(light)
	var fill_light := OmniLight3D.new()
	fill_light.name = "ArenaFillLight"
	fill_light.position = Vector3(0.0, 12.0, 0.0)
	fill_light.light_energy = 3.0
	fill_light.omni_range = 55.0
	add_child(fill_light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.03, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 1.0)
	environment.ambient_light_energy = 1.5
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
	add_child(world)
	_load_level_environment()

func _load_level_environment() -> void:
	const LEVEL_MODEL_PATH := "res://Assets/haven-main/lvl 2 mekan/zorhaven.fbx"
	if not ResourceLoader.exists(LEVEL_MODEL_PATH):
		push_warning("Level model is missing; using the generated test room.")
		return
	var resource: Resource = load(LEVEL_MODEL_PATH)
	if not (resource is PackedScene):
		push_warning("Level model could not be imported as a scene; using the generated test room.")
		return
	var container := Node3D.new()
	container.name = "ImportedMekanScene"
	add_child(container)
	var level_scene: Node3D = (resource as PackedScene).instantiate() as Node3D
	if level_scene == null:
		container.queue_free()
		push_warning("Level model has no 3D scene root; using the generated test room.")
		return
	container.add_child(level_scene)
	var bounds: AABB = _collect_mesh_bounds(level_scene, level_scene)
	if bounds.size.x <= 0.01 or bounds.size.z <= 0.01:
		container.queue_free()
		push_warning("Level model contains no usable mesh bounds; using the generated test room.")
		return
	var fit_scale: float = minf(ARENA_SIZE / bounds.size.x, ARENA_SIZE / bounds.size.z)
	container.scale = Vector3.ONE * fit_scale
	container.position = Vector3(-bounds.get_center().x * fit_scale, LEVEL_MODEL_BASE_HEIGHT - bounds.position.y * fit_scale, -bounds.get_center().z * fit_scale)
	imported_level_loaded = true

func _collect_mesh_bounds(root: Node3D, node: Node) -> AABB:
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
		var child_bounds: AABB = _collect_mesh_bounds(root, child)
		if child_bounds.size != Vector3.ZERO:
			bounds = child_bounds if not has_bounds else bounds.merge(child_bounds)
			has_bounds = true
	return bounds if has_bounds else AABB()

func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(ARENA_SIZE + 30.0, 2.0, ARENA_SIZE + 30.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = GROUND_HEIGHT - 1.0
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ARENA_SIZE, 0.5, ARENA_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.1, 0.16)
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position.y = GROUND_HEIGHT - 0.25
	visual.visible = not imported_level_loaded
	body.add_child(visual)
	add_child(body)

func _build_walls() -> void:
	var half_size: float = ARENA_SIZE * 0.5
	var wall_height: float = 100.0
	var wall_center_y: float = GROUND_HEIGHT + wall_height * 0.5
	_add_wall(Vector3(0, wall_center_y, -half_size), Vector3(ARENA_SIZE, wall_height, 0.5))
	_add_wall(Vector3(0, wall_center_y, half_size), Vector3(ARENA_SIZE, wall_height, 0.5))
	_add_wall(Vector3(-half_size, wall_center_y, 0), Vector3(0.5, wall_height, ARENA_SIZE))
	_add_wall(Vector3(half_size, wall_center_y, 0), Vector3(0.5, wall_height, ARENA_SIZE))

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	if not imported_level_loaded:
		var mesh := BoxMesh.new()
		mesh.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.14, 0.22)
		mesh.surface_set_material(0, material)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		body.add_child(visual)
	body.position = pos
	add_child(body)

func _spawn_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector3(0, GROUND_HEIGHT + 1, 10)
	add_child(player)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(preload("res://scripts/hud.gd"))
	add_child(hud)

func _spawn_combatants() -> void:
	var male := CharacterBody3D.new()
	male.name = "MaleEnemy"
	male.set_script(ENEMY_SCRIPT)
	male.set("enemy_type", 0)
	male.position = Vector3(-3, GROUND_HEIGHT + 1, -5)
	add_child(male)
	var female := CharacterBody3D.new()
	female.name = "FemaleEnemy"
	female.set_script(ENEMY_SCRIPT)
	female.set("enemy_type", 1)
	female.position = Vector3(3, GROUND_HEIGHT + 1, -5)
	add_child(female)
	var boss := CharacterBody3D.new()
	boss.name = "Boss"
	boss.set_script(BOSS_SCRIPT)
	boss.position = Vector3(0, GROUND_HEIGHT + 1, -10)
	add_child(boss)
	_spawn_turret("TurretLeft", Vector3(-8, GROUND_HEIGHT, -10))
	_spawn_turret("TurretRight", Vector3(8, GROUND_HEIGHT, -10))

func _spawn_turret(node_name: String, pos: Vector3) -> void:
	var turret := StaticBody3D.new()
	turret.name = node_name
	turret.set_script(TURRET_SCRIPT)
	turret.position = pos
	add_child(turret)

func _spawn_utilities() -> void:
	var checkpoint := Area3D.new()
	checkpoint.name = "Checkpoint"
	checkpoint.set_script(CHECKPOINT_SCRIPT)
	checkpoint.position = Vector3(2, GROUND_HEIGHT, 10)
	add_child(checkpoint)
	var elevator := Area3D.new()
	elevator.name = "Elevator"
	elevator.set_script(ELEVATOR_SCRIPT)
	elevator.set("target_scene", "res://Scenes/level_2.tscn")
	elevator.position = Vector3(0, GROUND_HEIGHT, -13)
	add_child(elevator)
