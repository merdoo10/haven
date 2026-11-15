# hud.gd — Attach to a CanvasLayer node in your scene, or build from player
extends CanvasLayer

var health_bar: ProgressBar
var tech_bar: ProgressBar
var health_label: Label
var tech_label: Label
var death_overlay: ColorRect
var death_label: Label
var revive_label: Label


func _ready() -> void:
	_build_hud()
	if PlayerStats.start_blood_effect_pending:
		PlayerStats.start_blood_effect_pending = false
		_play_start_blood_effect()
	# Connect to autoload signals
	PlayerStats.health_changed.connect(_on_health_changed)
	PlayerStats.tech_changed.connect(_on_tech_changed)
	PlayerStats.player_died.connect(_on_player_died)
	PlayerStats.player_revived.connect(_on_player_revived)


func _build_hud() -> void:
	# --- Health Bar ---
	var health_container := VBoxContainer.new()
	health_container.position = Vector2(20, 20)
	health_container.size = Vector2(250, 60)
	add_child(health_container)

	health_label = Label.new()
	health_label.text = "HEALTH"
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	health_container.add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(220, 20)
	health_bar.max_value = PlayerStats.MAX_HEALTH
	health_bar.value = PlayerStats.health
	health_bar.show_percentage = false

	# Style the health bar red
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.9, 0.15, 0.15)
	health_fill.corner_radius_top_left = 3
	health_fill.corner_radius_bottom_left = 3
	health_fill.corner_radius_top_right = 3
	health_fill.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", health_fill)

	var health_bg := StyleBoxFlat.new()
	health_bg.bg_color = Color(0.2, 0.05, 0.05)
	health_bg.corner_radius_top_left = 3
	health_bg.corner_radius_bottom_left = 3
	health_bg.corner_radius_top_right = 3
	health_bg.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("background", health_bg)

	health_container.add_child(health_bar)

	# --- Tech Bar ---
	var tech_container := VBoxContainer.new()
	tech_container.position = Vector2(20, 80)
	tech_container.size = Vector2(250, 60)
	add_child(tech_container)

	tech_label = Label.new()
	tech_label.text = "TECH"
	tech_label.add_theme_font_size_override("font_size", 14)
	tech_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
	tech_container.add_child(tech_label)

	tech_bar = ProgressBar.new()
	tech_bar.custom_minimum_size = Vector2(220, 20)
	tech_bar.max_value = PlayerStats.MAX_TECH
	tech_bar.value = PlayerStats.tech
	tech_bar.show_percentage = false

	var tech_fill := StyleBoxFlat.new()
	tech_fill.bg_color = Color(0.15, 0.4, 0.95)
	tech_fill.corner_radius_top_left = 3
	tech_fill.corner_radius_bottom_left = 3
	tech_fill.corner_radius_top_right = 3
	tech_fill.corner_radius_bottom_right = 3
	tech_bar.add_theme_stylebox_override("fill", tech_fill)

	var tech_bg := StyleBoxFlat.new()
	tech_bg.bg_color = Color(0.05, 0.05, 0.2)
	tech_bg.corner_radius_top_left = 3
	tech_bg.corner_radius_bottom_left = 3
	tech_bg.corner_radius_top_right = 3
	tech_bg.corner_radius_bottom_right = 3
	tech_bar.add_theme_stylebox_override("background", tech_bg)

	tech_container.add_child(tech_bar)

	# --- Death Overlay ---
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.1, 0.0, 0.0, 0.7)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	add_child(death_overlay)

	death_label = Label.new()
	death_label.text = "YOU DIED"
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.position.y = -50
	death_overlay.add_child(death_label)

	revive_label = Label.new()
	revive_label.text = "MASH [F] TO REVIVE"
	revive_label.add_theme_font_size_override("font_size", 24)
	revive_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_label.set_anchors_preset(Control.PRESET_CENTER)
	revive_label.position.y = 30
	death_overlay.add_child(revive_label)


func _play_start_blood_effect() -> void:
	var effect := Control.new()
	effect.name = "StartBloodEffect"
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.z_index = 100
	add_child(effect)
	var wash := ColorRect.new()
	wash.color = Color(0.65, 0.015, 0.025, 0.42)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_child(wash)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for i in range(7):
		var x: float = viewport_size.x * (float(i) + 0.5) / 7.0
		var width: float = viewport_size.x * 0.055
		var length: float = viewport_size.y * (0.08 + float((i * 3) % 5) * 0.025)
		var drip := ColorRect.new()
		drip.color = Color(0.35, 0.0, 0.012, 0.72)
		drip.position = Vector2(x, 0.0)
		drip.size = Vector2(width, length)
		drip.pivot_offset = Vector2(width * 0.5, 0.0)
		drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect.add_child(drip)
	var tween := create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(effect.queue_free)


func _on_health_changed(value: float) -> void:
	health_bar.value = value
	health_label.text = "HEALTH: %d" % int(value)


func _on_tech_changed(value: float) -> void:
	tech_bar.value = value
	tech_label.text = "TECH: %d" % int(value)


func _on_player_died() -> void:
	death_overlay.visible = true


func _on_player_revived() -> void:
	death_overlay.visible = false
