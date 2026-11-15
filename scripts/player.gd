extends CharacterBody3D

# ═══════════════════════════════════════════
#  CONSTANTS
# ═══════════════════════════════════════════

# Movement
const WALK_SPEED: float = 7.0
const ACCELERATION: float = 15.0
const DECELERATION: float = 10.0
const AIR_ACCELERATION: float = 5.0
const JUMP_VELOCITY: float = 9.0
const GRAVITY: float = 25.0
const MAX_FALL_SPEED: float = 40.0

# Head bob
const BOB_FREQ: float = 12.0
const BOB_AMP_Y: float = 0.06
const BOB_AMP_X: float = 0.03

# Dash
const DASH_SPEED: float = 30.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 0.5

# Slide
const SLIDE_SPEED: float = 16.0
const SLIDE_DECELERATION: float = 8.0
const SLIDE_DURATION: float = 0.8
const SLIDE_CAMERA_TILT: float = 5.0
const SLIDE_HEIGHT: float = 1.0
const STAND_HEIGHT: float = 2.0

# Mouse
const MOUSE_SENS: float = 0.002

# Melee
const MELEE_MAX_RANGE: float = 1.0
const HOOK_THRESHOLD: float = 0.7
const UPPERCUT_THRESHOLD: float = 0.3
const PUNCH_DAMAGE: float = 20.0
const HOOK_DAMAGE: float = 35.0
const UPPERCUT_DAMAGE: float = 50.0
const UPPERCUT_LAUNCH_FORCE: float = 12.0
const PUNCH_COOLDOWN: float = 0.35
const PUNCH_LUNGE_FORCE: float = 5.0

# Parry
const PARRY_WINDOW: float = 0.3
const PARRY_COOLDOWN: float = 0.8
const PARRY_DAMAGE_REFLECT: float = 0.75
const PARRY_SLOWMO_DURATION: float = 0.2
const PARRY_KNOCKBACK: float = 15.0

# Finger shot
const FINGER_SHOT_DAMAGE: float = 15.0
const FINGER_SHOT_COOLDOWN: float = 0.5
const FINGER_SHOT_RANGE: float = 50.0

# Thumb shotgun
const THUMB_SHOT_PELLETS: int = 5
const THUMB_SHOT_DAMAGE: float = 12.0
const THUMB_SHOT_SPREAD: float = 8.0
const THUMB_SHOT_COOLDOWN: float = 5.0
const THUMB_SHOT_RANGE: float = 15.0

# Arm visuals
const RIGHT_ARM_DEFAULT: Vector3 = Vector3(0.25, -0.2, -0.4)
const LEFT_ARM_DEFAULT: Vector3 = Vector3(-0.25, -0.2, -0.4)
const ARM_DEFAULT_COLOR: Color = Color(0.2, 0.6, 1.0)
const PARRY_COLOR: Color = Color(1.0, 0.9, 0.2)
const PUNCH_COLOR: Color = Color(1.0, 0.3, 0.1)
const PARRY_FAIL_COLOR: Color = Color(0.5, 0.1, 0.1)

# ═══════════════════════════════════════════
#  ENUMS
# ═══════════════════════════════════════════

enum PunchType { NONE, STRAIGHT, HOOK, UPPERCUT }
enum CombatState { IDLE, PUNCHING, PARRYING, PARRY_RECOVERY }

# ═══════════════════════════════════════════
#  STATE
# ═══════════════════════════════════════════

var yaw: float = 0.0
var pitch: float = 0.0
var bob_time: float = 0.0
var combat_state: int = CombatState.IDLE
var current_punch: int = PunchType.NONE
var punch_timer: float = 0.0
var parry_timer: float = 0.0
var parry_cooldown_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var slide_timer: float = 0.0
var is_sliding: bool = false
var finger_index: int = 0
var finger_cooldown_timer: float = 0.0
var thumb_cooldown_timer: float = 0.0
var revive_mash_count: int = 0
var is_dead_local: bool = false

# ═══════════════════════════════════════════
#  NODE REFERENCES (built at runtime)
# ═══════════════════════════════════════════

var head: Node3D
var camera: Camera3D
var arm_container: Node3D
var player_model: Node3D
var right_arm: MeshInstance3D
var left_arm: MeshInstance3D
var melee_area: Area3D
var parry_area: Area3D
var collision_shape: CollisionShape3D
var debug_label: Label

# ═══════════════════════════════════════════
#  READY
# ═══════════════════════════════════════════

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build_scene_tree()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	PlayerStats.health_changed.connect(_on_health_changed)
	PlayerStats.tech_changed.connect(_on_tech_changed)
	PlayerStats.player_died.connect(_on_player_died)
	PlayerStats.player_revived.connect(_on_player_revived)

# ═══════════════════════════════════════════
#  INPUT
# ═══════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if is_dead_local:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
			PlayerStats.try_revive_press()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		yaw -= mm.relative.x * MOUSE_SENS
		pitch -= mm.relative.y * MOUSE_SENS
		pitch = clampf(pitch, -1.5, 1.5)

	if event.is_action_pressed("punch"):
		_do_punch()
	if event.is_action_pressed("parry"):
		_do_parry()
	if event.is_action_released("parry"):
		_end_parry()
	if event.is_action_pressed("shoot"):
		_do_finger_shot()
	if event.is_action_pressed("shoot_alt"):
		_do_thumb_shot()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

# ═══════════════════════════════════════════
#  PHYSICS
# ═══════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if is_dead_local:
		return

	# Gravity
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

	# Timers
	punch_timer = maxf(punch_timer - delta, 0.0)
	parry_timer = maxf(parry_timer - delta, 0.0)
	parry_cooldown_timer = maxf(parry_cooldown_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	finger_cooldown_timer = maxf(finger_cooldown_timer - delta, 0.0)
	thumb_cooldown_timer = maxf(thumb_cooldown_timer - delta, 0.0)

	# Combat state machine
	if combat_state == CombatState.PUNCHING and punch_timer <= 0.0:
		combat_state = CombatState.IDLE
		current_punch = PunchType.NONE
	if combat_state == CombatState.PARRY_RECOVERY and parry_cooldown_timer <= 0.0:
		combat_state = CombatState.IDLE

	# Dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_sliding:
		if PlayerStats.use_tech(PlayerStats.COST_DASH):
			dash_timer = DASH_DURATION
			dash_cooldown_timer = DASH_COOLDOWN
			var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			dash_dir = (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			if dash_dir == Vector3.ZERO:
				dash_dir = -head.global_basis.z

	if dash_timer > 0.0:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
	else:
		# Slide
		if Input.is_action_pressed("slide") and is_on_floor() and not is_sliding and velocity.length() > 3.0:
			if PlayerStats.use_tech(PlayerStats.COST_SLIDE):
				is_sliding = true
				slide_timer = SLIDE_DURATION
				collision_shape.shape.height = SLIDE_HEIGHT
				collision_shape.position.y = (SLIDE_HEIGHT - STAND_HEIGHT) * 0.5

		if is_sliding:
			slide_timer -= delta
			var slide_dir := -head.global_basis.z
			velocity.x = slide_dir.x * SLIDE_SPEED
			velocity.z = slide_dir.z * SLIDE_SPEED
			velocity.x = move_toward(velocity.x, 0.0, SLIDE_DECELERATION * delta)
			velocity.z = move_toward(velocity.z, 0.0, SLIDE_DECELERATION * delta)
			if slide_timer <= 0.0 or not is_on_floor():
				is_sliding = false
				collision_shape.shape.height = STAND_HEIGHT
				collision_shape.position.y = 0.0
		else:
			# Normal movement
			var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			var direction := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var accel := ACCELERATION if is_on_floor() else AIR_ACCELERATION
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * WALK_SPEED, accel * delta)
				velocity.z = move_toward(velocity.z, direction.z * WALK_SPEED, accel * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
				velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)

	move_and_slide()

	# Camera rotation
	head.rotation.y = yaw
	camera.rotation.x = pitch

	# Head bob
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0 and not is_sliding:
		bob_time += delta * BOB_FREQ
		camera.position.y = sin(bob_time) * BOB_AMP_Y
		camera.position.x = cos(bob_time * 0.5) * BOB_AMP_X
	else:
		bob_time = 0.0
		camera.position.y = lerpf(camera.position.y, 0.0, 10.0 * delta)
		camera.position.x = lerpf(camera.position.x, 0.0, 10.0 * delta)

	# Slide camera tilt
	if is_sliding:
		camera.rotation.z = lerpf(camera.rotation.z, deg_to_rad(SLIDE_CAMERA_TILT), 10.0 * delta)
	else:
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, 10.0 * delta)

	# Arm visuals
	_update_arm_visuals(delta)

	# Debug HUD
	_update_debug_hud()

# ═══════════════════════════════════════════
#  COMBAT
# ═══════════════════════════════════════════

func _do_punch() -> void:
	if combat_state != CombatState.IDLE or punch_timer > 0.0:
		return
	var dist := _get_nearest_enemy_distance()
	var norm_dist := clampf(dist / MELEE_MAX_RANGE, 0.0, 1.0)
	if norm_dist > HOOK_THRESHOLD:
		current_punch = PunchType.STRAIGHT
	elif norm_dist > UPPERCUT_THRESHOLD:
		current_punch = PunchType.HOOK
	else:
		current_punch = PunchType.UPPERCUT

	combat_state = CombatState.PUNCHING
	punch_timer = PUNCH_COOLDOWN

	# Lunge
	var lunge_dir := -head.global_basis.z
	velocity += lunge_dir * PUNCH_LUNGE_FORCE

	# Hit detection
	var damage: float = PUNCH_DAMAGE
	if current_punch == PunchType.HOOK:
		damage = HOOK_DAMAGE
	elif current_punch == PunchType.UPPERCUT:
		damage = UPPERCUT_DAMAGE

	var bodies: Array = melee_area.get_overlapping_bodies()
	for body: Node3D in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(damage, current_punch, global_position)
			_fx("spawn_sparks", [body.global_position + Vector3(0, 1, 0), 10])
			if current_punch == PunchType.UPPERCUT and body.has_method("apply_launch"):
				body.apply_launch(Vector3.UP * UPPERCUT_LAUNCH_FORCE)
			if current_punch == PunchType.HOOK and body.has_method("apply_stagger"):
				body.apply_stagger(-head.global_basis.z * 2.0)

	# Arm animation
	if right_arm != null:
		right_arm.position.z = RIGHT_ARM_DEFAULT.z + 0.2

func _do_parry() -> void:
	if combat_state != CombatState.IDLE or parry_cooldown_timer > 0.0:
		return
	combat_state = CombatState.PARRYING
	parry_timer = PARRY_WINDOW
	parry_area.monitoring = true

func _end_parry() -> void:
	if combat_state == CombatState.PARRYING:
		parry_area.monitoring = false
		if parry_timer > 0.0:
			# Failed parry
			combat_state = CombatState.PARRY_RECOVERY
			parry_cooldown_timer = PARRY_COOLDOWN
		else:
			combat_state = CombatState.IDLE

func _do_finger_shot() -> void:
	if finger_cooldown_timer > 0.0:
		return
	if not PlayerStats.use_tech(PlayerStats.COST_FINGER_SHOT):
		return
	finger_cooldown_timer = FINGER_SHOT_COOLDOWN

	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_basis.z * FINGER_SHOT_RANGE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 + 4  # World + Enemy
	query.exclude = [self]
	var result: Dictionary = space.intersect_ray(query)

	if result.size() > 0:
		var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
		var collider: Node3D = result.get("collider", null) as Node3D
		if collider != null and collider.is_in_group("enemy") and collider.has_method("take_damage"):
			collider.take_damage(FINGER_SHOT_DAMAGE, PunchType.NONE, global_position)
			_fx("spawn_sparks", [hit_pos, 8])
		else:
			_fx("spawn_sparks", [hit_pos, 5])
	else:
		_fx("spawn_muzzle_flash", [from + (-camera.global_basis.z * 0.5)])

	# Finger cycle visual
	finger_index = (finger_index + 1) % 4
	if right_arm != null:
		right_arm.position.z = RIGHT_ARM_DEFAULT.z + 0.05

func _do_thumb_shot() -> void:
	if thumb_cooldown_timer > 0.0:
		return
	if not PlayerStats.use_tech(PlayerStats.COST_THUMB_SHOT):
		return
	thumb_cooldown_timer = THUMB_SHOT_COOLDOWN

	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var base_dir := -camera.global_basis.z

	for i: int in range(THUMB_SHOT_PELLETS):
		var spread_dir := base_dir.rotated(Vector3.UP, deg_to_rad(randf_range(-THUMB_SHOT_SPREAD, THUMB_SHOT_SPREAD)))
		spread_dir = spread_dir.rotated(camera.global_basis.x, deg_to_rad(randf_range(-THUMB_SHOT_SPREAD, THUMB_SHOT_SPREAD)))
		var to := from + spread_dir * THUMB_SHOT_RANGE
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1 + 4
		query.exclude = [self]
		var result: Dictionary = space.intersect_ray(query)
		if result.size() > 0:
			var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
			var collider: Node3D = result.get("collider", null) as Node3D
			if collider != null and collider.is_in_group("enemy") and collider.has_method("take_damage"):
				collider.take_damage(THUMB_SHOT_DAMAGE, PunchType.NONE, global_position)
				_fx("spawn_blood", [hit_pos, 8])

	_fx("spawn_muzzle_flash", [from + base_dir * 0.5])
	if left_arm != null:
		left_arm.position.z = LEFT_ARM_DEFAULT.z + 0.1

func _try_interact() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_basis.z * 3.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 + 4 + 8
	var result: Dictionary = space.intersect_ray(query)
	if result.size() > 0:
		var collider: Node = result.get("collider", null) as Node
		if collider != null and collider.has_method("interact"):
			collider.interact(self)

# ═══════════════════════════════════════════
#  PARRY HIT (called by enemy projectiles/attacks)
# ═══════════════════════════════════════════

func parry_hit(damage: float, attacker_pos: Vector3) -> bool:
	if combat_state != CombatState.PARRYING or parry_timer <= 0.0:
		return false
	# Successful parry
	parry_timer = 0.0
	parry_area.monitoring = false
	combat_state = CombatState.PARRY_RECOVERY
	parry_cooldown_timer = PARRY_COOLDOWN * 0.5  # shorter recovery on success

	# Reflect damage to nearest enemy
	var bodies: Array = parry_area.get_overlapping_bodies()
	for body: Node3D in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			var reflected: float = damage * PARRY_DAMAGE_REFLECT
			body.take_damage(reflected, PunchType.STRAIGHT, global_position)
			if body.has_method("apply_knockback"):
				var kb_dir := (body.global_position - global_position).normalized()
				body.apply_knockback(kb_dir * PARRY_KNOCKBACK)
			if body.has_method("apply_parry_stun"):
				body.apply_parry_stun()
			_fx("spawn_sparks", [body.global_position + Vector3(0, 1, 0), 20])
			break

	# Slow-mo
	Engine.time_scale = 0.2
	_reset_time_scale_after_parry()
	return true

func _reset_time_scale_after_parry() -> void:
	await get_tree().create_timer(PARRY_SLOWMO_DURATION * 0.2).timeout
	Engine.time_scale = 1.0

# ═══════════════════════════════════════════
#  DAMAGE / DEATH
# ═══════════════════════════════════════════

func take_damage(amount: float) -> void:
	if is_dead_local:
		return
	PlayerStats.take_damage(amount)
	_fx("spawn_blood", [global_position + Vector3(0, 1.2, 0), 10])

func _on_player_died() -> void:
	is_dead_local = true
	Engine.time_scale = 1.0
	if debug_label != null:
		debug_label.text = "YOU DIED\nMash F to revive!"

func _on_player_revived() -> void:
	is_dead_local = false
	if debug_label != null:
		debug_label.text = ""

func _on_health_changed(_val: float) -> void:
	pass

func _on_tech_changed(_val: float) -> void:
	pass

# ═══════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════

func _get_nearest_enemy_distance() -> float:
	var nearest: float = 999.0
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var enemy: Node3D = e as Node3D
		if enemy == null:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest:
			nearest = d
	return nearest

func _fx(method_name: String, args: Array) -> void:
	var fx: Node = get_node_or_null("/root/FX")
	if fx != null and fx.has_method(method_name):
		fx.callv(method_name, args)

func _update_arm_visuals(delta: float) -> void:
	if right_arm == null or left_arm == null:
		return
	var r_mat: StandardMaterial3D = null
	var l_mat: StandardMaterial3D = null
	if right_arm.mesh != null:
		r_mat = right_arm.mesh.surface_get_material(0) as StandardMaterial3D
	if left_arm.mesh != null:
		l_mat = left_arm.mesh.surface_get_material(0) as StandardMaterial3D

	if combat_state == CombatState.PARRYING:
		right_arm.position = right_arm.position.lerp(Vector3(0.05, -0.1, -0.3), 15.0 * delta)
		left_arm.position = left_arm.position.lerp(Vector3(-0.05, -0.1, -0.3), 15.0 * delta)
		if r_mat != null:
			r_mat.albedo_color = PARRY_COLOR
		if l_mat != null:
			l_mat.albedo_color = PARRY_COLOR
	elif combat_state == CombatState.PUNCHING:
		if r_mat != null:
			r_mat.albedo_color = PUNCH_COLOR
		right_arm.position = right_arm.position.lerp(RIGHT_ARM_DEFAULT, 8.0 * delta)
		left_arm.position = left_arm.position.lerp(LEFT_ARM_DEFAULT, 8.0 * delta)
		if l_mat != null:
			l_mat.albedo_color = ARM_DEFAULT_COLOR
	else:
		right_arm.position = right_arm.position.lerp(RIGHT_ARM_DEFAULT, 10.0 * delta)
		left_arm.position = left_arm.position.lerp(LEFT_ARM_DEFAULT, 10.0 * delta)
		if r_mat != null:
			r_mat.albedo_color = ARM_DEFAULT_COLOR
		if l_mat != null:
			l_mat.albedo_color = ARM_DEFAULT_COLOR

func _update_debug_hud() -> void:
	if debug_label == null:
		return
	if is_dead_local:
		return
	var state_str: String = CombatState.keys()[combat_state]
	debug_label.text = "State: %s | Punch: %s\nFinger: %d/4 | Thumb CD: %.1f\nDash CD: %.1f" % [
		state_str,
		PunchType.keys()[current_punch],
		finger_index + 1,
		thumb_cooldown_timer,
		dash_cooldown_timer
	]

# ═══════════════════════════════════════════
#  SCENE TREE BUILDER
# ═══════════════════════════════════════════

func _build_scene_tree() -> void:
	# Collision
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = STAND_HEIGHT
	collision_shape.shape = capsule
	collision_shape.position.y = 0.0
	add_child(collision_shape)

	# Head
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 0.6
	add_child(head)

	# Camera
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 90.0
	camera.current = true
	head.add_child(camera)

	# First person uses the supplied Feedbacker as a single right arm.
	_build_first_person_arm()

	# Melee area
	melee_area = Area3D.new()
	melee_area.name = "MeleeArea"
	melee_area.collision_layer = 0
	melee_area.collision_mask = 4
	var melee_col := CollisionShape3D.new()
	var melee_sphere := SphereShape3D.new()
	melee_sphere.radius = 1.4
	melee_col.shape = melee_sphere
	melee_col.position = Vector3(0, 0, -0.5)
	melee_area.add_child(melee_col)
	camera.add_child(melee_area)

	# Parry area
	parry_area = Area3D.new()
	parry_area.name = "ParryArea"
	parry_area.collision_layer = 0
	parry_area.collision_mask = 16 + 32
	parry_area.monitoring = false
	var parry_col := CollisionShape3D.new()
	var parry_box := BoxShape3D.new()
	parry_box.size = Vector3(1.0, 1.0, 0.5)
	parry_col.shape = parry_box
	parry_col.position = Vector3(0, 0, -0.4)
	parry_area.add_child(parry_col)
	camera.add_child(parry_area)

	# Debug HUD
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "DebugHUD"
	add_child(hud_layer)

	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(0, 1, 0))
	hud_layer.add_child(debug_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.anchors_preset = Control.PRESET_CENTER
	hud_layer.add_child(crosshair)

func _build_first_person_arm() -> void:
	arm_container = Node3D.new()
	arm_container.name = "Arms"
	camera.add_child(arm_container)
	right_arm = _make_arm("RightArm", RIGHT_ARM_DEFAULT)
	left_arm = _make_arm("LeftArm", LEFT_ARM_DEFAULT)
	arm_container.add_child(right_arm)
	arm_container.add_child(left_arm)

func _make_arm(arm_name: String, arm_position: Vector3) -> MeshInstance3D:
	var arm := MeshInstance3D.new()
	arm.name = arm_name
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.25)
	var material := StandardMaterial3D.new()
	material.albedo_color = ARM_DEFAULT_COLOR
	material.metallic = 0.8
	material.roughness = 0.3
	box.surface_set_material(0, material)
	arm.mesh = box
	arm.position = arm_position
	return arm
