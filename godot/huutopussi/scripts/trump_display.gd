extends Label

var game_engine: Node

func _ready() -> void:
	game_engine = get_node_or_null("../gameEngine")
	if game_engine:
		game_engine.round_started.connect(_on_round_started)
		game_engine.trump_changed.connect(_on_trump_changed)
		_update_display()

func _on_round_started() -> void:
	_update_display()

func _on_trump_changed(_suit: StringName, _player_id: int) -> void:
	_update_display()

func _update_display() -> void:
	if not game_engine or game_engine.trump_suit == &"":
		text = "Trump: None"
		return
	text = "Trump: %s" % str(game_engine.trump_suit).capitalize()
