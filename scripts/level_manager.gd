extends Node

signal transition_started()
signal transition_finished()

var overlay: ColorRect
var canvas: CanvasLayer
var is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(9999, 9999)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

func transition_to_level(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	transition_started.emit()

	await fade_to_black(0.5)
	PlayerStats.reset_for_new_level()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_from_black(0.5)

	is_transitioning = false
	transition_finished.emit()

func fade_to_black(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), duration)
	await tween.finished

func fade_from_black(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), duration)
	await tween.finished
