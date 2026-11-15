# dialog_manager.gd — Autoload named "DialogManager"
extends CanvasLayer

signal dialog_finished()

var is_active: bool = false
var current_lines: Array[String] = []
var current_line_index: int = 0

# UI elements
var bg_rect: ColorRect
var name_label: Label
var text_label: Label
var continue_label: Label
var text_timer: float = 0.0
var full_text: String = ""
var displayed_chars: int = 0
const CHARS_PER_SECOND: float = 40.0


func _ready() -> void:
	layer = 50
	_build_ui()
	visible = false


func _build_ui() -> void:
	# Dim background
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0, 0, 0, 0.5)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_rect)

	# Dialog box
	var box := Panel.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -180
	box.offset_bottom = -20
	box.offset_left = 40
	box.offset_right = -40

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.05, 0.05, 0.12, 0.95)
	box_style.border_color = Color(0.2, 0.5, 1.0)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(4)
	box_style.set_content_margin_all(15)
	box.add_theme_stylebox_override("panel", box_style)
	add_child(box)

	# Speaker name
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	name_label.position = Vector2(55, -170)
	add_child(name_label)

	# Dialog text
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	text_label.offset_top = -140
	text_label.offset_bottom = -50
	text_label.offset_left = 60
	text_label.offset_right = -60
	add_child(text_label)

	# Continue prompt
	continue_label = Label.new()
	continue_label.text = "▼ Click to continue"
	continue_label.add_theme_font_size_override("font_size", 14)
	continue_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	continue_label.offset_top = -50
	continue_label.offset_bottom = -25
	continue_label.offset_left = -200
	continue_label.offset_right = -50
	continue_label.visible = false
	add_child(continue_label)


func show_dialog(speaker: String, lines: Array[String]) -> void:
	"""Call this to start a dialog sequence. Pauses the game tree."""
	current_lines = lines
	current_line_index = 0
	is_active = true
	name_label.text = speaker
	visible = true

	# Pause game
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	_show_current_line()


func _show_current_line() -> void:
	if current_line_index >= current_lines.size():
		_end_dialog()
		return

	full_text = current_lines[current_line_index]
	displayed_chars = 0
	text_label.text = ""
	continue_label.visible = false
	text_timer = 0.0


func _process(delta: float) -> void:
	if not is_active:
		return

	# Typewriter effect
	if displayed_chars < full_text.length():
		text_timer += delta
		var chars_to_show := int(text_timer * CHARS_PER_SECOND)
		if chars_to_show > displayed_chars:
			displayed_chars = mini(chars_to_show, full_text.length())
			text_label.text = full_text.substr(0, displayed_chars)
	else:
		continue_label.visible = true
		# Blink
		continue_label.modulate.a = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_advance()


func _advance() -> void:
	if displayed_chars < full_text.length():
		# Skip to end of current line
		displayed_chars = full_text.length()
		text_label.text = full_text
	else:
		# Next line
		current_line_index += 1
		_show_current_line()


func _end_dialog() -> void:
	is_active = false
	visible = false
	get_tree().paused = false
	emit_signal("dialog_finished")


# ============================================
# PRESET DIALOGS — Call these from level scripts
# ============================================

func show_intro_dialog() -> void:
	show_dialog("SYSTEM", [
		"Neural link established. Cybernetic arms online.",
		"Your mission: ascend the Nexus Tower. 4 floors. One way up.",
		"Use your fists for melee (F). Your fingers fire energy rounds. You have to press left mouse to shoot burst rounds.",
		"Your thumb houses a micro-shotgun. (Q) Use it wisely — it costs tech.",
		"Parry enemy attacks with right-click to reflect damage.",
		"Collect CPU parts for health and RAM chips for tech energy.",
		"Good luck. You'll need it."
	])


func show_level_complete_dialog(level_num: int) -> void:
	var lines: Array[String] = []
	match level_num:
		1:
			lines = [
				"Floor 1 cleared. The elevator is unlocked.",
				"Things get harder from here. Stay sharp."
			]
		2:
			lines = [
				"Floor 2 down. You're making good time.",
				"I'm detecting heavier signatures above. Watch yourself."
			]
		3:
			lines = [
				"Floor 3 complete. you got one left.",
				"Whatever is up there... it's big. Stock up on CPU and RAM.",
				"This is it. No turning back."
			]
		4:
			lines = [
				"TARGET ELIMINATED.",
				"Nexus Tower is down for good.",
				"Disconnecting neural link... Return to Hackclub HQ."
			]
	show_dialog("SYSTEM", lines)
