extends Control

var game_engine: Node
var winner_label: Label
var scores_label: Label

func _ready() -> void:
	game_engine = get_node_or_null("../gameEngine")
	_build_screen()
	visible = false
	if game_engine:
		game_engine.game_won.connect(_on_game_won)

func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.08, 0.86)
	add_child(backdrop)

	var panel := Panel.new()
	panel.position = Vector2(650, 340)
	panel.size = Vector2(620, 360)
	add_child(panel)

	var contents := VBoxContainer.new()
	contents.position = Vector2(36, 30)
	contents.size = Vector2(548, 300)
	contents.add_theme_constant_override("separation", 18)
	panel.add_child(contents)

	var title := Label.new()
	title.text = "Game over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	contents.add_child(title)
	winner_label = Label.new()
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 26)
	contents.add_child(winner_label)
	scores_label = Label.new()
	scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(scores_label)

	var restart_button := Button.new()
	restart_button.text = "Restart game"
	restart_button.custom_minimum_size = Vector2(0, 48)
	restart_button.pressed.connect(_on_restart_pressed)
	contents.add_child(restart_button)

func _on_game_won(winner_id: int, cumulative_points: Array) -> void:
	winner_label.text = "Player %d wins!" % (winner_id + 1)
	var score_lines: PackedStringArray = []
	for player_id in cumulative_points.size():
		score_lines.append("Player %d: %d points" % [player_id + 1, cumulative_points[player_id]])
	scores_label.text = "\n".join(score_lines)
	visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()