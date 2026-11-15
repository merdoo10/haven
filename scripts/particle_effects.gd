# particle_effects.gd  —  Autoload name: FX
extends Node

"""
Usage:
  FX.spawn_sparks(pos)
  FX.spawn_blood(pos)
  FX.spawn_smoke(pos)
  FX.spawn_explosion(pos)
  FX.spawn_muzzle_flash(pos)
"""


func spawn_sparks(pos: Vector3, count: int = 15) -> void:
	var p: GPUParticles3D = _create_particle_node(pos)
	p.amount = count
	p.lifetime = 0.4
	p.explosiveness = 0.9
	p.process_material = _make_spark_process()
	var mesh: SphereMesh = _make_small_mesh()
	mesh.surface_set_material(0, _make_draw_material(Color(1.0, 0.8, 0.2)))
	p.draw_pass_1 = mesh
	_auto_destroy(p, 0.8)


func spawn_blood(pos: Vector3, count: int = 20) -> void:
	var p: GPUParticles3D = _create_particle_node(pos)
	p.amount = count
	p.lifetime = 0.6
	p.explosiveness = 0.7
	p.process_material = _make_blood_process()
	var mesh: SphereMesh = _make_small_mesh()
	mesh.surface_set_material(0, _make_draw_material(Color(0.85, 0.05, 0.05)))
	p.draw_pass_1 = mesh
	_auto_destroy(p, 1.0)


func spawn_smoke(pos: Vector3, count: int = 10) -> void:
	var p: GPUParticles3D = _create_particle_node(pos)
	p.amount = count
	p.lifetime = 1.5
	p.explosiveness = 0.3
	p.process_material = _make_smoke_process()
	var mesh: QuadMesh = _make_smoke_mesh()
	var mat: StandardMaterial3D = _make_draw_material(Color(0.35, 0.35, 0.4, 0.5))
	mat.emission_energy_multiplier = 0.2
	mesh.surface_set_material(0, mat)
	p.draw_pass_1 = mesh
	_auto_destroy(p, 2.0)


func spawn_muzzle_flash(pos: Vector3) -> void:
	var p: GPUParticles3D = _create_particle_node(pos)
	p.amount = 6
	p.lifetime = 0.12
	p.explosiveness = 1.0
	p.process_material = _make_spark_process()
	var mesh: SphereMesh = _make_small_mesh()
	mesh.surface_set_material(0, _make_draw_material(Color(1.0, 0.9, 0.4)))
	p.draw_pass_1 = mesh
	_auto_destroy(p, 0.4)


func spawn_explosion(pos: Vector3) -> void:
	spawn_sparks(pos, 30)
	spawn_smoke(pos, 14)

	var flash: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	flash.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = mat

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(flash)
	flash.global_position = pos

	var tween: Tween = create_tween()
	tween.tween_property(flash, "scale", Vector3(4, 4, 4), 0.18)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


# ============================================
# INTERNAL
# ============================================

func _create_particle_node(pos: Vector3) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		scene_root.add_child(p)
		p.global_position = pos
	return p


func _make_draw_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	return mat


func _make_spark_process() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -15, 0)
	mat.damping_min = 2.0
	mat.damping_max = 5.0
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	return mat


func _make_blood_process() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.5, -1).normalized()
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -20, 0)
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	mat.scale_min = 0.8
	mat.scale_max = 2.0
	return mat


func _make_smoke_process() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, 0.6, 0)
	mat.damping_min = 0.5
	mat.damping_max = 1.5
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	return mat


func _make_small_mesh() -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh


func _make_smoke_mesh() -> QuadMesh:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.25, 0.25)
	return mesh


func _auto_destroy(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()
