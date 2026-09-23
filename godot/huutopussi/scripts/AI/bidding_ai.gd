extends Node
class_name BiddingAI

var game_engine: Node
var player_id: int = -1

func configure(engine: Node, controlled_player_id: int) -> void:
	game_engine = engine
	player_id = controlled_player_id

func get_bidding_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_bidding_state"):
		return {}
	return game_engine.get_bidding_state(player_id)

func get_hand_creation_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_hand_creation_state"):
		return {}
	return game_engine.get_hand_creation_state(player_id)

func choose_bid(_state: Dictionary) -> int:
	return -1

func choose_discard_cards(_state: Dictionary) -> Array[Node2D]:
	return []

func choose_rebid(_state: Dictionary) -> int:
	return -1
