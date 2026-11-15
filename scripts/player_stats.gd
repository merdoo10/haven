# player_stats.gd — Autoload (add to Project > Project Settings > Autoload)
extends Node

signal health_changed(new_value: float)
signal tech_changed(new_value: float)
signal player_died()
signal player_revived()

const MAX_HEALTH: float = 100.0  # 5 hits at 20 damage each
const MAX_TECH: float = 100.0
const TECH_REGEN_RATE: float = 1.0  # 1 point per second
const REVIVE_HEALTH: float = 20.0
const REVIVE_WINDOW: float = 5.0
const REVIVE_PRESSES_NEEDED: int = 10

var health: float = MAX_HEALTH
var tech: float = MAX_TECH
var is_dead: bool = false
var revive_timer: float = 0.0
var revive_presses: int = 0
var checkpoint_position: Vector3 = Vector3.ZERO
var checkpoint_scene: String = ""
var start_blood_effect_pending: bool = true

# Tech costs
const COST_SLIDE: float = 10.0
const COST_DASH: float = 10.0
const COST_FINGER_SHOT: float = 10.0
const COST_THUMB_SHOT: float = 20.0


func _process(delta: float) -> void:
	# Tech regen
	if not is_dead and tech < MAX_TECH:
		tech = minf(tech + TECH_REGEN_RATE * delta, MAX_TECH)
		emit_signal("tech_changed", tech)

	# Revive window countdown
	if is_dead:
		revive_timer -= delta
		if revive_timer <= 0.0:
			_permanent_death()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	health = maxf(health, 0.0)
	emit_signal("health_changed", health)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	emit_signal("health_changed", health)


func use_tech(amount: float) -> bool:
	"""Returns true if enough tech, deducts it."""
	if tech >= amount:
		tech -= amount
		emit_signal("tech_changed", tech)
		return true
	return false


func add_tech(amount: float) -> void:
	tech = minf(tech + amount, MAX_TECH)
	emit_signal("tech_changed", tech)


func try_revive_press() -> bool:
	"""Mash F during the revive window to get back up."""
	if not is_dead:
		return false
	revive_presses += 1
	if revive_presses >= REVIVE_PRESSES_NEEDED:
		_revive()
		return true
	return false


func respawn() -> void:
	if not is_dead:
		return
	print("[RESPAWN] Restoring full health and tech")
	reset_for_new_level()
	if checkpoint_scene != "" and ResourceLoader.exists(checkpoint_scene):
		get_tree().change_scene_to_file(checkpoint_scene)
	else:
		get_tree().reload_current_scene()


func set_checkpoint(pos: Vector3, scene_path: String) -> void:
	checkpoint_position = pos
	checkpoint_scene = scene_path
	print("[CHECKPOINT] Saved at %s" % pos)


func reset_for_new_level() -> void:
	health = MAX_HEALTH
	tech = MAX_TECH
	is_dead = false
	emit_signal("health_changed", health)
	emit_signal("tech_changed", tech)


func _die() -> void:
	is_dead = true
	revive_timer = REVIVE_WINDOW
	revive_presses = 0
	emit_signal("player_died")
	print("[DEATH] Mash F to revive! (%.1f seconds)" % REVIVE_WINDOW)


func _revive() -> void:
	is_dead = false
	revive_timer = 0.0
	health = REVIVE_HEALTH
	emit_signal("health_changed", health)
	emit_signal("player_revived")
	print("[REVIVED] with %.0f HP!" % REVIVE_HEALTH)


func _permanent_death() -> void:
	respawn()
