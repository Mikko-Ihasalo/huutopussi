extends Node
class_name GameplayAI

var game_engine: Node
var player_id: int = -1

func configure(engine: Node, controlled_player_id: int) -> void:
	game_engine = engine
	player_id = controlled_player_id

func get_gameplay_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_gameplay_state"):
		return {}
	return game_engine.get_gameplay_state(player_id)

func choose_card(_state: Dictionary) -> Node2D:
	return null

func choose_trump(_state: Dictionary) -> StringName:
	return &""
