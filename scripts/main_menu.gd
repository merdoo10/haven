extends Control

var title_label: Label
var prompt_label: Label
var pulse_time: float = 0.0
var is_starting: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_menu()

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color(0.015, 0.02, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	title_label = Label.new()
	title_label.text = "HYPER 2093"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.position = Vector2(-400, -100)
	title_label.size = Vector2(800, 140)
	title_label.add_theme_font_size_override("font_size", 76)
	title_label.add_theme_color_override("font_color", Color(0.15, 0.72, 1.0))
	add_child(title_label)

	prompt_label = Label.new()
	prompt_label.text = "PRESS ANY KEY TO START"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-300, 70)
	prompt_label.size = Vector2(600, 50)
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	add_child(prompt_label)

func _process(delta: float) -> void:
	pulse_time += delta
	prompt_label.modulate.a = 0.55 + 0.45 * sin(pulse_time * 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if is_starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_start_game()
	elif event is InputEventJoypadButton and event.pressed:
		_start_game()

func _start_game() -> void:
	is_starting = true
	PlayerStats.start_blood_effect_pending = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.45)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/level_1.tscn")
